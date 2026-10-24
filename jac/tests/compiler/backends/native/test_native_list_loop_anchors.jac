"""List loops: alias tags for list headers and elements, headers read before the loop.

The IR carried no alias information, so a store into a list element might
have changed any list's length or data pointer, and LLVM reloaded both after
every store. List header fields and list elements now carry TBAA tags of
their own. And a range loop whose body cannot change a list header (no calls
but a few builtins, no reassignment of the list, no slice store, no `del`)
reads each indexed list's length and data pointer once before the loop; its
scalar element reads and writes check against and index through them, and
anything out of range takes the old path, which raises as before.

The fixture prints what the Python backend prints under rc and managed, and
the loops that may change a list keep the old access.
"""

import os;
import re;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "list_loop_anchors.jac"),
     USER_CODE_FIXTURE: str = os.path.join(
         NATIVE_FIXTURES, "list_loop_anchors_user_code.jac"
     );

"""The unoptimized IR of `path`, by default the main fixture."""
def fixture_ir(path: str = FIXTURE) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=path, options=CompileOptions(aot_mode=True, na_gc_mode="rc")
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

test "loops that cannot change a list read its header once" {
    text = fixture_ir();
    for name in ["axpy", "copy_into", "reverse", "matmul"] {
        assert "anchor.len" in body_of(text, name) , f"{name} has no anchored list";
    }
    assert "anchor.len" not in body_of(text, "grow") , "grow appends in its loop";
    assert "cur.anchor" not in body_of(text, "rebind") , "rebind reassigns the list";
    assert "a.anchor" not in body_of(text, "swap_rebind") , (
        "swap_rebind reassigns the list by unpacking"
    );
}

test "the program prints what the Python backend prints under rc and managed" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert "caught 2.0 4.0" in out , out;
}

test "loops whose body can run user code keep the old access" {
    text = fixture_ir(USER_CODE_FIXTURE);
    for name in ["shadowed", "nested"] {
        assert "anchor.len" not in body_of(text, name) , (
            f"{name} reads its list header once although its body runs user code"
        );
    }
    out = assert_native_identity(USER_CODE_FIXTURE, profiles=["rc", "managed"]);
    assert out.splitlines()[:2] == ["caught 5", "caught 6"] , out;
}
