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

import from tests.support {
    assert_native_identity,
    compile_native_ir,
    names_function,
    KernelFixture,
    NATIVE_FIXTURES
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import os;

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "borrow_infer.jac");

"""The fixture compiled under `gc_mode`. Reference counting is decided after
the MIR decision step, so the retains are read from the emitted LLVM IR."""
def fixture_ir(gc_mode: str) -> KernelFixture {
    return compile_native_ir(
        FIXTURE,
        "",
        CompileOptions(force_codespace="native", aot_mode=True, na_gc_mode=gc_mode)
    );
}

"""How many retains function `name` emits."""
def retains_in(fx: KernelFixture, name: str) -> int {
    symbol = fx.symbol(name);
    active = False;
    count = 0;
    for line in fx.llvm_ir().split("\n") {
        if line.startswith("define") {
            active = names_function(line, symbol);
            continue;
        }
        if active and line == "}" {
            return count;
        }
        if active and "call" in line and names_function(line, "__jac_rt_retain") {
            count += 1;
        }
    }
    assert active , f"{name} not found in the IR";
    return count;
}

test "locals that only borrow emit no retain" {
    for gc_mode in ["cycles", "rc"] {
        fx = fixture_ir(gc_mode);
        for name in ["keep_elem", "keep_loop", "keep_field"] {
            assert retains_in(fx, name) == 0 , f"{gc_mode} {name}: {retains_in(
                fx, name
            )} retains";
        }
    }
}

test "locals whose source can be released before their last use stay counted" {
    fx = fixture_ir("rc");
    for name in [
        "must_elem_overwrite",
        "must_field_overwrite",
        "must_call_clear",
        "must_method_clear",
        "must_loop_overwrite",
        "must_global_root",
        "must_copied_root",
        "must_remove_eq",
        "must_aug_op",
        "must_reused_loop_name",
        "must_own_root"
    ] {
        assert retains_in(fx, name) >= 1 , f"{name} lost its retain";
    }
}

test "two loop variables of one name both stay counted" {
    # they share a slot, so the second loop releases what the first left there
    for gc_mode in ["cycles", "rc"] {
        got = retains_in(fixture_ir(gc_mode), "must_reused_loop_name");
        assert got >= 2 , f"{gc_mode}: {got} retains";
    }
}

test "the program prints what the Python backend prints under rc and managed" {
    assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
}
