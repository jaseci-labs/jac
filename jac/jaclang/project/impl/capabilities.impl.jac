impl CapabilityClosure.is_empty -> bool {
    return not self.deps;
}

impl CapabilityClosure.package_names -> list[str] {
    return sorted(self.deps.keys());
}

impl get_capability_registry -> dict[str, Capability] {
    if _registry is None {
        built: dict[str, Capability] = {};
        for (name, spec) in CAPABILITY_SPECS.items() {
            built[name] = Capability(
                name=name,
                deps=dict(spec.get("deps", {})),
                context=str(spec.get("context", RUNTIME)),
                requires=list(spec.get("requires", []))
            );
        }
        for cap in built.values() {
            for req in cap.requires {
                if req not in built {
                    raise ValueError(
                        f"Capability '{cap.name}' requires unknown capability '{req}'. "
                        f"Available: {', '.join(sorted(built.keys()))}"
                    );
                }
            }
        }
        _registry = built;
    }
    return _registry;
}

impl get_capability(name: str) -> Capability | None {
    return get_capability_registry().get(name);
}

impl all_capability_names -> list[str] {
    return sorted(get_capability_registry().keys());
}

impl _normalize_package(name: str) -> str {
    base = name;
    if "[" in base {
        base = base[:base.index("[")];
    }
    return base.strip().lower().replace("_", "-").replace(".", "-");
}

impl derive_capabilities(
    intent: dict[str, any] | None, commands: list[str] | None = None
) -> set[str] {
    caps: set[str] = set(commands or []);
    if not isinstance(intent, dict) {
        return caps;
    }
    for rule in INTENT_RULES {
        section = intent.get(str(rule["section"]));
        if not isinstance(section, dict) {
            continue;
        }
        keys: list[str] = list(rule["keys"]);
        flag = rule.get("flag");
        if flag is not None {
            for key in keys {
                if section.get(key) {
                    caps.add(str(flag));
                }
            }
            continue;
        }
        values: dict[str, str] = dict(rule.get("values", {}));
        for key in keys {
            raw = section.get(key);
            if isinstance(raw, str) {
                cap = values.get(raw.strip().lower());
                if cap {
                    caps.add(str(cap));
                }
            }
        }
    }
    return caps;
}

impl scale_intent_from_config(config: JacConfig) -> dict[str, any] {
    if config is None {
        return {};
    }
    raw = config.get_section("scale");
    if isinstance(raw, dict) {
        return raw;
    }
    plugin = config.plugins.get("scale") if isinstance(config.plugins, dict) else None;
    if isinstance(plugin, dict) {
        return plugin;
    }
    return {};
}

impl command_capabilities(action: str, scale: bool = False) -> list[str] {
    if action != "serve" {
        return [];
    }
    caps: list[str] = ["serve"];
    if scale {
        caps.append("deploy.k8s");
    }
    return caps;
}

impl _expand_requires(cap_names: set[str]) -> set[str] {
    available = get_capability_registry();
    unknown = sorted(
        [
            c
            for c in cap_names
            if c not in available
        ]
    );
    if unknown {
        raise ValueError(
            f"Unknown capability: {', '.join(unknown)}. "
            f"Available: {', '.join(all_capability_names())}"
        );
    }
    full: set[str] = set();
    stack = list(cap_names);
    while stack {
        cur = stack.pop();
        if cur in full or cur not in available {
            continue;
        }
        full.add(cur);
        stack.extend(available[cur].requires);
    }
    return full;
}

impl resolve_closure(cap_names: set[str], context: str) -> CapabilityClosure {
    registry = get_capability_registry();
    full = _expand_requires(cap_names);
    selected: list[str] = [];
    deps: dict[str, str] = {};
    for name in sorted(full) {
        cap = registry[name];
        if context == DEPLOY or cap.context == RUNTIME {
            selected.append(name);
            for (pkg, ver) in cap.deps.items() {
                deps[pkg] = ver;
            }
        }
    }
    return CapabilityClosure(context=context, capabilities=selected, deps=deps);
}

impl resolve_closures(cap_names: set[str]) -> dict[str, CapabilityClosure] {
    return {
        RUNTIME: resolve_closure(cap_names, RUNTIME),
        DEPLOY: resolve_closure(cap_names, DEPLOY)
    };
}

impl byllm_intent_capabilities(config: JacConfig) -> set[str] {
    caps: set[str] = set();
    if config is None {
        return caps;
    }
    byllm = config.plugins.get("byllm") if isinstance(config.plugins, dict) else None;
    if not isinstance(byllm, dict) {
        return caps;
    }
    caps.add("llm");
    model = byllm.get("model");
    default_model = model.get("default_model", "") if isinstance(model, dict) else "";
    if (isinstance(default_model, str) and default_model.startswith("local:"))
        or isinstance(byllm.get("local"), dict) {
        caps.add("llm.local");
    }
    return caps;
}

impl resolve_config_closures(
    config: JacConfig, action: str = "serve", scale: bool = False
) -> dict[str, CapabilityClosure] {
    intent = scale_intent_from_config(config);
    caps = derive_capabilities(intent, command_capabilities(action, scale));
    caps |= byllm_intent_capabilities(config);
    return resolve_closures(caps);
}

impl capability_for_package(package: str) -> str | None {
    target = _normalize_package(package);
    for name in all_capability_names() {
        cap = get_capability(name);
        if cap is None {
            continue;
        }
        for pkg in cap.deps.keys() {
            if _normalize_package(pkg) == target {
                return name;
            }
        }
    }
    return None;
}

impl missing_capability_error(capability: str) -> str {
    cap = get_capability(capability);
    if cap is None {
        return (
            f"Unknown capability '{capability}'. "
            f"Available: {', '.join(all_capability_names())}"
        );
    }
    where = "operator machine" if cap.context == DEPLOY else "project";
    provides = ", ".join(sorted(cap.deps.keys()));
    return (
        f"Capability '{capability}' is required but not installed (provides: {provides}). "
        f"Declare the matching intent in jac.toml, then run 'jac install' to sync the "
        f"'{cap.context}' closure into the {where}'s .jac/venv."
    );
}

impl package_missing_error(package: str) -> str {
    cap = capability_for_package(package);
    if cap is None {
        return (
            f"'{package}' is required but not installed. "
            f"Add it with 'jac install {package}'."
        );
    }
    return f"'{package}' is missing. {missing_capability_error(cap)}";
}

impl missing_capability_dists(capability: str) -> list[str] {
    import from importlib.metadata { distribution, PackageNotFoundError }
    registry = get_capability_registry();
    if capability not in registry {
        return [];
    }
    missing: list[str] = [];
    for name in sorted(_expand_requires({capability})) {
        for (pkg, ver) in registry[name].deps.items() {
            base = pkg[:pkg.index("[")] if "[" in pkg else pkg;
            try {
                distribution(base.strip());
            } except PackageNotFoundError {
                if not ver or ver in ("*", "latest") {
                    missing.append(pkg);
                } elif ver.startswith(("=", ">", "<", "~", "!")) {
                    missing.append(f"{pkg}{ver}");
                } else {
                    missing.append(f"{pkg}=={ver}");
                }
            }
        }
    }
    return sorted(missing);
}

impl ensure_global_capability(capability: str) -> bool {
    import importlib;
    import subprocess;

    missing = missing_capability_dists(capability);
    if not missing {
        return get_capability(capability) is not None;
    }
    result = subprocess.run(
        pip_command(pip_python(), ["install", "--quiet"] + missing),
        capture_output=True,
        text=True,
        env=pip_env()
    );
    importlib.invalidate_caches();
    if result.returncode != 0 {
        import logging;
        detail = (result.stderr or result.stdout or "").strip();
        logging.getLogger(__name__).warning(
            f"pip install into the jac global site failed for capability "
            f"'{capability}' ({' '.join(missing)}): {detail}"
        );
    }
    return result.returncode == 0 and not missing_capability_dists(capability);
}

impl require_optional(package: str, capability: str) {
    try {
        __import__(package);
    } except (ImportError, ValueError) {
        raise ImportError(
            f"'{package}' is required for this feature. "
            f"{missing_capability_error(capability)}"
        );
    }
}

impl is_optional_available(package: str) -> bool {
    try {
        __import__(package);
        return True;
    } except (ImportError, ValueError) {
        return False;
    }
}
