"""In-process JIT stress harness for the trial-deletion cycle collector.

The AOT RSS test (`test_native_gc.jac`) proves collection end-to-end but needs a
vendored musl toolchain and reads peak RSS, which never shrinks after a free and
is noisy. This harness instead JIT-compiles a cyclic fixture, drives it directly
through ctypes, and measures the glibc allocator's *in-use* byte count
(`mallinfo2().uordblks`) — which drops the instant the collector frees a cycle.
That gives a deterministic, musl-free assertion the reviewer asked for: run each
cyclic graph with cycle collection both on and off and check live-heap behaviour.

The invariant under test, for a graph of mutually-referential objects that plain
reference counting can never reclaim:

  - cycles ON  (`__rc_cycles_enabled = 1`): in-use bytes stay flat across a long
    build/drop loop — every cycle is reclaimed. A collector that mis-orders
    reclaim (freeing a still-buffered root), leaves a buffered object dangling,
    or cannot trace across a container leaks pairs and this growth blows up (or
    the process crashes on a use-after-free — also a failure).
  - cycles OFF (default): the cyclic garbage leaks (in-use grows), proving the
    fixture really is unreclaimable by RC alone, AND — because root buffering is
    gated on `__rc_cycles_enabled` — the leak tracks the raw object bytes without
    an unbounded purple-root buffer piled on top.

Linux/glibc only (needs `mallinfo2`); skipped elsewhere, where the AOT RSS test
carries the coverage.
"""

import ctypes;
import os;
import sys;
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );


"""Return a callable reading glibc `mallinfo2().uordblks`, or None if unavailable."""
def _inuse_probe -> (object | None) {
    if not sys.platform.startswith("linux") {
        return None;
    }
    try {
        libc = ctypes.CDLL("libc.so.6");
        _fields = [
            (n, ctypes.c_size_t)
            for n in (
                "arena",
                "ordblks",
                "smblks",
                "hblks",
                "hblkhd",
                "usmblks",
                "fsmblks",
                "uordblks",
                "fordblks",
                "keepcost"
            )
        ];
        _MI = type("Mallinfo2", (ctypes.Structure, ), {"_fields_": _fields});
        libc.mallinfo2.restype = _MI;
    } except (OSError, AttributeError) {
        return None;
    }
    return lambda { int(libc.mallinfo2().uordblks); };
}


"""JIT-compile `fixture` and drive its `make_cycle`/`__rc_collect_cycles` hooks,
returning in-use-heap growth (bytes) across a build/drop loop with cycle
collection `enable`d or not."""
def _cycle_growth(fixture: str, enable: bool, inuse: object) -> int {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    assert not prog.errors_had , (
        f"compile errors in {fixture}: {[str(e) for e in prog.errors_had]}"
    );
    eng = ir.gen.native_engine;
    assert eng is not None , f"no native engine for {fixture}";

    def _fn(name: str) -> object {
        addr = eng.get_function_address(name);
        assert addr , f"symbol '{name}' not found in {fixture}";
        return ctypes.CFUNCTYPE(None)(addr);
    }
    make_cycle = _fn("make_cycle");
    collect = _fn("__rc_collect_cycles");

    if enable {
        gaddr = eng.get_global_value_address("__rc_cycles_enabled");
        assert gaddr , "could not locate __rc_cycles_enabled global";
        ctypes.cast(gaddr, ctypes.POINTER(ctypes.c_uint8))[0] = 1;
    }

    # Warm the allocator, then baseline after a collect so transient buffers are
    # drained; the measured window is pure steady-state build/drop.
    for _ in range(2000) {
        make_cycle();
    }
    collect();
    base = inuse();
    for k in range(50000) {
        make_cycle();
        if k % 5000 == 0 {
            collect();
        }
    }
    collect();
    return inuse() - base;
}


"""Assert `fixture`'s cycles are reclaimed with collection on and leak with it off."""
def _assert_reclaims(fixture: str, leak_floor: int = 2 * 1024 * 1024) {
    inuse = _inuse_probe();
    if inuse is None {
        return;  # non-glibc platform: AOT RSS test covers this
    }
    on_growth = _cycle_growth(fixture, True, inuse);
    off_growth = _cycle_growth(fixture, False, inuse);
    # ON: a slab of allocator slack is fine, but it must not scale with the 50k
    # iterations — a real leak here is tens of MB. Half the leak floor is a wide
    # margin that still fails hard on any per-iteration retention.
    assert on_growth <= leak_floor // 2 , (
        f"{fixture}: cycle collection ON still grew in-use heap by {on_growth} B"
        f" over 50k build/drop iterations — cycles are not being reclaimed"
    );
    # OFF: the cyclic garbage must actually leak, else the fixture proves nothing.
    assert off_growth >= leak_floor , (
        f"{fixture}: cycle collection OFF grew in-use heap by only {off_growth} B;"
        f" expected >= {leak_floor} B (fixture is not building real cyclic garbage)"
    );
    # ON must be dramatically better than OFF — the actual proof of reclamation.
    assert on_growth * 8 < off_growth , (
        f"{fixture}: cycle collection barely helped (on={on_growth} B,"
        f" off={off_growth} B) — collector is leaking cycles"
    );
}


test "cycle collector reclaims two-node struct cycles (JIT, in-use heap)" {
    _assert_reclaims("cycle_collect_storm.na.jac");
}

test "cycle collector reclaims cycles routed through a container (JIT, in-use heap)" {
    _assert_reclaims("cycle_collect_container.na.jac");
}
