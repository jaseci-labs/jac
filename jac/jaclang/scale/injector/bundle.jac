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
     TOOLCHAIN_SUBDIR: str = ".jactoolchain",
     DEFAULT_SEAL_TIMEOUT_S: int = 1800,
     PLACEHOLDER_JAC_TOML: str = "[project]\nname = \"app\"\n";

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

    if len(parts) >= 2 and parts[0] == ".jac" and parts[1] == "admin" {
        return False;
    }
    if len(parts) == 2 and parts[0] == ".jac" and parts[1] == "serve_manifest.json" {
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


def det_tar_member(info: tarfile.TarInfo) -> tarfile.TarInfo {
    info.mtime = 0;
    info.uid = 0;
    info.gid = 0;
    info.uname = "";
    info.gname = "";
    return info;
}


def open_det_tar(buf: io.BytesIO) -> tuple[tarfile.TarFile, any] {
    gz = gzip.GzipFile(fileobj=buf, mode="wb", mtime=0);
    return (tarfile.open(fileobj=gz, mode="w"), gz);
}


def nested_sanitized_tomls(base: Path) -> dict[str, str] {
    out: dict[str, str] = {};
    for toml_path in sorted(base.rglob("jac.toml")) {
        rel = toml_path.relative_to(base);
        if len(rel.parts) == 1 or any(part in _EXCLUDE_DIRS for part in rel.parts) {
            continue;
        }
        text = sanitized_jac_toml(toml_path.parent);
        if text is not None {
            out[rel.as_posix()] = text;
        }
    }
    return out;
}


def _stage_app(base: Path, sanitized_toml: (str | None)) -> Path {
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
        stage.mkdir(parents=True, exist_ok=True);
        if sanitized_toml is not None {
            (stage / "jac.toml").write_text(sanitized_toml, encoding="utf-8");
        } else {
            (stage / "jac.toml").write_text(PLACEHOLDER_JAC_TOML, encoding="utf-8");
        }
        for (rel, text) in nested_sanitized_tomls(base).items() {
            dest = stage / Path(rel);
            dest.parent.mkdir(parents=True, exist_ok=True);
            dest.write_text(text, encoding="utf-8");
        }
        marker = stage / "__init__.jac";
        if not marker.exists() {
            marker.write_text("");
        }
        return stage_root;
    } except Exception {
        shutil.rmtree(str(stage_root), ignore_errors=True);
        raise;
    }
}


def _seal_subprocess_env -> dict[str, str] {
    return {
        k: v
        for (k, v) in os.environ.items()
        if k not in ("PYTHONPATH", "PYTHONHOME", "JAC_LLVM_SHIM")
    };
}


def _precompile_app(
    base: Path, seal_binary: bytes, sanitized_toml: (str | None), timeout_s: int
) -> Path {
    stage_root = _stage_app(base, sanitized_toml);
    stage = stage_root / "app";
    try {
        jac_path = stage_root / ".seal-jac";
        jac_path.write_bytes(seal_binary);
        jac_path.chmod(0o755);
        script = Path(str(__file__)).parent.parent.parent
            / "utils"
            / "precompile_bytecode.jac";

        result = subprocess.run(
            [str(jac_path), "run", str(script), str(stage_root), "--seal"],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=_seal_subprocess_env(),
            cwd=str(stage_root)
        );
        jac_path.unlink();
        if (
            result.returncode != 0
            or not (stage / "_precompiled" / "MANIFEST.json").is_file()
        ) {
            raise RuntimeError(
                f"App seal did not complete, so the deploy cannot produce a "
                f".jab: {(result.stderr or result.stdout).strip()[-2000:]}"
            );
        }
        for line in (result.stdout or "").splitlines()[-12:] {
            if line.strip() {
                logger.info(f"seal: {line.strip()}");
            }
        }
        return stage;
    } except Exception {
        shutil.rmtree(str(stage_root), ignore_errors=True);
        raise;
    }
}


def fat_bundle_setting(project_dir: str) -> tuple[bool, bool] {
    import from jaclang.project.config { get_config_for_path }

    try {
        config = get_config_for_path(Path(project_dir));
    } except Exception as exc {
        logger.warning(f"fat_bundle check skipped, jac.toml unparseable: {exc}");
        return (False, False);
    }
    if config is None {
        return (False, False);
    }
    section = config.get_section("scale");
    if section is None or "fat_bundle" not in section {
        return (True, False);
    }
    return (bool(section.get("fat_bundle")), True);
}


def fat_bundle_enabled(project_dir: str) -> bool {
    (enabled, _) = fat_bundle_setting(project_dir);
    return enabled;
}


def seal_timeout_setting(project_dir: str) -> int {
    import from jaclang.project.config { get_config_for_path }

    try {
        config = get_config_for_path(Path(project_dir));
    } except Exception as exc {
        logger.warning(f"seal_timeout check skipped, jac.toml unparseable: {exc}");
        return DEFAULT_SEAL_TIMEOUT_S;
    }
    if config is None {
        return DEFAULT_SEAL_TIMEOUT_S;
    }
    section = config.get_section("scale");
    if section is None or "seal_timeout" not in section {
        return DEFAULT_SEAL_TIMEOUT_S;
    }
    try {
        val = int(section.get("seal_timeout"));
    } except (TypeError, ValueError) {
        logger.warning("Ignoring non-integer [scale] seal_timeout in jac.toml.");
        return DEFAULT_SEAL_TIMEOUT_S;
    }
    return val if val > 0 else DEFAULT_SEAL_TIMEOUT_S;
}


def _pod_wheel_platform(pod_arch: str) -> str {
    if not pod_arch {
        return "";
    }
    return f"manylinux_2_36_{pod_arch}";
}


def _vendor_stage(stage: Path, seal_binary: bytes, platform_tag: str = "") {
    jac_path = stage.parent / ".seal-jac";
    jac_path.write_bytes(seal_binary);
    jac_path.chmod(0o755);
    script = Path(str(__file__)).parent.parent / "utils" / "vendor_wheels.jac";
    cmd = [str(jac_path), "run", str(script), str(stage)];
    if platform_tag {
        cmd.append(platform_tag);
    }
    try {
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=900, env=_seal_subprocess_env()
        );
    } finally {
        jac_path.unlink(missing_ok=True);
    }
    if (result.returncode != 0 or not (stage / "_vendor" / "VENDOR.json").is_file()) {
        raise RuntimeError(
            f"Fat bundle vendoring failed, so the deploy cannot ship offline "
            f"deps: {(result.stderr or result.stdout).strip()[-300:]}"
        );
    }

    for line in f"{result.stdout}\n{result.stderr}".splitlines() {
        if line.strip() {
            logger.info(f"vendor: {line.strip()}");
        }
    }
}


def pack_jab(project_dir: str, seal_binary: bytes, pod_arch: str = "") -> bytes {
    if not seal_binary {
        raise ValueError(
            "pack_jab requires a host-runnable jac binary to seal the app "
            "image; none given."
        );
    }
    base = Path(project_dir).resolve();
    if not base.is_dir() {
        raise ValueError(
            f"App project directory does not exist: {base}. A deploy seals "
            "the project tree; check the code_folder path."
        );
    }
    sanitized = sanitized_jac_toml(base);
    staged = _precompile_app(
        base, seal_binary, sanitized, seal_timeout_setting(project_dir)
    );

    try {
        (fat, fat_explicit) = fat_bundle_setting(project_dir);
        if fat {
            try {
                _vendor_stage(staged, seal_binary, _pod_wheel_platform(pod_arch));
            } except Exception as exc {
                if fat_explicit {
                    raise;
                }

                shutil.rmtree(str(staged / "_vendor"), ignore_errors=True);
                logger.warning(
                    f"Fat bundle vendoring failed; shipping a thin bundle "
                    f"(pods will install python deps from PyPI at boot). "
                    f"Set [scale] fat_bundle = true to make this fatal. {exc}"
                );
            }
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
                pre = staged / "_precompiled";
                count = 0;
                for path in sorted(pre.rglob("*")) {
                    if path.is_file() {
                        rel = path.relative_to(staged);
                        tar.add(str(path), arcname=str(rel), filter=det_tar_member);
                        count += 1;
                    }
                }
                logger.info(
                    f"Sealed {count} precompiled app-module artifacts into the .jab."
                );
                ven = staged / "_vendor";
                if ven.is_dir() {
                    wheel_count = 0;
                    for path in sorted(ven.rglob("*")) {
                        if path.is_file() {
                            rel = path.relative_to(staged);
                            tar.add(str(path), arcname=str(rel), filter=det_tar_member);
                            if path.suffix == ".whl" {
                                wheel_count += 1;
                            }
                        }
                    }
                    logger.info(
                        f"Fat bundle: vendored {wheel_count} wheel(s) into the "
                        f".jab; pods install python deps offline."
                    );
                }
                if sanitized is not None {
                    data = sanitized.encode("utf-8");
                    info = tarfile.TarInfo(name="jac.toml");
                    info.size = len(data);
                    tar.addfile(info, io.BytesIO(data));
                }
                for (toml_rel, toml_text) in nested_sanitized_tomls(base).items() {
                    data = toml_text.encode("utf-8");
                    info = tarfile.TarInfo(name=toml_rel);
                    info.size = len(data);
                    tar.addfile(info, io.BytesIO(data));
                }
            }
        } finally {
            gz.close();
        }
        return buf.getvalue();
    } finally {
        shutil.rmtree(str(staged.parent), ignore_errors=True);
    }
}


def content_address(raw: bytes) -> str {
    return hashlib.sha256(raw).hexdigest();
}


def bundle_object_key(app_name: str, digest: str) -> str {
    return f"bundles/{app_name}/{digest}.jab";
}


def ensure_jac_toml_cmd -> str {
    return (
        f"[ -f {APP_MOUNT_PATH}/jac.toml ] || "
        f"printf '[project]\\nname = \"app\"\\n' > {APP_MOUNT_PATH}/jac.toml"
    );
}
