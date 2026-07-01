import io;
import hashlib;
import tarfile;
import from pathlib { Path }

glob APP_VOLUME_NAME: str = "jac-app",
     APP_MOUNT_PATH: str = "/app",
     JAC_HOME: str = "/app/.jachome",
     TOOLCHAIN_SUBDIR: str = ".jactoolchain";

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


def is_excluded(rel: Path) -> bool {
    parts = rel.parts;
    if (
        len(parts) >= 3
        and parts[0] == ".jac"
        and parts[1] == "client"
        and parts[2] == "dist"
    ) {
        return False;
    }
    for part in parts {
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


def _is_secret_path(name: str) -> bool {
    return name == "plugins.scale.secrets"
    or name.startswith("plugins.scale.secrets.")
    or name == "scale.secrets"
    or name.startswith("scale.secrets.");
}


def _is_dev_section(name: str) -> bool {
    return name == "dev" or name.startswith("dev.");
}


def sanitized_jac_toml(base: Path) -> (str | None) {
    src = base / "jac.toml";
    if not src.is_file() {
        return None;
    }
    out: list[str] = [];
    pending: list[str] = [];
    in_stripped_section = False;
    current_section = "";
    for line in src.read_text().splitlines() {
        stripped = line.lstrip();
        if stripped.startswith("[") {
            header = stripped.lstrip("[").split("]")[0].strip();
            in_stripped_section = _is_secret_path(header) or _is_dev_section(header);
            current_section = header;
            if in_stripped_section {
                pending = [];
                continue;
            }
            out.extend(pending);
            pending = [];
            out.append(line);
            continue;
        }
        if in_stripped_section {
            continue;
        }
        if stripped == "" or stripped.startswith("#") {
            pending.append(line);
            continue;
        }
        key = stripped.split("=")[0].strip();
        full_key = key if current_section == "" else f"{current_section}.{key}";
        if _is_secret_path(full_key) {
            pending = [];
            continue;
        }
        out.extend(pending);
        pending = [];
        out.append(line);
    }
    out.extend(pending);
    return "\n".join(out) + "\n";
}


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


def content_address(raw: bytes) -> str {
    return hashlib.sha256(raw).hexdigest();
}


def bundle_object_key(app_name: str, digest: str) -> str {
    return f"bundles/{app_name}/{digest}.tar.gz";
}


def ensure_jac_toml_cmd -> str {
    return (
        f"[ -f {APP_MOUNT_PATH}/jac.toml ] || "
        f"printf '[project]\\nname = \"app\"\\n' > {APP_MOUNT_PATH}/jac.toml"
    );
}
