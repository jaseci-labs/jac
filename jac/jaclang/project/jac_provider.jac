import json;
import os;
import re;
import shutil;
import tomllib;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.project.config { JacConfig }
import from jaclang.project.providers {
    EcosystemProvider,
    InstallContext,
    ResolvedDependency
}
import from jaclang.project.jac_store {
    JacDepError,
    dirhash,
    fetch_package,
    git_package_name,
    materialize,
    normalize_git_url
}

glob REF_HEX: str = "^[0-9a-fA-F]{40}$",
     DEPS_MAP_VERSION: str = "1",
     _deps_roots_cache: dict = {};

obj JacPackage {
    has name: str = "",
        key: str = "",
        source: str = "git",
        ref: str = "",
        sha: str = "",
        tree: str = "",
        pkg_root: str = "",
        version: str = "",
        local_path: Path | None = None,
        requested_by: list[str] = [],
        manifest: dict = {};
}


def manifest_jac_deps(config: JacConfig) -> tuple[dict, dict] {
    raw = config.plugin_dependencies.get("jac", {});
    deps: dict[str, dict] = {};
    dev_deps: dict[str, dict] = {};
    for (name, value) in raw.items() {
        if name == "dev" {
            if isinstance(value, dict) {
                for (dname, dval) in value.items() {
                    if isinstance(dval, dict) {
                        dev_deps[dname] = dval;
                    } else {
                        raise entry_error(
                            dname,
                            dval,
                            "[dev-dependencies.jac] entries must be inline tables"
                        );
                    }
                }
            }
            continue;
        }
        if isinstance(value, dict) {
            deps[name] = value;
        } else {
            raise entry_error(
                name,
                value,
                "a bare string has no meaning here (there is no jac registry "
                "to resolve a name against); use { git = ... } or { path = ... }"
            );
        }
    }
    return (deps, dev_deps);
}


def entry_error(name: str, dep: any, why: str) -> JacDepError {
    return JacDepError(
        f"Invalid [dependencies.jac] dep '{name}': {why}\n"
        f"  got: {dep}\n"
        "  expected e.g. { git = \"github.com/user/repo\", branch = \"main\" } "
        "or { path = \"../utils\" }"
    );
}


def _entry_key(name: str, dep: dict, base_dir: Path) -> tuple[str, str] {
    git_val = dep.get("git");
    path_val = dep.get("path");
    has_git = isinstance(git_val, str) and bool(git_val.strip());
    has_path = isinstance(path_val, str) and bool(path_val.strip());
    if has_git and has_path {
        raise entry_error(name, dep, "cannot declare both 'git' and 'path'");
    }
    if has_git {
        return ("git", normalize_git_url(dep["git"]));
    }
    if has_path {
        path_text = str(dep["path"]);
        if any(ord(c) < 32 for c in path_text) {
            raise entry_error(name, dep, "path contains control characters");
        }
        real = os.path.realpath(str(base_dir / dep["path"]));
        return ("path", real);
    }
    raise entry_error(name, dep, "needs a 'git' or 'path' field");
}


def _safe_dep_name(name: str) -> bool {
    # A dependency name becomes a single directory under .jac/packages, so
    # it must be exactly one safe path component on every platform. TOML
    # keys of fetched packages are dependency-controlled input; on Windows,
    # backslashes are separators and drive colons escape the root, so the
    # check is explicit rather than delegated to Path.
    if not name or name in (".", "..") {
        return False;
    }
    if any(c in name for c in ("/", "\\", ":")) {
        return False;
    }
    if any(ord(c) < 32 or ord(c) == 127 for c in name) {
        return False;
    }
    if name != name.strip() or name.endswith(".") {
        # Trailing dots/spaces are component-significant on Windows.
        return False;
    }
    stem = name.split(".", 1)[0].upper();
    if stem in {
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5",
        "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5",
        "LPT6", "LPT7", "LPT8", "LPT9"
    } {
        return False;
    }
    return True;
}


def _entry_ref(name: str, dep: dict) -> tuple[str, str] {
    ref = "";
    for field in ("ref", "branch", "tag") {
        value = dep.get(field);
        if isinstance(value, str) and value.strip() {
            if ref and ref != value.strip() {
                raise entry_error(
                    name, dep, f"declares conflicting refs '{ref}' and '{value}'"
                );
            }
            ref = value.strip();
        }
    }
    commit = dep.get("commit");
    if commit is not None
        and (not isinstance(commit, str) or not re.match(REF_HEX, commit.strip())) {
        raise entry_error(name, dep, "'commit' must be a 40-hex sha");
    }
    return (ref, commit.strip() if isinstance(commit, str) else "");
}


def parse_jac_spec(spec: str) -> tuple[str, dict] {
    if not spec.startswith("jac:") {
        raise JacDepError(f"Not a jac: spec: {spec}");
    }
    body = spec[len("jac:"):].strip();
    if not body {
        raise JacDepError("Empty jac: spec");
    }
    if body.startswith(("./", "../", "/")) or body in (".", "..") {
        ppath = Path(body);
        name = ppath.resolve().name if ppath.exists() else ppath.name;
        return (name, {"path": body});
    }
    at = body.rfind("@");
    url_part = body[:at] if at > 0 else body;
    ref_part = body[at + 1:] if at > 0 else "";
    name = git_package_name(url_part);
    if not name or ("/" not in url_part and "." not in url_part) {
        raise JacDepError(
            f"'{spec}' does not name a git repository. "
            "Bare names need a registry (deferred); use jac:<git-url> or jac:<path>."
        );
    }
    dep: dict = {"git": url_part};
    if ref_part {
        if re.match(REF_HEX, ref_part) {
            dep["commit"] = ref_part;
        } else {
            dep["ref"] = ref_part;
        }
    }
    return (name, dep);
}


def _vtuple(version: str) -> tuple {
    parts: list = [];
    for piece in re.findall(r"\d+", version.split("+")[0].split("-")[0])[:3] {
        parts.append(int(piece));
    }
    while len(parts) < 3 {
        parts.append(0);
    }
    return tuple(parts);
}


def version_satisfied(constraint: str, actual: str) -> bool {
    constraint = constraint.strip();
    actual_v = _vtuple(actual);
    if constraint.startswith("^") {
        body = constraint[1:];
        if not re.match(r"^\d+(\.\d+)*$", body) {
            raise JacDepError(
                f"Unsupported version constraint '{constraint}': use an exact "
                "version ('1.2.3' or '=1.2.3') or a caret ('^1.2.3')"
            );
        }
        base = _vtuple(body);
        if base[0] > 0 {
            return actual_v >= base and actual_v[0] == base[0];
        }
        if base[1] > 0 {
            return (actual_v >= base and actual_v[0] == 0 and actual_v[1] == base[1]);
        }
        return actual_v == base;
    }
    exact = constraint.lstrip("=");
    if re.match(r"^\d+(\.\d+)*$", exact) {
        return actual_v == _vtuple(exact);
    }
    raise JacDepError(
        f"Unsupported version constraint '{constraint}': use an exact "
        "version ('1.2.3' or '=1.2.3') or a caret ('^1.2.3')"
    );
}


def _read_tree_manifest(pkg_root: Path) -> dict {
    toml_path = pkg_root / "jac.toml";
    if not toml_path.is_file() {
        raise JacDepError(
            f"Fetched package has no jac.toml at its root ({pkg_root}). "
            "A pure-jac dependency must be a jac project."
        );
    }
    try {
        with open(toml_path, "rb") as f {
            return tomllib.load(f);
        }
    } except tomllib.TOMLDecodeError as e {
        raise JacDepError(f"Malformed jac.toml in {pkg_root}: {e}") from None;
    }
}


def _validate_package_field(pkg_root: Path, name: str, dep: dict) -> None {
    module = dep.get("package");
    if not isinstance(module, str) or not module.strip() {
        return;
    }
    module = module.strip();
    base = pkg_root / module.replace(".", "/");
    if not base.is_file() and not (base / "__init__.jac").is_file() {
        raise JacDepError(
            f"[dependencies.jac] '{name}' declares package = \"{module}\", "
            f"but the fetched tree provides no {module}.jac "
            f"(or {module}/__init__.jac) at its root"
        );
    }
}


def deps_map_path(config: JacConfig) -> Path {
    return config.get_build_dir() / "deps.json";
}


def read_deps_map(config: JacConfig) -> dict {
    map_path = deps_map_path(config);
    try {
        data = json.loads(map_path.read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return {};
    }
    return data if isinstance(data, dict) else {};
}


def restore_saved_packages(config: JacConfig) -> None {
    # Rebuild .jac/packages from the deps map recorded on disk. Used when
    # a materialization sweep fails midway so live packages keep matching
    # the metadata that is still on disk: recorded packages are
    # re-materialized from their roots, unrecorded leftover dirs from the
    # failed sweep are removed.
    data = read_deps_map(config);
    packages_root = config.get_build_dir() / "packages";
    known: set[str] = set();
    for row in data.get("packages", []) {
        if not isinstance(row, dict) {
            continue;
        }
        name = str(row.get("name", ""));
        src_root = str(row.get("root", ""));
        if not name or not _safe_dep_name(name) {
            continue;
        }
        known.add(name);
        if src_root and os.path.isdir(src_root) {
            materialize(Path(src_root), packages_root / name);
        }
    }
    if packages_root.is_dir() {
        for child in packages_root.iterdir() {
            if child.name in known or not _safe_dep_name(child.name) {
                continue;
            }
            if child.is_symlink() or not child.is_dir() {
                child.unlink(missing_ok=True);
            } else {
                shutil.rmtree(child, ignore_errors=True);
            }
        }
    }
}


def read_deps_roots(project_root: Path) -> list[str] {
    import from jaclang.project.config { get_config_for_path }
    try {
        config = get_config_for_path(project_root);
    } except (OSError, ValueError) {
        return [];
    }
    if config is None {
        return [];
    }
    map_path = deps_map_path(config);
    if not map_path.is_file() {
        return [];
    }
    try {
        mtime = map_path.stat().st_mtime;
    } except OSError {
        return [];
    }
    cached = _deps_roots_cache.get(str(map_path));
    if cached is not None and cached[0] == mtime {
        return list(cached[1]);
    }
    roots: list[str] = [];
    try {
        data = json.loads(map_path.read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return [];
    }
    if not isinstance(data, dict) {
        return [];
    }
    packages = data.get("packages", []);
    if not isinstance(packages, list) {
        return [];
    }
    for pkg in packages {
        if not isinstance(pkg, dict) {
            continue;
        }
        loc = pkg.get("local", "") or pkg.get("root", "");
        if isinstance(loc, str) and loc and os.path.isdir(loc) {
            roots.append(loc);
        }
    }
    _deps_roots_cache[str(map_path)] = (mtime, list(roots));
    return roots;
}


def pth_lines(resolved: dict[str, JacPackage]) -> list[str] {
    seen: set[str] = set();
    lines: list[str] = [];
    for name in sorted(resolved.keys()) {
        local = resolved[name].local_path;
        if local is None {
            continue;
        }
        text = str(local.resolve());
        if text in seen {
            continue;
        }
        if any(ord(c) < 32 for c in text) {
            raise JacDepError(
                f"Dependency path for '{name}' contains control characters "
                "and would corrupt the import map"
            );
        }
        seen.add(text);
        lines.append(text);
    }
    return lines;
}


def pth_path(config: JacConfig) -> Path | None {
    import from jaclang.project.pyvenv { get_venv_site_packages }
    venv_dir = config.get_venv_dir();
    if not venv_dir {
        return None;
    }
    site = Path(get_venv_site_packages(Path(venv_dir)));
    if not site.is_dir() {
        return None;
    }
    return site / "_jac_deps.pth";
}


def write_pth(config: JacConfig, resolved: dict[str, JacPackage]) -> None {
    pth = pth_path(config);
    if pth is None {
        return;
    }
    lines = pth_lines(resolved);
    if lines {
        pth.write_text("\n".join(lines) + "\n", encoding="utf-8");
    } else {
        pth.unlink(missing_ok=True);
    }
}


def _apply_override(
    overrides: dict, noted: set, name: str, dep: dict, requirer: str
) -> dict {
    if name in overrides and isinstance(overrides[name], dict) {
        if name not in noted {
            console.print(
                f"  override: using [override] dep for '{name}' "
                f"(requested by {requirer})",
                style="muted"
            );
            noted.add(name);
        }
        return overrides[name];
    }
    return dep;
}


obj JacGitProvider(EcosystemProvider) {
    has name: str = "jac",
        manifest_key: str = "jac",
        cli_flag: str = "";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency] {
        (deps, dev_deps) = manifest_jac_deps(config);
        resolved: list[ResolvedDependency] = [];
        for (pkg_name, dep) in deps.items() {
            resolved.append(
                ResolvedDependency(
                    name=pkg_name,
                    version=str(dep.get("version", "")),
                    ecosystem="jac",
                    source="git" if dep.get("git") else "path",
                    origin="manifest",
                    data={k: str(v) for (k, v) in dep.items()}
                )
            );
        }
        if include_dev {
            for (pkg_name, dep) in dev_deps.items() {
                resolved.append(
                    ResolvedDependency(
                        name=pkg_name,
                        version=str(dep.get("version", "")),
                        ecosystem="jac",
                        source="git" if dep.get("git") else "path",
                        origin="manifest",
                        dev=True,
                        data={k: str(v) for (k, v) in dep.items()}
                    )
                );
            }
        }
        return resolved;
    }

    def resolve_closure(
        config: JacConfig,
        ctx: InstallContext | None = None,
        frozen_pins: dict[str, dict] | None = None,
        collect_only: bool = False
    ) -> dict[str, JacPackage] {
        frozen_pins = frozen_pins or {};
        overrides = config.get_section("override");
        overrides = overrides if isinstance(overrides, dict) else {};
        noted_overrides: set[str] = set();
        project_root = config.project_root or Path.cwd();
        (root_deps, root_dev) = manifest_jac_deps(config);
        root_entries = {** root_deps, ** root_dev};
        packages_root = config.get_build_dir() / "packages";

        queue: list[tuple] = [];
        resolved: dict[str, JacPackage] = {};
        seen: dict[str, tuple] = {};
        queued: set[str] = set();
        for (name, dep) in root_entries.items() {
            dep = _apply_override(overrides, noted_overrides, name, dep, "root");
            (source, key) = _entry_key(name, dep, Path(str(project_root)));
            (ref, commit) = _entry_ref(name, dep);
            seen[name] = (key, ref, commit);
            queue.append(
                (name, dep, str(project_root), "root", source, key, ref, commit)
            );
            queued.add(name);
        }
        idx = 0;
        while idx < len(queue) {
            (name, dep, base_dir, requirer, source, key, ref, commit) = queue[idx];
            idx += 1;
            if not isinstance(dep, dict) {
                raise entry_error(
                    name,
                    dep,
                    "string entries have no meaning here; a pure-jac dep needs "
                    "{ git = ... } or { path = ... }"
                );
            }
            existing = resolved.get(name);
            if existing is not None {
                self._check_unification(
                    existing, name, key, ref, commit, dep, requirer
                );
                continue;
            }
            pkg = self._resolve_one(
                name,
                dep,
                source,
                key,
                ref,
                commit,
                base_dir,
                requirer,
                frozen_pins.get(name, {}),
                ctx
            );
            resolved[name] = pkg;
            self._materialize_pkg(pkg, packages_root, ctx, collect_only);
            transitive = pkg.manifest.get("dependencies", {}).get("jac", {});
            for (tname, tentry) in transitive.items() {
                if not isinstance(tentry, dict) {
                    continue;
                }
                tentry = _apply_override(
                    overrides, noted_overrides, tname, tentry, name
                );
                (tsource, tkey) = _entry_key(tname, tentry, Path(pkg.pkg_root));
                (tref, tcommit) = _entry_ref(tname, tentry);
                existing = resolved.get(tname);
                if existing is not None {
                    self._check_unification(
                        existing, tname, tkey, tref, tcommit, tentry, name
                    );
                    continue;
                }
                if tname in seen {
                    (skey, sref, scommit) = seen[tname];
                    if tkey != skey {
                        raise JacDepError(
                            f"Dependency name collision: '{tname}' is '{skey}' "
                            f"and '{tkey}' (via {name}). Rename one of the "
                            f"packages or use [override]."
                        );
                    }
                    if (sref and tref and sref != tref)
                        or (scommit and tcommit and scommit != tcommit) {
                        raise JacDepError(
                            f"Version conflict for '{tname}': "
                            f"{sref or scommit[:12]} vs "
                            f"{tref or tcommit[:12] or 'default branch'} "
                            f"(via {name}). Unify the refs or use [override]."
                        );
                    }
                } else {
                    seen[tname] = (tkey, tref, tcommit);
                }
                if tname not in queued {
                    queued.add(tname);
                    queue.append(
                        (
                            tname,
                            tentry,
                            pkg.pkg_root,
                            name,
                            tsource,
                            tkey,
                            tref,
                            tcommit
                        )
                    );
                }
            }
        }
        return resolved;
    }

    def _materialize_pkg(
        pkg: JacPackage,
        packages_root: Path,
        ctx: InstallContext | None,
        collect_only: bool = False
    ) -> None {
        if pkg.source == "path" or (ctx is not None and ctx.is_dry_run()) {
            pkg.local_path = Path(pkg.pkg_root);
            return;
        }
        if collect_only {
            # Resolution-only sweep (update convergence, no-save install):
            # leave local_path unset; materialize_closure copies the final
            # closure once the whole graph has resolved.
            return;
        }
        if not _safe_dep_name(pkg.name) {
            raise JacDepError(f"Unsafe dependency name for install: '{pkg.name}'");
        }
        dest = packages_root / pkg.name;
        real_dest = os.path.realpath(str(dest));
        real_root = os.path.realpath(str(packages_root));
        if not real_dest.startswith(real_root + os.sep) {
            raise JacDepError(
                f"Unsafe dependency destination for install: '{pkg.name}' "
                f"resolves outside {real_root}"
            );
        }
        try {
            pkg.local_path = materialize(Path(pkg.pkg_root), dest);
        } except OSError as e {
            raise JacDepError(
                f"Could not install '{pkg.name}' into {dest}: {e}"
            ) from None;
        }
    }

    def materialize_closure(
        config: JacConfig,
        resolved: dict[str, JacPackage],
        ctx: InstallContext | None = None
    ) -> None {
        # Copy the final resolved closure into .jac/packages. Callers resolve
        # with collect_only=True first so a failed resolution never touches
        # materialized state, then commit everything here in one sweep.
        packages_root = config.get_build_dir() / "packages";
        for pkg in resolved.values() {
            self._materialize_pkg(pkg, packages_root, ctx);
        }
    }

    def _check_unification(
        existing: JacPackage,
        name: str,
        key: str,
        ref: str,
        commit: str,
        dep: dict,
        requirer: str
    ) {
        if existing.key != key {
            raise JacDepError(
                f"Dependency name collision: '{name}' is '{existing.key}' "
                f"(via {', '.join(existing.requested_by)}) and '{key}' "
                f"(via {requirer})"
            );
        }
        if (existing.sha and commit and existing.sha != commit)
            or (existing.ref and ref and existing.ref != ref) {
            raise JacDepError(
                f"Version conflict for '{name}': "
                f"{existing.ref or existing.sha[:12]} "
                f"(via {', '.join(existing.requested_by)}) vs "
                f"{ref or commit[:12] or 'default branch'} (via {requirer}). "
                f"Unify the refs or use [override]."
            );
        }
        constraint = str(dep.get("version", "")) if dep.get("version") else "";
        if constraint
            and existing.version
            and not version_satisfied(constraint, existing.version) {
            raise JacDepError(
                f"Version conflict for '{name}': '{requirer}' requires "
                f"{constraint}, but {key} resolves to {existing.version}"
            );
        }
        if requirer not in existing.requested_by {
            existing.requested_by.append(requirer);
        }
    }

    def _resolve_one(
        name: str,
        dep: dict,
        source: str,
        key: str,
        ref: str,
        commit: str,
        base_dir: str,
        requirer: str,
        pins: dict,
        ctx: InstallContext | None
    ) -> JacPackage {
        if not _safe_dep_name(name) {
            raise JacDepError(
                f"Unsafe dependency name: '{name}' (requested by {requirer}). "
                "Names must be a single safe path component."
            );
        }
        if source == "path" {
            if not os.path.isdir(key) {
                raise JacDepError(
                    f"[dependencies.jac] '{name}': path '{dep.get('path')}' "
                    f"(resolved {key}) does not exist"
                );
            }
            pkg_tree = dirhash(Path(key));
            if ctx is not None and ctx.frozen {
                # A path dep must replay exactly what the lock recorded:
                # verify the row exists, is still a path row, and that the
                # live tree hash matches the recorded one. Hashing the live
                # filesystem without this check lets a frozen install
                # consume code that differs from the lock closure.
                row = pins if isinstance(pins, dict) else {};
                if not row {
                    raise JacDepError(
                        f"jac.lock is missing '{name}' (requested by "
                        f"{requirer}). Run 'jac install' to refresh the "
                        f"lockfile."
                    );
                }
                if row.get("git") {
                    raise JacDepError(
                        f"'{name}': manifest declares a path dependency but "
                        f"jac.lock records a git source. Run 'jac install' to "
                        f"refresh the lockfile."
                    );
                }
                recorded_tree = str(row.get("tree", ""));
                if not recorded_tree {
                    raise JacDepError(
                        f"jac.lock row for path dependency '{name}' records "
                        f"no tree hash. Run 'jac install' to refresh the "
                        f"lockfile."
                    );
                }
                if recorded_tree != pkg_tree {
                    raise JacDepError(
                        f"'{name}': path dependency content differs from the "
                        f"recorded lock entry (lock tree {recorded_tree[:12]}, "
                        f"live tree {pkg_tree[:12]}). Run 'jac install' to "
                        f"refresh the lockfile."
                    );
                }
                recorded_path = str(row.get("path", ""));
                if recorded_path
                    and os.path.realpath(recorded_path) != os.path.realpath(key) {
                    raise JacDepError(
                        f"'{name}': manifest path resolves to {key} but "
                        f"jac.lock records {recorded_path}. Run 'jac install' "
                        f"to refresh the lockfile."
                    );
                }
            }
            pkg = JacPackage(
                name=name,
                key=key,
                source="path",
                pkg_root=key,
                tree=pkg_tree,
                requested_by=[requirer]
            );
        } else {
            pin_sha = str(pins.get("sha", "")) if pins else "";
            stale: list[str] = [];
            if pin_sha and commit and commit != pin_sha {
                stale.append(
                    f"manifest pins commit {commit[:12]} but jac.lock records "
                    f"{pin_sha[:12]}"
                );
            }
            if pin_sha and str(pins.get("git", "")) != key {
                stale.append(
                    f"manifest source is {key} but jac.lock records "
                    f"{pins.get('git', '')}"
                );
            }
            if stale and ctx is not None and ctx.frozen {
                raise JacDepError(
                    f"'{name}': {'; '.join(stale)}. "
                    f"Run 'jac install' to refresh the lockfile."
                );
            }
            if stale {
                pins = {};
                pin_sha = "";
            }
            if ctx is not None and ctx.frozen and not pin_sha {
                raise JacDepError(
                    f"jac.lock is missing '{name}' (requested by "
                    f"{requirer}). Run 'jac install' to refresh the lockfile."
                );
            }
            fetched = fetch_package(
                url=key,
                ref=ref,
                sha=commit or pin_sha or None,
                expected_tree=str(pins.get("tree", "")),
                verify=bool(pins),
                frozen=(ctx is not None and ctx.frozen)
            );
            pkg = JacPackage(
                name=name,
                key=key,
                source="git",
                ref=ref,
                sha=fetched["sha"],
                tree=fetched["tree"],
                pkg_root=fetched["path"],
                requested_by=[requirer]
            );
        }
        pkg.manifest = _read_tree_manifest(Path(pkg.pkg_root));
        project = pkg.manifest.get("project", {});
        pkg.version = str(project.get("version", ""));
        constraint = str(dep.get("version", "")) if dep.get("version") else "";
        if constraint
            and pkg.version
            and not version_satisfied(constraint, pkg.version) {
            raise JacDepError(
                f"Version conflict for '{name}': '{requirer}' requires "
                f"{constraint}, but {key} resolves to {pkg.version}"
            );
        }
        _validate_package_field(Path(pkg.pkg_root), name, dep);
        if ctx is not None and ctx.verbose {
            via = f" @ {pkg.sha[:12]}" if pkg.sha else "";
            console.print(f"  jac dep {name}{via} -> {pkg.pkg_root}", style="muted");
        }
        return pkg;
    }

    def save_deps_map(config: JacConfig, resolved: dict[str, JacPackage]) -> bool {
        map_path = deps_map_path(config);
        map_path.parent.mkdir(parents=True, exist_ok=True);
        packages = [
            {
                "name": p.name,
                "source": p.source,
                "key": p.key,
                "ref": p.ref,
                "sha": p.sha,
                "tree": p.tree,
                "root": p.pkg_root,
                "local": str(p.local_path) if p.local_path else "",
                "version": p.version
            } for p in resolved.values()
        ];
        map_path.write_text(
            json.dumps({"version": DEPS_MAP_VERSION, "packages": packages}, indent=2)
                + "\n",
            encoding="utf-8"
        );
        return True;
    }

    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool {
        (root_deps, root_dev) = manifest_jac_deps(config);
        if not root_deps and not root_dev {
            return True;
        }
        import from jaclang.project.lockfile {
            jac_lock_rows,
            read_lock,
            update_jac_rows
        }
        pins = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
        if ctx.frozen {
            missing = [
                n
                for n in {** root_deps, ** root_dev}
                if n not in pins
            ];
            if missing {
                console.error(
                    f"jac.lock is missing: {', '.join(sorted(missing))}. "
                    f"Run 'jac install' to refresh the lockfile."
                );
                return False;
            }
        }
        try {
            resolved = self.resolve_closure(config, ctx, frozen_pins=pins);
        } except JacDepError as e {
            console.error(str(e));
            return False;
        }
        self.save_deps_map(config, resolved);
        if not ctx.is_dry_run() {
            update_jac_rows(config.project_root or Path.cwd(), resolved);
            write_pth(config, resolved);
            for pkg in resolved.values() {
                via = f"{pkg.key}@{pkg.sha[:12]}" if pkg.sha else pkg.key;
                console.print(f"  ✔ {pkg.name} ({via})", style="success");
            }
        }
        return True;
    }

    def install_no_save(
        config: JacConfig, specs: list[str], ctx: InstallContext
    ) -> bool {
        # Project-scoped no-save install: resolves and materializes the
        # requested pure-jac closure into the project's dependency state
        # (.jac/deps.json + venv import path) without recording anything
        # in jac.toml or jac.lock. The in-memory manifest section is
        # only a transient scratch pad and is restored below. Resolution
        # runs collect-only so a failed resolve leaves .jac/packages and
        # the deps map untouched.
        original = config.plugin_dependencies.get("jac");
        had_section = isinstance(original, dict);
        backup: dict = dict(original) if had_section else {};
        try {
            section = config.plugin_dependencies.setdefault("jac", {});
            for spec in specs {
                (name, ent) = parse_jac_spec(spec);
                section[name] = ent;
            }
            resolved = self.resolve_closure(config, ctx, collect_only=True);
            try {
                self.materialize_closure(config, resolved, ctx);
            } except Exception as e {
                # A mid-closure copy failure must not leave .jac/packages
                # holding code the deps map does not describe: rebuild the
                # package dirs from the deps map still on disk.
                console.error(str(e));
                try {
                    restore_saved_packages(config);
                } except Exception {
                    console.warning(
                        "Could not restore previous packages; run "
                        "'jac install' to repair .jac/ state."
                    );
                }
                return False;
            }
            self.save_deps_map(config, resolved);
            write_pth(config, resolved);
            for pkg in resolved.values() {
                via = f"{pkg.key}@{pkg.sha[:12]}" if pkg.sha else pkg.key;
                console.print(f"  ✔ {pkg.name} ({via})", style="success");
            }
            return True;
        } except JacDepError as e {
            console.error(str(e));
            return False;
        } finally {
            if had_section {
                config.plugin_dependencies["jac"] = backup;
            } else {
                config.plugin_dependencies.pop("jac", None);
            }
        }
    }

    def add_spec(
        config: JacConfig,
        spec: str,
        dev: bool = False,
        ctx: InstallContext | None = None
    ) -> str | None {
        (name, dep) = parse_jac_spec(spec);
        section = config.plugin_dependencies.setdefault("jac", {});
        if dev {
            dev_section = section.setdefault("dev", {});
            previous = dev_section.get(name);
            dev_section[name] = dep;
        } else {
            previous = section.get(name);
            section[name] = dep;
        }
        config.save();
        import from jaclang.project.lockfile {
            jac_lock_rows,
            read_lock,
            update_jac_rows
        }
        try {
            resolved = self.resolve_closure(
                config,
                ctx,
                frozen_pins=jac_lock_rows(read_lock(config.project_root or Path.cwd()))
            );
        } except JacDepError as e {
            if previous is not None {
                if dev {
                    restored = section.setdefault("dev", {});
                    restored[name] = previous;
                } else {
                    section[name] = previous;
                }
            } else {
                self._unrecord(config, name, dev);
            }
            config.save();
            console.error(str(e));
            self._rematerialize(config);
            return None;
        }
        self.save_deps_map(config, resolved);
        if ctx is None or not ctx.is_dry_run() {
            update_jac_rows(config.project_root or Path.cwd(), resolved);
            write_pth(config, resolved);
            pkg = resolved[name];
            via = f"{pkg.key}@{pkg.sha[:12]}" if pkg.sha else pkg.key;
            console.print(f"  ✔ {name} ({via})", style="success");
            return via;
        }
        return name;
    }

    def _rematerialize(config: JacConfig) {
        import from jaclang.project.lockfile { jac_lock_rows, read_lock }
        try {
            pins = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            resolved = self.resolve_closure(config, None, frozen_pins=pins);
            self.save_deps_map(config, resolved);
            write_pth(config, resolved);
        } except Exception {
            console.warning(
                "Previous dependencies could not be re-materialized; "
                "run 'jac install' to restore .jac/ state."
            );
        }
    }

    def _unrecord(config: JacConfig, name: str, dev: bool) {
        section = config.plugin_dependencies.get("jac", {});
        if dev and isinstance(section.get("dev"), dict) {
            section["dev"].pop(name, None);
        } else {
            section.pop(name, None);
        }
    }

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None {
        raise NotImplementedError(
            "pure-jac deps are added with 'jac install jac:<url-or-path>'"
        );
    }

    override def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool {
        (deps, dev_deps) = manifest_jac_deps(config);
        if name not in deps and name not in dev_deps {
            return False;
        }
        is_dev = dev or (name not in deps and name in dev_deps);
        if is_dev and name in dev_deps {
            previous = dev_deps[name];
        } else {
            previous = deps.get(name);
        }
        if not config.remove_dependency(name, dev=is_dev, dep_type="jac") {
            return False;
        }
        config.save();
        try {
            resolved = self.resolve_closure(config, ctx);
        } except JacDepError as e {
            section = config.plugin_dependencies.setdefault("jac", {});
            if is_dev {
                restored = section.setdefault("dev", {});
                restored[name] = previous;
            } else {
                section[name] = previous;
            }
            config.save();
            console.error(str(e));
            self._rematerialize(config);
            return False;
        }
        stale = config.get_build_dir() / "packages" / name;
        if _safe_dep_name(name) and stale.is_dir() {
            shutil.rmtree(stale, ignore_errors=True);
        }
        self.save_deps_map(config, resolved);
        import from jaclang.project.lockfile { update_jac_rows }
        update_jac_rows(config.project_root or Path.cwd(), resolved);
        write_pth(config, resolved);
        console.print(f"  ✔ Removed {name} from [dependencies.jac]", style="success");
        return True;
    }

    override def list_installed(config: JacConfig) -> list[str] {
        data = read_deps_map(config);
        return sorted(
            p.get("name", "")
            for p in data.get("packages", [])
            if isinstance(p, dict)
        );
    }

    override def emit_standalone(
        config: JacConfig, deps: list[ResolvedDependency], out_dir: Path, mode: str
    ) -> list[Path] {
        try {
            resolved = self.resolve_closure(config, None);
        } except JacDepError as e {
            console.warning(
                f"Could not resolve jac dependencies ({e}); " "continuing without them."
            );
            resolved = {};
        }
        if not resolved {
            return [];
        }
        out_dir.mkdir(parents=True, exist_ok=True);
        out_path = out_dir / "jac-deps.txt";
        lines: list[str] = [];
        for pkg in resolved.values() {
            if pkg.source == "git" {
                lines.append(f"{pkg.name} {pkg.key}#{pkg.sha}");
            } else {
                lines.append(f"{pkg.name} path:{pkg.key}");
            }
        }
        out_path.write_text("\n".join(lines) + "\n", encoding="utf-8");
        return [out_path];
    }
}
