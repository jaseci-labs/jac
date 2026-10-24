"""Small objects recycle their blocks through per-size-class free lists.

A release build keeps one free list per 16-byte size class from 48 to 128
bytes, header included: a free pushes the block onto its class's list (up to
a cap) and an allocation pops one before it calls malloc, both inline. The
class sits in the top byte of the alloc-id word. Only a single-threaded
program pools; once a thread runs, blocks go back to malloc and free, and
every pooled block is a malloc block, so free takes it too. A debug build
does not pool.
"""

import os;
import re;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "alloc_pool.jac");

"""The fixture's unoptimized IR."""
def fixture_ir(debug: bool) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(aot_mode=True, na_gc_mode="rc", rc_debug_codegen=debug)
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""The body of the function named exactly `name`."""
def body_of(text: str, name: str) -> (str | None) {
    found = re.search(r'define [^\n]*@"' + re.escape(name) + r'"\(.*?\n}\n', text, re.S);
    return found.group(0) if found is not None else None;
}

test "a release build allocates from and frees into the pool" {
    text = fixture_ir(False);
    alloc = body_of(text, "__rc_alloc");
    assert alloc is not None and "pool.pop" in alloc;
    assert body_of(text, "__rc_free_block") is not None;
}

test "a debug build does not pool" {
    text = fixture_ir(True);
    alloc = body_of(text, "__rc_alloc");
    assert alloc is not None and "pool.pop" not in alloc;
    assert body_of(text, "__rc_free_block") is None;
}

test "pooled allocation agrees with the Python backend, before and after threads" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert out.splitlines()[0].endswith(" 516 t5") , out;
}
