"""NAPI addon loader.

Loads a .node NAPI addon and returns its exports as a JSValue.

Flow:
  1. Ensure the Jac dispatcher is registered with the C shim (once per process).
  2. dlopen the .node path with RTLD_NOW | RTLD_LOCAL.
     The addon's __attribute__((constructor)) calls napi_module_register(mod),
     which stores the Init function pointer in the C shim.
  3. Retrieve the Init function pointer from the shim via _napi_get_pending_init().
     If it is 0, try dlsym(handle, "napi_register_module_v1") as a fallback
     (for addons using the NAPI_MODULE_INIT() macro form).
  4. Create an empty JS object as the exports argument.
  5. Call Init(env, exports) via _napi_invoke_register.
  6. Return the result (Init may return a different napi_value as exports).

Bun reference:
  bun/src/bun.js/bindings/NapiHandleScope.cpp (_napi_register_module_v1)
"""

import from engine.src.ffi.libdl { dlopen, dlsym, dlerror, RTLD_NOW, RTLD_LOCAL }
import from napi.src.napi_dispatch {
    _napi_dispatch,
    _napi_set_dispatch,
    _napi_get_pending_init,
    _napi_invoke_register
}
import from napi.src.napi_ops { NAPI_OK }
import from napi.src.napi_env { _napi_set_vm_ptr }
import from engine.src.runtime.jsvalue { JSValue, js_undefined }
import from engine.src.runtime.jsobject { js_object_create_null }
import from engine.src.runtime.error { make_error, vm_throw_native }
import from engine.src.runtime.jsstring { str_intern }

# ── State ─────────────────────────────────────────────────────────────────────

"""1 after _napi_set_dispatch has been called; 0 beforehand."""
glob _napi_initialized: int = 0;

# ── Internal helpers ──────────────────────────────────────────────────────────

"""Register the Jac dispatcher with the C shim if not already done.
Must be called before the first dlopen so the shim is ready to dispatch."""
def _napi_ensure_init -> None {
    if _napi_initialized != 0 {
        return;
    }
    _napi_initialized = 1;
    # Pass _napi_dispatch as int64 (ptrtoint coercion).
    # The shim stores it and calls it for every napi_* op.
    _napi_set_dispatch(_napi_dispatch);
}

# ── Public API ────────────────────────────────────────────────────────────────

"""Load a .node NAPI addon and return its exports JSValue.

  vm_napi_env_ptr — integer env ID to pass as napi_env.
  path            — absolute path to the .node shared library.

Returns js_undefined() on failure (dlopen failed or no init function found)."""
def:pub _load_napi_addon(vm_napi_env_ptr: int, path: str) -> JSValue {
    _napi_ensure_init();

    # Record the VM (env) pointer so NAPI value-handlers can reach it.
    _napi_set_vm_ptr(vm_napi_env_ptr);

    # Step 2: dlopen the addon.
    # RTLD_LOCAL: keep the addon's own symbols private (the napi_* symbols it
    # needs are visible globally via libnapi_shim.so loaded with RTLD_GLOBAL).
    handle: int = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if handle == 0 {
        err_msg: str = dlerror();
        if err_msg == "" {
            err_msg = "dlopen failed for " + path;
        }
        vm_throw_native(make_error(err_msg));
        return js_undefined();
    }

    # Step 3a: retrieve the Init function stored by napi_module_register.
    init_fn: int = _napi_get_pending_init();

    # Step 3b: fallback — NAPI_MODULE_INIT() style exports via well-known name.
    if init_fn == 0 {
        init_fn = dlsym(handle, "napi_register_module_v1");
    }

    if init_fn == 0 {
        err_msg2: str = dlerror();
        if err_msg2 == "" {
            err_msg2 = "no NAPI init function in " + path;
        }
        vm_throw_native(make_error(err_msg2));
        return js_undefined();
    }

    # Step 4: create the default exports object.
    exports_jsval: JSValue = js_object_create_null();

    # Step 5: call Init(env, exports) through the C helper in the shim.
    # _napi_invoke_register handles the C function-pointer call safely.
    result_raw: int = _napi_invoke_register(init_fn, vm_napi_env_ptr, exports_jsval);

    # Step 6: Init may return a different napi_value (JSValue) as its exports.
    # If it returned 0 (NULL in C), fall back to the exports object we passed.
    if result_raw == 0 {
        return exports_jsval;
    }
    # Reinterpret the raw int64 as a JSValue.
    # napi_value == JSValue (tagged int64), so this is identity.
    result_jsval: JSValue = result_raw;
    return result_jsval;
}
