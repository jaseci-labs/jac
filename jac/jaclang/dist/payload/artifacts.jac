import hashlib;
import json;
import os;
import shutil;
import time;
import from pathlib { Path }
import from jaclang.jac0core.cache_paths { FileLock, atomic_write }

obj ArtifactStore {
    has directory: Path,
        ttl_days: float = 30.0,
        swept: set[str] = set();

    def location(kind: str, key: str) -> Path {
        if not kind.replace("_", "").isalnum()
            or len(key) != 64
            or any(char not in "0123456789abcdef" for char in key) {
            raise ValueError("Invalid build artifact identity");
        }
        return self.directory / kind / key;
    }

    def lock(kind: str, key: str) -> FileLock {
        return FileLock(str(self.location(kind, key)) + ".lock");
    }

    def restore(kind: str, key: str, outputs: dict[str, Path]) -> bool {
        location = self.location(kind, key);
        self.prune(kind, key);
        try {
            manifest = json.loads((location / "manifest.json").read_text());
            if not isinstance(manifest, dict)
                or manifest.get("schema") != 1
                or manifest.get("key") != key {
                return False;
            }
            records = manifest.get("files", {});
            if set(records) != set(outputs) {
                return False;
            }
            images: dict[str, bytes] = {};
            modes: dict[str, int] = {};
            for name in outputs {
                if name in ("", ".", "..") or Path(name).name != name {
                    raise ValueError("Artifact members must be basenames");
                }
                data = (location / name).read_bytes();
                record = records[name];
                if hashlib.sha256(data).hexdigest() != record["sha256"] {
                    return False;
                }
                images[name] = data;
                mode = int(record["mode"]);
                if mode < 0 or mode > 0o777 {
                    return False;
                }
                modes[name] = mode;
            }
            for (name, destination) in outputs.items() {
                atomic_write(destination, images[name], mode=modes[name]);
            }
            try {
                os.utime(location, None);
            } except OSError {}
            return True;
        } except (OSError, ValueError, KeyError, TypeError) {
            return False;
        }
    }

    def publish(kind: str, key: str, outputs: dict[str, Path]) {
        location = self.location(kind, key);
        self.prune(kind, key);
        records: dict[str, dict[str, str | int]] = {};
        for (name, source) in outputs.items() {
            if name in ("", ".", "..") or Path(name).name != name {
                raise ValueError("Artifact members must be basenames");
            }
            data = source.read_bytes();
            mode = source.stat().st_mode & 0o777;
            atomic_write(location / name, data, mode=mode);
            records[name] = {"sha256": hashlib.sha256(data).hexdigest(), "mode": mode};
        }
        atomic_write(
            location / "manifest.json",
            json.dumps(
                {"schema": 1, "key": key, "files": records}, sort_keys=True
            ).encode()
        );
    }

    def prune(kind: str, active_key: str) {
        if kind in self.swept or self.ttl_days <= 0 {
            return;
        }
        self.swept.add(kind);
        directory = self.location(kind, active_key).parent;
        if not directory.is_dir() {
            return;
        }
        cutoff = time.time() - self.ttl_days * 86400;
        for candidate in directory.iterdir() {
            if not candidate.is_dir() or candidate.name == active_key {
                continue;
            }
            try {
                self.location(kind, candidate.name);
                if candidate.stat().st_mtime >= cutoff {
                    continue;
                }
                with FileLock(str(candidate) + ".lock", timeout=0.0) {
                    if candidate.stat().st_mtime < cutoff {
                        shutil.rmtree(candidate);
                    }
                }
            } except (OSError, ValueError) {}
        }
    }
}
