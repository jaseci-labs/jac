import from jaclang.project.config { JacConfig }

glob RUNTIME: str = "runtime",
     DEPLOY: str = "deploy";

glob CAPABILITY_SPECS: dict[str, dict[str, any]] = {
         "serve": {
             "context": "runtime",
             "deps": {
                 "fastapi": ">=0.121.3,<0.122.0",
                 "uvicorn[standard]": ">=0.38.0,<0.39.0",
                 "pyjwt": ">=2.10.1,<2.11.0",
                 "fastapi-sso": ">=0.21.0,<1.0.0",
                 "python-multipart": ">=0.0.21,<1.0.0",
                 "bcrypt": ">=4.0.0,<5.0.0",
                 "aiohttp": ">=3.9.0,<4.0.0",
                 "sqlalchemy": ">=2.0.0,<3.0.0",
                 "email-validator": ">=2.3.0,<3.0.0",
                 "python-dotenv": ">=1.2.1,<2.0.0",
                 "requests": ">=2.32.0,<3.0.0"
             }
         },
         "data.mongo": {"context": "runtime", "deps": {"pymongo": ">=4.15.4,<5.0.0"}},
         "data.redis": {"context": "runtime", "deps": {"redis": ">=7.1.0,<8.0.0"}},
         "monitoring": {
             "context": "runtime",
             "deps": {"prometheus-client": ">=0.21.0,<1.0.0"}
         },
         "tracing": {
             "context": "runtime",
             "deps": {
                 "opentelemetry-sdk": ">=1.27.0,<2.0.0",
                 "opentelemetry-exporter-otlp-proto-http": ">=1.27.0,<2.0.0"
             }
         },
         "scheduler": {
             "context": "runtime",
             "deps": {"apscheduler": ">=3.11.2,<4.0.0"}
         },
         "storage.gcs": {
             "context": "runtime",
             "deps": {"google-cloud-storage": ">=2.19.0,<3.0.0"}
         },
         "storage.firebase": {
             "context": "runtime",
             "deps": {
                 "google-cloud-firestore": ">=2.21.0,<3.0.0",
                 "google-cloud-storage": ">=2.19.0,<3.0.0",
                 "firebase-admin": ">=6.0.0,<8.0.0"
             }
         },
         "storage.s3": {"context": "runtime", "deps": {"boto3": ">=1.40.0,<2.0.0"}},
         "deploy.k8s": {
             "context": "deploy",
             "deps": {"kubernetes": ">=34.1.0,<35.0.0", "docker": ">=7.1.0,<8.0.0"}
         },
         "llm": {
             "context": "runtime",
             "deps": {
                 "litellm": ">=1.70.0,<=1.82.6",
                 "pillow": ">=12.0.0,<13.0.0",
                 "httpx": ">=0.27.0",
                 "loguru": ">=0.7.2,<0.8.0"
             }
         },
         "llm.local": {
             "context": "runtime",
             "requires": ["llm"],
             "deps": {"llama-cpp-python": ">=0.2.90", "huggingface_hub": ">=0.24.0"}
         },
         "llm.mcp": {
             "context": "runtime",
             "requires": ["llm"],
             "deps": {"mcp": ">=1.0.0"}
         },
         "llm.video": {
             "context": "runtime",
             "requires": ["llm"],
             "deps": {"opencv-python-headless": ">=4.10.0,<5.0.0"}
         }
     };

glob INTENT_RULES: list[dict[str, any]] = [
         {
             "section": "database",
             "keys": ["backend", "type"],
             "values": {
                 "mongo": "data.mongo",
                 "mongodb": "data.mongo",
                 "redis": "data.redis"
             }
         },
         {
             "section": "events",
             "keys": ["backend", "broker"],
             "values": {"redis": "data.redis"}
         },
         {
             "section": "storage",
             "keys": ["backend", "type", "storage_type"],
             "values": {
                 "gcs": "storage.gcs",
                 "firebase": "storage.firebase",
                 "firestore": "storage.firebase",
                 "s3": "storage.s3"
             }
         },
         {
             "section": "deploy",
             "keys": ["target"],
             "values": {"kubernetes": "deploy.k8s", "k8s": "deploy.k8s"}
         },
         {"section": "monitoring", "keys": ["enabled"], "flag": "monitoring"},
         {"section": "tracing", "keys": ["enabled"], "flag": "tracing"},
         {"section": "scheduler", "keys": ["enabled"], "flag": "scheduler"}
     ];

obj Capability {
    has name: str,
        deps: dict[str, str] = {},
        context: str = "runtime",
        requires: list[str] = [];
}

obj CapabilityClosure {
    has context: str,
        capabilities: list[str] = [],
        deps: dict[str, str] = {};

    def is_empty -> bool {
        return not self.deps;
    }

    def package_names -> list[str] {
        return sorted(self.deps.keys());
    }
}

glob _registry: dict[str, Capability] | None = None;

def get_capability_registry -> dict[str, Capability] {
    global _registry;
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

def get_capability(name: str) -> Capability | None {
    return get_capability_registry().get(name);
}

def all_capability_names -> list[str] {
    return sorted(get_capability_registry().keys());
}

def _normalize_package(name: str) -> str {
    base = name;
    if "[" in base {
        base = base[:base.index("[")];
    }
    return base.strip().lower().replace("_", "-").replace(".", "-");
}

def derive_capabilities(
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
        keys: list = list(rule["keys"]);
        flag = rule.get("flag");
        if flag is not None {
            for key in keys {
                if section.get(key) {
                    caps.add(str(flag));
                }
            }
            continue;
        }
        values: dict = dict(rule.get("values", {}));
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

    if intent and ("serve" in caps) and not ({"data.mongo", "data.redis"} & caps) {
        caps.add("data.mongo");
    }
    return caps;
}

def scale_intent_from_config(config: JacConfig) -> dict[str, any] {
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

def command_capabilities(action: str, scale: bool = False) -> list[str] {
    if action != "serve" {
        return [];
    }
    caps: list[str] = ["serve"];
    if scale {
        caps.append("deploy.k8s");
    }
    return caps;
}

def _expand_requires(cap_names: set[str]) -> set[str] {
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

def resolve_closure(cap_names: set[str], context: str) -> CapabilityClosure {
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

def resolve_closures(cap_names: set[str]) -> dict[str, CapabilityClosure] {
    return {
        RUNTIME: resolve_closure(cap_names, RUNTIME),
        DEPLOY: resolve_closure(cap_names, DEPLOY)
    };
}

def byllm_intent_capabilities(config: JacConfig) -> set[str] {
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

def resolve_config_closures(
    config: JacConfig, action: str = "serve", scale: bool = False
) -> dict[str, CapabilityClosure] {
    intent = scale_intent_from_config(config);
    caps = derive_capabilities(intent, command_capabilities(action, scale));
    caps |= byllm_intent_capabilities(config);
    return resolve_closures(caps);
}

def capability_for_package(package: str) -> str | None {
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

def missing_capability_error(capability: str) -> str {
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

def package_missing_error(package: str) -> str {
    cap = capability_for_package(package);
    if cap is None {
        return (
            f"'{package}' is required but not installed. "
            f"Add it with 'jac add {package}' and run 'jac install'."
        );
    }
    return f"'{package}' is missing. {missing_capability_error(cap)}";
}

def require_optional(package: str, capability: str) {
    try {
        __import__(package);
    } except (ImportError, ValueError) {
        raise ImportError(
            f"'{package}' is required for this feature. "
            f"{missing_capability_error(capability)}"
        );
    }
}

def is_optional_available(package: str) -> bool {
    try {
        __import__(package);
        return True;
    } except (ImportError, ValueError) {
        return False;
    }
}
