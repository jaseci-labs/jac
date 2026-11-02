"""`disengage` leaves the regions an event ability entered.

An event ability enters its anchor's region on entry and leaves it on the
fall-through path; `skip` left it too, but `disengage` returned straight
after `osp_disengage`. A walker that disengaged inside a region open left
that region on the thread's region stack after the open closed, so every
later allocation on the thread went into freed region memory. The kernel's
parse runs the early passes (graph lowering disengages) inside its region,
and the next kernel call after it corrupted memory.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "a disengaging ability leaves the region stack as it found it" {
    (eng, _ir) = compile_native("disengage_region.jac");
    depth = get_func(eng, "__jac_region_depth", ctypes.c_int64);
    before = depth();
    assert get_func(eng, "spawn_disengaging_in_region", ctypes.c_int64)() == 5;
    assert depth() == before;
    assert get_func(eng, "spawn_finishing_in_region", ctypes.c_int64)() == 101;
    assert depth() == before;
}
