"""NapiEnv — per-addon NAPI environment state.

The env is identified by an integer ID (napi_env_id), not a raw pointer,
to stay within Jac's type system.

Bun reference: bun/src/bun.js/bindings/NapiHandleScope.h (NapiEnv struct).
"""

import from engine.src.runtime.realm { Realm }
import from engine.src.vm.closure_type { JSClosure }

obj:pub NapiEnv {
    # Unique integer ID passed as napi_env to the C shim.
    has id: int = 0,
        vm_ptr: int = 0,
        pending_exc: int = 0,
        scope_depth: int = 0,
        instance_data: int = 0,
        module_filename: str = "";
}

# Back-pointer to the VM (stored as raw int to avoid circular import).
# Cast to VM in napi_loader when needed.

# Currently pending exception JSValue (0 == none).

# Depth of the current handle scope stack.

# Per-addon instance data (set by napi_set_instance_data).

# File name of the addon that owns this env (for node_api_get_module_file_name).
# ── Module-level VM and global state ─────────────────────────────────────────────

"""Raw VM pointer (int address) set by napi_loader before the first Init call.
Used by value handlers that need to reach VM state (e.g. napi_get_global)."""
glob:pub _napi_vm_ptr: int = 0;

"""The global_this JSValue set by napi_loader from vm.global_this.
Used by _h_get_global in napi_values.na.jac via _napi_get_global_jsv()."""
glob:pub _napi_global_jsv: int = 0;

"""Set the raw VM pointer (int address) — called by napi_loader on first load."""
def:pub _napi_set_vm_ptr(vm_int: int) {
    _napi_vm_ptr = vm_int;
}

"""Set the global_this JSValue — called by napi_loader after VM is ready."""
def:pub _napi_set_global_jsv(jsv: int) {
    _napi_global_jsv = jsv;
}

"""Return the current global_this JSValue."""
def:pub _napi_get_global_jsv -> int {
    return _napi_global_jsv;
}

# ── Shared realm reference ───────────────────────────────────────────────────────

"""Realm shared with the JS VM — provides access to realm.closures."""
glob:pub _napi_realm: Realm;

"""Set the realm reference — called by vm.na.jac before loading any NAPI addon."""
def:pub _napi_set_realm(r: Realm) {
    _napi_realm = r;
}

"""Return the shared realm (for napi_func.na.jac closure registration)."""
def:pub _napi_get_realm -> Realm {
    return _napi_realm;
}

# ── Pending exception bridging ───────────────────────────────────────────────────

"""Pending NAPI exception JSValue as int64 (0 = none)."""
glob:pub _napi_pending_exc: int = 0;

"""True when a NAPI exception has been thrown and not yet consumed."""
glob:pub _napi_had_exception: bool = False;

"""Pending NAPI exception JSValue (int) — set by napi_throw* handlers."""
def:pub _napi_set_exception(exc: int) {
    _napi_pending_exc = exc;
    _napi_had_exception = True;
}

"""Return True if a NAPI exception is currently pending."""
def:pub _napi_get_had_exception -> bool {
    return _napi_had_exception;
}

"""Consume and clear the pending exception; returns its JSValue as int."""
def:pub _napi_consume_exception -> int {
    exc: int = _napi_pending_exc;
    _napi_pending_exc = 0;
    _napi_had_exception = False;
    return exc;
}
