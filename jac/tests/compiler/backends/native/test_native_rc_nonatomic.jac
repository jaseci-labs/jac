"""Refcount updates are plain (non-atomic) load/add/store.

Native execution is single-threaded per isolate, so retain/release and
the alloc-id counter use ordinary memory operations; an atomic RMW on
every RC update was the dominant cost of RC-heavy code. The IR test
pins the emission (no `atomicrmw` anywhere in the module); the
behavioral test proves correctness on an RC-churn workload where any
dropped or doubled retain/release corrupts the checksum or crashes.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "rc: refcount updates emit no atomic RMW" {
    (eng, ir) = compile_native("rc_nonatomic.jac");
    text = str(ir.gen.llvm_ir);
    assert text.count("atomicrmw") == 0 , "RC helpers must use plain load/store updates";
}

test "rc: RC-churn workload computes correctly" {
    (eng, _) = compile_native("rc_nonatomic.jac");
    f = get_func(eng, "rc_churn", ctypes.c_int64, ctypes.c_int64);
    assert f(500) == 2 * (500 + 1390);
    assert f(1) == 4;
    assert f(0) == 0;
}
