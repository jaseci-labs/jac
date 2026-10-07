"""
Built-in Module Registry — maps module names to factory functions.

When `require("path")` or `require("node:path")` is called, the registry
is checked first.  If the module name matches a built-in, the corresponding
factory function creates and returns the module's exports object.

If no built-in matches, the module system falls through to user-file loading.

Bun reference: bun/src/bun.js/HardcodedModule.zig
Node.js reference: https://nodejs.org/api/modules.html#built-in-modules
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_null,
    js_false,
    jsv_is_undefined,
    jsv_is_string_cell,
    jsv_is_object_cell,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_from_int32
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_set,
    js_object_get,
    js_object_set_prototype,
    KEY_CTOR_KIND
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.builtins.array { js_array_create }
import from engine.src.builtins.native_registry { js_native_create, is_native_val }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_MODULE_IS_BUILTIN,
    NATIVE_KIND_VM_RUN_IN_THIS_CONTEXT,
    NATIVE_KIND_VM_CREATE_CONTEXT,
    NATIVE_KIND_VM_IS_CONTEXT,
    NATIVE_KIND_VM_RUN_IN_CONTEXT,
    NATIVE_KIND_MODULE_CREATE_REQUIRE,
    NATIVE_KIND_MODULE_NOOP,
    NATIVE_KIND_MODULE_SYNC_BUILTIN_ESM,
    NATIVE_KIND_MODULE_SOURCEMAP,
    NATIVE_KIND_MODULE_ENABLE_COMPILE_CACHE,
    NATIVE_KIND_MODULE_FLUSH_COMPILE_CACHE,
    NATIVE_KIND_MODULE_GET_COMPILE_CACHE_DIR,
    NATIVE_KIND_MODULE_CTOR,
    NATIVE_KIND_MODULE_REGISTER_HOOKS,
    NATIVE_KIND_MODULE_HOOKS_DEREGISTER
}
import from engine.src.builtins.module_bindings { module_create_bound_require }
import from engine.src.runtime.gc_pin { gc_pin_value, gc_unpin_value, gc_pin_live_list }

# ── module.compileCache stubs (Node module.enableCompileCache parity) ─────────
# Intentional no-op: records directory + status codes only (no disk cache I/O).
# Sufficient for Vite CLI bootstrap; not a production compile-cache implementation.

glob _compile_cache_enabled: bool = False,
     _compile_cache_dir: str = "";

"""Return { status, message? } for module.enableCompileCache(options|string)."""
def:pub module_enable_compile_cache(arg: JSValue) -> JSValue {
    dir_str: str = "";
    if jsv_is_string_cell(arg) {
        dir_str = str_from_id(jsv_to_table_id(arg));
    } elif jsv_is_object_cell(arg) {
        dir_val: JSValue = js_object_get(arg, str_intern("directory"));
        if jsv_is_string_cell(dir_val) {
            dir_str = str_from_id(jsv_to_table_id(dir_val));
        }
    }
    cc_ret: JSValue = js_object_create_null();
    if len(dir_str) == 0 {
        js_object_set(cc_ret, str_intern("status"), js_int(2));
        js_object_set(
            cc_ret,
            str_intern("message"),
            jsv_from_string_id(str_intern("invalid compile cache directory"))
        );
        return cc_ret;
    }
    if _compile_cache_enabled {
        js_object_set(cc_ret, str_intern("status"), js_int(1));
        return cc_ret;
    }
    _compile_cache_enabled = True;
    _compile_cache_dir = dir_str;
    js_object_set(cc_ret, str_intern("status"), js_int(0));
    return cc_ret;
}

def:pub module_flush_compile_cache -> JSValue {
    return js_undefined();
}

def:pub module_get_compile_cache_dir -> JSValue {
    if _compile_cache_enabled and len(_compile_cache_dir) > 0 {
        return jsv_from_string_id(str_intern(_compile_cache_dir));
    }
    return js_undefined();
}

# ── Registry lookup ──────────────────────────────────────────────────────────

"""
Check if `name` is a built-in module.  Returns True for known built-in names.
Accepts both bare names ("path") and prefixed ("node:path").
"""
def:pub is_builtin_module(name: str) -> bool {
    bare: str = name;
    if len(name) > 5
        and name[0] == "n"
        and name[1] == "o"
        and name[2] == "d"
        and name[3] == "e"
        and name[4] == ":" {
        bare = name[5:];
    }
    if bare == "path" {
        return True;
    }
    if bare == "events" {
        return True;
    }
    if bare == "util" {
        return True;
    }
    if bare == "buffer" {
        return True;
    }
    if bare == "os" {
        return True;
    }
    if bare == "constants" {
        return True;
    }
    if bare == "assert" {
        return True;
    }
    if bare == "url" {
        return True;
    }
    if bare == "fetch" {
        return True;
    }
    if bare == "binary_types" {
        return True;
    }
    if bare == "querystring" {
        return True;
    }
    if bare == "punycode" {
        return True;
    }
    if bare == "string_decoder" {
        return True;
    }
    if bare == "fs" {
        return True;
    }
    if bare == "fs/promises" {
        return True;
    }
    if bare == "stream/promises" {
        return True;
    }
    if bare == "process" {
        return True;
    }
    if bare == "timers" {
        return True;
    }
    if bare == "console" {
        return True;
    }
    if bare == "readline" {
        return True;
    }
    if bare == "tty" {
        return True;
    }
    if bare == "net" {
        return True;
    }
    if bare == "tls" {
        return True;
    }
    if bare == "stream" {
        return True;
    }
    if bare == "perf_hooks" {
        return True;
    }
    if bare == "diagnostics_channel" {
        return True;
    }
    if bare == "domain" {
        return True;
    }
    if bare == "repl" {
        return True;
    }
    if bare == "v8" {
        return True;
    }
    if bare == "module" {
        return True;
    }
    if bare == "dns" {
        return True;
    }
    if bare == "dgram" {
        return True;
    }
    if bare == "vm" {
        return True;
    }
    if bare == "vm_native" {
        return True;
    }  # internal: native bridge for js/vm.js
    if bare == "crypto" {
        return True;
    }
    if bare == "child_process" {
        return True;
    }
    if bare == "worker_threads" {
        return True;
    }
    if bare == "cluster" {
        return True;
    }
    if bare == "test" {
        return True;
    }
    if bare == "test/reporters" {
        return True;
    }
    if bare == "sea" {
        return True;
    }
    if bare == "stream/consumers" {
        return True;
    }
    if bare == "stream/web" {
        return True;
    }
    if bare == "async_hooks" {
        return True;
    }
    if bare == "webstreams" {
        return True;
    }
    if bare == "http2" {
        return True;
    }
    # Legacy Node internal aliases + subpath exports
    if bare == "_http_common" {
        return True;
    }
    if bare == "_http_server" {
        return True;
    }
    if bare == "_http_agent" {
        return True;
    }
    if bare == "_http_outgoing" {
        return True;
    }
    if bare == "_stream_readable" {
        return True;
    }
    if bare == "_stream_writable" {
        return True;
    }
    if bare == "_stream_duplex" {
        return True;
    }
    if bare == "_stream_transform" {
        return True;
    }
    if bare == "_stream_passthrough" {
        return True;
    }
    if bare == "_stream_wrap" {
        return True;
    }
    if bare == "_tls_common" {
        return True;
    }
    if bare == "util/types" {
        return True;
    }
    if bare == "path/posix" {
        return True;
    }
    if bare == "path/win32" {
        return True;
    }
    if bare == "assert/strict" {
        return True;
    }
    return False;
}

"""
Create the exports object for a built-in module by name.
Returns the module exports JSValue, or js_undefined() if unknown.

Each module factory builds a fresh JSObject with the correct properties.
For modules that are already wired as globalThis properties (fs, process,
console, timers), the factory returns a reference to the existing global.
"""
def:pub create_builtin_module(name: str, globals_ref: dict[str, JSValue]) -> JSValue {
    bare: str = name;
    if len(name) > 5
        and name[0] == "n"
        and name[1] == "o"
        and name[2] == "d"
        and name[3] == "e"
        and name[4] == ":" {
        bare = name[5:];
    }

    # ── Modules that are already global objects ─────────────────────
    if bare == "fs" {
        # Loaded from src/builtins/js/fs.js via vm._is_js_builtin (Node-compat wrappers)
        return js_undefined();
    }
    if bare == "process" {
        # Loaded from src/builtins/js/process.js (Wave 21 validation wrappers)
        return js_undefined();
    }
    if bare == "console" {
        # Loaded from src/builtins/js/console.js (adds Console class)
        return js_undefined();
    }
    if bare == "timers" {
        return _create_timers_module(globals_ref);
    }
    # perf_hooks: src/builtins/js/perf_hooks.js (vm._is_js_builtin)
    if bare == "module" {
        return _create_module_module();
    }
    # `vm` itself is JS-implemented (src/builtins/js/vm.js); this is the native
    # primitive bridge it requires.
    if bare == "vm_native" {
        return _create_vm_native_module();
    }

    # ── Stub modules (return empty object for now, Phase 5.2+ fills in) ─
    if bare == "path" or bare == "url" or bare == "querystring" {
        return js_undefined();
    }
    if bare == "events" {
        return _create_events_stub();
    }
    if bare == "util" {
        return _create_util_stub();
    }
    if bare == "buffer" {
        # Loaded from src/builtins/js/buffer.js via vm._is_js_builtin
        return js_undefined();
    }
    if bare == "constants" {
        # Loaded from src/builtins/js/constants.js via vm._is_js_builtin
        return js_undefined();
    }
    if bare == "os" {
        return _create_os_stub();
    }
    if bare == "assert" {
        return _create_assert_stub();
    }
    if bare == "fetch" {
        return _create_fetch_stub();
    }
    if bare == "string_decoder" {
        return _create_string_decoder_stub();
    }
    if bare == "punycode" {
        return _create_punycode_stub();
    }
    if bare == "readline" {
        return js_object_create_null();
    }
    if bare == "tty" {
        return js_object_create_null();
    }

    return js_undefined();
}

# ── Timers module factory ────────────────────────────────────────────────────

"""Create `require("timers")` — wraps existing global timer functions."""
def _create_timers_module(globals_ref: dict[str, JSValue]) -> JSValue {
    mod: JSValue = js_object_create_null();
    # Re-expose the global timer functions
    if "setTimeout" in globals_ref {
        js_object_set(mod, str_intern("setTimeout"), globals_ref["setTimeout"]);
    }
    if "clearTimeout" in globals_ref {
        js_object_set(mod, str_intern("clearTimeout"), globals_ref["clearTimeout"]);
    }
    if "setInterval" in globals_ref {
        js_object_set(mod, str_intern("setInterval"), globals_ref["setInterval"]);
    }
    if "clearInterval" in globals_ref {
        js_object_set(mod, str_intern("clearInterval"), globals_ref["clearInterval"]);
    }
    if "setImmediate" in globals_ref {
        js_object_set(mod, str_intern("setImmediate"), globals_ref["setImmediate"]);
    }
    if "clearImmediate" in globals_ref {
        js_object_set(mod, str_intern("clearImmediate"), globals_ref["clearImmediate"]);
    }
    return mod;
}


# ── module builtin (Vite V-07) ───────────────────────────────────────────────

"""Names exposed via require('module').builtinModules (js_engine built-ins)."""
def _builtin_module_name_list -> list[str] {
    return [
        "assert",
        "buffer",
        "console",
        "constants",
        "events",
        "fs",
        "module",
        "path",
        "perf_hooks",
        "diagnostics_channel",
        "domain",
        "repl",
        "v8",
        "process",
        "querystring",
        "readline",
        "stream",
        "string_decoder",
        "timers",
        "tty",
        "url",
        "util",
        "punycode",
        "os",
        "net",
        "tls",
        "fetch",
        "binary_types",
        "dns",
        "dgram",
        "vm",
        "crypto",
        "child_process",
        "worker_threads",
        "cluster",
        "test",
        "test/reporters",
        "sea",
        "stream/consumers",
        "stream/web",
        "async_hooks",
        "webstreams",
        "http2",
        "_http_common",
        "_http_server",
        "_http_agent",
        "_http_outgoing",
        "_stream_readable",
        "_stream_writable",
        "_stream_duplex",
        "_stream_transform",
        "_stream_passthrough",
        "_stream_wrap",
        "_tls_common",
        "util/types",
        "path/posix",
        "path/win32",
        "assert/strict"
    ];
}

"""Create `require('vm_native')` exports — the engine-level primitives that
`src/builtins/js/vm.js` builds the public `vm` surface on top of.

Kept as a separate internal specifier because `vm` itself is a JS-implemented
builtin (see VM._is_js_builtin): the JS module cannot require itself to reach
these natives."""
def _create_vm_native_module -> JSValue {
    mod: JSValue = js_object_create_null();
    js_object_set(
        mod,
        str_intern("runInThisContext"),
        js_native_create("runInThisContext", 2, NATIVE_KIND_VM_RUN_IN_THIS_CONTEXT)
    );
    js_object_set(
        mod,
        str_intern("createContext"),
        js_native_create("createContext", 1, NATIVE_KIND_VM_CREATE_CONTEXT)
    );
    js_object_set(
        mod,
        str_intern("isContext"),
        js_native_create("isContext", 1, NATIVE_KIND_VM_IS_CONTEXT)
    );
    js_object_set(
        mod,
        str_intern("runInContext"),
        js_native_create("runInContext", 3, NATIVE_KIND_VM_RUN_IN_CONTEXT)
    );
    return mod;
}

glob _MODULE_MODULE_SINGLETON: JSValue = js_undefined(),
     _PENDING_MODULE_EXTENSIONS: JSValue = js_undefined(),
     _PENDING_MODULE_COMPILE: JSValue = js_undefined();

"""Create `require('module')` / `require('node:module')` exports (V-07)."""
def _create_module_module -> JSValue {
    if not jsv_is_undefined(_MODULE_MODULE_SINGLETON) {
        return _MODULE_MODULE_SINGLETON;
    }
    mod: JSValue = js_object_create_null();
    names: list[str] = _builtin_module_name_list();
    elems: list[JSValue] = [];
    ni: int = 0;
    while ni < len(names) {
        elems.append(jsv_from_string_id(str_intern(names[ni])));
        ni = ni + 1;
    }
    js_object_set(mod, str_intern("builtinModules"), js_array_create(elems));
    js_object_set(
        mod,
        str_intern("isBuiltin"),
        js_native_create("isBuiltin", 1, NATIVE_KIND_MODULE_IS_BUILTIN)
    );
    js_object_set(
        mod,
        str_intern("createRequire"),
        js_native_create("createRequire", 1, NATIVE_KIND_MODULE_CREATE_REQUIRE)
    );
    # Stub exports expected by NMOD-MOD-002 (incremental parity)
    js_object_set(
        mod,
        str_intern("register"),
        js_native_create("register", 1, NATIVE_KIND_MODULE_NOOP)
    );
    js_object_set(
        mod,
        str_intern("registerHooks"),
        js_native_create("registerHooks", 1, NATIVE_KIND_MODULE_REGISTER_HOOKS)
    );
    js_object_set(
        mod,
        str_intern("syncBuiltinESMExports"),
        js_native_create(
            "syncBuiltinESMExports", 0, NATIVE_KIND_MODULE_SYNC_BUILTIN_ESM
        )
    );
    js_object_set(
        mod,
        str_intern("findSourceMap"),
        js_native_create("findSourceMap", 1, NATIVE_KIND_MODULE_NOOP)
    );
    sm_ctor: JSValue = js_object_create_null();
    js_object_set(sm_ctor, KEY_CTOR_KIND, jsv_from_int32(NATIVE_KIND_MODULE_SOURCEMAP));
    js_object_set(mod, str_intern("SourceMap"), sm_ctor);
    # Node: module.exports IS the Module constructor; Module.Module === Module.
    mod_proto: JSValue = js_object_create_null();
    js_object_set(mod, str_intern("prototype"), mod_proto);
    js_object_set(mod, KEY_CTOR_KIND, jsv_from_int32(NATIVE_KIND_MODULE_CTOR));
    js_object_set(mod, str_intern("Module"), mod);
    mod_ctor: JSValue = mod;
    if not jsv_is_undefined(_PENDING_MODULE_EXTENSIONS) {
        js_object_set(mod_ctor, str_intern("_extensions"), _PENDING_MODULE_EXTENSIONS);
    }
    if is_native_val(_PENDING_MODULE_COMPILE) {
        js_object_set(mod_ctor, str_intern("_compile"), _PENDING_MODULE_COMPILE);
        js_object_set(mod_proto, str_intern("_compile"), _PENDING_MODULE_COMPILE);
    }
    cc_status: JSValue = js_object_create_null();
    js_object_set(cc_status, str_intern("ENABLED"), js_int(0));
    js_object_set(cc_status, str_intern("ALREADY_ENABLED"), js_int(1));
    js_object_set(cc_status, str_intern("FAILED"), js_int(2));
    js_object_set(cc_status, str_intern("DISABLED"), js_int(3));
    cc_const: JSValue = js_object_create_null();
    js_object_set(cc_const, str_intern("compileCacheStatus"), cc_status);
    js_object_set(mod, str_intern("constants"), cc_const);
    js_object_set(
        mod,
        str_intern("enableCompileCache"),
        js_native_create(
            "enableCompileCache", 1, NATIVE_KIND_MODULE_ENABLE_COMPILE_CACHE
        )
    );
    js_object_set(
        mod,
        str_intern("flushCompileCache"),
        js_native_create("flushCompileCache", 0, NATIVE_KIND_MODULE_FLUSH_COMPILE_CACHE)
    );
    js_object_set(
        mod,
        str_intern("getCompileCacheDir"),
        js_native_create(
            "getCompileCacheDir", 0, NATIVE_KIND_MODULE_GET_COMPILE_CACHE_DIR
        )
    );
    _MODULE_MODULE_SINGLETON = mod;
    gc_pin_value(mod);  # glob-held singleton — invisible to the GC root walk
    return mod;
}

"""Construct a `new Module(id?, parent?)` instance (Node module.Module)."""
def:pub module_construct_instance(args: list[JSValue]) -> JSValue {
    id_str: str = "";
    if len(args) > 0 and jsv_is_string_cell(args[0]) {
        id_str = str_from_id(jsv_to_table_id(args[0]));
    }
    inst: JSValue = js_object_create_null();
    if not jsv_is_undefined(_MODULE_MODULE_SINGLETON) {
        proto: JSValue = js_object_get(
            _MODULE_MODULE_SINGLETON, str_intern("prototype")
        );
        if jsv_is_object_cell(proto) {
            js_object_set_prototype(inst, proto);
        }
    }
    exports: JSValue = js_object_create_null();
    js_object_set(inst, str_intern("exports"), exports);
    js_object_set(inst, str_intern("id"), jsv_from_string_id(str_intern(id_str)));
    if id_str != "" {
        js_object_set(
            inst, str_intern("filename"), jsv_from_string_id(str_intern(id_str))
        );
    } else {
        js_object_set(inst, str_intern("filename"), js_null());
    }
    js_object_set(inst, str_intern("loaded"), js_false());
    js_object_set(inst, str_intern("children"), js_array_create([]));
    js_object_set(inst, str_intern("parent"), js_null());
    parent_file: str = id_str;
    if parent_file == "" {
        parent_file = ".";
    }
    js_object_set(
        inst, str_intern("require"), module_create_bound_require(parent_file)
    );
    return inst;
}

# ── module.registerHooks — synchronous resolve-hook chain state ───────────────
# Slots may be cleared (js_undefined) by deregister; the chain loop skips them.
glob _HOOK_RESOLVE_FNS: list[JSValue] = [],
     _HOOK_RESOLVE_FNS_ROOTED: bool = False,
     _HOOKS_RUNNING: int = 0,
     _HOOK_NEXT_CALLED: int = 0;

# Reentrancy guard: a require() issued from INSIDE a running hook must not
# re-enter the chain (infinite recursion).

# Set by the nextResolve trampoline so the chain can enforce Node's contract:
# a resolve hook must either call next or return { shortCircuit: true }.
def:pub module_hooks_count -> int {
    return len(_HOOK_RESOLVE_FNS);
}
def:pub module_hooks_get(i: int) -> JSValue {
    if i < 0 or i >= len(_HOOK_RESOLVE_FNS) {
        return js_undefined();
    }
    return _HOOK_RESOLVE_FNS[i];
}

def:pub module_hooks_running_get -> int {
    return _HOOKS_RUNNING;
}
def:pub module_hooks_running_set(v: int) {
    _HOOKS_RUNNING = v;
}
def:pub module_hook_next_reset {
    _HOOK_NEXT_CALLED = 0;
}
def:pub module_hook_next_mark {
    _HOOK_NEXT_CALLED = 1;
}
def:pub module_hook_next_called -> int {
    return _HOOK_NEXT_CALLED;
}
def:pub module_hooks_clear_slot(i: int) {
    if i >= 0 and i < len(_HOOK_RESOLVE_FNS) {
        _HOOK_RESOLVE_FNS[i] = js_undefined();
    }
}

"""module.registerHooks({resolve, load}) — records the resolve hook (run by the
require path in vm.jac); returns a handle whose deregister() removes it."""
def:pub module_register_hooks(hooks: JSValue) -> JSValue {
    handle: JSValue = js_object_create_null();
    slot: int = -1;
    if jsv_is_object_cell(hooks) {
        resolve_fn: JSValue = js_object_get(hooks, str_intern("resolve"));
        if not jsv_is_undefined(resolve_fn) {
            if not _HOOK_RESOLVE_FNS_ROOTED {
                # glob queue — contents invisible to the GC root walk
                gc_pin_live_list(_HOOK_RESOLVE_FNS);
                _HOOK_RESOLVE_FNS_ROOTED = True;
            }
            slot = len(_HOOK_RESOLVE_FNS);
            _HOOK_RESOLVE_FNS.append(resolve_fn);
        }
    }
    js_object_set(handle, str_intern("__hook_slot"), js_int(slot));
    js_object_set(
        handle,
        str_intern("deregister"),
        js_native_create("deregister", 0, NATIVE_KIND_MODULE_HOOKS_DEREGISTER)
    );
    return handle;
}

"""Wire Module._extensions / Module._compile after vm_init_require_extensions()."""
def:pub module_set_cjs_loader_exports(ext_obj: JSValue, compile_fn: JSValue) -> None {
    # glob-held roots — invisible to the GC root walk; may be re-wired, so unpin old
    gc_unpin_value(_PENDING_MODULE_EXTENSIONS);
    gc_unpin_value(_PENDING_MODULE_COMPILE);
    _PENDING_MODULE_EXTENSIONS = ext_obj;
    _PENDING_MODULE_COMPILE = compile_fn;
    gc_pin_value(_PENDING_MODULE_EXTENSIONS);
    gc_pin_value(_PENDING_MODULE_COMPILE);
    if jsv_is_undefined(_MODULE_MODULE_SINGLETON) {
        return;
    }
    mod_node: JSValue = js_object_get(_MODULE_MODULE_SINGLETON, str_intern("Module"));
    if jsv_is_object_cell(mod_node) {
        if not jsv_is_undefined(ext_obj) {
            js_object_set(mod_node, str_intern("_extensions"), ext_obj);
        }
        if is_native_val(compile_fn) {
            js_object_set(mod_node, str_intern("_compile"), compile_fn);
            mod_proto: JSValue = js_object_get(mod_node, str_intern("prototype"));
            if jsv_is_object_cell(mod_proto) {
                js_object_set(mod_proto, str_intern("_compile"), compile_fn);
            }
        }
    }
}

# ── Stub factories (Phase 5.2+ will replace these with real implementations) ─

def _create_events_stub -> JSValue {
    return js_object_create_null();
}

def _create_util_stub -> JSValue {
    return js_object_create_null();
}

def _create_os_stub -> JSValue {
    return js_object_create_null();
}

def _create_assert_stub -> JSValue {
    return js_object_create_null();
}

def _create_fetch_stub -> JSValue {
    return js_object_create_null();
}

def _create_string_decoder_stub -> JSValue {
    return js_object_create_null();
}

def _create_punycode_stub -> JSValue {
    return js_object_create_null();
}
