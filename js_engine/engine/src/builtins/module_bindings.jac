"""
Bound require() functions for module.createRequire().

Separated from modules.na.jac to avoid import cycles with module_resolver.
"""

import from engine.src.builtins.native_kinds {
    NATIVE_KIND_BOUND_REQUIRE,
    NATIVE_KIND_ESM_LIVE_GET
}
import from engine.src.builtins.native_registry {
    js_native_create,
    get_native_idx,
    is_native_val
}
import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_object_cell,
    js_undefined,
    jsv_to_table_id
}
import from engine.src.runtime.jsobject {
    js_object_get,
    js_object_get_own_accessor_getter
}
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.runtime.jsstring { str_from_id }
import from engine.src.ffi.libc { getenv, write }

"""
Map from native-function index (get_native_idx) → parent file path.
Keyed by native idx directly, matching the ESM live-getter pattern, because
native vals are not JSObject cells — js_object_set() silently no-ops on them,
making the old __bindId property approach unreliable.
"""
glob _REQUIRE_BIND_PARENT: dict[int, str] = {};

"""Live ESM export getter bindings: id -> source namespace + property key."""
glob _ESM_LIVE_GET_KEY: dict[int, int] = {};
glob _ESM_LIVE_GET_NS: dict[int, JSValue] = {},
     _ESM_LIVE_GET_NATIDX: dict[int, int] = {},
     _NEXT_ESM_LIVE_GET_ID: int = 1;

# native fn index → live-getter id
def:pub require_bind_parent(bind_id: int) -> str {
    if bind_id in _REQUIRE_BIND_PARENT {
        return _REQUIRE_BIND_PARENT[bind_id];
    }
    return "";
}

"""Store parent_file for a native-val function (keyed by native idx)."""
def:pub require_bind_set(native_fn: JSValue, parent: str) {
    if is_native_val(native_fn) {
        _REQUIRE_BIND_PARENT[get_native_idx(native_fn)] = parent;
    }
}

def:pub module_create_bound_require(parent_file: str) -> JSValue {
    req_fn: JSValue = js_native_create("require", 1, NATIVE_KIND_BOUND_REQUIRE);
    _REQUIRE_BIND_PARENT[get_native_idx(req_fn)] = parent_file;
    # Pre-create a resolve function and store its parent too so the first
    # req.resolve access that re-creates it still gets the right bid via
    # the VM's native-property handler calling require_bind_set.
    # (The VM recreates the resolve native val on each property access, so
    #  the res_fn created here is discarded — see vm.na.jac property handler.)
    return req_fn;
}

def:pub require_native_bind_id(native_fn: JSValue) -> int {
    # Native vals are not object cells so __bindId cannot be stored on them
    # via js_object_set.  Use the native-registry index directly as the key,
    # matching the pattern used by esm_live_getter_id().
    if is_native_val(native_fn) {
        return get_native_idx(native_fn);
    }
    return -1;
}

"""Create a native getter that reads src_ns[src_key] on each access (live ESM binding)."""
def:pub esm_create_live_getter(src_ns: JSValue, src_key: int) -> JSValue {
    gid: int = _NEXT_ESM_LIVE_GET_ID;
    if getenv("JAC_DBG_ESM") != None and (gid % 100000) == 0 {
        _clg_dbg: str = "[DBG_ESM] live_getter #"
            + str(gid)
            + " key='"
            + str_from_id(src_key)
            + "' ns_tid="
            + str(jsv_to_table_id(src_ns))
            + "\n";
        write(2, _clg_dbg, len(_clg_dbg));
    }
    _NEXT_ESM_LIVE_GET_ID = _NEXT_ESM_LIVE_GET_ID + 1;
    _ESM_LIVE_GET_KEY[gid] = src_key;
    _ESM_LIVE_GET_NS[gid] = src_ns;
    gc_pin_value(src_ns);
    gfn: JSValue = js_native_create("get", 0, NATIVE_KIND_ESM_LIVE_GET);
    nat_idx: int = get_native_idx(gfn);
    _ESM_LIVE_GET_NATIDX[nat_idx] = gid;
    return gfn;
}

# NOTE: esm_create_global_live_getter / esm_global_live_getter_name (backed by
# NATIVE_KIND_ESM_GLOBAL_LIVE_GET) were removed in the adel merge — they serviced
# the superseded EXPORT_VAR_LIVE opcode. Live `export {x}` of a var/function now
# uses adel's _esm_alias_add store-hook system (see compiler.jac). The ESM_LIVE_GET
# family below (re-export live bindings) is a different mechanism and stays.

def:pub esm_live_getter_id(native_fn: JSValue) -> int {
    if not is_native_val(native_fn) {
        return -1;
    }
    nat_idx: int = get_native_idx(native_fn);
    if nat_idx in _ESM_LIVE_GET_NATIDX {
        return _ESM_LIVE_GET_NATIDX[nat_idx];
    }
    return -1;
}

"""
Read a module export's current value, resolving live re-export getters
(`export { x } from '...'`) which are stored as ESM live-getter accessors rather
than plain data properties. Returns the concrete value for the module namespace
snapshot. Plain exports read directly.
"""
def:pub esm_export_value(exports: JSValue, key: int) -> JSValue {
    if not jsv_is_object_cell(exports) {
        return js_undefined();
    }
    # Re-export live getter (indirect binding) — resolve through it.
    ag: JSValue = js_object_get_own_accessor_getter(exports, key);
    if is_native_val(ag) {
        gid: int = esm_live_getter_id(ag);
        if gid >= 0 {
            return esm_live_getter_read(gid);
        }
    }
    return js_object_get(exports, key);
}

def:pub esm_live_getter_read(gid: int) -> JSValue {
    if gid in _ESM_LIVE_GET_NS and gid in _ESM_LIVE_GET_KEY {
        ns: JSValue = _ESM_LIVE_GET_NS[gid];
        k: int = _ESM_LIVE_GET_KEY[gid];
        if jsv_is_object_cell(ns) {
            # Check plain property first (direct exports).
            val: JSValue = js_object_get(ns, k);
            if not jsv_is_undefined(val) {
                return val;
            }
            # Check accessor getter — handles transitive `export * from` chains
            # where an intermediate namespace stores its exports as live getters
            # (set by REEXPORT_STAR) rather than plain properties.  Follow the
            # chain recursively until a concrete value is found.
            ag: JSValue = js_object_get_own_accessor_getter(ns, k);
            if is_native_val(ag) {
                inner_gid: int = esm_live_getter_id(ag);
                if inner_gid >= 0 {
                    return esm_live_getter_read(inner_gid);
                }
            }
        }
    }
    return js_undefined();
}
