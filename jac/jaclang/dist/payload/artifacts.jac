import hashlib;
import json;
import from pathlib { Path }
import from jaclang.jac0core.cache_paths { FileLock, atomic_write }

obj ArtifactStore {
    has directory: Path;

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
        try {
            manifest = json.loads((location / "manifest.json").read_text());
            if manifest.get("schema") != 1 or manifest.get("key") != key {
                return False;
            }
            records = manifest.get("files", {});
            if set(records) != set(outputs) {
                return False;
            }
            images: dict[str, bytes] = {};
            for name in outputs {
                if Path(name).name != name {
                    raise ValueError("Artifact members must be basenames");
                }
                data = (location / name).read_bytes();
                record = records[name];
                if hashlib.sha256(data).hexdigest() != record["sha256"] {
                    return False;
                }
                images[name] = data;
            }
            for (name, destination) in outputs.items() {
                atomic_write(
                    destination, images[name], mode=int(records[name]["mode"])
                );
            }
            return True;
        } except (OSError, ValueError, KeyError, TypeError) {
            return False;
        }
    }

    def publish(kind: str, key: str, outputs: dict[str, Path]) {
        location = self.location(kind, key);
        records: dict[str, dict[str, str | int]] = {};
        for (name, source) in outputs.items() {
            if Path(name).name != name {
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
}
