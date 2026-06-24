"""Reusable source bundling: pack a project into a tar.gz, content-address it,
and resolve the in-pod install specs.

Transport-independent: the PvcInjector places the bundle on a shared PVC, but the
packing rules (exclude build artifacts and secrets, sanitize jac.toml) are the
same regardless of how the bytes travel. Content-addressing the archive by sha256
gives immutable, cacheable bundle keys so a pod restart can never read a mutated
bundle.
"""

import io;
import hashlib;
import tarfile;
import from pathlib { Path }

# Pod-side contract shared with the injector's init container.
glob SOURCE_ARCHIVE_NAME: str = "source.tar.gz",
     SOURCE_VOLUME_NAME: str = "jac-source",
     SOURCE_MOUNT_PATH: str = "/jac-src",
     APP_VOLUME_NAME: str = "jac-app",
     APP_MOUNT_PATH: str = "/app",
     PYDEPS_DIR: str = "/app/.pydeps";

# Directories never shipped into the cluster: build output, caches, vendored
# deps, VCS metadata, virtualenvs.
glob _EXCLUDE_DIRS: set[str] = {
         ".jac",
         "__pycache__",
         "node_modules",
         ".git",
         "dist",
         "build",
         ".venv",
         "venv",
         ".mypy_cache",
         ".pytest_cache"
     };
# Secret-bearing files are never packed. The raw jac.toml is excluded (it can
# hold creds under [plugins.scale]); a [plugins.scale]-stripped copy is added
# back by pack_source so pods still get the app + client-build config.
glob _EXCLUDE_FILES: set[str] = {
         ".env",
         "jac.toml",
         "id_rsa",
         "id_dsa",
         "id_ecdsa",
         "id_ed25519"
     };
glob _EXCLUDE_SUFFIXES: tuple = (
         ".pem",
         ".key",
         ".crt",
         ".cer",
         ".p12",
         ".pfx",
         ".jks",
         ".keystore"
     );


"""True if `rel` (a project-relative Path) is a build artifact or secret file
that must not be packed into the bundle."""
def is_excluded(rel: Path) -> bool {
    for part in rel.parts {
        if part in _EXCLUDE_DIRS {
            return True;
        }
    }
    name = rel.name;
    if name in _EXCLUDE_FILES {
        return True;
    }
    if name == ".env" or name.startswith(".env.") {
        return True;
    }
    if name.endswith(_EXCLUDE_SUFFIXES) {
        return True;
    }
    return False;
}


"""The project's jac.toml with the [plugins.scale...] tables (deploy creds)
removed, or None when there's no jac.toml."""
def sanitized_jac_toml(base: Path) -> (str | None) {
    src = base / "jac.toml";
    if not src.is_file() {
        return None;
    }
    out: list[str] = [];
    skipping = False;
    for line in src.read_text().splitlines() {
        stripped = line.lstrip();
        if stripped.startswith("[") {
            header = stripped.lstrip("[").rstrip().rstrip("]").strip();
            skipping = header == "plugins.scale" or header.startswith("plugins.scale.");
            if skipping {
                continue;
            }
        } elif stripped == "plugins.scale" or stripped.startswith("plugins.scale.") {
            continue;
        }
        if not skipping {
            out.append(line);
        }
    }
    return "\n".join(out) + "\n";
}


"""Tar+gzip the project dir (excluding build artifacts + secret files) into raw
bytes, appending a sanitized jac.toml. Deterministic for a given tree so the
content address is stable."""
def pack_source(project_dir: str) -> bytes {
    base = Path(project_dir).resolve();
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        for path in sorted(base.rglob("*")) {
            if not path.is_file() {
                continue;
            }
            rel = path.relative_to(base);
            if is_excluded(rel) {
                continue;
            }
            tar.add(str(path), arcname=str(rel));
        }
        sanitized = sanitized_jac_toml(base);
        if sanitized is not None {
            data = sanitized.encode("utf-8");
            info = tarfile.TarInfo(name="jac.toml");
            info.size = len(data);
            tar.addfile(info, io.BytesIO(data));
        }
    }
    return buf.getvalue();
}


"""sha256 hex digest of the bundle bytes; the immutable content address."""
def content_address(raw: bytes) -> str {
    return hashlib.sha256(raw).hexdigest();
}


"""Object-store key for a bundle: namespaced by app, addressed by digest, so the
same content reuses the same key and a changed tree gets a new one."""
def bundle_object_key(app_name: str, digest: str) -> str {
    return f"bundles/{app_name}/{digest}.tar.gz";
}


"""In-pod pip specs, pinned to the versions the developer ran. `requests` is a
runtime dep of the scale plugin shipped only in the test extra, so it (and the
[all] deploy extras) must be installed explicitly. jac-client is added only when
present locally (fullstack apps)."""
def pinned_install_specs -> list[str] {
    import importlib.metadata as _md;
    specs: list[str] = [];
    targets: list[tuple[str, str, bool]] = [
        ("jaclang", "jaclang", True),
        ("jac-scale[all]", "jac-scale", True),
        ("requests", "requests", True),
        ("jac-client", "jac-client", False)
    ];
    for (pip_name, dist_name, required) in targets {
        try {
            specs.append(f"{pip_name}=={_md.version(dist_name)}");
        } except Exception {
            if required {
                specs.append(pip_name);
            }
        }
    }
    return specs;
}


"""Shell snippet writing a stub jac.toml when the bundle lacks one (the real
jac.toml is excluded; `jac start <svc>.jac` still requires a project toml)."""
def ensure_jac_toml_cmd -> str {
    return (
        f"[ -f {APP_MOUNT_PATH}/jac.toml ] || "
        f"printf '[project]\\nname = \"app\"\\n' > {APP_MOUNT_PATH}/jac.toml"
    );
}
