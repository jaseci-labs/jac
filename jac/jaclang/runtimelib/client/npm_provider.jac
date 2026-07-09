import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.project.providers {
    EMIT_EJECT,
    EcosystemProvider,
    InstallContext,
    ResolvedDependency,
    manifest_plugin_deps
}
import from jaclang.runtimelib.client_bundle { ClientBundleError }

glob CORE_RUNTIME_DEPS: dict[str, str] = {
         "react": "^18.2.0",
         "react-dom": "^18.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0"
     },
     OPTIONAL_RUNTIME_DEPS: dict[str, str] = {
         "@tanstack/react-form": "^1.33.0",
         "zod": "^4.3.6"
     },
     CORE_DEV_DEPS: dict[str, str] = {
         "vite": "^6.4.1",
         "@vitejs/plugin-react": "4.7.0",
         "typescript": "^5.3.3",
         "@types/react": "^18.2.0",
         "@types/react-dom": "^18.2.0"
     },
     LEGACY_META_PACKAGES: set = {"jac-client-node", "@jac-client/dev-deps"};


def resolve_client_target_name(config: JacConfig) -> str {
    import os;
    client_config = config.get_plugin_config("client");
    raw = str(client_config.get("target", "") or "").strip();
    if raw == "" {
        raw = str(os.environ.get("JAC_CLIENT_TARGET", "") or "").strip();
    }
    if raw == "" {
        return "web";
    }
    normalized = raw.lower().replace("-", "_");
    if normalized in ("rn", "reactnative") {
        return "react_native";
    }
    return normalized;
}


def target_scoped_npm_deps(config: JacConfig, target_name: str) -> dict[str, str] {
    npm_plugin_deps: dict = dict(config.plugin_dependencies.get("npm", {}));
    deps: dict[str, str] = {};
    key1 = str(target_name or "").strip();
    key2 = key1.replace("_", "-");
    for key in [key1, key2] {
        if key == "" {
            continue;
        }
        section = npm_plugin_deps.get(key, {});
        if isinstance(section, dict) {
            for (name, version) in section.items() {
                if isinstance(version, str) {
                    deps[name] = version;
                }
            }
        }
    }
    return deps;
}


def regenerate_and_install(project_dir: Path) {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    import from jaclang.runtimelib.client { get_bun }
    import from jaclang.runtimelib.client.bun_installer { bun_unavailable_message }

    bun = get_bun();
    if not bun {
        raise RuntimeError(bun_unavailable_message()) from None;
    }

    bundler = ViteBundler(project_dir);
    bundler.create_package_json();

    try {
        bundler.install_packages(force=True);
    } except ClientBundleError as e {
        raise RuntimeError(f"Failed to install packages: {e}") from e;
    }
}


obj NpmProvider(EcosystemProvider) {
    has name: str = "npm",
        manifest_key: str = "npm",
        cli_flag: str = "--npm";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency] {
        (deps, dev_deps) = manifest_plugin_deps(config, "npm");
        is_client = "client" in config.plugins;
        resolved: list[ResolvedDependency] = [];
        for (pkg, version) in deps.items() {
            if is_client and pkg in LEGACY_META_PACKAGES {
                continue;
            }
            resolved.append(
                ResolvedDependency(
                    name=pkg,
                    version=version,
                    ecosystem="npm",
                    source="npm",
                    origin="manifest"
                )
            );
        }

        for (pkg, version) in dev_deps.items() {
            if is_client and pkg in LEGACY_META_PACKAGES {
                continue;
            }
            resolved.append(
                ResolvedDependency(
                    name=pkg,
                    version=version,
                    ecosystem="npm",
                    source="npm",
                    origin="manifest",
                    dev=True
                )
            );
        }
        if is_client {
            core_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
            for (pkg, version) in core_runtime.items() {
                if pkg not in deps {
                    resolved.append(
                        ResolvedDependency(
                            name=pkg,
                            version=version,
                            ecosystem="npm",
                            source="npm",
                            origin="self-heal:client-core"
                        )
                    );
                }
            }
            for (pkg, version) in CORE_DEV_DEPS.items() {
                if pkg not in dev_deps {
                    resolved.append(
                        ResolvedDependency(
                            name=pkg,
                            version=version,
                            ecosystem="npm",
                            source="npm",
                            origin="self-heal:client-core",
                            dev=True
                        )
                    );
                }
            }
            target_name = resolve_client_target_name(config);
            for (pkg, version) in target_scoped_npm_deps(config, target_name).items() {
                resolved.append(
                    ResolvedDependency(
                        name=pkg,
                        version=version,
                        ecosystem="npm",
                        source="npm",
                        origin=f"target:{target_name}"
                    )
                );
            }
        }
        return resolved;
    }

    override def parse_spec(spec: str) -> tuple[str, str] {
        import re;
        spec = spec.strip();
        scoped = re.match(r"^(@[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+)@(.+)$", spec);
        if scoped {
            return (scoped.group(1), scoped.group(2));
        }
        plain = re.match(r"^([a-zA-Z0-9_.-]+)@(.+)$", spec);
        if plain {
            return (plain.group(1), plain.group(2));
        }
        return (spec, "");
    }

    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool {
        if not deps {
            return True;
        }
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        regenerate_and_install(Path(str(config.project_root)));
        return True;
    }

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None {
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        package_version: str = version or "latest";

        (deps, dev_deps) = manifest_plugin_deps(config, "npm");
        previous = (dev_deps if dev else deps).get(name);
        config.add_dependency(name, package_version, dev=dev, dep_type="npm");
        config.save();
        try {
            regenerate_and_install(Path(str(config.project_root)));
        } except Exception {
            if previous is not None {
                config.add_dependency(name, previous, dev=dev, dep_type="npm");
            } else {
                config.remove_dependency(name, dev=dev, dep_type="npm");
            }
            config.save();
            raise;
        }
        return package_version;
    }

    override def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool {
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        (deps, dev_deps) = manifest_plugin_deps(config, "npm");
        previous = (dev_deps if dev else deps).get(name);
        if not config.remove_dependency(name, dev=dev, dep_type="npm") {
            return False;
        }
        config.save();
        try {
            regenerate_and_install(Path(str(config.project_root)));
        } except Exception {
            if previous is not None {
                config.add_dependency(name, previous, dev=dev, dep_type="npm");
                config.save();
            }
            raise;
        }
        return True;
    }

    override def emit_standalone(
        config: JacConfig, deps: list[ResolvedDependency], out_dir: Path, mode: str
    ) -> list[Path] {
        import json;
        if mode != EMIT_EJECT {
            return [];
        }
        pkg_deps: dict[str, str] = {};
        dev_deps: dict[str, str] = {};
        for dep in deps {
            if dep.dev {
                dev_deps[dep.name] = dep.version;
            } else {
                pkg_deps[dep.name] = dep.version;
            }
        }
        if "vite" not in dev_deps and "vite" not in pkg_deps {
            dev_deps["vite"] = CORE_DEV_DEPS["vite"];
        }
        raw_name = config.project.name or out_dir.name;
        pkg = {
            "name": raw_name.lower().replace("_", "-").replace(" ", "-"),
            "version": config.project.version or "0.1.0",
            "private": True,
            "type": "module",
            "scripts": {
                "dev": "vite",
                "build": "vite build",
                "preview": "vite preview"
            },
            "dependencies": pkg_deps,
            "devDependencies": dev_deps
        };
        out_dir.mkdir(parents=True, exist_ok=True);
        pkg_path = out_dir / "package.json";
        pkg_path.write_text(json.dumps(pkg, indent=2) + "\n", encoding="utf-8");
        return [pkg_path];
    }
}
