import io;
import os;
import errno;
import gzip;
import hashlib;
import json;
import logging;
import shutil;
import subprocess;
import tarfile;
import tempfile;
import tomllib;
import from pathlib { Path }
import from jaclang.scale.injector.binary { ResolvedToolchain, host_platform }

glob logger = logging.getLogger(__name__);

glob APP_VOLUME_NAME: str = "jac-app",
     APP_MOUNT_PATH: str = "/app",
     JAC_HOME: str = "/app/.jachome";

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


def _write_run_shim(dir_: Path, module: str) -> Path {
    shim = dir_ / ("__" + module.split(".")[-1] + "_shim.jac");
    shim.write_text(
        "import from " + module + " { main }\n\nwith entry { main(); }\n",
        encoding="utf-8"
    );
    return shim;
}


def _run_toolchain_script(
    toolchain: ResolvedToolchain,
    workdir: Path,
    module: str,
    args: list[str],
    timeout: int,
    what: str
) -> any {
    import time;
    exec_bin = toolchain.exec_path();
    shim = _write_run_shim(workdir, module);
    try {
        for attempt in range(3) {
            try {
                result = subprocess.run(
                    [str(exec_bin), "run", str(shim)] + args,
                    capture_output=True,
                    text=True,
                    timeout=timeout
                );
            } except OSError as e {
                if e?.errno == errno.ENOEXEC {
                    raise RuntimeError(
                        f"The driver host ({host_platform()}) cannot execute "
                        f"the jac binary at {exec_bin} for the {what}. Point "
                        f"JAC_SCALE_BINARY_PATH at a binary built for this "
                        f"host; the pod binary is downloaded separately for "
                        f"the cluster's arch."
                    );
                }
                raise;
            }

            transient = result.returncode != 0
                and "runtime bring-up failed" in (result.stderr or "");
            if not transient or attempt == 2 {
                return result;
            }
            logger.warning(
                f"jac launcher bring-up transiently failed during the {what} "
                f"(attempt {attempt + 1}); retrying: "
                f"{(result.stderr or '').strip()[-200:]}"
            );
            time.sleep(0.5 * (attempt + 1));
        }
    } finally {
        shim.unlink(missing_ok=True);
    }
}


def _precompile_app(base: Path, toolchain: ResolvedToolchain) -> Path {
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

        marker = stage / "__init__.jac";
        if not marker.exists() {
            marker.write_text("");
        }

        result = _run_toolchain_script(
            toolchain,
            stage_root,
            "jaclang.utils.precompile_bytecode",
            [str(stage_root), "--seal"],
            600,
            "app seal"
        );
        if (
            result.returncode != 0
            or not (stage / "_precompiled" / "MANIFEST.json").is_file()
        ) {
            raise RuntimeError(
                f"App seal did not complete, so the deploy cannot produce a "
                f".jab: {(result.stderr or result.stdout).strip()[-300:]}"
            );
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


def _vendor_stage(
    stage: Path, sanitized_toml: (str | None), toolchain: ResolvedToolchain
) {
    if sanitized_toml is not None {
        (stage / "jac.toml").write_text(sanitized_toml, encoding="utf-8");
    }
    cross = toolchain.ship_platform != ""
        and toolchain.channel != "local"
        and toolchain.ship_platform != host_platform();
    args = [str(stage)];
    if cross {
        args.append(f"--platform={toolchain.ship_platform}");
    }
    result = _run_toolchain_script(
        toolchain,
        stage.parent,
        "jaclang.scale.utils.vendor_wheels",
        args,
        900,
        "fat-bundle vendoring"
    );
    manifest = stage / "_vendor" / "VENDOR.json";
    if result.returncode != 0 or not manifest.is_file() {
        raise RuntimeError(
            f"Fat bundle vendoring failed, so the deploy cannot ship offline "
            f"deps: {(result.stderr or result.stdout).strip()[-300:]}"
        );
    }
    if cross {
        stamped = str(json.loads(manifest.read_text()).get("platform_tag", ""));
        if stamped != toolchain.ship_platform {
            raise RuntimeError(
                f"The {toolchain.version or toolchain.channel} jac vendorer "
                f"resolved wheels for {stamped or 'the driver host'} instead of "
                f"the pod platform {toolchain.ship_platform}; that jac version "
                f"cannot cross-vendor from this host."
            );
        }
    }

    for line in f"{result.stdout}\n{result.stderr}".splitlines() {
        if line.strip() {
            logger.info(f"vendor: {line.strip()}");
        }
    }
}


def pack_jab(
    project_dir: str, provisioned_database: str, toolchain: (ResolvedToolchain | None)
) -> bytes {
    if toolchain is None {
        raise ValueError(
            "pack_jab requires a resolved toolchain to seal the app image; "
            "none given."
        );
    }
    base = Path(project_dir).resolve();
    staged = _precompile_app(base, toolchain);

    try {
        sanitized = sanitized_jac_toml(base, provisioned_database);
        (fat, fat_explicit) = fat_bundle_setting(project_dir);
        if fat {
            try {
                _vendor_stage(staged, sanitized, toolchain);
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
