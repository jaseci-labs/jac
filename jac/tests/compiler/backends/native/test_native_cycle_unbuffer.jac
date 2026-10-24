"""Freeing an object in the cycle collector's root buffer takes constant time.

Freeing a buffered object used to search the root buffer backwards for its
slot, so each such free cost time proportional to the buffer. A release build
now records the slot in the low half of the object's alloc-id word when it
buffers the object (only debug builds read that half) and clears that slot
directly; the search remains for a debug build and as a fallback when the
recorded slot does not hold the object.
"""

import os;
import re;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "cycle_unbuffer.jac");

"""The fixture's unoptimized IR under the cycle collector."""
def fixture_ir(debug: bool) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, na_gc_mode="cycles", rc_debug_codegen=debug
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""The body of the function named exactly `name`."""
def body_of(text: str, name: str) -> str {
    found = re.search(
        r'define [^\n]*@"?' + re.escape(name) + r'"?\(.*?\n}\n', text, re.S
    );
    assert found is not None , f"{name} not found in the IR";
    return found.group(0);
}

test "a release build clears a freed root's recorded slot" {
    text = fixture_ir(False);
    release = body_of(text, "__rc_release_impl");
    assert "unbuf.direct" in release;
    assert "unbuf.body" in release , "the fallback search is gone";
    assert "aid.slot" in body_of(text, "__rc_push_root");
}

test "a debug build keeps the search and the alloc ids" {
    text = fixture_ir(True);
    assert "unbuf.direct" not in body_of(text, "__rc_release_impl");
    assert "aid.slot" not in body_of(text, "__rc_push_root");
}

test "the program prints what the Python backend prints under managed" {
    out = assert_native_identity(FIXTURE, profiles=["managed", "rc"]);
    assert out.splitlines() == ["2691000", "58820650"] , out;
}
