import io;
import os;
import gzip;
import hashlib;
import logging;
import shutil;
import subprocess;
import tarfile;
import tempfile;
import tomllib;
import from pathlib { Path }

glob logger = logging.getLogger(__name__);

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


"""Materialize the database backend the deploy provisions into the shipped
manifest. The deployer injects the connection URI (e.g. MONGODB_URI) into
every service pod, so the pod's `jac install` must close over the matching
data capability; a project with no declared [plugins.scale.*] intent would
otherwise boot straight into an ImportError (#7137). scale_intent_from_config
prefers a top-level [scale] table over [plugins.scale], so the appended
section follows whichever form the project uses."""
def bake_database_intent(toml_text: str, backend: str) -> str {
    if not backend {
        return toml_text;
    }
    try {
        data = tomllib.loads(toml_text);
    } except tomllib.TOMLDecodeError as exc {
        logger.warning(
            f"Sanitized jac.toml is not parseable ({exc}); shipping it without "
            f"the provisioned '{backend}' database intent -- the pod's install "
            f"may miss the matching data capability."
        );
        return toml_text;
    }
    scale = data.get("scale");
    uses_scale_table = isinstance(scale, dict);
    if not uses_scale_table {
        plugins = data.get("plugins");
        scale = plugins.get("scale") if isinstance(plugins, dict) else None;
    }
    if isinstance(scale, dict) and isinstance(scale.get("database"), dict) {
        return toml_text;
    }
    header = "scale.database" if uses_scale_table else "plugins.scale.database";
    return f'{toml_text}\n[{header}]\nbackend = "{backend}"\n';
}


def sanitized_jac_toml(base: Path, provisioned_database: str = "") -> (str | None) {
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
    return bake_database_intent("\n".join(out) + "\n", provisioned_database);
}


def det_tar_member(info: tarfile.TarInfo) -> tarfile.TarInfo {
    # Bundles are content-addressed; wall-clock mtimes and uid/gid would give
    # identical content a new digest every deploy, defeating seed skip-if-present.
    info.mtime = 0;
    info.uid = 0;
    info.gid = 0;
    info.uname = "";
    info.gname = "";
    return info;
}


def open_det_tar(buf: io.BytesIO) -> tuple[tarfile.TarFile, any] {
    # gzip stamps the current time into its header - zero it for determinism.
    gz = gzip.GzipFile(fileobj=buf, mode="wb", mtime=0);
    return (tarfile.open(fileobj=gz, mode="w"), gz);
}


def _precompile_app(base: Path, pod_binary: bytes) -> (Path | None) {
    # Precompile the app's modules with the POD binary so pods load content-keyed
    # .jir from _precompiled/ instead of cold-compiling on first boot (#7179).
    # Best-effort by design: any failure means pods compile exactly as before.
    stage_root = Path(tempfile.mkdtemp(prefix="jac-app-precompile-"));
    stage = stage_root / "app";
    try {
        for path in sorted(base.rglob("*")) {
            if not path.is_file() or is_excluded(path.relative_to(base)) {
                continue;
            }
            dest = stage / path.relative_to(base);
            dest.parent.mkdir(parents=True, exist_ok=True);
            shutil.copy2(str(path), str(dest));
        }
        # The precompiler discovers a package by its __init__; app projects are
        # flat, so mark the staged copy (the marker's .jir is not packed).
        marker = stage / "__init__.jac";
        added_marker = not marker.exists();
        if added_marker {
            marker.write_text("");
        }
        jac_path = stage_root / ".pod-jac";
        jac_path.write_bytes(pod_binary);
        jac_path.chmod(0o755);
        script = Path(str(__file__)).parent.parent.parent / "utils" / "precompile_bytecode.jac";
        result = subprocess.run(
            [str(jac_path), "run", str(script), str(stage_root)],
            capture_output=True,
            text=True,
            timeout=600
        );
        jac_path.unlink();
        # Guarded: py3.11's rglob raises on a missing dir, which would mask the returncode diagnostics below.
        if added_marker and (stage / "_precompiled").is_dir() {
            for junk in (stage / "_precompiled").rglob("__init__.jir") {
                junk.unlink();
            }
        }
        if result.returncode != 0 or not (stage / "_precompiled").is_dir() {
            logger.warning(
                f"App precompile with the pod binary did not complete "
                f"({(result.stderr or result.stdout).strip()[-300:]}); pods will "
                f"compile on first boot."
            );
            shutil.rmtree(str(stage_root), ignore_errors=True);
            return None;
        }
        return stage;
    } except Exception as e {
        logger.warning(f"App precompile skipped ({e}); pods will compile on boot.");
        shutil.rmtree(str(stage_root), ignore_errors=True);
        return None;
    }
}


def pack_source(
    project_dir: str, provisioned_database: str = "", pod_binary: bytes = b""
) -> bytes {
    base = Path(project_dir).resolve();
    staged: (Path | None) = None;
    if pod_binary {
        staged = _precompile_app(base, pod_binary);
    }
    buf = io.BytesIO();
    (tar, gz) = open_det_tar(buf);
    try {
        with tar {
            for path in sorted(base.rglob("*")) {
                if not path.is_file() {
                    continue;
                }
                rel = path.relative_to(base);
                if is_excluded(rel) {
                    continue;
                }
                tar.add(str(path), arcname=str(rel), filter=det_tar_member);
            }
            if staged is not None {
                pre = staged / "_precompiled";
                count = 0;
                for path in sorted(pre.rglob("*")) {
                    if path.is_file() {
                        rel = path.relative_to(staged);
                        tar.add(str(path), arcname=str(rel), filter=det_tar_member);
                        count += 1;
                    }
                }
                logger.info(f"Bundled {count} precompiled app-module artifacts.");
                # staged is <stage_root>/app; remove the whole mkdtemp tree, not just the child.
                shutil.rmtree(str(staged.parent), ignore_errors=True);
            }
            sanitized = sanitized_jac_toml(base, provisioned_database);
            if sanitized is not None {
                data = sanitized.encode("utf-8");
                info = tarfile.TarInfo(name="jac.toml");
                info.size = len(data);
                tar.addfile(info, io.BytesIO(data));
            }
        }
    } finally {
        gz.close();
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
