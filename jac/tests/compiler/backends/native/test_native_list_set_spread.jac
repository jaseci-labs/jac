"""A `*` spread in a list or set display, checked by value.

A spread stands for a runtime number of elements, so a display containing
one cannot be built by appending `values` one for one. Native used to walk
`values` and append whatever lowered: the first element's failure was
propagated, but every later element was appended under an `if val is not
None` with no `else`, so a spread anywhere but the front vanished. The
container came out short, the program kept running, and nothing was
written to stderr -- a wrong answer no seam coverage counting E5092 could
see.

So every assertion here reads the container back as a number that encodes
both its length and its contents, and every function is additionally
checked against the sv/bytecode result of the same fixture, the parity
idiom `test_native_union_slot_ops` uses. A silently short container fails
the value check; a spread shape that cannot lower has to fail loudly
instead, which the guardrail test at the bottom pins.

Refs #8070
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "list_set_spread.jac",
     LIST_FNS = [
         "tail_spread",
         "mid_spread",
         "head_spread",
         "multi_spread",
         "only_spread",
         "only_two_spreads",
         "empty_spread",
         "empty_head_spread",
         "literal_spread",
         "nested_spread",
         "dynamic_spread",
         "declared_spread",
         "str_spread",
         "float_spread",
         "spread_then_mutate",
         "glob_spread",
         "call_arg_spread",
         "compr_spread",
         "source_survives"
     ],
     SET_FNS = [
         "set_tail",
         "set_head",
         "set_mid",
         "set_multi",
         "set_only",
         "set_dedup",
         "set_empty_spread",
         "set_from_set",
         "list_from_set"
     ],
     FLAGS = [0, 1, 2, 3];


"""Compile the fixture natively and return the JIT engine."""
def _compile -> object {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, FIXTURE)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {FIXTURE}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {FIXTURE}";
    gi_addr = native_address(eng, "__jac_glob_init");
    if gi_addr {
        ctypes.CFUNCTYPE(None)(gi_addr)();
    }
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(eng: any, name: str) -> object {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import the same fixture through the sv/bytecode pathway."""
def _sv_module -> object {
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


"""Compile a snippet natively and hand back the program for error inspection."""
def _compile_inline(label: str, code: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, f"_spread_{label}.jac"),
        use_str=code,
        options=native_force_opts()
    );
    return prog;
}


"""True if the program emitted at least one alert carrying the given code."""
def _has_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}


test "a spread anywhere in a list display contributes all of its elements" {
    eng = _compile();
    expect = {
        "tail_spread": 1123,
        "mid_spread": 11239,
        "head_spread": 1239,
        "multi_spread": 11236457,
        "only_spread": 123,
        "only_two_spreads": 12345
    };
    for (name, want) in expect.items() {
        got = _get(eng, name)(0);
        assert got == want , (
            f"{name}: got {got}, want {want} -- a shorter fold means elements "
            f"were dropped from the display"
        );
    }
}


test "an empty spread contributes nothing and disturbs nothing" {
    eng = _compile();
    assert _get(eng, "empty_spread")(0) == 112 , "an empty middle spread";
    assert _get(eng, "empty_head_spread")(0) == 14 , (
        "an empty leading spread leaves no element to seed storage from"
    );
    assert _get(eng, "set_empty_spread")(0) == 1064 , "an empty spread into a set";
}


test "a spread source that is a literal, a spread result, or runtime-sized" {
    eng = _compile();
    assert _get(eng, "literal_spread")(0) == 11234 , "the operand is itself a display";
    assert _get(eng, "nested_spread")(0) == 1023 , "spreading a spread's result";
    dyn = _get(eng, "dynamic_spread");
    assert dyn(0) == 178 , "an empty runtime source";
    assert dyn(1) == 1718 , "a one-element runtime source";
    assert dyn(3) == 171238 , "a three-element runtime source";
}


test "a spread lowers wherever a display can appear" {
    eng = _compile();
    assert _get(eng, "glob_spread")(0) == 11234 , (
        "a module-level initializer, whose copy loop lands in glob init"
    );
    assert _get(eng, "call_arg_spread")(0) == 11234 , (
        "a display passed straight to a call"
    );
    assert _get(eng, "compr_spread")(0) == 133 , (
        "a display as a comprehension's output expression"
    );
}


test "spread elements agree with the display's element storage" {
    eng = _compile();
    assert _get(eng, "declared_spread")(0) == 11234 , (
        "a declared list[int] element type"
    );
    assert _get(eng, "str_spread")(0) == 11234 , (
        "pointer-flavoured elements must survive the copy"
    );
    assert _get(eng, "float_spread")(0) == 175 , "float-flavoured elements";
}


test "the spread copies its source rather than aliasing it" {
    eng = _compile();
    assert _get(eng, "spread_then_mutate")(0) == 11234 , (
        "appending after the display must not disturb the copied elements"
    );
    assert _get(eng, "source_survives")(0) == 1124023 , (
        "mutating the result must leave the spread source intact"
    );
}


test "a spread anywhere in a set display contributes all of its elements" {
    eng = _compile();
    expect = {
        "set_tail": 3014,
        "set_head": 3028,
        "set_mid": 4046,
        "set_multi": 5062,
        "set_only": 2012,
        "set_dedup": 2006,
        "set_from_set": 3014,
        "list_from_set": 2013
    };
    for (name, want) in expect.items() {
        got = _get(eng, name)(0);
        assert got == want , (
            f"{name}: got {got}, want {want} -- the low digits are a membership "
            f"mask and the high digits the length"
        );
    }
}


test "every spread form agrees with the sv result" {
    eng = _compile();
    sv = _sv_module();
    for name in LIST_FNS + SET_FNS {
        na_fn = _get(eng, name);
        sv_fn = getattr(sv, name);
        for flag in FLAGS {
            assert na_fn(flag) == sv_fn(flag) , (
                f"{name}({flag}): native {na_fn(flag)} != sv {sv_fn(flag)}"
            );
        }
    }
}


test "a spread that cannot lower refuses loudly instead of dropping" {
    cases = {
        "dict_src": "def f -> int {\n    d: dict[str, int] = {\"a\": 1};\n"
            + "    c = [1, *d];\n    return len(c);\n}\n",
        "str_src": "def f -> int {\n    s = \"ab\";\n    c = [1, *s];\n"
            + "    return len(c);\n}\n",
        "set_dict_src": "def f -> int {\n    d: dict[str, int] = {\"a\": 1};\n"
            + "    s = {1, *d};\n    return len(s);\n}\n"
    };
    for (label, code) in cases.items() {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, f"_spread_{label}.jac"),
            use_str=code,
            options=native_force_opts()
        );
        assert not prog.errors_had , (
            f"{label}: the spread refusal is owned by f(), which must demote "
            f"to a seam, got: {[str(e) for e in prog.errors_had]}"
        );
        assert ir.gen.native_layout is not None , (
            f"{label}: whole-module native compile aborted"
        );
        assert "f" not in ir.gen.native_layout.functions , (
            f"{label}: a spread native cannot lower must demote its function "
            f"out of the native layout, never silently build a shorter "
            f"container"
        );
    }
}
