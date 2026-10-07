"""Phase 0 spike: can Jac Native store and call function references in a list?

Result: if this test passes, table-driven native dispatch is viable.
If it fails to compile, use domain sub-dispatcher functions instead.
"""

import from engine.src.ffi.libc { fflush, _exit }

glob _spike_ok: int = 0,
     _spike_fail: int = 0;

def _add(a: int, b: int) -> int {
    return a + b;
}

def _chk(label: str, got: bool) {
    if got {
        _spike_ok = _spike_ok + 1;
    } else {
        _spike_fail = _spike_fail + 1;
        print("FAIL: " + label);
    }
}

glob
     # Typed exactly like the VM's dense opcode table (_OPCODE_TABLE_D). An
     # untyped `list` (or list[int]) silently drops appended function
     # references in the native backend; only Callable-typed lists keep them.
     handlers: list[Callable[[int, int], int]] = [];
with entry {
    handlers.append(_add);
    _chk("stored fn in list", len(handlers) == 1);
    fn = handlers[0];
    result: int = fn(2, 3);
    _chk("called fn from list", result == 5);
    print("dispatch spike: ok=" + str(_spike_ok) + " fail=" + str(_spike_fail));
    if _spike_fail > 0 {
        fflush(0);
        _exit(1);
    }
}
