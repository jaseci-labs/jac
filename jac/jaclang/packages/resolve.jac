import os;
import from pathlib { Path }
import from jaclang.packages.index {
    IndexEntry,
    Registry,
    RegistryError,
    registry_named,
    registry_urls
}
import from jaclang.packages.lock { LockedPackage, Lockfile, digest_of }
import from jaclang.packages.pubgrub { PackageSource, SolveFailure, solve }
import from jaclang.packages.semver { Requirement, SemverError, Version }
import from jaclang.packages.sources { GitError, checkout, pack_checkout, resolve_path }
import from jaclang.project.config { JacConfig }
import from jaclang.project.dependencies { PackageDep }
import from jaclang.project.jac_version { satisfies as jac_satisfies }
import from jaclang.project.package_scope { is_package_name }

obj ResolveError(Exception) {}

obj LocalPackage {
    has name: str,
        version: Version,
        config: JacConfig,
        tree: Path,
        source: str,
        sha256: str = "";
}

def running_jac_version -> Version {
    import from jaclang.compiler.driver.jir { jaclang_version }
    try {
        return Version.parse(jaclang_version()).release();
    } except SemverError {
        return Version.parse("0.0.0");
    }
}

def pip_requirement(name: str, spec: str) -> str {
    if spec.startswith("@") {
        return f"{name} {spec}";
    }
    return f"{name}{spec}" if spec and spec != "*" else name;
}

def manifest_pypi(config: JacConfig) -> dict[str, str] {
    out = dict(config.pypi_dependencies);
    for (name, info) in config.pypi_git_dependencies.items() {
        ref = info.get("rev") or info.get("branch") or info.get("tag") or "";
        out[name] = f"@ git+{info.get('git', '')}" + (f"@{ref}" if ref else "");
    }
    return out;
}

def manifest_npm(config: JacConfig) -> dict[str, str] {
    return {
        k: v
        for (k, v) in config.plugin_dependencies.get("npm", {}).items()
        if isinstance(v, str)
    };
}

def manifest_inputs(config: JacConfig) -> str {
    return digest_of(
        {
            "deps": {n: d.to_toml() for (n, d) in sorted(config.dependencies.items())},
            "dev": {
                n: d.to_toml() for (n, d) in sorted(config.dev_dependencies.items())
            },
            "registries": registry_urls(config.registries)
        }
    );
}

obj GraphSource(PackageSource) {
    has root_dir: Path,
        registries: dict[str, str],
        locked: dict[str, str] = {},
        unlock: set[str] = set(),
        unlock_all: bool = False,
        jac_version: Version = Version.parse("0.0.0"),
        locals: dict[str, LocalPackage] = {},
        origin_registry: dict[str, str] = {},
        prerelease: set[str] = set();

    def registry_for(name: str) -> Registry {
        return registry_named(self.origin_registry.get(name, ""), self.registries);
    }

    def note_requirement(name: str, req: Requirement) {
        if req.names_prerelease {
            self.prerelease.add(name);
        }
    }

    def add_local(dep: PackageDep, base: Path) -> LocalPackage {
        if dep.name in self.locals {
            return self.locals[dep.name];
        }
        if dep.kind() == "path" {
            tree = resolve_path(base, dep.path);
            if not (tree / "jac.toml").is_file() {
                raise ResolveError(
                    f"{dep.name}: path dependency {dep.path} has no jac.toml at {tree}"
                );
            }
            source = "path+"
                + os.path.relpath(str(tree), str(self.root_dir)).replace(os.sep, "/");
            sha256 = "";
        } else {
            try {
                co = checkout(dep.git, dep.rev);
            } except GitError as e {
                raise ResolveError(f"{dep.name}: {e}");
            }
            (_, sha256) = pack_checkout(co);
            tree = co.tree;
            source = f"git+{dep.git}#{co.commit}";
        }
        cfg = JacConfig.load(tree / "jac.toml");
        if cfg.project.name != dep.name {
            raise ResolveError(
                f"{dep.name}: {dep.path or dep.git} is the package '{cfg.project.name}'"
            );
        }
        try {
            version = Version.parse(cfg.project.version);
        } except SemverError as e {
            raise ResolveError(f"{dep.name}: {e}");
        }
        pkg = LocalPackage(
            name=dep.name,
            version=version,
            config=cfg,
            tree=tree,
            source=source,
            sha256=sha256
        );
        self.locals[dep.name] = pkg;
        for nested in cfg.dependencies.values() {
            if nested.kind() != "registry" {
                self.add_local(nested, tree);
            } elif nested.registry {
                self.origin_registry.setdefault(nested.name, nested.registry);
            }
        }
        return pkg;
    }

    override def versions(name: str) -> list[Version] {
        if name in self.locals {
            return [self.locals[name].version];
        }
        try {
            entries = self.registry_for(name).entries(name);
        } except RegistryError as e {
            raise ResolveError(str(e));
        }
        out: list[Version] = [];
        for e in entries {
            if e.yanked and self.locked.get(name) != e.version {
                continue;
            }
            try {
                out.append(Version.parse(e.version));
            } except SemverError {
                continue;
            }
        }
        return out;
    }

    def _entry(name: str, version: Version) -> IndexEntry {
        item = self.registry_for(name).find(name, str(version));
        if item is None {
            raise ResolveError(f"{name} {version} vanished from the index");
        }
        return item;
    }

    override def dependencies(name: str, version: Version) -> dict[str, Requirement] {
        raw: dict[str, str] = {};
        if name in self.locals {
            for (dep_name, dep) in self.locals[name].config.dependencies.items() {
                raw[dep_name] = dep.version;
            }
        } else {
            item = self._entry(name, version);
            for (dep_name, text) in item.deps.items() {
                raw[dep_name] = text;
                self.origin_registry.setdefault(
                    dep_name, self.origin_registry.get(name, "")
                );
            }
        }
        out: dict[str, Requirement] = {};
        for (dep_name, text) in raw.items() {
            try {
                req = Requirement.parse(text);
            } except SemverError as e {
                raise ResolveError(f"{name} {version} -> {dep_name}: {e}");
            }
            self.note_requirement(dep_name, req);
            out[dep_name] = req;
        }
        return out;
    }

    override def unavailable_reason(name: str, version: Version) -> str {
        if name in self.locals {
            wanted = self.locals[name].config.project.jac_version;
            role = "lib";
        } else {
            item = self._entry(name, version);
            wanted = item.jac_version;
            role = item.role;
        }
        if role != "lib" {
            return f"it is a {role} package, not a library";
        }
        if wanted and not jac_satisfies(str(self.jac_version), wanted) {
            return f"it needs jac {wanted}, this is jac {self.jac_version}";
        }
        return "";
    }

    override def preferred(name: str) -> Version | None {
        if self.unlock_all or name in self.unlock {
            return None;
        }
        pinned = self.locked.get(name);
        if not pinned {
            return None;
        }
        try {
            return Version.parse(pinned);
        } except SemverError {
            return None;
        }
    }

    override def allows_prerelease(name: str) -> bool {
        return name in self.prerelease;
    }

    def locked_entry(name: str, version: Version) -> LockedPackage {
        if name in self.locals {
            pkg = self.locals[name];
            return LockedPackage(
                name=name,
                version=str(version),
                source=pkg.source,
                sha256=pkg.sha256,
                deps=sorted(pkg.config.dependencies.keys()),
                pypi=manifest_pypi(pkg.config),
                npm=manifest_npm(pkg.config)
            );
        }
        item = self._entry(name, version);
        return LockedPackage(
            name=name,
            version=str(version),
            source=f"registry+{self.registry_for(name).base()}",
            sha256=item.sha256,
            deps=sorted(item.deps.keys()),
            pypi=dict(item.pypi),
            npm=dict(item.npm)
        );
    }
}

def _mark_dev(
    packages: list[LockedPackage], runtime_roots: list[str]
) -> list[LockedPackage] {
    by_name = {p.name: p for p in packages};
    reachable: set[str] = set();
    pending = list(runtime_roots);
    while pending {
        name = pending.pop();
        if name in reachable or name not in by_name {
            continue;
        }
        reachable.add(name);
        pending.extend(by_name[name].deps);
    }
    for p in packages {
        p.dev = p.name not in reachable;
    }
    return packages;
}

def resolve_graph(
    config: JacConfig, previous: Lockfile | None = None, update: list[str] | None = None
) -> Lockfile {
    import from jaclang.compiler.driver.jir { jaclang_version }
    if config.project_root is None {
        raise ResolveError("resolving packages needs a project (jac.toml)");
    }
    root_dir = Path(config.project_root);
    source = GraphSource(
        root_dir=root_dir,
        registries=dict(config.registries),
        locked={
            p.name: p.version
            for p in (previous.packages if previous is not None else [])
        },
        unlock=set(update or []),
        unlock_all=update is not None and not update,
        jac_version=running_jac_version()
    );
    root_deps: dict[str, Requirement] = {};
    for dep in [*config.dependencies.values(), *config.dev_dependencies.values()] {
        if dep.kind() != "registry" {
            source.add_local(dep, root_dir);
        } elif dep.registry {
            source.origin_registry[dep.name] = dep.registry;
        }
        try {
            req = Requirement.parse(dep.version);
        } except SemverError as e {
            raise ResolveError(f"jac.toml: {dep.name}: {e}");
        }
        source.note_requirement(dep.name, req);
        root_deps[dep.name] = req;
    }
    root_name = config.project.name
        if is_package_name(config.project.name)
        else "the project";
    try {
        root_version = Version.parse(config.project.version);
    } except SemverError {
        root_version = Version.parse("0.0.0");
    }
    try {
        decisions = solve(source, root_name, root_version, root_deps);
    } except SolveFailure as e {
        raise ResolveError(str(e));
    }
    packages = [
        source.locked_entry(name, version)
        for (name, version) in sorted(decisions.items())
    ];
    _mark_dev(packages, list(config.dependencies.keys()));
    lock = Lockfile(
        jac=jaclang_version(), inputs=manifest_inputs(config), packages=packages
    );
    if previous is not None {
        lock.pypi_resolved = previous.pypi_resolved;
        lock.pypi_inputs = previous.pypi_inputs;
        lock.npm_bun_lock = previous.npm_bun_lock;
    }
    return lock;
}
