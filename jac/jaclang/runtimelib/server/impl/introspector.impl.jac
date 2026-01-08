"""ModuleIntrospector implementations."""
import inspect;
import json;
import os;
import from collections.abc { Callable }
import from typing { Any, get_type_hints }
import from jaclang.project.config { get_config }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from jaclang.runtimelib.server.introspector { ModuleIntrospector }
import from jaclang.runtimelib.server.serializer { JacSerializer }
import from jaclang { JacRuntime as Jac }

import from jaclang.pycore.constructs { WalkerArchetype }
import html;

impl ModuleIntrospector.postinit -> None {
    self._bundle_builder = Jac.get_client_bundle_builder();
}

"""Load module and refresh caches."""
impl ModuleIntrospector.load(force_reload: bool = False) -> None {
    needs_import = force_reload or (self.module_name not in Jac.loaded_modules);
    if (needs_import and self.base_path) {
        Jac.jac_import(
            target=self.module_name,
            base_path=os.path.abspath(self.base_path),
            lng='jac',
            reload_module=force_reload
        );
    }
    module = Jac.loaded_modules.get(self.module_name);
    if (not module or ((self._module is module) and not needs_import)) {
        return;
    }
    self._module = module;
    self._load_manifest();
    self._extract_access_levels();
    self._functions = self._collect_functions();
    self._walkers = self._collect_walkers();
    self._bundle = None;
    self._bundle_error = None;
}

"""Load client manifest from module."""
impl ModuleIntrospector._load_manifest -> None {
    if not self._module {
        return;
    }
    mod_path = getattr(self._module, '__file__', None);
    if mod_path {
        mod = Jac.program.mod.hub.get(mod_path);
        # If module not in hub, compile it to get the manifest
        if not mod {
            mod = Jac.program.compile(mod_path);
        }
        if (mod and mod.gen.client_manifest) {
            manifest = mod.gen.client_manifest;
            self._client_manifest = {
                'exports': manifest.exports,
                'globals': manifest.globals,
                'params': manifest.params,
                'globals_values': manifest.globals_values,
                'has_client': manifest.has_client
            };
            return;
        }
    }
    self._client_manifest = {};
}

"""Extract access level information from module AST."""
impl ModuleIntrospector._extract_access_levels -> None {
    if not self._module {
        return;
    }
    import jaclang.pycore.unitree as uni;
    import from jaclang.pycore.constructs { WalkerArchetype }
    self._function_access = {};
    self._walker_access = {};
    mod_path = getattr(self._module, '__file__', None);
    if not mod_path {
        return;
    }
    mod_ast = Jac.program.mod.hub.get(mod_path);
    # If module not in hub, compile it to get the AST
    if not mod_ast {
        mod_ast = Jac.program.compile(mod_path);
    }
    if not mod_ast {
        return;
    }
    for item in mod_ast.body {
        if (isinstance(item, uni.Ability) and (item.name_ref is not None)) {
            func_name = item.name_ref.sym_name;
            self._function_access[func_name] = not item.public_access;
        } elif isinstance(item, uni.Archetype) {
            arch_name = item.name.sym_name;
            if hasattr(self._module, arch_name) {
                cls = getattr(self._module, arch_name);
                if (isinstance(cls, <>type) and issubclass(cls, WalkerArchetype)) {
                    self._walker_access[arch_name] = not item.public_access;
                }
            }
        }
    }
}

"""Collect callable functions from module."""
impl ModuleIntrospector._collect_functions -> dict[str, Callable[(..., Any)]] {
    if not self._module {
        return {};
    }
    functions: dict[(str, Callable[(..., Any)])] = {};
    export_names = <>set(self._client_manifest.get('exports', []));
    for (name, <>obj) in inspect.getmembers(self._module) {
        if (
            inspect.isfunction(<>obj)
            and not name.startswith('_')
            and (<>obj.__module__ == self._module.__name__)
        ) {
            functions[name] = <>obj;
            if (name in export_names) {
                self._client_functions[name] = <>obj;
            }
        }
    }
    for name in export_names {
        if ((name not in self._client_functions) and hasattr(self._module, name)) {
            attr = getattr(self._module, name);
            if callable(attr) {
                self._client_functions[name] = attr;
            }
        }
    }
    return functions;
}

"""Collect walker classes from module."""
impl ModuleIntrospector._collect_walkers -> dict[str, type[WalkerArchetype]] {
    import from jaclang.pycore.constructs { WalkerArchetype }
    if not self._module {
        return {};
    }
    walkers: dict[(str, type[WalkerArchetype])] = {};
    for (name, <>obj) in inspect.getmembers(self._module) {
        if (
            isinstance(<>obj, <>type)
            and issubclass(<>obj, WalkerArchetype)
            and (<>obj is not WalkerArchetype)
            and (<>obj.__module__ == self._module.__name__)
        ) {
            walkers[name] = <>obj;
        }
    }
    return walkers;
}

"""Get all functions."""
impl ModuleIntrospector.get_functions -> dict[str, Callable[(..., Any)]] {
    if not self._functions {
        self.load();
    }
    return <>dict(self._functions);
}

"""Get all walkers."""
impl ModuleIntrospector.get_walkers -> dict[str, type[WalkerArchetype]] {
    if not self._walkers {
        self.load();
    }
    return <>dict(self._walkers);
}

"""Get client-exportable functions."""
impl ModuleIntrospector.get_client_functions -> dict[str, Callable[(..., Any)]] {
    if not self._client_functions {
        self.load();
    }
    return <>dict(self._client_functions);
}

"""Get callable signature information."""
impl ModuleIntrospector.introspect_callable(
    func: Callable[(..., Any)]
) -> dict[str, Any] {
    try {
        sig = inspect.signature(func);
        type_hints = get_type_hints(func);
    } except Exception {
        return {'parameters': {}, 'return_type': 'Any'};
    }
    params = {
        name: {
            'type': getattr(
                type_hints.get(name, Any), '__name__', str(type_hints.get(name, Any))
            ),
            'required': (param.default == inspect.Parameter.empty),
            'default': None
            if (param.default == inspect.Parameter.empty)
            else str(param.default)
        } for (name, param) in sig.parameters.items()
    };
    return_type = type_hints.get('return', Any);
    return {
        'parameters': params,
        'return_type': getattr(return_type, '__name__', str(return_type))
    };
}

"""Get walker field information."""
impl ModuleIntrospector.introspect_walker(
    walker_cls: type[WalkerArchetype]
) -> dict[str, Any] {
    try {
        sig = inspect.signature(walker_cls.init);
        type_hints = get_type_hints(walker_cls.init);
    } except Exception {
        return {'fields': {}};
    }
    fields = {
        name: {
            'type': getattr(
                type_hints.get(name, Any), '__name__', str(type_hints.get(name, Any))
            ),
            'required': (param.default == inspect.Parameter.empty),
            'default': None
            if (param.default == inspect.Parameter.empty)
            else param.default
        }
        for (name, param) in sig.parameters.items()
        if (name not in ('self', 'args', 'kwargs'))
    };
    fields['_jac_spawn_node'] = {
        'type': 'str (node ID, optional)',
        'required': False,
        'default': 'root'
    };
    return {'fields': fields};
}

"""Ensure client bundle is available and return hash."""
impl ModuleIntrospector.ensure_bundle -> str {
    if not self._module {
        raise RuntimeError('Module not loaded') ;
    }
    if self._bundle {
        return self._bundle.hash;
    }
    try {
        self._bundle = self._bundle_builder.build(self._module);
        self._bundle_error = None;
        return self._bundle.hash;
    } except ClientBundleError as exc {
        self._bundle = None;
        self._bundle_error = str(exc);
        raise exc from RuntimeError(self._bundle_error) ;
    }
}

"""Render HTML page for client function."""
impl ModuleIntrospector.render_page(
    function_name: str, args: dict[(str, Any)], username: str
) -> dict[str, Any] {
    self.load();
    available_exports = (
        <>set(self._client_manifest.get('exports', []))
        or <>set(self.get_client_functions().keys())
    );
    if (function_name not in available_exports) {
        raise ValueError(f"Client function '{function_name}' not found") ;
    }
    bundle_hash = self.ensure_bundle();
    arg_order = <>list(self._client_manifest.get('params', {}).get(function_name, []));
    globals_payload = {
        name: JacSerializer.serialize(value)
        for (name, value) in self._collect_client_globals().items()
    };
    initial_state = {
        'module': self._module.__name__ if self._module else self.module_name,
        'function': function_name,
        'args': {key: JacSerializer.serialize(value) for (key, value) in args.items()},
        'globals': globals_payload,
        'argOrder': arg_order
    };
    safe_initial_json = json.dumps(initial_state).replace('</', '<\\/');
    page = f'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"/><title>{html.escape(
        function_name
    )}</title></head><body><div id="__jac_root"></div><script id="__jac_init__" type="application/json">{safe_initial_json}</script><script src="/static/client.js?hash={bundle_hash}" defer></script></body></html>';
    return {'html': page, 'bundle_hash': bundle_hash, 'bundle_code': self._bundle.code};
}

"""Check if authentication is required for a function based on its access level.

Public functions: no authentication required
Protected/Private functions: authentication required
"""
impl ModuleIntrospector.is_auth_required_for_function(func_name: str) -> bool {
    return self._function_access.get(func_name, False);
}

"""Check if authentication is required for a walker based on its access level.

Public walkers: no authentication required
Protected/Private walkers: authentication required
"""
impl ModuleIntrospector.is_auth_required_for_walker(walker_name: str) -> bool {
    return self._walker_access.get(walker_name, False);
}

"""Collect client-exposed global values."""
impl ModuleIntrospector._collect_client_globals -> dict[str, Any] {
    if not self._module {
        return {};
    }
    result: dict[(str, Any)] = {};
    names = self._client_manifest.get('globals', []);
    values_map = self._client_manifest.get('globals_values', {});
    for name in names {
        if (name in values_map) {
            result[name] = values_map[name];
        } elif hasattr(self._module, name) {
            result[name] = getattr(self._module, name);
        } else {
            result[name] = None;
        }
    }
    return result;
}
