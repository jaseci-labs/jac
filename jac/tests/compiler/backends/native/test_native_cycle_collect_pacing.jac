"""The cycle collector's cost follows the garbage a program makes, not the
size of the live graph it holds.

A release that leaves an object's count above zero buffers it as a candidate
root, and every thousand candidates a collection traced everything reachable
from them. A program that keeps a large cyclic graph (a game level, a scene
graph) and touches it every frame retraced all of it every thousand releases,
and most candidates could never be on a cycle at all (an object of a type with
no trace function: a vector of floats, a list of ints). Now such objects are
marked untraced the first time they are offered and never buffered, and after
each collection the next waits for a quarter as many candidates as the live
objects the last one traced (RC_CYCLE_PACE), never fewer than a thousand.

Driven in-process through the JIT: the collector's own globals give exact
counts (`__rc_roots_count`, `__rc_roots_threshold`, `__rc_traced`)."""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "cycle_collect_pacing.jac"
     );

"""The fixture compiled into a fresh JIT engine with cycle collection on."""
obj Collector {
    has eng: any = None;

    def postinit {
        prog = JacProgram();
        ir = prog.compile(file_path=FIXTURE, options=native_force_opts());
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        self.eng = ir.gen.native_engine;
        assert self.eng is not None;
        self.global_word("__rc_cycles_enabled", ctypes.c_uint8)[0] = 1;
        self.call("collect");
    }

    def global_word(name: str, kind: any = ctypes.c_uint64) -> any {
        addr = self.eng.get_global_value_address(name);
        assert addr , f"no global {name}";
        return ctypes.cast(addr, ctypes.POINTER(kind));
    }

    def read(name: str) -> int {
        return int(self.global_word(name)[0]);
    }

    def call(name: str, *args: int) -> int {
        addr = native_address(self.eng, name);
        assert addr , f"no function {name}";
        kinds = [ctypes.c_int64 for _ in args];
        return ctypes.CFUNCTYPE(ctypes.c_int64, *kinds)(addr)(*args);
    }

    """The buffered candidate roots (freed ones read as 0)."""
    def roots -> list[int] {
        buf = self.read("__rc_roots_buf");
        count = self.read("__rc_roots_count");
        if count == 0 {
            return [];
        }
        slots = ctypes.cast(buf, ctypes.POINTER(ctypes.c_uint64));
        return [int(slots[i]) for i in range(count)];
    }
}

test "objects with nothing to trace are never buffered as candidate roots" {
    for step in ["share_untraced", "read_untraced"] {
        gc = Collector();
        gc.call(step, 100);
        assert gc.roots() == [] , f"{step}: {len(
            gc.roots()
        )} untraced objects buffered";
    }
}

test "the next collection waits for a quarter of the live objects the last traced" {
    gc = Collector();
    gc.call("grow_hub", 20000);
    gc.call("touch_hub");
    assert len(gc.roots()) >= 1;
    gc.call("collect");
    traced = gc.read("__rc_traced");
    assert traced > 20000 , traced;
    assert gc.read("__rc_roots_threshold") == traced // 4;
    # A small live graph brings the threshold back to its floor.
    gc2 = Collector();
    gc2.call("touch_hub");
    gc2.call("collect");
    assert gc2.read("__rc_roots_threshold") == 1000;
}

test "cycles are still reclaimed automatically while a large graph is live" {
    gc = Collector();
    gc.call("grow_hub", 20000);
    gc.call("touch_hub");
    gc.call("collect");
    threshold = gc.read("__rc_roots_threshold");
    gc.call("make_pairs", threshold * 2);
    assert gc.call("dropped_boxes") > 0 , "no collection ran on its own";
    gc.call("collect");
    assert gc.call("dropped_boxes") == threshold * 4;
    assert gc.call("dropped_leaves") == threshold * 2;
}

test "freeing a buffered object clears its own slot and no other" {
    gc = Collector();
    gc.call("buffer_two");
    before = gc.roots();
    assert len(before) == 2 and 0 not in before , before;
    gc.call("drop_first");
    after = gc.roots();
    assert len(after) == 2 , after;
    assert sorted([slot == 0 for slot in after]) == [False, True] , after;
    assert [
        slot
        for slot in after
        if slot != 0
    ][0]
        in before;
}
