"""A `(T | None)` slot on a generic archetype: stored, or refused out loud.

A generic archetype is laid out once for all of its instantiations, so a slot
typed by the class's type parameter is a bare pointer. `(T | None)` is that
same pointer with null spelling None, but it used to land in the *foreign
optional* bucket -- the one for an option over a type the native lane cannot
model -- and a foreign slot is one the constructor is forbidden to fill. The
argument was dropped, the declared default with it, and the slot read back as
None however it had been constructed. Assigning the field afterwards worked,
so nothing crashed and nothing complained: the shape compiled and answered
wrongly, which is the class of defect this file exists to close.

The erasure is only sound while the type argument is a reference. One struct
serves every instantiation, so `Ctx[int]` would put a scalar in a pointer
slot -- read back as an object it segfaults, and as an option its zero payload
is indistinguishable from the null that means None. Those instantiations are
refused at the construction site instead, so the two halves below are the two
permitted outcomes: lower correctly at an archetype type argument, refuse
loudly at a scalar one. Nothing in between.

Every value is additionally checked against the sv/bytecode answer for the
same fixture, since a dropped store is still well typed and still compiles.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "generic_optional_field.jac",
     XMOD = "generic_optional_xmod_main.jac",
     XMOD_FNS = ["local_built", "lib_built", "lib_name_len"],
     ALL_FNS = [
         "ctor_num",
         "ctor_tag",
         "assign_num",
         "default_none",
         "explicit_none",
         "ctor_name_len",
         "method_num",
         "overwrite_num",
         "returned_num",
         "param_num",
         "nongen_zero",
         "nongen_num"
     ],
     FLAGS = [0, 1, 2];


"""Compile a fixture natively; a demotion here is the bug, not a symptom."""
def _compile(fixture: str) -> object {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(eng: any, name: str) -> object {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import a fixture through the sv/bytecode pathway."""
def _sv_module(fixture: str) -> object {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=fixture[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , f"sv import of {fixture} produced no module";
    return mods[0];
}


"""Every E5092 the native compile of a fixture reported."""
def _demotions(fixture: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    return [
        d.pretty_print()
        for d in (prog.errors_had or [])
        if d.code is not None and d.code.code == "E5092"
    ];
}


"""Compile a snippet natively and hand back the program and its IR."""
def _compile_src(label: str, code: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, f"_gen_opt_{label}.jac"),
        use_str=code,
        options=native_force_opts()
    );
    return (prog, ir);
}


"""The coverage seam reasons recorded while compiling a snippet."""
def _seam_reasons(label: str, code: str) -> list[str] {
    path = os.path.join(FIXTURES, f"_gen_opt_{label}.jac");
    prog = JacProgram();
    na_coverage_begin();
    try {
        prog.compile(file_path=path, use_str=code, options=native_force_opts());
    } finally {
        coverage = na_coverage_end();
    }
    out: list[str] = [];
    for rec in coverage.values() {
        for s in (rec.get("seams") or []) {
            out.append(str(s));
        }
    }
    return out;
}


test "an optional erased slot lowers rather than demoting" {
    assert not _demotions(FIXTURE) , (
        f"a (T | None) slot on a generic archetype did not lower: "
        f"{_demotions(FIXTURE)}"
    );
}


test "the constructor argument for an optional erased slot survives" {
    f = _get(_compile(FIXTURE), "ctor_num");
    assert f(2) == 32 , (
        "the Leaf handed to the constructor must be what the slot holds; "
        "a dropped store reads back as None and answers -1"
    );
    assert f(0) == 30 , "the same store with a different payload";
}


test "the slot after the erased option keeps its own offset" {
    f = _get(_compile(FIXTURE), "ctor_tag");
    assert f(0) == 7 , (
        "a mis-sized option would shift `tag` and return part of the "
        "pointer instead of 7"
    );
}


test "constructing and assigning the same slot agree" {
    eng = _compile(FIXTURE);
    ctor = _get(eng, "ctor_num");
    assign = _get(eng, "assign_num");
    for flag in FLAGS {
        assert ctor(flag) == assign(flag) , (
            f"ctor_num({flag}) == {ctor(flag)} but assign_num({flag}) == "
            f"{assign(flag)}; the two write paths must reach one slot"
        );
    }
}


test "an untouched optional slot is None, and so is an explicit one" {
    eng = _compile(FIXTURE);
    d = _get(eng, "default_none");
    e = _get(eng, "explicit_none");
    assert d(0) == -1 , "the declared `= None` default stays None";
    assert e(1) == -2 , "a None passed by name stays None";
}


test "a str payload reads back whole through the erased option" {
    f = _get(_compile(FIXTURE), "ctor_name_len");
    assert f(0) == 5 , "'abcde' behind the optional erased slot";
}


test "the option reads off `self` inside a method" {
    f = _get(_compile(FIXTURE), "method_num");
    assert f(1) == 21 , "`self.cell.value.num` through a holder's method";
    assert f(0) == -1 , "the unset holder takes the else arm";
}


test "a store over a constructor-set slot is what the next read sees" {
    f = _get(_compile(FIXTURE), "overwrite_num");
    assert f(1) == 61 , "the assigned Leaf, not the constructed one";
    assert f(0) == 1 , "no assignment: the constructed Leaf";
}


test "the option crosses a return type and a parameter annotation" {
    eng = _compile(FIXTURE);
    r = _get(eng, "returned_num");
    p = _get(eng, "param_num");
    assert r(0) == 141 , "70 + 71 through the returned Ctx";
    assert p(0) == 86 , "80 + 6 through the annotated parameter";
}


test "the non-generic control still answers for the payload zero" {
    eng = _compile(FIXTURE);
    z = _get(eng, "nongen_zero");
    n = _get(eng, "nongen_num");
    assert z(0) == 0 , (
        "an `(int | None)` field holding 0 is not None; it is tag-and-payload, "
        "so the zero payload must not read as the absent tag"
    );
    assert n(1) == 41 , "the same control with a non-aliasing payload";
}


test "every optional erased-slot answer agrees with sv" {
    eng = _compile(FIXTURE);
    sv = _sv_module(FIXTURE);
    for name in ALL_FNS {
        na_fn = _get(eng, name);
        sv_fn = getattr(sv, name);
        for flag in FLAGS {
            assert na_fn(flag) == sv_fn(flag) , (
                f"{name}({flag}): native {na_fn(flag)} != sv {sv_fn(flag)}"
            );
        }
    }
}


test "an imported generic archetype's optional slot stores on both sides" {
    assert not _demotions(XMOD) , (
        f"cross-module optional erased slot did not lower: {_demotions(XMOD)}"
    );
    eng = _compile(XMOD);
    sv = _sv_module(XMOD);
    for name in XMOD_FNS {
        na_fn = _get(eng, name);
        sv_fn = getattr(sv, name);
        for flag in FLAGS {
            assert na_fn(flag) == sv_fn(flag) , (
                f"{name}({flag}): native {na_fn(flag)} != sv {sv_fn(flag)}"
            );
        }
    }
}


test "a generic archetype instantiated at a scalar is refused, not lowered" {
    (prog, ir) = _compile_src(
        "scalar_opt",
        "obj Ctx[T] {\n"
        "    has value: (T | None) = None;\n"
        "}\n"
        "def zero() -> int {\n"
        "    c = Ctx[int](value=0);\n"
        "    if c.value is not None {\n"
        "        return c.value;\n"
        "    }\n"
        "    return -1;\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"the refusal is owned by zero(), which must demote to a seam: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "zero" not in ir.gen.native_layout.functions , (
        "Ctx[int] puts a scalar in an erased pointer slot, where 0 is "
        "indistinguishable from the null that spells None; it must demote, "
        "never lower"
    );
}


test "the scalar refusal names the archetype and the type argument" {
    msgs = _seam_reasons(
        "scalar_named",
        "obj Ctx[T] {\n"
        "    has value: (T | None) = None;\n"
        "}\n"
        "def five() -> int {\n"
        "    c = Ctx[int](value=5);\n"
        "    if c.value is not None {\n"
        "        return c.value;\n"
        "    }\n"
        "    return -1;\n"
        "}\n"
    );
    assert any([("Ctx[int]" in m) for m in msgs]) , (
        f"the seam reason must name the offending instantiation: {msgs}"
    );
}


test "a bare `T` slot at a scalar type argument is refused too" {
    # Before the gate this did not merely answer wrongly: the scalar sat in
    # a pointer slot and the read dereferenced it, so the binary segfaulted.
    (prog, ir) = _compile_src(
        "scalar_bare",
        "obj Plain[T] {\n"
        "    has value: T,\n"
        "        tag: int = 3;\n"
        "}\n"
        "def get() -> int {\n"
        "    d = Plain[int](value=9);\n"
        "    return d.tag;\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"the refusal must demote get() rather than fail the module: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "get" not in ir.gen.native_layout.functions , (
        "Plain[int] stores a scalar in an erased pointer slot; it must demote"
    );
}


test "an inferred scalar type argument is refused the same as a written one" {
    # No subscript at the call site: the checker solves `T` from the
    # argument, so the gate has to read the solved instance type rather
    # than the spelling.
    (prog, ir) = _compile_src(
        "scalar_inferred",
        "obj Ctx[T] {\n"
        "    has value: (T | None) = None;\n"
        "}\n"
        "def go() -> int {\n"
        "    c = Ctx(value=5);\n"
        "    if c.value is not None {\n"
        "        return c.value;\n"
        "    }\n"
        "    return -1;\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"the refusal must demote go() rather than fail the module: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "go" not in ir.gen.native_layout.functions , (
        "an inferred Ctx[int] is the same unsound erasure as a written one"
    );
}


test "an inferred archetype type argument still lowers" {
    (prog, ir) = _compile_src(
        "ref_inferred",
        "obj Leaf {\n"
        "    has num: int = 0;\n"
        "}\n"
        "obj Ctx[T] {\n"
        "    has value: (T | None) = None;\n"
        "}\n"
        "def go() -> int {\n"
        "    c = Ctx(value=Leaf(num=5));\n"
        "    if c.value is not None {\n"
        "        return c.value.num;\n"
        "    }\n"
        "    return -1;\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"an inferred reference type argument must lower: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "go" in ir.gen.native_layout.functions , (
        "the gate must not refuse an inferred type argument that is sound"
    );
}


test "every type parameter an erased slot can hold is checked, not just the first" {
    # `(T | U | None)` is one erased pointer that either parameter can fill,
    # so checking only `T` let `Choice[Leaf, int]` through and the scalar in
    # the pointer slot segfaulted on the read.
    (prog, ir) = _compile_src(
        "multi_tv_scalar",
        "obj Leaf {\n"
        "    has num: int = 0;\n"
        "}\n"
        "obj Choice[T, U] {\n"
        "    has value: (T | U | None) = None,\n"
        "        tag: int = 0;\n"
        "}\n"
        "def go() -> int {\n"
        "    c = Choice[Leaf, int](value=7, tag=1);\n"
        "    if c.value is not None {\n"
        "        return 1;\n"
        "    }\n"
        "    return -1;\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"the refusal must demote go() rather than fail the module: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "go" not in ir.gen.native_layout.functions , (
        "a scalar in the second type parameter is the same unsound erasure "
        "as one in the first"
    );
}


test "a multi-parameter erased slot still lowers when every argument is a reference" {
    (prog, ir) = _compile_src(
        "multi_tv_ref",
        "obj Leaf {\n"
        "    has num: int = 0;\n"
        "}\n"
        "obj Other {\n"
        "    has num: int = 0;\n"
        "}\n"
        "obj Choice[T, U] {\n"
        "    has value: (T | U | None) = None,\n"
        "        tag: int = 0;\n"
        "}\n"
        "def go() -> int {\n"
        "    c = Choice[Leaf, Other](value=Leaf(num=7), tag=1);\n"
        "    if c.value is not None {\n"
        "        return c.tag;\n"
        "    }\n"
        "    return -1;\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"two reference type arguments are both sound and must lower: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "go" in ir.gen.native_layout.functions , (
        "the widened check must not refuse a slot whose parameters are all "
        "references"
    );
}


test "an archetype type argument is still accepted for a bare `T` slot" {
    (prog, ir) = _compile_src(
        "ref_bare",
        "obj Leaf {\n"
        "    has num: int = 0;\n"
        "}\n"
        "obj Plain[T] {\n"
        "    has value: T,\n"
        "        tag: int = 3;\n"
        "}\n"
        "def get() -> int {\n"
        "    d = Plain[Leaf](value=Leaf(num=9));\n"
        "    return d.value.num + d.tag;\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"a reference type argument is the sound case and must lower: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "get" in ir.gen.native_layout.functions , (
        "the gate must not refuse the erasure that is actually sound"
    );
}


test "a `list[T]` slot on a generic archetype stays loud" {
    # Not fixed here and not silently broken either: it reports E5092 and
    # demotes, which is the outcome this file's bar demands of anything the
    # erasure cannot represent.
    _src = "obj Leaf {\n"
    "    has num: int = 0;\n"
    "}\n"
    "obj Bag[T] {\n"
    "    has items: list[T] = [];\n"
    "}\n"
    "def go() -> int {\n"
    "    b = Bag[Leaf]();\n"
    "    b.items.append(Leaf(num=4));\n"
    "    return len(b.items);\n"
    "}\n";
    (prog, ir) = _compile_src("list_tv", _src);
    msgs = _seam_reasons("list_tv_coverage", _src);
    assert any([("list[T]" in m) for m in msgs]) , (
        f"a list over an unsolved type parameter must keep reporting: {msgs}"
    );
    _layout = ir.gen.native_layout;
    assert _layout is None or "go" not in _layout.functions , (
        "the unlowerable container must demote its callable"
    );
}
