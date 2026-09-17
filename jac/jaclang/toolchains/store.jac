import hashlib;
import json;
import os;
import re;
import shutil;
import tarfile;
import tempfile;
import time;
import zipfile;
import from pathlib { Path }
import from http.client { HTTPResponse }
import from urllib.request { Request, urlopen }
import from urllib.parse { urlsplit }
import from jaclang.cli.console { console }
import from jaclang.cache.registry { bucket, family_root, maybe_sweep }

obj Artifact {
    has name: str,
        version: str,
        platform: str,
        url: str,
        digest: str,
        algorithm: str = "sha256",
        headers: dict[str, str] = {};

    def key -> str {
        for value in [self.name, self.version, self.platform] {
            if not re.fullmatch(r"[A-Za-z0-9_.+\-]+", value) or value in [".", ".."] {
                raise ValueError(f"Invalid toolchain identifier: {value}");
            }
        }
        if self.algorithm not in ["sha256", "sha1"] {
            raise ValueError("Unsupported artifact digest algorithm");
        }
        width = 64 if self.algorithm == "sha256" else 40;
        if not re.fullmatch(f"[a-f0-9]{{{width}}}", self.digest) {
            raise ValueError(f"Invalid {self.algorithm} digest for {self.name}");
        }
        return f"{self.name}/{self.version}/{self.platform}-{self.digest[:16]}";
    }
}

def cache_root -> Path {
    return family_root("toolchains");
}

def offline -> bool {
    return os.environ.get("JAC_OFFLINE", "").lower() in ["1", "true", "yes"];
}

obj InstallLock {
    has path: Path,
        handle: int = -1;

    def __enter__ -> InstallLock {
        self.path.parent.mkdir(parents=True, exist_ok=True);
        self.handle = os.open(str(self.path), os.O_CREAT | os.O_RDWR, 0o600);
        try {
            if os.name == "nt" and os.fstat(self.handle).st_size == 0 {
                os.write(self.handle, b"0");
            }
            start = time.monotonic();
            announced = False;
            while True {
                try {
                    if os.name == "nt" {
                        import msvcrt;
                        os.lseek(self.handle, 0, 0);
                        msvcrt.locking(self.handle, msvcrt.LK_NBLCK, 1);
                    } else {
                        import fcntl;
                        fcntl.flock(self.handle, fcntl.LOCK_EX | fcntl.LOCK_NB);
                    }
                    break;
                } except OSError {
                    if not announced {
                        console.print(
                            f"Waiting for another build to finish using {self.path.name}",
                            style="muted"
                        );
                        announced = True;
                    }
                    if time.monotonic() - start > 1800 {
                        raise TimeoutError(f"Timed out waiting for {self.path}");
                    }
                    time.sleep(0.1);
                }
            }
        } except Exception {
            os.close(self.handle);
            self.handle = -1;
            raise;
        }
        return self;
    }

    def __exit__(_exc_type: object, _exc_value: object, _traceback: object) {
        os.close(self.handle);
        self.handle = -1;
    }
}

def file_digest(path: Path, algorithm: str = "sha256") -> str {
    digest = hashlib.new(algorithm);
    with path.open("rb") as source {
        while chunk := source.read(1024 * 1024) {
            digest.update(chunk);
        }
    }
    return digest.hexdigest();
}

def fetch(
    artifact: Artifact,
    destination: Path | None = None,
    bucket_name: str = "toolchains-downloads"
) -> Path {
    artifact.key();
    if destination is None {
        destination = bucket("toolchains-downloads").path()
            / f"{artifact.algorithm}-{artifact.digest}";
        bucket_name = "toolchains-downloads";
    }
    with InstallLock(destination.with_suffix(".lock")) {
        if destination.is_file()
            and file_digest(destination, artifact.algorithm) == artifact.digest {
            console.print(
                f"Using cached {artifact.name} {artifact.version}", style="muted"
            );
            bucket(bucket_name).note_hit(destination);
            return destination;
        }
        if offline() {
            raise RuntimeError(
                f"{artifact.name} {artifact.version} is not cached. Disable JAC_OFFLINE and run setup first."
            );
        }
        if not allowed_url(artifact.url) {
            raise ValueError("Toolchain downloads require HTTPS");
        }
        part = destination.with_suffix(".part");
        for attempt in range(3) {
            console.print(
                f"Downloading {artifact.name} {artifact.version} ({artifact.platform})"
            );
            try {
                request = Request(
                    artifact.url,
                    headers={"User-Agent": "Jac-toolchains", ** artifact.headers}
                );
                opened: HTTPResponse = urlopen(request, timeout=60);
                with opened as response {
                    if not allowed_url(response.geturl()) {
                        raise ValueError(
                            "Toolchain download redirected away from HTTPS"
                        );
                    }
                    total = int(response.headers.get("Content-Length", "0"));
                    received = 0;
                    last = 0.0;
                    with part.open("wb") as output {
                        while chunk := response.read(1024 * 1024) {
                            output.write(chunk);
                            received += len(chunk);
                            now = time.monotonic();
                            if now - last >= 2.0 {
                                progress = format_size(received);
                                if total {
                                    progress += f" / {format_size(total)} ({received
                                        * 100
                                        // total}%)";
                                }
                                console.print(
                                    f"  {artifact.name}: {progress}", style="muted"
                                );
                                last = now;
                            }
                        }
                    }
                    if total and received != total {
                        raise OSError(
                            f"Incomplete download: {received} of {total} bytes"
                        );
                    }
                }
                if file_digest(part, artifact.algorithm) != artifact.digest {
                    raise ValueError(
                        f"Checksum mismatch for {artifact.name} {artifact.version}"
                    );
                }
                part.replace(destination);
                console.print(
                    f"Verified {artifact.name}: {format_size(received)}",
                    style="success"
                );
                maybe_sweep(bucket_name);
                return destination;
            } except Exception {
                part.unlink(missing_ok=True);
                if attempt == 2 {
                    raise;
                }
                console.print(
                    f"Retrying {artifact.name} download ({attempt + 2}/3)",
                    style="muted"
                );
            }
        }
    }
    raise RuntimeError(f"Could not download {artifact.name}");
}

def extract(archive: Path, destination: Path) {
    destination.mkdir(parents=True, exist_ok=True);
    if zipfile.is_zipfile(archive) {
        with zipfile.ZipFile(archive) as bundle {
            for member in bundle.infolist() {
                name = member.filename.replace("\\", "/");
                target = (destination / name).resolve();
                if not target.is_relative_to(destination.resolve()) or ":" in name {
                    raise ValueError(f"Unsafe archive member: {name}");
                }
                mode = member.external_attr >> 16;
                if mode & 0o170000 == 0o120000 {
                    raise ValueError(f"Zip symlinks are not supported: {name}");
                }
                if member.is_dir() {
                    target.mkdir(parents=True, exist_ok=True);
                } else {
                    target.parent.mkdir(parents=True, exist_ok=True);
                    with bundle.open(member) as source {
                        with target.open("wb") as output {
                            shutil.copyfileobj(source, output);
                        }
                    }
                    target.chmod(0o755 if mode & 0o111 else 0o644);
                }
            }
        }
    } else {
        with tarfile.open(archive) as bundle {
            bundle.extractall(destination, filter="data");
        }
    }
}

def install(artifact: Artifact, required: str) -> Path {
    key = artifact.key();
    destination = bucket("toolchains-installed").path() / key;
    if Path(required).is_absolute() or ".." in Path(required).parts {
        raise ValueError("Installation marker must be a relative path");
    }
    with InstallLock(destination.with_suffix(".lock")) {
        if (destination / required).exists() and slot_installed(destination) {
            console.print(
                f"Using {artifact.name} {artifact.version} at {destination}",
                style="muted"
            );
            return destination;
        }
        archive = fetch(artifact);
        destination.parent.mkdir(parents=True, exist_ok=True);
        with tempfile.TemporaryDirectory(
            prefix=".install-", dir=destination.parent
        ) as tmp {
            staged = Path(tmp) / "payload";
            console.print(
                f"Extracting {artifact.name} {artifact.version}", style="muted"
            );
            extract(archive, staged);
            if not (staged / required).exists() {
                raise RuntimeError(f"{artifact.name} archive is missing {required}");
            }
            (staged / _marker("toolchains-installed")).write_text(
                json.dumps(
                    {
                        "name": artifact.name,
                        "version": artifact.version,
                        "platform": artifact.platform,
                        "digest": artifact.digest,
                        "algorithm": artifact.algorithm,
                        "url": artifact.url
                    },
                    indent=2
                )
            );
            if destination.exists() {
                shutil.rmtree(destination);
            }
            staged.replace(destination);
        }
        console.print(f"Ready: {artifact.name} {artifact.version}", style="success");
        maybe_sweep("toolchains-installed");
    }
    return destination;
}

def _marker(bucket_name: str) -> str {
    return bucket(bucket_name).policy.markers[0];
}

def build_slot(name: str, host: str, digest: str) -> Path {
    return bucket("toolchains-build").path() / name / host / digest;
}

def slot_ready(slot: Path) -> bool {
    if not (slot / _marker("toolchains-build")).is_file() {
        return False;
    }
    bucket("toolchains-build").note_hit(slot);
    return True;
}

def publish_build_slot(staged: Path, slot: Path) {
    (staged / _marker("toolchains-build")).touch();
    slot.parent.mkdir(parents=True, exist_ok=True);
    if slot.exists() {
        shutil.rmtree(slot);
    }
    staged.replace(slot);
    maybe_sweep("toolchains-build");
}

def install_slot(name: str, version: str, platform: str) -> Path {
    return bucket("toolchains-installed").path() / name / version / platform;
}

def slot_installed(slot: Path) -> bool {
    if not (slot / _marker("toolchains-installed")).is_file() {
        return False;
    }
    bucket("toolchains-installed").note_hit(slot);
    return True;
}

def publish_install_slot(slot: Path, meta: dict[str, str]) {
    (slot / _marker("toolchains-installed")).write_text(json.dumps(meta, indent=2));
    maybe_sweep("toolchains-installed");
}


def format_size(size: int) -> str {
    if size < 1024 {
        return f"{size} B";
    }
    if size < 1048576 {
        return f"{size // 1024} KiB";
    }
    return f"{size // 1048576} MiB";
}


def allowed_url(url: str) -> bool {
    parsed = urlsplit(url);
    return parsed.scheme == "https"
        or (
            parsed.scheme == "http"
            and parsed.hostname in ["127.0.0.1", "::1", "localhost"]
        );
}
