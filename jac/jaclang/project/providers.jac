import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.project.config { JacConfig }
import from jaclang.project.pyvenv {
    ensure_venv,
    get_venv_site_packages,
    make_git_spec,
    make_pip_spec,
    run_pip,
    summarize_pip_failure
}

glob EMIT_EJECT: str = "eject",
     EMIT_PUBLISH: str = "publish";

obj ResolvedDependency {
    has name: str,
        version: str = "",
        ecosystem: str = "python",
        source: str = "pypi",
        origin: str = "manifest",
        dev: bool = False,
        data: dict[str, str] = {};
}

obj DependencyPlan {
    has deps: list[ResolvedDependency] = [];

    def for_ecosystem(name: str) -> list[ResolvedDependency] {
        return [
            d
            for d in self.deps
            if d.ecosystem == name
        ];
    }

    def ecosystems -> list[str] {
        seen: list[str] = [];
        for d in self.deps {
            if d.ecosystem not in seen {
                seen.append(d.ecosystem);
            }
        }
        return seen;
    }

    def is_empty -> bool {
        return not self.deps;
    }
}

obj InstallContext {
    has verbose: bool = False,
        install_flags: list[str] = [],
        target: str = "project";

    def is_dry_run -> bool {
        return "--dry-run" in self.install_flags;
    }
}

obj EcosystemProvider {
    has name: str = "",
        manifest_key: str = "",
        cli_flag: str = "";

    def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency] {
        return [];
    }

    def parse_spec(spec: str) -> tuple[str, str] {
        return (spec.strip(), "");
    }

    def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool {
        raise NotImplementedError(f"provider '{self.name}' cannot install");
    }

    def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None {
        raise NotImplementedError(f"provider '{self.name}' cannot add packages");
    }

    def add_packages(
        config: JacConfig, specs: list[tuple[str, str]], dev: bool, ctx: InstallContext
    ) -> list[str] | None {
        recorded: list[str] = [];
        for (name, version) in specs {
            one = self.add_package(config, name, version, dev, ctx);
            if one is None {
                return None;
            }
            recorded.append(one);
        }
        return recorded;
    }

    def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool {
        raise NotImplementedError(f"provider '{self.name}' cannot remove packages");
    }

    def list_installed(config: JacConfig) -> list[str] {
        return [];
    }

    def emit_standalone(
        config: JacConfig, deps: list[ResolvedDependency], out_dir: Path, mode: str
    ) -> list[Path] {
        return [];
    }
}

def manifest_plugin_deps(
    config: JacConfig, key: str
) -> tuple[dict[str, str], dict[str, str]] {
    raw = config.plugin_dependencies.get(key, {});
    deps: dict[str, str] = {
        k: v
        for (k, v) in raw.items()
        if k != "dev" and isinstance(v, str)
    };
    dev_section = raw.get("dev", {});
    dev_deps: dict[str, str] = {};
    if isinstance(dev_section, dict) {
        for (k, v) in dev_section.items() {
            if isinstance(k, str) and isinstance(v, str) {
                dev_deps[k] = v;
            }
        }
    }
    return (deps, dev_deps);
}

obj PythonProvider(EcosystemProvider) {
    has name: str = "python",
        manifest_key: str = "",
        cli_flag: str = "";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency] {
        resolved: list[ResolvedDependency] = [];
        for (name, version) in config.dependencies.items() {
            resolved.append(
                ResolvedDependency(name=name, version=version, origin="manifest")
            );
        }
        if include_dev {
            for (name, version) in config.dev_dependencies.items() {
                resolved.append(
                    ResolvedDependency(
                        name=name, version=version, origin="manifest", dev=True
                    )
                );
            }
        }
        for (name, git_info) in config.git_dependencies.items() {
            if isinstance(git_info, dict) and "git" in git_info {
                resolved.append(
                    ResolvedDependency(
                        name=name,
                        version=git_info.get("branch", ""),
                        source="git",
                        origin="manifest",
                        data={
                            "git": str(git_info.get("git", "")),
                            "branch": str(git_info.get("branch", ""))
                        }
                    )
                );
            }
        }
        return resolved;
    }

    def resolve_extras(
        config: JacConfig, groups: list[str]
    ) -> list[ResolvedDependency] {
        opt_deps = config.optional_dependencies;
        unknown: list[str] = [
            g
            for g in groups
            if g not in opt_deps
        ];
        if unknown {
            available: str = ", ".join(sorted(opt_deps.keys())) if opt_deps else "none";
            raise ValueError(
                f"Unknown extras: {', '.join(unknown)}. Available: {available}"
            );
        }
        pkg_key: str = config.project.name.lower().replace("_", "-");
        resolved: dict[str, tuple[str, str]] = {};
        seen: set[str] = set();
        queue: list[str] = list(groups);
        while queue {
            group: str = queue.pop(0);
            if group in seen or group not in opt_deps {
                continue;
            }
            seen.add(group);
            for (name, ver) in opt_deps[group].items() {
                if "[" in name and name.endswith("]") {
                    bracket: int = name.index("[");
                    dep_pkg: str = name[:bracket].lower().replace("_", "-").strip();
                    if dep_pkg == pkg_key {
                        queue.extend(
                            [g.strip() for g in name[bracket + 1:-1].split(",")]
                        );
                        continue;
                    }
                }
                resolved[name] = (ver, group);
            }
        }
        extras_deps: list[ResolvedDependency] = [];
        for (dep_name, info) in resolved.items() {
            extras_deps.append(
                ResolvedDependency(
                    name=dep_name, version=info[0], origin=f"extra:{info[1]}"
                )
            );
        }
        return extras_deps;
    }

    override def parse_spec(spec: str) -> tuple[str, str] {
        import re;
        spec = spec.strip();
        m = re.match(r"^([a-zA-Z0-9._-]+)\s*([<>=!~]+.+)?$", spec);
        if m {
            return (m.group(1), m.group(2) or "");
        }
        return (spec, "");
    }

    def pip_spec(dep: ResolvedDependency) -> str {
        if dep.source == "git" {
            return make_git_spec(dep.data.get("git", ""), dep.data.get("branch", ""));
        }
        return make_pip_spec(dep.name, dep.version);
    }

    def specs_for(deps: list[ResolvedDependency]) -> list[str] {
        return [self.pip_spec(d) for d in deps];
    }

    def _project_venv(config: JacConfig) -> Path {
        if config is None {
            raise ValueError(
                "No jac.toml found. Run 'jac create <name>' to create a project."
            );
        }
        return config.get_venv_dir();
    }

    def _run_project_pip(
        config: JacConfig, args: list[str], verbose: bool = False
    ) -> tuple[int, str, str] {
        return run_pip(self._project_venv(config), args, verbose);
    }

    def _snapshot_installed(config: JacConfig) -> tuple[bool, set[tuple]] {
        import json;
        try {
            (rc, out, _) = self._run_project_pip(config, ["list", "--format=json"]);
            if rc == 0 {
                return (
                    True,
                    {(p["name"].lower(), p["version"]) for p in json.loads(out)}
                );
            }
        } except Exception { }
        return (False, set());
    }

    def install_specs(
        config: JacConfig, specs: list[str], ctx: InstallContext
    ) -> bool {
        if not specs {
            return True;
        }
        if ctx.target == "global" {
            return self._install_global(specs, ctx);
        }
        venv_dir = self._project_venv(config);
        ensure_venv(venv_dir, ctx.verbose);
        is_dry_run = ctx.is_dry_run();
        (before_snapshot_ok, before_set) = (
            self._snapshot_installed(config) if not is_dry_run else (False, set())
        );
        (returncode, stdout, stderr) = self._run_project_pip(
            config, ["install", "--upgrade"] + ctx.install_flags + specs, ctx.verbose
        );
        if returncode == 0 {
            if is_dry_run {
                preview = stderr or stdout;
                if preview {
                    console.print(preview, style="dim");
                }
                return True;
            }
            newly_installed: list[tuple] = [];
            (after_ok, after_set) = self._snapshot_installed(config);
            if after_ok and before_snapshot_ok {
                newly_installed = sorted(after_set - before_set);
            }
            if newly_installed {
                console.print("✔ Installation complete:", style="success");
                for (pkg_name, pkg_ver) in newly_installed {
                    console.print(f"  ✓ {pkg_name}=={pkg_ver}", style="dim");
                }
            } else {
                console.print(
                    f"✔ Successfully installed {len(specs)} package(s)", style="success"
                );
            }
            return True;
        }

        (package, detail) = summarize_pip_failure(specs, stderr);
        header = (
            f"Failed to install {package}"
                if package
                else f"Failed to install {len(specs)} package(s)"
        );
        console.error(
            f"{header}\n  {detail}" if detail else header,
            hint=None if ctx.verbose else "re-run with --verbose for full pip output"
        );
        if ctx.verbose and stderr.strip() {
            console.print(stderr.strip(), style="dim");
        }
        return False;
    }

    def _install_global(specs: list[str], ctx: InstallContext) -> bool {
        import subprocess;
        import sys;
        cmd: list[str] = [sys.executable, "-m", "pip", "install", "--upgrade"] + ctx.install_flags + specs;
        if ctx.verbose {
            console.print(f"  Running: {' '.join(cmd)}", style="muted");
        }
        result = subprocess.run(cmd, capture_output=not ctx.verbose, text=True);
        if result.returncode != 0 {
            console.error(
                f"Install failed:\n{result.stderr
                or result.stdout
                or '(see output above)'}"
            );
            return False;
        }
        if ctx.is_dry_run() and result.stdout {
            console.print(result.stdout, style="dim");
        }
        return True;
    }

    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool {
        return self.install_specs(config, self.specs_for(deps), ctx);
    }

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None {
        recorded = self.add_packages(config, [(name, version)], dev, ctx);
        return recorded[0] if recorded else None;
    }

    override def add_packages(
        config: JacConfig, specs: list[tuple[str, str]], dev: bool, ctx: InstallContext
    ) -> list[str] | None {
        plan: list[tuple[str, str]] = [];
        for (name, version) in specs {
            declared = _declared_constraint(config, name, dev);
            keep_typed_name = declared is None or "[" in name;
            record_name = name if keep_typed_name else declared[0];
            if version {
                if declared and declared[1] != version {
                    console.warning(
                        f"{declared[0]}: replacing declared constraint "
                        f"'{declared[1]}' with '{version}' in jac.toml"
                    );
                }
                plan.append((record_name, version));
            } elif declared {
                plan.append((record_name, declared[1]));
            } else {
                plan.append((name, ""));
            }
        }
        install_targets: list[str] = [
            make_pip_spec(name, version) for (name, version) in plan
        ];
        if not self.install_specs(config, install_targets, ctx) {
            return None;
        }
        recorded: list[str] = [];
        for (name, version) in plan {
            version_str = version;
            if not version_str {
                installed_version = self.get_installed_version(config, name);
                if installed_version {
                    version_str = f"~={_major_minor(installed_version)}";
                    if ctx.verbose {
                        console.print(
                            f"Detected version: {installed_version}", style="muted"
                        );
                    }
                } else {
                    version_str = ">=0.0.0";
                    if ctx.verbose {
                        console.warning(
                            f"Could not detect version for {name}, using >=0.0.0"
                        );
                    }
                }
            }
            config.add_dependency(name, version_str, dev=dev, dep_type="python");
            recorded.append(version_str);
        }
        return recorded;
    }

    override def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool {
        dep_type = "python";
        is_dev = dev;
        if name in config.git_dependencies {
            dep_type = "git";
        } elif not dev
        and name not in config.dependencies
        and name in config.dev_dependencies {
            is_dev = True;
        }
        if not config.remove_dependency(name, dev=is_dev, dep_type=dep_type) {
            return False;
        }
        self.uninstall(config, name, ctx);
        return True;
    }

    def uninstall(config: JacConfig, name: str, ctx: InstallContext) -> bool {
        venv_dir = self._project_venv(config);
        if not venv_dir.exists() {
            return False;
        }
        console.print(f"Uninstalling {name}...");
        if not self.is_installed(config, name) {
            if ctx.verbose {
                console.print(f"  {name} was not installed");
            }
            return False;
        }
        (returncode, stdout, stderr) = self._run_project_pip(
            config, ["uninstall", "-y", name]
        );
        if returncode == 0 {
            console.print(f"  {name} uninstalled successfully");
            return True;
        }
        console.error(f"  Failed to uninstall {name}: {stderr}");
        return False;
    }

    def is_installed(config: JacConfig, name: str) -> bool {
        if not self._project_venv(config).exists() {
            return False;
        }
        (returncode, _, _) = self._run_project_pip(config, ["show", name]);
        return returncode == 0;
    }

    def get_installed_version(config: JacConfig, name: str) -> str | None {
        if not self._project_venv(config).exists() {
            return None;
        }
        (returncode, stdout, _) = self._run_project_pip(config, ["show", name]);
        if returncode != 0 {
            return None;
        }
        for line in stdout.splitlines() {
            line = line.strip();
            if line.startswith("Version:") {
                return line.split(":", 1)[1].strip();
            }
        }
        return None;
    }

    override def list_installed(config: JacConfig) -> list[str] {
        import json;
        if not self._project_venv(config).exists() {
            return [];
        }
        (returncode, stdout, _) = self._run_project_pip(
            config, ["list", "--format=json"]
        );
        if returncode != 0 {
            return [];
        }
        try {
            packages_data = json.loads(stdout);
            infrastructure = {"pip", "setuptools", "wheel"};
            return sorted(
                [
                    str(pkg["name"])
                    for pkg in packages_data
                    if str(pkg["name"]).lower() not in infrastructure
                ]
            );
        } except (json.JSONDecodeError, KeyError) {
            return [];
        }
    }

    override def emit_standalone(
        config: JacConfig, deps: list[ResolvedDependency], out_dir: Path, mode: str
    ) -> list[Path] {
        lines: list[str] = [];
        for dep in deps {
            spec = self.pip_spec(dep);
            if dep.origin.startswith("capability:") {
                lines.append(f"{spec}  # via {dep.origin}");
            } else {
                lines.append(spec);
            }
        }
        out_dir.mkdir(parents=True, exist_ok=True);
        req_path = out_dir / "requirements.txt";
        req_path.write_text("\n".join(lines) + "\n", encoding="utf-8");
        return [req_path];
    }
}

def _major_minor(version: str) -> str {
    parts = version.split(".");
    if len(parts) >= 2 {
        return f"{parts[0]}.{parts[1]}";
    }
    return version;
}

obj ProviderRegistry {
    has _providers: dict[str, EcosystemProvider] = {},
        _order: list[str] = [];

    def register(provider: EcosystemProvider) {
        if not provider.name {
            raise ValueError("Ecosystem provider must have a 'name'");
        }
        if provider.name not in self._order {
            self._order.append(provider.name);
        }
        self._providers[provider.name] = provider;
    }

    def get(name: str) -> EcosystemProvider | None {
        return self._providers.get(name);
    }

    def get_by_flag(flag: str) -> EcosystemProvider | None {
        for provider in self._providers.values() {
            if provider.cli_flag and provider.cli_flag == flag {
                return provider;
            }
        }
        return None;
    }

    def all -> list[EcosystemProvider] {
        return [self._providers[name] for name in self._order];
    }

    def has(name: str) -> bool {
        return name in self._providers;
    }

    def clear {
        self._providers.clear();
        self._order.clear();
    }
}

glob _registry: ProviderRegistry | None = None;

def get_provider_registry -> ProviderRegistry {
    global _registry;
    if _registry is None {
        _registry = ProviderRegistry();
        _registry.register(PythonProvider());
    }
    return _registry;
}

def get_python_provider -> PythonProvider {
    provider = get_provider_registry().get("python");
    if not isinstance(provider, PythonProvider) {
        raise RuntimeError("python provider missing from the registry");
    }
    return provider;
}

def reset_provider_registry {
    global _registry;
    _registry = None;
}

def initialize_provider_registry -> None {
    registry = get_provider_registry();

    try {
        import from jaclang.runtimelib.client.plugin_config { JacClientPluginConfig }
    } except Exception {
        return;
    }
    results = JacClientPluginConfig.register_ecosystem_providers();
    if results is None {
        return;
    }
    for result in results {
        if result is None {
            continue;
        }
        providers = result if isinstance(result, list) else [result];
        for provider in providers {
            if isinstance(provider, EcosystemProvider) {
                registry.register(provider);
            }
        }
    }
}

def capability_dependencies(
    config: JacConfig,
    action: str = "",
    scale: bool = False,
    detected_intents: list[str] = []
) -> list[ResolvedDependency] {
    import from jaclang.project.capabilities {
        DEPLOY,
        RUNTIME,
        byllm_intent_capabilities,
        command_capabilities,
        derive_capabilities,
        get_capability_registry,
        resolve_closure,
        scale_intent_from_config
    }
    import from jaclang.project.kinds { plan_project_run }
    if config is None {
        return [];
    }
    if not action {
        proj_root = str(config.project_root) if config.project_root else ".";
        plan = plan_project_run(config, proj_root);
        action = plan.action if plan else "execute";
    }
    intent = scale_intent_from_config(config);
    if intent and action != "serve" {
        action = "serve";
    }
    caps = derive_capabilities(intent, command_capabilities(action, scale));
    caps |= byllm_intent_capabilities(config);
    caps |= set(detected_intents);
    if not caps {
        return [];
    }
    context = DEPLOY if scale else RUNTIME;
    closure = resolve_closure(caps, context);
    cap_registry = get_capability_registry();
    seen: set[str] = set();
    resolved: list[ResolvedDependency] = [];
    for cap_name in closure.capabilities {
        for (pkg, ver) in sorted(cap_registry[cap_name].deps.items()) {
            if pkg in seen {
                continue;
            }
            seen.add(pkg);
            resolved.append(
                ResolvedDependency(
                    name=pkg, version=ver, origin=f"capability:{cap_name}"
                )
            );
        }
    }
    return resolved;
}

def _normalized_name(name: str) -> str {
    base = name;
    if "[" in base {
        base = base[:base.index("[")];
    }
    return base.strip().lower().replace("_", "-");
}

def _declared_constraint(
    config: JacConfig, name: str, dev: bool
) -> tuple[str, str] | None {
    sections = (
        [config.dev_dependencies, config.dependencies]
            if dev
            else [config.dependencies, config.dev_dependencies]
    );
    wanted = _normalized_name(name);
    for section in sections {
        for (declared, spec) in section.items() {
            if _normalized_name(declared) == wanted
            and isinstance(spec, str)
            and spec.strip() {
                return (declared, spec.strip());
            }
        }
    }
    return None;
}

def resolve_plan(
    config: JacConfig,
    include_dev: bool = False,
    extras: list[str] = [],
    action: str = "",
    scale: bool = False,
    detected_intents: list[str] = [],
    include_capabilities: bool = True
) -> DependencyPlan {
    plan = DependencyPlan();
    if config is None {
        return plan;
    }
    registry = get_provider_registry();
    for provider in registry.all() {
        plan.deps.extend(provider.resolve(config, include_dev));
    }
    if extras {
        plan.deps.extend(get_python_provider().resolve_extras(config, extras));
    }
    if include_capabilities {
        manifest_names = {
            _normalized_name(d.name) for d in plan.for_ecosystem("python")
        };
        for dep in capability_dependencies(config, action, scale, detected_intents) {
            if _normalized_name(dep.name) not in manifest_names {
                plan.deps.append(dep);
            }
        }
    }
    return plan;
}
