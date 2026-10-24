"""List loops: alias tags for list headers and elements.

The IR carried no alias information, so a store into a list element might
have changed any list's length or data pointer, and LLVM reloaded both after
every store. List header fields and list elements now carry TBAA tags of
their own. The fixture prints what the Python backend prints under rc and
managed.
"""

import os;
import re;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "list_loop_anchors.jac");

"""The fixture's unoptimized IR."""
def fixture_ir() -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=FIXTURE, options=CompileOptions(aot_mode=True, na_gc_mode="rc")
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""The body of the function whose name ends in `name`."""
def body_of(text: str, name: str) -> str {
    found = re.search(r'define [^\n]*\.' + name + r'"?\(.*?\n}\n', text, re.S);
    assert found is not None , f"{name} not found in the IR";
    return found.group(0);
}

test "list headers and elements carry alias tags" {
    text = fixture_ir();
    assert '!{ !"jac.tbaa" }' in text or '!{!"jac.tbaa"}' in text , "no TBAA root";
    axpy = body_of(text, "axpy");
    assert "!tbaa" in axpy;
}

test "the program prints what the Python backend prints under rc and managed" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert "caught 2.0 4.0" in out , out;
}
