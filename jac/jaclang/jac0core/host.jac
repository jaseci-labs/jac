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
     HOST_TEST: str = 'test',
     HOST_WEB_WORKER: str = 'web-worker',
     HOST_SERVICE_WORKER: str = 'service-worker',
     HOST_EDGE: str = 'edge',
     HOST_CLI_JS: str = 'cli-js',
     HOST_CPYTHON: str = 'cpython',
     HOST_BARE_METAL: str = 'bare-metal',
     SV_SERVICE_HOST_KINDS: frozenset = frozenset(
         {HOST_BUN, HOST_TEST, HOST_CPYTHON}
     ),
     P3_JS_HOST_KINDS: tuple = (
         HOST_WEB_WORKER,
         HOST_SERVICE_WORKER,
         HOST_EDGE,
         HOST_CLI_JS
     ),
     P3_JS_HOST_CAPS: list[str] = [HOST_NPM, HOST_JS_GLOBALS],
     HOST_CAPABILITIES: dict[str, list[str]] = {
         HOST_BROWSER: [HOST_DOM, HOST_NPM, HOST_JS_GLOBALS],
         'webview': [HOST_DOM, HOST_NPM, HOST_JS_GLOBALS],
         HOST_RN: [HOST_NPM, HOST_JS_GLOBALS],
         HOST_BUN: [HOST_NPM, HOST_JS_GLOBALS, HOST_PERSIST],
         HOST_WEB_WORKER: [HOST_NPM, HOST_JS_GLOBALS],
         HOST_SERVICE_WORKER: [HOST_NPM, HOST_JS_GLOBALS],
         HOST_EDGE: [HOST_NPM, HOST_JS_GLOBALS],
         HOST_CLI_JS: [HOST_NPM, HOST_JS_GLOBALS],
         HOST_CPYTHON: [HOST_PY, HOST_PERSIST],
         HOST_BARE_METAL: [HOST_FFI]
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
         'web-worker': 'web-worker',
         'worker': 'web-worker',
         'service-worker': 'service-worker',
         'sw': 'service-worker',
         'edge': 'edge',
         'cloudflare': 'edge',
         'cloudflare-workers': 'edge',
         'cli-js': 'cli-js',
         'cli_js': 'cli-js',
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

def normalize_host_registry_name(name: str) -> str {
    return name.lower().strip().replace('_', '-');
}


def resolve_registry_name(name: str, table: any) -> (str | None) {
    key = normalize_host_registry_name(name);
    if not key {
        return None;
    }
    if key in table {
        return key;
    }
    alt = key.replace('-', '_');
    if alt != key and alt in table {
        return alt;
    }
    return None;
}

def host_kind_for_target(name: str) -> str {
    key = resolve_registry_name(name, TARGET_HOST_KIND);
    if key is None {
        # Absent target resolves to the browser default upstream; an explicit
        # but unknown target is a configuration error and must be loud.
        if str(name or '').strip() {
            valid = ', '.join(sorted(TARGET_HOST_KIND.keys()));
            raise ValueError(
                f"Unknown client target '{name}'; valid targets: {valid}"
            );
        }
        return HOST_BROWSER;
    }
    return TARGET_HOST_KIND[key];
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
    } except ImportError {
        # Optional dependency missing (config loader unavailable): fall back
        # to the default host. Invalid *values* raise — see
        # host_kind_for_target.
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

def host_kind_for_node(nd: uni.UniNode) -> str {
    if nd.in_native_context() {
        return HOST_BARE_METAL;
    }
    if nd.in_client_context() {
        mod = nd.find_parent_of_type(uni.Module);
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

def host_provides_node(nd: uni.UniNode, cap: str) -> bool {
    return host_provides_kind(host_kind_for_node(nd), cap);
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
    } except (ImportError, AttributeError) {
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
