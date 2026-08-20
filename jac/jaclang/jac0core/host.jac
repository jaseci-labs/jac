import jaclang.jac0core.unitree as uni;
import os;
import from jaclang.jac0core.constant { CodeContext }

glob HOST_DOM: str = 'DOM',
     HOST_NPM: str = 'NPM',
     HOST_PY: str = 'PY',
     HOST_PERSIST: str = 'PERSIST',
     HOST_FFI: str = 'FFI',
     HOST_JS_GLOBALS: str = 'JS_GLOBALS',
     HOST_BROWSER: str = 'browser',
     HOST_WEBVIEW: str = 'webview',
     HOST_RN: str = 'rn',
     HOST_BUN: str = 'bun',
     HOST_CPYTHON: str = 'cpython',
     HOST_BARE_METAL: str = 'bare-metal',
     HOST_CAPABILITIES: dict[str, list[str]] = {
         'browser': ['DOM', 'NPM', 'JS_GLOBALS'],
         'webview': ['DOM', 'NPM', 'JS_GLOBALS'],
         'rn': ['NPM', 'JS_GLOBALS'],
         'bun': ['NPM', 'JS_GLOBALS'],
         'cpython': ['PY', 'PERSIST'],
         'bare-metal': ['FFI']
     },
     TARGET_HOST_KIND: dict[str, str] = {
         'web': 'browser',
         'pwa': 'browser',
         'static': 'browser',
         'mobile': 'browser',
         'react-native': 'rn',
         'react_native': 'rn',
         'rn': 'rn',
         'bun': 'bun',
         'server': 'bun',
         'desktop': 'webview',
         'cef': 'webview'
     },
     CAPABILITY_CODESPACE: dict[str, CodeContext] = {
         'FFI': CodeContext.NATIVE,
         'DOM': CodeContext.CLIENT,
         'NPM': CodeContext.CLIENT
     },
     CAPABILITY_SEED_ORDER: tuple = ('FFI', 'DOM', 'NPM'),
     NPM_SEED_REASONS: tuple = (
         'string-path import',
         'virtual @jac import',
         'npm dependency'
     ),
     JS_DOM_HOST_GLOBALS: tuple = (
         'window',
         'document',
         'navigator',
         'location',
         'history',
         'screen'
     );

def host_kind_for_target(name: str) -> str {
    key = name.lower().strip().replace('_', '-');
    if key == '' {
        return HOST_BROWSER;
    }
    mapped = TARGET_HOST_KIND.get(key);
    if mapped is not None {
        return mapped;
    }
    alt = key.replace('-', '_');
    mapped = TARGET_HOST_KIND.get(alt);
    if mapped is not None {
        return mapped;
    }
    return HOST_BROWSER;
}

def resolve_project_host_kind(mod_path: str = '') -> str {
    try {
        import from jaclang.project.config { get_config, get_config_for_dir }
        import from jaclang.runtimelib.client.npm_provider {
            resolve_client_target_name
        }
        cfg = None;
        if mod_path.strip() {
            cfg = get_config_for_dir(os.path.dirname(os.path.abspath(mod_path)));
        }
        if cfg is None {
            cfg = get_config();
        }
        if cfg is None {
            return HOST_CPYTHON;
        }
        target = resolve_client_target_name(cfg);
        return host_kind_for_target(target);
    } except Exception {
        return HOST_CPYTHON;
    }
}

def host_kind_for_module(module: uni.Module) -> str {
    if module.decided_codespace == 'native' {
        return HOST_BARE_METAL;
    }
    for stmt in module.body {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            mod_path = module.loc.mod_path if module.loc is not None else '';
            return resolve_project_host_kind(mod_path or '');
        }
    }
    if module.decided_codespace == 'client' {
        mod_path = module.loc.mod_path if module.loc is not None else '';
        return resolve_project_host_kind(mod_path or '');
    }
    return HOST_CPYTHON;
}

def host_kind_for_node(node: uni.UniNode) -> str {
    if node.in_native_context() {
        return HOST_BARE_METAL;
    }
    if node.in_client_context() {
        mod = node.find_parent_of_type(uni.Module);
        mod_path = '';
        if mod is not None and mod.loc is not None {
            mod_path = mod.loc.mod_path or '';
        }
        return resolve_project_host_kind(mod_path);
    }
    return HOST_CPYTHON;
}

def host_provides_kind(kind: str, cap: str) -> bool {
    caps = HOST_CAPABILITIES.get(kind, []);
    return cap in caps;
}

def host_provides_node(node: uni.UniNode, cap: str) -> bool {
    return host_provides_kind(host_kind_for_node(node), cap);
}

def js_global_requires_dom(name: str) -> bool {
    return name in JS_DOM_HOST_GLOBALS;
}

def codespace_for_capability(cap: str) -> (CodeContext | None) {
    return CAPABILITY_CODESPACE.get(cap);
}

def seed_codespace_for_req(cap: str, reason: str) -> (CodeContext | None) {
    if cap == HOST_NPM and reason not in NPM_SEED_REASONS {
        return None;
    }
    return codespace_for_capability(cap);
}

def framework_for_host_kind(kind: str) -> str {
    if kind == HOST_BUN {
        return 'bun';
    }
    if kind == HOST_RN {
        return 'react';
    }
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        if cfg is not None and cfg.client is not None and cfg.client.framework {
            return cfg.client.framework;
        }
    } except Exception {
        ;
    }
    return 'react';
}

def framework_for_module(module: uni.Module) -> str {
    return framework_for_host_kind(host_kind_for_module(module));
}

def native_unmet_capability(cap: str) -> bool {
    if cap in ('ENDPOINT', 'SERVER') {
        return False;
    }
    return not host_provides_kind(HOST_BARE_METAL, cap);
}
