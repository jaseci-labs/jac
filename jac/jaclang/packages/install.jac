import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.packages.index { RegistryError, registry_named }
import from jaclang.packages.lock { LockedPackage, Lockfile, LockError }
import from jaclang.packages.mounts { link_mounts }
import from jaclang.packages.resolve {
    ResolveError,
    manifest_inputs,
    pip_requirement,
    resolve_graph
}
import from jaclang.packages.sources { GitError, checkout, pack_checkout }
import from jaclang.packages.store { StoreError, cached, materialize }
import from jaclang.project.config { JacConfig }
import from jaclang.project.package_scope { is_package_name }

obj InstallError(Exception) {}

obj SyncResult {
    has lock: Lockfile,
        targets: dict[str, Path] = {},
        resolved: bool = False;
}

def lock_path(config: JacConfig) -> Path {
    return Lockfile.path_for(project_dir(config));
}

def load_lock(config: JacConfig) -> Lockfile | None {
    try {
        return Lockfile.read(lock_path(config));
    } except LockError as e {
        raise InstallError(str(e));
    }
}

def has_packages(config: JacConfig) -> bool {
    return bool(config.dependencies or config.dev_dependencies)
        or is_package_name(config.project.name);
}

def lock_is_current(config: JacConfig, lock: Lockfile | None) -> bool {
    return lock is not None and lock.inputs == manifest_inputs(config);
}

def project_dir(config: JacConfig) -> Path {
    if config.project_root is None {
        raise InstallError("packages need a project (jac.toml)");
    }
    return Path(config.project_root);
}

def fetch_locked(config: JacConfig, pkg: LockedPackage) -> Path {
    kind = pkg.source_kind();
    if kind == "path" {
        target = (project_dir(config) / pkg.source_ref()).resolve();
        if not (target / "jac.toml").is_file() {
            raise InstallError(f"{pkg.name}: path dependency {target} is gone");
        }
        return target;
    }
    hit = cached(pkg.name, pkg.version, pkg.sha256);
    if hit is not None {
        return hit;
    }
    if kind == "registry" {
        registry = _registry_for_source(config, pkg.source_ref());
        item = registry.find(pkg.name, pkg.version);
        if item is None {
            raise InstallError(
                f"{pkg.name} {pkg.version} is locked but not in the index at "
                f"{registry.base()}"
            );
        }
        if item.sha256 != pkg.sha256 {
            raise InstallError(
                f"{pkg.name} {pkg.version}: the index now lists sha256 "
                f"{item.sha256[:16]} but jac.lock pins {pkg.sha256[:16]}; a "
                "published version never changes, so treat this as tampering"
            );
        }
        data = registry.fetch_blob(item);
        return materialize(pkg.name, pkg.version, pkg.sha256, data, pkg.source);
    }
    if kind == "git" {
        (url, _, commit) = pkg.source_ref().partition("#");
        co = checkout(url, commit);
        (data, sha256) = pack_checkout(co);
        if sha256 != pkg.sha256 {
            raise InstallError(
                f"{pkg.name}: {url}@{commit[:12]} no longer packs to the locked sha256"
            );
        }
        return materialize(pkg.name, pkg.version, sha256, data, pkg.source);
    }
    raise InstallError(f"{pkg.name}: unknown lock source '{pkg.source}'");
}

def _registry_for_source(config: JacConfig, base: str) -> any {
    import from jaclang.packages.index { Registry, registry_urls }
    for (name, url) in registry_urls(config.registries).items() {
        candidate = registry_named(name, config.registries);
        if candidate.base() == base {
            return candidate;
        }
    }
    return Registry(name=base, url=base);
}

def mount_targets(
    config: JacConfig, lock: Lockfile, include_dev: bool = True
) -> dict[str, Path] {
    targets: dict[str, Path] = {};
    for pkg in lock.packages {
        if pkg.dev and not include_dev {
            continue;
        }
        targets[pkg.name] = fetch_locked(config, pkg);
    }
    if is_package_name(config.project.name) {
        targets[config.project.name] = project_dir(config);
    }
    return targets;
}

def sync(
    config: JacConfig,
    update: list[str] | None = None,
    frozen: bool = False,
    include_dev: bool = True
) -> SyncResult {
    previous = load_lock(config);
    lock = previous;
    resolved = False;
    if update is not None or not lock_is_current(config, previous) {
        if frozen {
            raise InstallError(
                "jac.lock is out of date with jac.toml (or missing); run "
                "'jac install' without --frozen to update it"
            );
        }
        try {
            lock = resolve_graph(config, previous, update);
        } except (ResolveError, RegistryError) as e {
            raise InstallError(str(e));
        }
        resolved = True;
    }
    if lock is None {
        raise InstallError("no jac.lock to install from");
    }
    try {
        targets = mount_targets(config, lock, include_dev);
    } except (StoreError, RegistryError, GitError) as e {
        raise InstallError(str(e));
    }
    link_mounts(config.get_build_dir(), targets);
    return SyncResult(lock=lock, targets=targets, resolved=resolved);
}

def write_lock(config: JacConfig, lock: Lockfile) {
    lock.write(lock_path(config));
}

def package_pip_requirements(
    lock: Lockfile | None, include_dev: bool
) -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    if lock is None {
        return out;
    }
    for pkg in lock.packages {
        if pkg.dev and not include_dev {
            continue;
        }
        for (name, spec) in sorted(pkg.pypi.items()) {
            out.append((name, spec, pkg.name));
        }
    }
    return out;
}

def package_npm_requirements(
    lock: Lockfile | None, include_dev: bool
) -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    if lock is None {
        return out;
    }
    for pkg in lock.packages {
        if pkg.dev and not include_dev {
            continue;
        }
        for (name, spec) in sorted(pkg.npm.items()) {
            out.append((name, spec, pkg.name));
        }
    }
    return out;
}

def describe_sync(result: SyncResult) {
    if not result.lock.packages {
        return;
    }
    verb = "Resolved" if result.resolved else "Using locked";
    console.print(
        f"  {verb} {len(result.lock.packages)} Jac package(s)", style="muted"
    );
    for pkg in result.lock.packages {
        tag = " (dev)" if pkg.dev else "";
        console.print(f"  ✔ {pkg.name} {pkg.version}{tag}", style="success");
    }
}
