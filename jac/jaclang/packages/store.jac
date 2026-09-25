import hashlib;
import json;
import os;
import shutil;
import from pathlib { Path }
import from jaclang.dist.archive { extract_tar_gz }
import from jaclang.packages.artifact { ArtifactError, expect_identity }
import from jaclang.project.package_scope { store_root }

glob MARKER_NAME: str = ".jac-package.json";

obj StoreError(Exception) {}

def store_path(name: str, version: str, sha256: str) -> Path {
    (org, pkg) = name.split("/", 1);
    return store_root() / org / pkg / f"{version}-{sha256[:12]}";
}

def is_materialized(path: Path, sha256: str) -> bool {
    marker = path / MARKER_NAME;
    if not marker.is_file() {
        return False;
    }
    try {
        return json.loads(marker.read_text(encoding="utf-8")).get("sha256") == sha256;
    } except (OSError, ValueError) {
        return False;
    }
}

def materialize(
    name: str, version: str, sha256: str, data: bytes, source: str
) -> Path {
    import from jaclang.cache.registry { bucket }
    import from jaclang.toolchains.store { InstallLock }
    actual = hashlib.sha256(data).hexdigest();
    if actual != sha256 {
        raise StoreError(
            f"{name} {version}: content sha256 {actual[:16]} does not match the "
            f"recorded {sha256[:16]}"
        );
    }
    dest = store_path(name, version, sha256);
    dest.parent.mkdir(parents=True, exist_ok=True);
    with InstallLock(dest.parent / f".{dest.name}.lock") {
        if is_materialized(dest, sha256) {
            bucket("pkgs").note_hit(dest / MARKER_NAME);
            return dest;
        }
        staging = dest.parent / f".fetch-{os.getpid()}-{dest.name}";
        shutil.rmtree(staging, ignore_errors=True);
        staging.mkdir(parents=True);
        try {
            extract_tar_gz(data, staging);
            expect_identity(staging, name, version);
            (staging / MARKER_NAME).write_text(
                json.dumps(
                    {
                        "name": name,
                        "version": version,
                        "sha256": sha256,
                        "source": source
                    },
                    sort_keys=True
                ),
                encoding="utf-8"
            );
            shutil.rmtree(dest, ignore_errors=True);
            staging.rename(dest);
        } except ArtifactError as e {
            raise StoreError(str(e));
        } finally {
            shutil.rmtree(staging, ignore_errors=True);
        }
    }
    bucket("pkgs").note_hit(dest / MARKER_NAME);
    return dest;
}

def cached(name: str, version: str, sha256: str) -> Path | None {
    path = store_path(name, version, sha256);
    return path if is_materialized(path, sha256) else None;
}
