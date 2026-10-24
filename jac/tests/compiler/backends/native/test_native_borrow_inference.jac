"""Borrow inference: a local that only names what something else keeps alive is not counted.

The ownership pass infers a local a borrow when every bind is `None` or a
place (`.field` and `list[index]` steps from a parameter, `self`, another
borrow or a local bound once), and nothing in the function may write that
path or run code it cannot see; codegen then binds it without a retain and
never releases it. These tests check both sides: the `keep_*` functions of
the fixture lose their refcount traffic, the `must_*` ones keep it (each
would read a freed object otherwise), and the program prints what the
Python backend prints under both refcounting profiles.
"""

import re;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import os;

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "borrow_infer.jac");

"""The fixture's unoptimized IR under `gc_mode`."""
def fixture_ir(gc_mode: str) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=FIXTURE, options=CompileOptions(aot_mode=True, na_gc_mode=gc_mode)
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""How many retains function `name` emits."""
def retains_in(text: str, name: str) -> int {
    found = re.search(r'define [^\n]*\.' + name + r'"?\(.*?\n}\n', text, re.S);
    assert found is not None , f"{name} not found in the IR";
    return len(re.findall(r'call void @"__rc_retain"', found.group(0)));
}

test "locals that only borrow emit no retain" {
    for gc_mode in ["cycles", "rc"] {
        text = fixture_ir(gc_mode);
        for name in ["keep_elem", "keep_loop", "keep_field"] {
            assert retains_in(text, name) == 0 , f"{gc_mode} {name}: {retains_in(
                text, name
            )} retains";
        }
    }
}

test "locals whose source can be released before their last use stay counted" {
    text = fixture_ir("rc");
    for name in [
        "must_elem_overwrite",
        "must_field_overwrite",
        "must_call_clear",
        "must_method_clear",
        "must_loop_overwrite",
        "must_global_root",
        "must_copied_root"
    ] {
        assert retains_in(text, name) >= 1 , f"{name} lost its retain";
    }
}

test "the program prints what the Python backend prints under rc and managed" {
    assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
}
