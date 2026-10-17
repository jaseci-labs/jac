"""A native build session and the cyclic garbage collector.

A session keeps every unit's analysis until it closes, so at each unit boundary
it collects what is new and freezes the survivors: no later full collection
walks them again, while what a unit drops is still reclaimed. The collector is
handed back exactly as the session found it, also when the build fails, and
only one session holds it at a time.
"""

import gc;
import os;
import shutil;
import tempfile;
import weakref;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.nativecache {
    NativeBuildSession,
    SessionHeap,
    SESSION_FULL_GC_EVERY
}
import from jaclang.compiler.backends.native.link_plan { build_link_plan }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures" / "link_diamond"),
     UNITS: list[str] = ["base.jac", "left.jac", "right.jac", "extra.jac", "top.jac"];

obj Cell {
    has other: any = None;
}

def _diamond_copy -> str {
    tmp = tempfile.mkdtemp(prefix="jac-session-heap-");
    for name in UNITS {
        shutil.copy(os.path.join(FIXTURES, name), os.path.join(tmp, name));
    }
    return tmp;
}

def _opts -> CompileOptions {
    return CompileOptions(
        aot_mode=True, default_codespace='native', skip_native_engine=True
    );
}

def _collector_state -> tuple[bool, tuple[int, int, int], int] {
    return (gc.isenabled(), gc.get_threshold(), gc.get_freeze_count());
}

def _cycle -> tuple[Cell, any] {
    cell = Cell();
    cell.other = cell;
    return (cell, weakref.ref(cell));
}

def _is_scanned(target: any) -> bool {
    return any(o is target for o in gc.get_objects());
}

test "garbage a unit drops is reclaimed at the boundary, and survivors are frozen" {
    assert gc.isenabled() and gc.get_freeze_count() == 0;
    before = _collector_state();
    heap = SessionHeap();
    assert heap.take();
    gc.disable();
    try {
        (dropped, dropped_ref) = _cycle();
        (kept, kept_ref) = _cycle();
        del dropped;
        assert dropped_ref() is not None;
        heap.settle();
        assert dropped_ref() is None , "a cycle dropped before the boundary must be reclaimed";
        assert kept_ref() is kept;
        assert not _is_scanned(kept) , "a survivor of the boundary must be frozen";
        assert gc.get_threshold()[2] >= SESSION_FULL_GC_EVERY;
    } finally {
        gc.enable();
        heap.release();
    }
    assert _collector_state() == before;
    assert _is_scanned(kept) , "closing hands the frozen objects back to the collector";
}

test "only one session holds the collector, and none takes it from a frozen process" {
    assert gc.isenabled() and gc.get_freeze_count() == 0;
    outer = SessionHeap();
    inner = SessionHeap();
    assert outer.take();
    try {
        assert not inner.take() , "a nested session leaves the outer policy alone";
        inner.release();
        assert gc.get_threshold()[2] >= SESSION_FULL_GC_EVERY;
    } finally {
        outer.release();
    }
    gc.freeze();
    try {
        frozen = gc.get_freeze_count();
        late = SessionHeap();
        assert not late.take();
        late.settle();
        late.release();
        assert gc.get_freeze_count() == frozen , "a session must not unfreeze what it did not freeze";
    } finally {
        gc.unfreeze();
    }
    gc.disable();
    try {
        assert not SessionHeap().take() , "a process that turned the collector off keeps it off";
    } finally {
        gc.enable();
    }
}

test "a link plan hands the collector back exactly as it found it" {
    assert gc.isenabled() and gc.get_freeze_count() == 0;
    found = gc.get_threshold();
    gc.set_threshold(1234, 7, 9);
    try {
        before = _collector_state();
        root_dir = _diamond_copy();
        prog = JacProgram();
        opts = _opts();
        prog.options = opts;
        seen: list[tuple[int, int]] = [];
        registry = prog.native_units();

        def note(line: str) {
            seen.append((gc.get_freeze_count(), gc.get_threshold()[2]));
        }
        registry.progress = note;
        plan = build_link_plan(prog, [os.path.join(root_dir, "top.jac")], opts);
        assert len(plan.units) >= len(UNITS);
        assert _collector_state() == before;
        assert any(frozen > 0 for (frozen, _) in seen) , "the session froze its units' products";
        assert any(
            full >= SESSION_FULL_GC_EVERY
            for (frozen, full) in seen
            if frozen > 0
        );
        assert "gc settle" in registry.phase_summary();
    } finally {
        gc.set_threshold(*found);
    }
}

test "a unit's analysis is frozen for the rest of the session" {
    assert gc.isenabled() and gc.get_freeze_count() == 0;
    root_dir = _diamond_copy();
    base = os.path.realpath(os.path.join(root_dir, "base.jac"));
    prog = JacProgram();
    opts = _opts();
    prog.options = opts;
    registry = prog.native_units();
    checked: list[bool] = [];

    def watch(line: str) {
        session = registry.session;
        if session is None or "] lower" not in line {
            return;
        }
        analyzed = session.lowered.get(base);
        if analyzed is not None {
            assert gc.is_tracked(analyzed);
            checked.append(_is_scanned(analyzed));
        }
    }
    registry.progress = watch;
    build_link_plan(prog, [os.path.join(root_dir, "top.jac")], opts);
    assert checked , "units were lowered after base in this session";
    assert not any(checked) , "a full collection would walk base's analysis again";
    assert gc.get_freeze_count() == 0;
}

test "a failing build still hands the collector back" {
    assert gc.isenabled() and gc.get_freeze_count() == 0;
    before = _collector_state();
    root_dir = _diamond_copy();
    prog = JacProgram();
    opts = _opts();
    prog.options = opts;
    finish = NativeBuildSession.finish;
    froze: list[int] = [];

    def fail(self: NativeBuildSession, paths: list[str]) {
        froze.append(gc.get_freeze_count());
        raise RuntimeError("the build failed after lowering");
    }
    NativeBuildSession.finish = fail;
    try {
        raised = False;
        try {
            build_link_plan(prog, [os.path.join(root_dir, "top.jac")], opts);
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    } finally {
        NativeBuildSession.finish = finish;
    }
    assert froze and froze[0] > 0 , "the session held the collector when it failed";
    assert _collector_state() == before;
}
