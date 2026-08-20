"""Native backend robustness: graceful demotion instead of hard crashes.

The native (.jac) backend is best-effort -- a construct it cannot lower must
fall back to the Python implementation, never crash the whole compile with an
uncaught Python exception. These tests pin two guarantees:

1. A void-typed value bound to a variable demotes its owning free function
   with a diagnostic that names the binding (epic #8201 made free functions
   seam-demotable like methods) instead of asserting deep in
   `_entry_alloca` -> `PointerType.as_pointer()`.
2. A method whose body raises a hard error in the emitter is demoted to
   Python-only (workstream A4, #6930), so sibling methods in the same module
   still compile natively rather than the whole module aborting.
"""

import os;
import from pathlib { Path }
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

# --- Fix B: void binding is a named seam, not a crash ---
test "void binding demotes its function with a named reason, not a crash" {
    # Previously raised AssertionError in PointerType.as_pointer (void pointee);
    # the granular-demotion contract then turned the loud module error into a
    # per-function seam whose reason still names the void binding.
    (log, ir) = _demotion_log("void_binding.jac");
    block = _demote_block(log, "caller");
    assert "void" in block , f"the demotion reason should name the binding:\n{block}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "sink" in layout.functions , (
        f"clean sibling function was lost: {list(layout.functions)}"
    );
    assert "caller" not in layout.functions , (
        "the function with the void binding should be demoted/skipped"
    );
}

# --- Fix A: a hard emitter error in one method does not abort the module ---
test "hard codegen error in one method demotes it, keeps siblings native" {
    prog = JacProgram();
    # Previously raised TypeError (i64 != void) and aborted the whole compile.
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "method_codegen_crash.jac"),
        options=native_force_opts()
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "no native layout -- whole-module native compile aborted";
    assert "C.good" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "C.bad" not in layout.methods , "un-lowerable method should be demoted/skipped";
    assert ir.gen.native_engine is not None , "no native engine produced after demotion";
}

# --- A demotion names its cause, not the reads downstream of it ---
"""Compile the fixture with the demotion diagnostics on, returning them.

`JAC_NA_DEBUG` writes `NA_DEBUG demote <method>` plus every diagnostic behind
the demotion to stderr; that stream is the only place the full per-method
reason list survives, since the coverage keeps just the first one.
"""
def _demotion_log(fixture: str) -> tuple {
    import contextlib;
    import io;
    prog = JacProgram();
    buf = io.StringIO();
    _prev = os.environ.get("JAC_NA_DEBUG");
    os.environ["JAC_NA_DEBUG"] = "1";
    try {
        with contextlib.redirect_stderr(buf) {
            ir = prog.compile(
                file_path=os.path.join(FIXTURES, fixture), options=native_force_opts()
            );
        }
    } finally {
        if _prev is None {
            del os.environ["JAC_NA_DEBUG"];
        } else {
            os.environ["JAC_NA_DEBUG"] = _prev;
        }
    }
    return (buf.getvalue(), ir);
}

"""The stderr block a single `NA_DEBUG demote <method>` header introduces."""
def _demote_block(log: str, method: str) -> str {
    head = f"NA_DEBUG demote {method}\n";
    start = log.find(head);
    assert start != -1 , f"no demotion recorded for {method} in:\n{log}";
    start += len(head);
    nxt = log.find("NA_DEBUG demote ", start);
    return log[start:] if nxt == -1 else log[start:nxt];
}

test "a failed binding is reported once, not again at every read of the name" {
    (log, ir) = _demotion_log("unlowered_local_cascade.jac");
    block = _demote_block(log, "C.cascaded");

    assert block.count("error[E5092]") == 1 , (
        f"the failed binding should be the only reported cause, got:\n{block}"
    );
    assert "eval" in block , f"the reported cause should name the binding:\n{block}";
    for kind in ["'CompareExpr'", "'Name'", "'IfElseExpr'"] {
        assert kind not in block , (
            f"a read of the unbound name was blamed as {kind}:\n{block}"
        );
    }

    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "C.clean" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "C.cascaded" not in layout.methods , (
        "the method whose binding could not lower should still be demoted"
    );
}

test "the poison follows a name rebound from an unlowerable one" {
    (log, _) = _demotion_log("unlowered_local_cascade.jac");
    block = _demote_block(log, "C.chained");
    assert block.count("error[E5092]") == 1 , (
        f"only the original binding should be reported, got:\n{block}"
    );
    assert "eval" in block , f"the reported cause should name the binding:\n{block}";
}

test "a tuple target leaves every name it destructures unbound, not blamed" {
    (log, _) = _demotion_log("unlowered_local_cascade.jac");
    block = _demote_block(log, "C.unpacked");
    assert block.count("error[E5092]") == 1 , (
        f"only the failed call should be reported, got:\n{block}"
    );
    assert "'C.pair'" in block , (
        f"the reported cause should name the call that failed:\n{block}"
    );
}
