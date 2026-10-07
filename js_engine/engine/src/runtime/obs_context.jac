"""Thread-local observable VM handle for native property access (Issue #15).

Stores an opaque int handle set by the VM around call_native; vm_obs.na.jac
maps handles to VM instances.  Int-only storage avoids import cycles.
"""

glob _OBS_VM_HANDLE: int = 0,
     _OBS_ACTIVE: bool = False;

"""Set the active VM handle for observable native property access (0 = inactive)."""
def:pub obs_set_vm_handle(handle: int) {
    _OBS_VM_HANDLE = handle;
    _OBS_ACTIVE = handle != 0;
}

"""Return the active VM handle (0 when no native observable context is active)."""
def:pub obs_get_vm_handle -> int {
    return _OBS_VM_HANDLE;
}

"""Return True when observable native property access is active."""
def:pub obs_is_active -> bool {
    return _OBS_ACTIVE;
}

"""Mark observable context active/inactive (used by legacy call sites)."""
def:pub obs_set_active(active: bool) {
    _OBS_ACTIVE = active;
}
