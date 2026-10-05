import from pathlib { Path }

glob PYPI_HINT: str = "Jac packages are scoped as org/name; install a Python package with 'jac install --pypi <name>'";

obj PackageSpec {
    has name: str,
        version: str = "";

    static def parse(text: str) -> PackageSpec {
        (name, sep, version) = text.strip().partition("@");
        return PackageSpec(name=name.strip(), version=version.strip() if sep else "");
    }
}

def split_package_specs(texts: list[str]) -> tuple[list[PackageSpec], list[str]] {
    specs: list[PackageSpec] = [];
    stray: list[str] = [];
    for text in texts {
        spec = PackageSpec.parse(text);
        if is_package_name(spec.name) {
            specs.append(spec);
        } else {
            stray.append(text);
        }
    }
    return (specs, stray);
}

def _install_python(
    config: JacConfig,
    lock: Lockfile,
    specs: list[str],
    ctx: InstallContext,
    refresh: bool
) -> bool {
    python = get_python_provider();
    inputs = digest_of(sorted(specs));
    replay = not refresh
        and lock.pypi_resolved
        and lock.pypi_inputs == inputs
        and not ctx.is_dry_run();
    if replay {
        pinned_ctx = InstallContext(
            verbose=ctx.verbose,
            install_flags=[*ctx.install_flags, "--no-deps"],
            target=ctx.target
        );
        if python.install_specs(config, list(lock.pypi_resolved), pinned_ctx) {
            return True;
        }
        console.warning(
            "jac.lock's Python pins do not install on this machine; re-resolving "
            "from jac.toml"
        );
    }
    if not python.install_specs(config, specs, ctx) {
        return False;
    }
    if not ctx.is_dry_run() {
        lock.pypi_resolved = python.freeze(config);
        lock.pypi_inputs = inputs;
    }
    return True;
}

def install_project(
    config: JacConfig,
    include_dev: bool = False,
    extras: list[str] | None = None,
    scale: bool = False,
    frozen: bool = False,
    skip_npm: bool = False,
    update: list[str] | None = None,
    ctx: InstallContext | None = None
) -> int {
    ctx = ctx or InstallContext();
    lock = load_lock(config) or Lockfile();
    if has_packages(config) or lock.packages {
        try {
            result: SyncResult = sync(config, update=update, frozen=frozen);
        } except InstallError as e {
            console.error(str(e));
            return 1;
        }
        describe_sync(result);
        lock = result.lock;
    }
    lock.inputs = manifest_inputs(config);
    try {
        plan = resolve_plan(
            config, include_dev=include_dev, extras=extras or [], scale=scale
        );
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    python_deps = plan.for_ecosystem("python");
    ok = True;
    if python_deps {
        python = get_python_provider();
        specs = python.specs_for(python_deps);
        if frozen
            and lock.pypi_inputs
            and lock.pypi_inputs != digest_of(sorted(specs)) {
            console.error(
                "jac.lock's Python pins are out of date with the declared "
                "dependencies; run 'jac install' without --frozen"
            );
            return 1;
        }
        with console.status(
            f"Installing {len(python_deps)} Python package(s)...", spinner="dots"
        ) as _ {
            ok = _install_python(config, lock, specs, ctx, refresh=update is not None);
        }
    }
    if ctx.is_dry_run() {
        return 0 if ok else 1;
    }
    failed = not ok;
    for provider in get_provider_registry().all() {
        if provider.name in ("python", "jac") {
            continue;
        }
        if provider.name == "npm" and skip_npm {
            console.print("\n  Skipping npm dependencies (--no-npm)", style="muted");
            continue;
        }
        provider_deps = plan.for_ecosystem(provider.name);
        if not provider_deps {
            continue;
        }
        console.print(f"\n  Installing {provider.name} dependencies", style="muted");
        try {
            provider.install_all(config, provider_deps, ctx);
            console.print(
                f"  ✔ {provider.name} dependencies installed", style="success"
            );
        } except Exception as e {
            console.error(f"  ✗ {provider.name} dependencies failed: {e}");
            failed = True;
        }
    }
    clashes = _org_collisions(config, lock);
    if clashes {
        console.error(
            "Python packages in .jac/venv shadow Jac package orgs: "
                + ", ".join(clashes),
            hint="import from <org>.<name> would load the Python module; rename or remove the Python package"
        );
        failed = True;
    }
    lock.npm_bun_lock = _bun_lock_digest(config);
    if lock.packages or lock.pypi_resolved or lock.npm_bun_lock {
        write_lock(config, lock);
    }
    if failed {
        console.error("Some dependencies failed to install");
        return 1;
    }
    console.success("All dependencies installed");
    return 0;
}

def _org_collisions(config: JacConfig, lock: Lockfile) -> list[str] {
    orgs = {p.name.split("/", 1)[0] for p in lock.packages};
    venv = config.get_venv_dir();
    if not orgs or not venv.is_dir() {
        return [];
    }
    try {
        site = get_venv_site_packages(venv);
    } except Exception {
        return [];
    }
    return sorted(
        [
            org
            for org in orgs
            if (site / org).is_dir() or (site / f"{org}.py").is_file()
        ]
    );
}

def _bun_lock_digest(config: JacConfig) -> str {
    import hashlib;
    client_dir = config.get_client_dir();
    for candidate in sorted(client_dir.glob("**/bun.lock*")) {
        if candidate.is_file() and "node_modules" not in candidate.parts {
            return "sha256:" + hashlib.sha256(candidate.read_bytes()).hexdigest();
        }
    }
    return "";
}

def _dep_from_source(git: str, path: str, rev: str, base: Path) -> PackageDep {
    if path {
        tree = resolve_path(base, path);
        name = read_identity(tree).name;
        return PackageDep(name=name, path=path);
    }
    co = checkout(git, rev);
    return PackageDep(name=read_identity(co.tree).name, git=git, rev=rev or co.commit);
}

def add_packages(
    config: JacConfig,
    texts: list[str],
    dev: bool = False,
    git: str = "",
    path: str = "",
    rev: str = "",
    ctx: InstallContext | None = None
) -> int {
    (specs, stray) = split_package_specs(texts);
    if stray {
        console.error(f"Not Jac package names: {', '.join(stray)}", hint=PYPI_HINT);
        return 1;
    }
    table = config.dev_dependencies if dev else config.dependencies;
    added: list[PackageDep] = [];
    if git or path {
        if len(specs) > 1 {
            console.error("--git/--path take at most one package name");
            return 1;
        }
        try {
            dep = _dep_from_source(git, path, rev, project_dir(config));
        } except Exception as e {
            console.error(f"Cannot read the package at {git or path}: {e}");
            return 1;
        }
        if specs and specs[0].name != dep.name {
            console.error(
                f"{git or path} is the package '{dep.name}', not '{specs[0].name}'"
            );
            return 1;
        }
        if not is_package_name(dep.name) {
            console.error(
                f"{git or path} declares '{dep.name}', which is not a scoped "
                "package name (org/name)"
            );
            return 1;
        }
        dep.dev = dev;
        table[dep.name] = dep;
        added.append(dep);
    } else {
        if not specs {
            console.error("Name at least one package (org/name[@range]).");
            return 1;
        }
        for spec in specs {
            if spec.version {
                try {
                    import from jaclang.packages.semver { Requirement }
                    Requirement.parse(spec.version);
                } except SemverError as e {
                    console.error(f"{spec.name}: {e}");
                    return 1;
                }
            }
            dep = PackageDep(name=spec.name, version=spec.version or "*", dev=dev);
            table[spec.name] = dep;
            added.append(dep);
        }
    }
    rc = install_project(config, include_dev=True, ctx=ctx);
    if rc != 0 {
        return rc;
    }
    lock = load_lock(config);
    for dep in added {
        if dep.kind() == "registry" and dep.version == "*" and lock is not None {
            locked = lock.get(dep.name);
            if locked is not None {
                try {
                    dep.version = caret_for(Version.parse(locked.version));
                } except SemverError {}
            }
        }
    }
    config.save();
    if lock is not None {
        lock.inputs = manifest_inputs(config);
        write_lock(config, lock);
    }
    section = "dev-dependencies" if dev else "dependencies";
    for dep in added {
        shown = dep.version if dep.kind() == "registry" else (dep.path or dep.git);
        console.print(f"  ✔ {dep.name} {shown}", style="success");
    }
    console.print(f"\n  ✔ Updated jac.toml [{section}] and jac.lock", style="muted");
    return 0;
}

def remove_packages(config: JacConfig, texts: list[str], dev: bool = False) -> int {
    (specs, stray) = split_package_specs(texts);
    if stray {
        console.error(f"Not Jac package names: {', '.join(stray)}", hint=PYPI_HINT);
        return 1;
    }
    missing: list[str] = [];
    for spec in specs {
        found = False;
        for table in (
            [config.dev_dependencies]
                if dev
                else [config.dependencies, config.dev_dependencies]
        ) {
            if spec.name in table {
                del table[spec.name];
                found = True;
                break;
            }
        }
        if not found {
            missing.append(spec.name);
        }
    }
    if missing {
        console.error(f"Not declared in jac.toml: {', '.join(missing)}");
        return 1;
    }
    config.save();
    try {
        result = sync(config);
    } except InstallError as e {
        console.error(str(e));
        return 1;
    }
    lock = result.lock;
    lock.inputs = manifest_inputs(config);
    write_lock(config, lock);
    for spec in specs {
        console.success(f"Removed {spec.name}");
    }
    return 0;
}
