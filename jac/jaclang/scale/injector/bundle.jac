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
glob _EXCLUDE_ENV: set[str] = {
         "PYTHONPATH",
         "PYTHONHOME",
         "JAC_LLVM_SHIM",
         "JAC_DEV_SOURCE",
         "JAC_NO_PRECOMPILE",
         "JAC_EXECUTABLE"
     };


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


def release_binary_env -> dict[str, str] {
    return {
        k: v
        for (k, v) in os.environ.items()
        if k not in _EXCLUDE_ENV
    };
}


def _precompile_app(base: Path, pod_binary: bytes) -> Path {
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
        jac_path = stage_root / ".pod-jac";
        jac_path.write_bytes(pod_binary);
        jac_path.chmod(0o755);
        script = stage_root / "pod_seal_boot.jac";
        script.write_text(
            "import from jaclang.utils.precompile_bytecode { main }\n"
            "with entry:__main__ { main(); }\n",
            encoding="utf-8"
        );

        result = subprocess.run(
            [str(jac_path), "run", str(script), str(stage_root), "--seal"],
            capture_output=True,
            text=True,
            timeout=600,
            env=release_binary_env(),
            cwd=str(stage_root)
        );
        jac_path.unlink();
        script.unlink();
        if (
            result.returncode != 0
            or not (stage / "_precompiled" / "MANIFEST.json").is_file()
        ) {
            raise RuntimeError(
                f"App seal did not complete, so the deploy cannot produce a "
                f".jab: {(result.stderr or result.stdout).strip()[-2000:]}"
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


def _vendor_stage(stage: Path, sanitized_toml: (str | None), pod_binary: bytes) {
    if sanitized_toml is not None {
        (stage / "jac.toml").write_text(sanitized_toml, encoding="utf-8");
    }
    jac_path = stage.parent / ".pod-jac";
    jac_path.write_bytes(pod_binary);
    jac_path.chmod(0o755);
    script = stage.parent / "pod_vendor_boot.jac";
    script.write_text(
        "import from jaclang.scale.utils.vendor_wheels { main }\n"
        "with entry:__main__ { main(); }\n",
        encoding="utf-8"
    );
    try {
        result = subprocess.run(
            [str(jac_path), "run", str(script), str(stage)],
            capture_output=True,
            text=True,
            timeout=900
        );
    } finally {
        jac_path.unlink(missing_ok=True);
        script.unlink(missing_ok=True);
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


def _resolved_python_specs(stage: Path) -> list[str] {
    import from jaclang.project.config { JacConfig }
    import from jaclang.project.providers { get_python_provider, resolve_plan }
    config = JacConfig.load(stage / "jac.toml");
    deps = resolve_plan(config).for_ecosystem("python");
    return get_python_provider().specs_for(deps);
}


def _strip_external_record_lines(site: Path) {
    # Entry-point scripts under bin/ embed the staging path in their shebang,
    # so their RECORD hash lines differ on every seal; bin/ never ships, and
    # dropping its lines keeps RECORD (and the bundle digest) deterministic.
    for record in sorted(site.`glob("*.dist-info/RECORD")) {
        lines = record.read_text(encoding="utf-8").splitlines(keepends=True);
        kept = [
            line
            for line in lines
            if not line.startswith("../")
        ];
        if len(kept) != len(lines) {
            record.write_text("".join(kept), encoding="utf-8");
        }
    }
}


def staged_venv_files(stage: Path) -> list[Path] {
    import from jaclang.project.providers { VENV_DEPS_MARKER }
    import from jaclang.project.pyvenv { get_venv_site_packages }
    venv = stage / ".jac" / "venv";
    marker = venv / VENV_DEPS_MARKER;
    if not marker.is_file() {
        return [];
    }
    site = get_venv_site_packages(venv);
    if not site.is_dir() {
        return [];
    }
    files = [marker];
    for path in sorted(site.rglob("*")) {
        if (
            path.is_file() and path.suffix != ".pyc" and "__pycache__" not in path.parts
        ) {
            files.append(path);
        }
    }
    return files;
}


def _prune_seed_pip(site: Path, specs: list[str]) {
    # ensurepip seeds pip into every fresh venv, but a sealed venv never
    # runs pip again (the marker short-circuits jac install), so shipping
    # it only bloats the bundle. Kept when the app itself depends on pip.
    import re;
    for spec in specs {
        if re.split(r"[<>=!~\[ ;@]", spec.strip())[0].lower() == "pip" {
            return;
        }
    }
    for item in sorted(site.iterdir()) {
        if item.name == "pip"
        or (item.name.startswith("pip-") and item.name.endswith(".dist-info")) {
            shutil.rmtree(str(item), ignore_errors=True);
        }
    }
}


def _venv_stage(stage: Path, pod_binary: bytes, timeout_s: int = 900) {
    jac_path = stage.parent / ".seal-venv-jac";
    jac_path.write_bytes(pod_binary);
    jac_path.chmod(0o755);
    env = release_binary_env();
    # The same offline install the pod bootstrap runs. Offline also keeps the
    # staged venv a pure function of the vendored wheels, so the bundle
    # digest stays deterministic across seals.
    env["PIP_NO_INDEX"] = "1";
    env["PIP_FIND_LINKS"] = str(stage / "_vendor" / "wheels");
    env["PIP_PREFIX"] = str(stage / ".jac" / "venv");
    # The seal host's own runtime site may already satisfy some specs, which
    # would make pip skip them and leave the staged prefix silently empty.
    env["PIP_IGNORE_INSTALLED"] = "1";
    env["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    try {
        result = subprocess.run(
            [str(jac_path), "install"],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=env,
            cwd=str(stage)
        );
    } finally {
        jac_path.unlink(missing_ok=True);
    }
    if result.returncode != 0 {
        raise RuntimeError(
            f"seal-time venv build failed (host cannot install the "
            f"pod-platform wheels?): "
            f"{(result.stderr or result.stdout).strip()[-300:]}"
        );
    }
    venv = stage / ".jac" / "venv";
    import from jaclang.project.pyvenv { get_venv_site_packages }
    site = get_venv_site_packages(venv);
    if not site.is_dir() {
        raise RuntimeError(f"seal-time venv build left no site-packages under {venv}");
    }
    specs = _resolved_python_specs(stage);
    _prune_seed_pip(site, specs);
    _strip_external_record_lines(site);
    import from jaclang.project.providers { write_venv_deps_marker }
    write_venv_deps_marker(venv, specs);
}


def pack_jab(project_dir: str, provisioned_database: str, pod_binary: bytes) -> bytes {
    if not pod_binary {
        raise ValueError(
            "pack_jab requires the pod binary to seal the app image; none given."
        );
    }
    base = Path(project_dir).resolve();
    staged = _precompile_app(base, pod_binary);

    try {
        sanitized = sanitized_jac_toml(base, provisioned_database);
        (fat, fat_explicit) = fat_bundle_setting(project_dir);
        if fat {
            try {
                _vendor_stage(staged, sanitized, pod_binary);
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
        if (
            not os.environ.get("JAC_SEAL_SKIP_VENV")
            and (staged / "_vendor" / "wheels").is_dir()
        ) {
            try {
                _venv_stage(staged, pod_binary);
            } except Exception as exc {
                shutil.rmtree(str(staged / ".jac"), ignore_errors=True);
                logger.warning(
                    f"Seal-time venv staging failed; pods will build the venv "
                    f"at boot instead. {exc}"
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
                venv_files = staged_venv_files(staged);
                for path in venv_files {
                    rel = path.relative_to(staged);
                    tar.add(str(path), arcname=str(rel), filter=det_tar_member);
                }
                if venv_files {
                    logger.info(
                        f"Sealed a prebuilt venv ({len(venv_files)} files) "
                        f"into the .jab; pods skip the boot-time dependency "
                        f"install."
                    );
                }
                venv_files = staged_venv_files(staged);
                for path in venv_files {
                    rel = path.relative_to(staged);
                    tar.add(str(path), arcname=str(rel), filter=det_tar_member);
                }
                if venv_files {
                    logger.info(
                        f"Sealed a prebuilt venv ({len(venv_files)} files) "
                        f"into the .jab; pods skip the boot-time dependency "
                        f"install."
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
