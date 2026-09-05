"""A call result iterated straight from the `for` header is owned (issue #8147).

`for part in t.mangle().split("|")` hands the loop a +1 reference nobody
named. The emitter released it in one place -- the loop's own exit block --
so `break` was covered and every other way out was not: an early `return`,
an exception unwinding past the loop, and the outer loop of a nested pair
whose inner loop returns all abandoned the whole collection. Binding the
same expression to a local first was leak-free, because a named local has a
frame slot and `_emit_scope_cleanup` walks those on every exit; that rewrite
is what #8052 had to apply in `Ability.event_trigger_type_names`.

Nothing about the answer changes when the collection leaks, so this suite
works two ways. Every plain-value function is compared against the
sv/bytecode result of the same fixture, which pins that the fix does not
move a single answer. The defect itself is read off the fixture's `drop`
ledger: each accounting function encodes `destructions * 1000 + value` into
one i64, so a leak is a number, not an inference about freed memory.

Refs #8039, #8052
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, names_function, native_address, native_force_opts }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "for_header_call_temp.jac",
     VALUE_FNS = [
         "full_header",
         "break_header",
         "continue_header",
         "early_ret_header",
         "early_ret_local",
         "chained_header",
         "raise_header",
         "nested_header",
         "adapter_header",
         "empty_header",
         "str_header",
         "dict_header"
     ],
     _MEMO: list = [];


"""Compile the fixture once natively; return (engine, module ir)."""
def _compiled -> tuple {
    if _MEMO {
        return _MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, FIXTURE)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {FIXTURE}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {FIXTURE}";
    _MEMO.append((eng, ir));
    return _MEMO[0];
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(name: str) -> any {
    (eng, _) = _compiled();
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Run one accounting function and split it into (destructions, value)."""
def _account(name: str, n: int) -> tuple {
    encoded = _get(name)(n);
    return (encoded // 1000, encoded % 1000);
}


"""Slice one function's textual IR out of the module dump."""
def _fn_ir(name: str) -> str {
    (_, ir) = _compiled();
    out: list[str] = [];
    inside = False;
    for ln in str(ir.gen.llvm_ir).split("\n") {
        if not inside and ln.startswith("define") and names_function(ln, name) {
            inside = True;
        }
        if inside {
            out.append(ln);
            if ln == "}" {
                break;
            }
        }
    }
    assert out , f"No IR found for function '{name}'";
    return "\n".join(out);
}


"""Import the same fixture through the sv/bytecode pathway."""
def _sv_module -> any {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=FIXTURE[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , "sv import of the fixture produced no module";
    return mods[0];
}


test "the shapes that always worked keep their accounting" {
    # The loop's exit block did hold a release, so a loop that runs to the
    # end -- or leaves by `break`, which branches to exactly that block --
    # was already correct. These are the control: if the fix double-releases,
    # they are where it shows up first, as a count above 3 or a crash.
    assert _account("full_header_drops", 3) == (3, 123) , (
        "a loop run to completion must free its collection exactly once"
    );
    assert _account("break_header_drops", 3) == (3, 1) , (
        "`break` branches to the block that holds the release"
    );
    assert _account("continue_header_drops", 3) == (3, 13) , (
        "`continue` goes round the back edge; the collection stays live"
    );
    assert _account("empty_header_drops", 3) == (0, 7) , (
        "an empty collection has nothing to destroy, and must not fault"
    );
}


test "a named local and a header temporary account the same on early return" {
    # The two functions differ only in whether the call result has a name.
    # `early_ret_local` was right all along; the header form is the bug.
    local_side = _account("early_ret_local_drops", 3);
    header_side = _account("early_ret_header_drops", 3);
    assert local_side == (3, 2) , f"the named-local form regressed: {local_side}";
    assert header_side == local_side , (
        f"header temporary accounted {header_side} where the identical loop "
        f"with the call bound to a local accounted {local_side}: an early "
        f"`return` leaves the loop without passing through its exit block, "
        f"so the collection is released nowhere"
    );
}


test "a chained header call gives back both of its temporaries" {
    # `mk_bag(n).all()` leaves two owned values in registers: the Bag and the
    # list its accessor built. Releasing the list alone drops the elements to
    # rc 1 and destroys nothing, so 3 is the count that needs both.
    assert _account("chained_header_drops", 3) == (3, 2) , (
        "`a.f().g()` in the header must release the receiver temporary as "
        "well as the collection"
    );
}


test "an exception unwinding past the loop releases the collection" {
    assert _account("raise_header_drops", 3) == (3, 5) , (
        "a `raise` caught outside the loop skips the loop's exit block, so "
        "the collection has to be reachable from the frame's own cleanup"
    );
}


test "nested header calls each release their own collection" {
    # The inner loop completes once (a.tag == 1) and returns out of its
    # second run, so 3 of the 9 were already freed by the exit block: the
    # discriminator is the outer collection plus the abandoned inner one.
    assert _account("nested_header_drops", 3) == (9, 22) , (
        "returning out of the inner loop must free the inner collection and "
        "the outer one, not just whichever the exit block reached"
    );
}


test "the iterator-protocol loop owns its adapter the same way" {
    # `for (i, nd) in enumerate(mk_nodes(n))` takes `_try_iter_protocol_for`,
    # a separate lowering with the identical single-release-after-the-loop
    # shape.
    assert _account("adapter_header_drops", 3) == (3, 12) , (
        "an adapter built over a header call must be released on the early "
        "`return` path too"
    );
}


test "the header temporary is released through the frame's scope cleanup" {
    # Not merely "the leak is gone": the mechanism has to be the shared one,
    # so a future exit path gets it for free rather than needing its own
    # special case. `_emit_scope_cleanup` names its loads `cleanup.<var>`.
    body = _fn_ir("early_ret_header");
    assert "cleanup.for.coll" in body , (
        "the loop's collection slot is not in the frame's scope-cleanup walk"
    );
}


test "every plain-value answer matches the sv result" {
    sv = _sv_module();
    for name in VALUE_FNS {
        na_fn = _get(name);
        sv_fn = getattr(sv, name);
        for n in [0, 1, 2, 3, 5] {
            assert na_fn(n) == sv_fn(n) , (
                f"{name}({n}): native {na_fn(n)} != sv {sv_fn(n)}"
            );
        }
    }
}
