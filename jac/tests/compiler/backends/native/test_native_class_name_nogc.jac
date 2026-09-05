"""`__class__.__name__` must not probe a header that does not exist.

Resolving the runtime class of a receiver whose static type names no class
reads the class-name stamp in the rc header (#8148). Headerless
`--gc none --enforce-nogc` allocates with a bare `malloc`: there is no header
in front of the allocation and nothing stamps a class name anywhere, so the
probe's first load (`HDR_RC_OFF`, sixteen bytes *before* the pointer) reads
memory the allocation does not own.

Two failure modes, and the second is the reason this is asserted rather than
left to review. A load that crosses a page boundary faults. But if the bytes
in front of the allocation happen to equal `RC_SENTINEL`, or to satisfy the
magic check, the probe proceeds to load the tag offset and returns whatever is
there **as a class name** -- a wrong answer with no diagnostic, which is the
same shape as the two silent divergences #8148 already fixed.

So under headerless mode the probe is not emitted at all, and a read that
would need it is refused. `__jac_str_len` already draws the line in exactly
this place: it branches on headerless and falls back to `strlen` rather than
consulting the header. A class name has no such fallback, so the answer is
E5092.

What survives headerless mode is everything the header was never needed for:
the class-name constant in vtable slot 0 (a slot inside the struct) and the
compile-time constant for a class with no hierarchy. The last test compiles
the *same* open-receiver fixture under an ordinary gc mode and reads the right
answer out of it, which is what makes the refusal above mode-specific rather
than a lowering defect.

The refusal test is the regression guard: with the headerless gate removed,
the open read compiles clean under `--gc none --enforce-nogc` and answers off
the probe, and that test is the one that catches it. The other two pin what
must keep working around it.

Refs #8148
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "nogc"
     ),
     STATIC_FIXTURE = "class_name_nogc.jac",
     OPEN_FIXTURE = "class_name_nogc_open.jac",
     PROBE_SYMBOL = "__jac_class_name";


"""Headerless: `--gc none` with nogc enforced, the mode with no rc header."""
def _headerless_opts -> any {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    return CompileOptions(
        force_codespace='native',
        force_target_program=True,
        na_gc_mode="none",
        nogc_enforce_all=True
    );
}


"""Compile a fixture and hand back the program and its module, errors and all."""
def _compile(fixture: str, options: any) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)), options=options);
    return (prog, ir);
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(eng: any, name: str) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""True if the program emitted at least one alert with the given code."""
def _has_code(prog: any, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}


def _ir_text(ir: any) -> str {
    return str(ir.gen.llvm_ir) if (ir is not None and ir.gen.llvm_ir) else "";
}


test "headerless mode keeps the class-name reads that need no header" {
    (prog, ir) = _compile(STATIC_FIXTURE, _headerless_opts());
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {STATIC_FIXTURE}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the headerless fixture";

    vt = _get(eng, "vtable_rank");
    assert vt(1) == 1 , (
        "a vtabled receiver reports its runtime class from vtable slot 0, "
        "which lives inside the struct and survives a headerless allocation"
    );
    assert vt(0) == 2 , "and the base class reports its own name";
    assert _get(eng, "lone_rank")(0) == 3 , (
        "a class with no hierarchy has its name frozen at compile time"
    );
    assert PROBE_SYMBOL not in _ir_text(ir) , (
        f"'{PROBE_SYMBOL}' was emitted for reads that resolve statically; "
        "neither of these may start depending on a header to answer"
    );
}


test "an open receiver is refused under headerless mode, not answered" {
    (prog, ir) = _compile(OPEN_FIXTURE, _headerless_opts());
    assert not prog.errors_had , (
        "the refused read is owned by erased_rank, which must demote to a "
        f"seam: got {[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "erased_rank" not in layout.functions , (
        "a type-erased receiver's class name can only come from the header, "
        "which headerless mode does not have, so the reading function must "
        "be demoted out of the native layout, never answered"
    );
    assert PROBE_SYMBOL not in _ir_text(ir) , (
        f"'{PROBE_SYMBOL}' reached the IR for a refused read"
    );
}


test "the same open read answers under a gc mode that has headers" {
    (prog, ir) = _compile(OPEN_FIXTURE, native_force_opts());
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , (
        f"the open fixture must lower where a header exists: {errors}"
    );
    assert PROBE_SYMBOL in _ir_text(ir) , (
        f"'{PROBE_SYMBOL}' is how this read is answered when a header exists"
    );
    assert _get(ir.gen.native_engine, "erased_rank")(0) == 1 , (
        "the erased slot holds a Marked and the header stamp says so -- so "
        "the refusal above is specific to headerless mode, not a lowering gap"
    );
}
