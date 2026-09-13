import io;
import os;
import gzip;
import hashlib;
import logging;
import shutil;
import subprocess;
import tarfile;
import tempfile;
import time;
import tomllib;
import from pathlib { Path }
import from jaclang.scale.runtime.fleet { FleetSpec }

glob logger = logging.getLogger(__name__);

glob APP_VOLUME_NAME: str = "jac-app",
     APP_MOUNT_PATH: str = "/app",
     JAC_HOME: str = "/app/.jachome",
     TOOLCHAIN_SUBDIR: str = ".jactoolchain",
     DEFAULT_SEAL_TIMEOUT_S: int = 1800,
     PLACEHOLDER_JAC_TOML: str = "[project]\nname = \"app\"\n",
     STAGE_PREFIX: str = "jac-app-precompile-",
     STAGE_REAP_AGE_S: int = 86400;

glob _stage_roots: list[str] = [];

glob _reported_prunes: set[str] = set();

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


def _is_bundle_required(rel: Path) -> bool {
    parts = rel.parts;
    if (
        len(parts) >= 3
        and parts[0] == ".jac"
        and parts[1] == "client"
        and parts[2] == "dist"
    ) {
        return True;
    }

    if len(parts) >= 2 and parts[0] == ".jac" and parts[1] == "admin" {
        return True;
    }
    return len(parts) == 2 and parts[0] == ".jac" and parts[1] == "serve_manifest.json";
}


obj BundleSourceFilter {
    has ignore_patterns: list[str];

    def parks(rel: Path) -> bool {
        import from jaclang.compiler.frontend.helpers { path_matches_exclude }

        return path_matches_exclude(rel.as_posix(), self.ignore_patterns);
    }

    def is_build_tree(rel: Path) -> bool {
        return _exclude_dir_root(rel) is not None;
    }

    def excludes_tree(rel: Path) -> bool {
        if self.is_build_tree(rel) {
            return True;
        }
        return self.parks(rel);
    }

    def excludes(rel: Path) -> bool {
        if _is_bundle_required(rel) {
            return False;
        }
        if self.excludes_tree(rel) {
            return True;
        }
        name = rel.name;
        if name in _EXCLUDE_FILES {
            return True;
        }
        if name == ".env" or name.startswith(".env.") {
            return True;
        }
        return name.endswith(_EXCLUDE_SUFFIXES);
    }

    def matching_ignore_pattern(rel: Path) -> str {
        import from jaclang.compiler.frontend.helpers { path_matches_exclude }

        for pattern in self.ignore_patterns {
            if path_matches_exclude(rel.as_posix(), [pattern]) {
                return pattern;
            }
        }
        return "";
    }

    def exclusion_reason(rel: Path) -> str {
        for part in rel.parts {
            if part in _EXCLUDE_DIRS {
                return f"'{part}/' is a build or cache tree the deploy never ships";
            }
        }
        pattern = self.matching_ignore_pattern(rel);
        if pattern {
            return f"parked by the .jacignore pattern '{pattern}'";
        }
        name = rel.name;
        if name == "jac.toml" {
            return (
                "the deploy ships a sanitized jac.toml with [scale.secrets] "
                "and [dev] stripped"
            );
        }
        if name == ".env" or name.startswith(".env.") {
            return (
                "'.env' files never ship; move deploy values to "
                "[scale.secrets] or pod env"
            );
        }
        if name in _EXCLUDE_FILES or name.endswith(_EXCLUDE_SUFFIXES) {
            return f"'{name}' is key material the deploy never ships";
        }
        return "excluded from the bundle";
    }
}


def source_filter_for(base: Path) -> BundleSourceFilter {
    import from jaclang.compiler.frontend.helpers { read_jacignore_patterns }

    return BundleSourceFilter(ignore_patterns=read_jacignore_patterns(str(base)));
}


def _project_config(project_dir: str) -> any {
    import from jaclang.project.config { get_config_for_path }

    try {
        return get_config_for_path(Path(project_dir));
    } except Exception as exc {
        raise ValueError(
            f"jac.toml under '{project_dir}' cannot be parsed ({exc}), so the "
            "deploy cannot resolve the entry module or the service modules, "
            "and every pod would fail on the same file at boot. Fix jac.toml "
            "and re-deploy."
        ) from exc;
    }
}


def _entry_module_spec(project_dir: str) -> (tuple[Path, Path] | None) {
    config = _project_config(project_dir);
    if config is None {
        return None;
    }
    proj_root: Path = config.project_root or Path(project_dir);
    if config.apps {
        try {
            app = config.resolve_app("");
        } except ValueError {
            return None;
        }
        return (proj_root.resolve(), Path(app.entry_path(str(proj_root))));
    }
    if not config.project.entry_point {
        return None;
    }
    import from jaclang.project.apps { resolve_entry_path }
    return (
        proj_root.resolve(),
        Path(resolve_entry_path(config.project.entry_point, str(proj_root)))
    );
}


def entry_module_rel(project_dir: str) -> (Path | None) {
    spec = _entry_module_spec(project_dir);
    if spec is None {
        return None;
    }
    (proj_root, entry_path) = spec;
    try {
        return (proj_root / entry_path).resolve().relative_to(
            Path(project_dir).resolve()
        );
    } except ValueError {
        return None;
    }
}


def assert_entry_module_ships(base: Path, excluded: BundleSourceFilter) {
    rel = entry_module_rel(str(base));
    if rel is None or not (base / rel).is_file() or not excluded.excludes(rel) {
        return;
    }
    raise ValueError(
        f"The project entry module '{rel.as_posix()}' is excluded from the "
        f"bundle ({excluded.exclusion_reason(rel)}), so the bundle would ship "
        "without an entry point and every pod would crash-loop on boot. Ship "
        "the module (for .jacignore, drop the pattern that matches it), or "
        "point [project] entry-point at a module the bundle ships."
    );
}


def _exclude_dir_root(rel: Path) -> (str | None) {
    parts = rel.parts;
    depth = 0;
    for part in parts {
        depth += 1;
        if part in _EXCLUDE_DIRS {
            return "/".join(parts[:depth]);
        }
    }
    return None;
}


def partition_bundle_sources(base: Path) -> tuple[list[Path], list[str]] {
    excluded = source_filter_for(base);
    kept: list[Path] = [];
    pruned: set[str] = set();
    for path in sorted(base.rglob("*")) {
        rel = path.relative_to(base);
        if not excluded.excludes(rel) {
            if path.is_file() {
                kept.append(path);
            }
            continue;
        }
        pruned_tree = _exclude_dir_root(rel);
        if pruned_tree is not None {
            pruned.add(pruned_tree);
        }
    }
    shipped: set[str] = set();
    for path in kept {
        parent = path.relative_to(base).parent;
        while parent.as_posix() not in (".", "") {
            shipped.add(parent.as_posix());
            parent = parent.parent;
        }
    }
    return (
        kept,
        sorted(
            [
                tree
                for tree in pruned
                if tree not in shipped
            ]
        )
    );
}


def bundle_source_files(base: Path) -> list[Path] {
    (kept, pruned) = partition_bundle_sources(base);
    for pruned_tree in pruned {
        key = f"{base}::{pruned_tree}";
        if key in _reported_prunes {
            continue;
        }
        _reported_prunes.add(key);
        logger.info(
            f"Bundle: nothing under '{pruned_tree}/' ships, because a path segment "
            f"names a build output directory. Rename it if it holds source "
            f"the pods need."
        );
    }
    return kept;
}


def resolve_fleet_entries(project_dir: str, fleet: any) -> dict[str, str] {
    base = Path(project_dir).resolve();
    excluded = source_filter_for(base);
    members = [path.relative_to(base).as_posix() for path in bundle_source_files(base)];
    return check_fleet_entries(base, members, excluded, fleet);
}


def _fleet_entry_rel(base: Path, app: str, file: str) -> str {
    raw = Path(file);
    if raw.is_absolute() {
        try {
            return raw.resolve().relative_to(base.resolve()).as_posix();
        } except ValueError {
            raise ValueError(
                f"App '{app}' boots '{file}', which resolves outside the deployed "
                f"tree '{base}', so the bundle cannot ship it and every '{app}' "
                "pod would crash-loop on boot. Deploy from the project root."
            );
        }
    }
    rel = Path(raw.as_posix()).as_posix();
    if rel.startswith("./") {
        rel = rel[2:];
    }
    if ".." in Path(rel).parts {
        raise ValueError(
            f"App '{app}' boots '{file}', which reaches outside the deployed "
            f"tree, so the bundle cannot ship it."
        );
    }
    return rel;
}


def check_fleet_entries(
    base: Path,
    members: list[str],
    excluded: BundleSourceFilter,
    fleet: (FleetSpec | None)
) -> dict[str, str] {
    if fleet is None or fleet.is_empty() {
        return {};
    }
    member_set: set[str] = set(members);
    resolved: dict[str, str] = {};
    for (app, member) in fleet.members.items() {
        if not member.file {
            raise ValueError(
                f"App '{app}' has no entry file, so every '{app}' pod would "
                "crash-loop on boot. Set [apps.{app}] entry-point."
            );
        }
        rel = _fleet_entry_rel(base, app, member.file);
        if rel in member_set {
            resolved[app] = rel;
            continue;
        }
        if not (base / rel).is_file() {
            raise ValueError(
                f"App '{app}' boots '{rel}', but no such file exists in the "
                f"project, so every '{app}' pod would crash-loop on boot. Add "
                f"the module or fix [apps.{app}] entry-point."
            );
        }
        raise ValueError(
            f"App '{app}' boots '{rel}', but the bundle does not ship it "
            f"({excluded.exclusion_reason(Path(rel))}), so every '{app}' pod "
            "would crash-loop on boot. Ship the file, or point the app at a "
            "module the bundle ships."
        );
    }
    return resolved;
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


def add_source_members(
    tar: tarfile.TarFile, base: Path, sources: (list[Path] | None) = None
) {
    for path in (sources if sources is not None else bundle_source_files(base)) {
        tar.add(str(path), arcname=str(path.relative_to(base)), filter=det_tar_member);
    }
}


def nested_sanitized_tomls(base: Path) -> dict[str, str] {
    excluded = source_filter_for(base);
    out: dict[str, str] = {};
    for toml_path in sorted(base.rglob("jac.toml")) {
        rel = toml_path.relative_to(base);
        if len(rel.parts) == 1 or excluded.excludes_tree(rel) {
            continue;
        }
        text = sanitized_jac_toml(toml_path.parent);
        if text is not None {
            out[rel.as_posix()] = text;
        }
    }
    return out;
}


def stage_roots_in_use -> list[str] {
    return list(_stage_roots);
}


def _stage_root_prefix -> str {
    return f"{STAGE_PREFIX}{os.getpid()}-";
}


def _stage_root_pid(name: str) -> int {
    if not name.startswith(STAGE_PREFIX) {
        return 0;
    }
    parts = name[len(STAGE_PREFIX):].split("-");
    if len(parts) < 2 or not parts[0].isdigit() {
        return 0;
    }
    return int(parts[0]);
}


def _pid_alive(pid: int) -> bool {
    try {
        os.kill(pid, 0);
        return True;
    } except ProcessLookupError {
        return False;
    } except OSError {
        return True;
    }
}


def _stage_root_expired(stage_root: Path) -> bool {
    try {
        return (time.time() - stage_root.stat().st_mtime) > STAGE_REAP_AGE_S;
    } except OSError {
        return False;
    }
}


def reap_stale_stage_roots -> int {
    removed = 0;
    holder = Path(tempfile.gettempdir());
    try {
        entries = sorted(holder.iterdir());
    } except OSError {
        return 0;
    }
    for `entry in entries {
        if not `entry.is_dir() or not `entry.name.startswith(STAGE_PREFIX) {
            continue;
        }
        pid = _stage_root_pid(`entry.name);
        if pid == 0 {
            if not _stage_root_expired(`entry) {
                continue;
            }
        } elif _pid_alive(pid) {
            continue;
        }
        shutil.rmtree(str(`entry), ignore_errors=True);
        if not `entry.exists() {
            removed += 1;
        }
    }
    if removed {
        logger.info(
            f"removed {removed} deploy staging director(ies) left by dead runs"
        );
    }
    return removed;
}


def remove_stage_root(stage_root: Path) {
    shutil.rmtree(str(stage_root), ignore_errors=True);
    if str(stage_root) in _stage_roots {
        _stage_roots.remove(str(stage_root));
    }
}


def _remove_stage_roots {
    for path in list(_stage_roots) {
        shutil.rmtree(path, ignore_errors=True);
    }
    _stage_roots.clear();
}


def seal_step_env -> dict[str, str] {
    import from jaclang.server.session { SCRATCH_ENV }
    env = release_binary_env();
    env[SCRATCH_ENV] = "1";
    return env;
}


def _stage_app(base: Path, sanitized_toml: (str | None)) -> Path {
    reap_stale_stage_roots();
    stage_root = Path(tempfile.mkdtemp(prefix=_stage_root_prefix()));
    if not _stage_roots {
        import atexit;
        atexit.register(_remove_stage_roots);
    }
    _stage_roots.append(str(stage_root));
    stage = stage_root / "app";
    try {
        for path in bundle_source_files(base) {
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
        remove_stage_root(stage_root);
        raise;
    }
}


def release_binary_env -> dict[str, str] {
    return {
        k: v
        for (k, v) in os.environ.items()
        if k not in _EXCLUDE_ENV
    };
}


def _child_tree_script(
    jac_path: Path,
    work_dir: Path,
    timeout_s: int,
    rel_candidates: tuple[str, ...],
    fallback: Path
) -> Path {
    probe = work_dir / "_seal_probe.jac";
    try {
        probe.write_text('import jaclang;\nwith entry { print(jaclang.__file__); }\n');
        result = subprocess.run(
            [str(jac_path), "run", str(probe)],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=seal_step_env(),
            cwd=str(work_dir)
        );
    } except Exception {
        return fallback;
    } finally {
        probe.unlink(missing_ok=True);
    }
    if result.returncode != 0 {
        return fallback;
    }
    for line in reversed((result.stdout or "").splitlines()) {
        candidate = line.strip();
        if not candidate.endswith("__init__.py") {
            continue;
        }
        pkg_dir = Path(candidate).parent;
        for rel in rel_candidates {
            script = pkg_dir / rel;
            if script.is_file() {
                return script;
            }
        }
    }
    return fallback;
}


def _legacy_sealer_script_for(
    jac_path: Path, stage_root: Path, timeout_s: int
) -> Path {
    return _child_tree_script(
        jac_path,
        stage_root,
        timeout_s,
        ("dist/precompile_bytecode.jac", "utils/precompile_bytecode.jac"),
        Path(str(__file__)).parent.parent.parent / "dist" / "precompile_bytecode.jac"
    );
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

        manifest_script = stage_root / "_serve_payloads.jac";
        manifest_script.write_text(
            "import from pathlib { Path }\n"
                + "import from jaclang.project.config { get_config_for_path }\n"
                + "import from jaclang.dist.seal { bake_serve_payloads }\n"
                + "with entry {\n"
                + "    project = Path('app').resolve();\n"
                + "    config = get_config_for_path(project);\n"
                + "    if not bake_serve_payloads(config, project, bake_client=False) {\n"
                + "        raise RuntimeError('Serving metadata preparation failed');\n"
                + "    }\n}\n"
        );
        prepared = subprocess.run(
            [str(jac_path), "run", str(manifest_script)],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=seal_step_env(),
            cwd=str(stage_root)
        );
        manifest_script.unlink();
        if prepared.returncode != 0 {
            raise RuntimeError(
                "App serving metadata preparation failed: "
                    + (prepared.stderr or prepared.stdout).strip()[-4000:]
            );
        }

        result = subprocess.run(
            [str(jac_path), "precompile", str(stage_root), "--seal"],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=seal_step_env(),
            cwd=str(stage_root)
        );
        if (
            result.returncode != 0
            and "invalid choice: 'precompile'" in (result.stderr or "")
        ) {
            logger.warning(
                "Seal binary predates 'jac precompile'; falling back to its "
                "legacy sealer script."
            );
            script = _legacy_sealer_script_for(jac_path, stage_root, timeout_s);
            result = subprocess.run(
                [str(jac_path), "run", str(script), str(stage_root), "--seal"],
                capture_output=True,
                text=True,
                timeout=timeout_s,
                env=seal_step_env(),
                cwd=str(stage_root)
            );
        }
        jac_path.unlink();
        if (
            result.returncode != 0
            or not (stage / "_precompiled" / "MANIFEST.json").is_file()
        ) {
            for stream_line in (
                (result.stderr or "") + "\n" + (result.stdout or "")
            ).splitlines() {
                if stream_line.strip() {
                    logger.error(f"seal stderr: {stream_line.rstrip()}");
                }
            }
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
        remove_stage_root(stage_root);
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
    script = _child_tree_script(
        jac_path,
        stage.parent,
        900,
        ("scale/utils/vendor_wheels.jac", ),
        Path(str(__file__)).parent.parent / "utils" / "vendor_wheels.jac"
    );
    cmd = [str(jac_path), "run", str(script), str(stage)];
    if platform_tag {
        cmd.append(platform_tag);
    }
    try {
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=900,
            env=seal_step_env(),
            cwd=str(stage.parent)
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


def _resolved_python_specs(stage: Path) -> list[str] {
    import from jaclang.project.config { JacConfig }
    import from jaclang.project.providers { get_python_provider, resolve_plan }
    config = JacConfig.load(stage / "jac.toml");
    deps = resolve_plan(config).for_ecosystem("python");
    return get_python_provider().specs_for(deps);
}


def _strip_external_record_lines(site: Path) {
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


def _venv_stage(stage: Path, seal_binary: bytes, timeout_s: int) {
    jac_path = stage.parent / ".seal-jac";
    jac_path.write_bytes(seal_binary);
    jac_path.chmod(0o755);
    env = seal_step_env();

    env["PIP_NO_INDEX"] = "1";
    env["PIP_FIND_LINKS"] = str(stage / "_vendor" / "wheels");
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


def pack_jab(
    project_dir: str, seal_binary: bytes, pod_arch: str = "", fleet: any = None
) -> bytes {
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
    excluded = source_filter_for(base);
    assert_entry_module_ships(base, excluded);
    sources = bundle_source_files(base);
    check_fleet_entries(
        base, [path.relative_to(base).as_posix() for path in sources], excluded, fleet
    );
    if excluded.ignore_patterns {
        logger.info(
            f"Honoring {len(excluded.ignore_patterns)} .jacignore pattern(s) "
            f"while staging the app bundle."
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
        if (
            not os.environ.get("JAC_SEAL_SKIP_VENV")
            and (staged / "_vendor" / "wheels").is_dir()
        ) {
            try {
                _venv_stage(staged, seal_binary, seal_timeout_setting(project_dir));
            } except Exception as exc {
                shutil.rmtree(str(staged / ".jac" / "venv"), ignore_errors=True);
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
                add_source_members(tar, base, sources=sources);
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
                import from jaclang.server.sealed_serve { SERVE_MANIFEST_REL }
                serve_manifest = staged / SERVE_MANIFEST_REL;
                if serve_manifest.is_file() {
                    tar.add(
                        str(serve_manifest),
                        arcname=SERVE_MANIFEST_REL,
                        filter=det_tar_member
                    );
                }
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
        remove_stage_root(staged.parent);
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
