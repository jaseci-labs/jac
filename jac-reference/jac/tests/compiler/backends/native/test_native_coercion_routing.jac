"""Congruence tests for optional coercion at call and assignment seams (N2).

`NaIRGenPass._coerce_type` implements optional wrapping and checked
unwrapping. Three use sites did not route through it: method call
arguments on the primitive dispatch path, method receivers, and
tuple-unpack stores. The tests whose names begin "primitive call
argument", "call receiver" and "unpack store" write the idiomatic jac
those seams used to reject.

The tests named "user obj call argument" and "primitive call argument:
element wrap" pin coercions that already worked before that fix -- the
first through the coercion loop against the callee's declared LLVM
signature, the second through the list emitter's own element-type
coercion. They are kept because they are cheap native-vs-sv congruence
coverage, not because they pin the new routing.

Every test asserts the native result equals the result of the same
fixture run through the sv/bytecode pathway.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }
import jaclang;

import from jaclang.runtime.runtime { JacRuntime }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Import the same fixture through the sv/bytecode pathway."""
def sv_module -> any {
    return JacRuntime.jac_import(
        target="coercion_routing", base_path=FIXTURES, override_name="cr_sv_mod"
    )[0];
}

test "user obj call argument: a plain value wraps into an optional parameter" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_wrap", ctypes.c_int64, ctypes.c_int64);
    for n in [3, 0, -4] {
        assert f(n) == sv.arg_wrap(n) , (
            f"arg_wrap({n}): native {f(n)} != sv {sv.arg_wrap(n)}"
        );
    }
    assert f(3) == 13 , "base 10 + 3 through the int|None parameter";
}

test "user obj call argument: an explicit None reaches an optional parameter" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_wrap_none", ctypes.c_int64);
    assert f() == sv.arg_wrap_none() , f"arg_wrap_none: {f()} != {sv.arg_wrap_none()}";
    assert f() == -1 , "None selects the None branch";
}

test "user obj call argument: a narrowed optional unwraps into a plain parameter" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_unwrap", ctypes.c_int64, ctypes.c_int64);
    for n in [4, 0] {
        assert f(n) == sv.arg_unwrap(n) , (
            f"arg_unwrap({n}): native {f(n)} != sv {sv.arg_unwrap(n)}"
        );
    }
    assert f(4) == 18 , "base 10 + 4 * 2 after the unwrap";
    assert f(0) == -1 , "the None branch still wins";
}

test "primitive call argument: a narrowed optional list unwraps for extend" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_unwrap_container", ctypes.c_int64, ctypes.c_int64);
    for flag in [1, 0] {
        assert f(flag) == sv.arg_unwrap_container(flag) , (
            f"arg_unwrap_container({flag}): native {f(flag)} != "
            f"sv {sv.arg_unwrap_container(flag)}"
        );
    }
    assert f(1) == 446 , "extend copies all three elements";
    assert f(0) == 1 , "the None guard returns the untouched length";
}

test "primitive call argument: a narrowed optional str unwraps for startswith" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_unwrap_str", ctypes.c_int64, ctypes.c_int64);
    for flag in [1, 0] {
        assert f(flag) == sv.arg_unwrap_str(flag) , (
            f"arg_unwrap_str({flag}): native {f(flag)} != sv {sv.arg_unwrap_str(flag)}"
        );
    }
    assert f(1) == 1 , "'abcdef'.startswith('abc') after the unwrap";
    assert f(0) == -1 , "the None guard returns early";
}

test "primitive call argument: a narrowed optional list unwraps for str.join" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_join_unwrap", ctypes.c_int64, ctypes.c_int64);
    for flag in [1, 0] {
        assert f(flag) == sv.arg_join_unwrap(flag) , (
            f"arg_join_unwrap({flag}): native {f(flag)} != "
            f"sv {sv.arg_join_unwrap(flag)}"
        );
    }
    assert f(1) == 5 , "len('ab-cd') after the unwrap";
    assert f(0) == -1 , "the None guard returns early";
}

test "primitive call argument: element wrap into an optional-element list" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_wrap_elem", ctypes.c_int64, ctypes.c_int64);
    for n in [2, 5] {
        assert f(n) == sv.arg_wrap_elem(n) , (
            f"arg_wrap_elem({n}): native {f(n)} != sv {sv.arg_wrap_elem(n)}"
        );
    }
    assert f(2) == 32 , "a plain str wraps into the list's str|None element slot";
}

test "call receiver: an optional list receiver unwraps for append" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "opt_list_receiver", ctypes.c_int64, ctypes.c_int64);
    for n in [2, 9] {
        assert f(n) == sv.opt_list_receiver(n) , (
            f"opt_list_receiver({n}): native {f(n)} != sv {sv.opt_list_receiver(n)}"
        );
    }
    assert f(2) == 212 , "two appends land: len 2, [1, 2]";
}

test "call receiver: a narrowed optional list receiver still takes both branches" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "opt_list_receiver_guarded", ctypes.c_int64, ctypes.c_int64);
    for flag in [3, 0] {
        assert f(flag) == sv.opt_list_receiver_guarded(flag) , (
            f"opt_list_receiver_guarded({flag}): native {f(flag)} != "
            f"sv {sv.opt_list_receiver_guarded(flag)}"
        );
    }
    assert f(3) == 73 , "appends land on the narrowed receiver";
    assert f(0) == -1 , "the None guard still returns early";
}

test "unpack store: plain elements wrap into optional-typed targets" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "unpack_wrap", ctypes.c_int64, ctypes.c_int64);
    for n in [3, 7] {
        assert f(n) == sv.unpack_wrap(n) , (
            f"unpack_wrap({n}): native {f(n)} != sv {sv.unpack_wrap(n)}"
        );
    }
    assert f(3) == 34 , "(a, b) = (3, 4) through int|None targets";
}

test "unpack store: optional elements unwrap into plain targets" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "unpack_unwrap", ctypes.c_int64, ctypes.c_int64);
    for n in [5, 1] {
        assert f(n) == sv.unpack_unwrap(n) , (
            f"unpack_unwrap({n}): native {f(n)} != sv {sv.unpack_unwrap(n)}"
        );
    }
    assert f(5) == 56 , "(p, q) = (5, 6) after the unwrap";
}
