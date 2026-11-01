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

One struct serves every instantiation, so `Ctx[int]` puts a scalar in a
pointer slot -- stored raw it segfaults when read back as an object, and as an
option its zero payload is indistinguishable from the null that means None. A
scalar (or `str`, tuple or option) argument is therefore boxed on the way into
an erased slot and unboxed at the access site, where the static type argument
names the representation. A type argument with no box (a tagged `any` union)
is refused at the construction site. Those are the permitted outcomes: lower
correctly, or refuse loudly. Nothing in between.

Every value is additionally checked against the sv/bytecode answer for the
same fixture, since a dropped store is still well typed and still compiles.
"""

import ctypes;
import os;
import from pathlib { Path }
import from tests.support {
    KernelFixture,
    TESTS_DIR,
    compile_mir,
    compile_native,
    native_address,
    write_case
}
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
    (eng, _) = compile_native(fixture);
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


"""Every function the decision step refused in a fixture, with its reason."""
def _demotions(fixture: str) -> dict[str, str] {
    return compile_mir(fixture).demoted();
}


"""Write a snippet as its own module; return (file name, directory)."""
def _case(label: str, code: str) -> tuple[str, str] {
    path = Path(write_case(code, f"_gen_opt_{label}.jac"));
    return (path.name, str(path.parent));
}


"""The decision step's verdict on a snippet."""
def _mir_src(label: str, code: str) -> KernelFixture {
    (name, where) = _case(label, code);
    return compile_mir(name, where);
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


"""The JIT function `name` of a snippet compiled natively, as (int) -> int."""
def _lowered_fn(label: str, code: str, name: str) -> object {
    (fixture, where) = _case(label, code);
    fx = compile_mir(fixture, where);
    assert not fx.is_demoted(name) , f"{name} demoted in {label}: {fx.demoted()}";
    (eng, _) = compile_native(fixture, where);
    return _get(eng, name);
}


test "a generic archetype at a scalar boxes, and 0 stays distinct from None" {
    # One struct serves every instantiation, so a slot typed by `T` is a
    # pointer. A scalar argument is boxed into it and unboxed at the access
    # site, so `0` is a present value and only null spells None.
    _src = "obj Ctx[T] {\n"
    "    has value: (T | None) = None;\n"
    "}\n"
    "def zero(k: int) -> int {\n"
    "    c = Ctx[int](value=k - k);\n"
    "    if c.value is not None {\n"
    "        return c.value + 10;\n"
    "    }\n"
    "    return -1;\n"
    "}\n"
    "def unset(k: int) -> int {\n"
    "    c = Ctx[int]();\n"
    "    if c.value is not None {\n"
    "        return c.value;\n"
    "    }\n"
    "    return -1 - k;\n"
    "}\n"
    "def reassign(k: int) -> int {\n"
    "    c = Ctx[int](value=k);\n"
    "    c.value = k * 3;\n"
    "    v = c.value;\n"
    "    return v if v is not None else -99;\n"
    "}\n";
    assert _lowered_fn("scalar_opt", _src, "zero")(5) == 10 , "a boxed 0 read as None";
    assert _lowered_fn("scalar_opt_unset", _src, "unset")(2) == -3;
    assert _lowered_fn("scalar_opt_store", _src, "reassign")(4) == 12;
}


test "an unboxable type argument is refused, naming the instantiation" {
    # A union of unrelated by-value kinds is a tagged `any` value with no box,
    # so the erasure has no sound representation for it.
    _src = "obj Ctx[T] {\n"
    "    has value: (T | None) = None;\n"
    "}\n"
    "def five() -> int {\n"
    "    c = Ctx[int | str](value=5);\n"
    "    if c.value is not None {\n"
    "        return 1;\n"
    "    }\n"
    "    return -1;\n"
    "}\n";
    fx = _mir_src("scalar_named", _src);
    assert fx.is_demoted("five") , (
        f"the refusal must demote five() rather than fail the module: {fx.demoted()}"
    );
    assert "Ctx" in fx.reason("five") , (
        f"the refusal must name the offending instantiation: {fx.reason('five')}"
    );
}


test "a bare `T` slot at a scalar type argument boxes too" {
    # Before boxing this did not merely answer wrongly: the scalar sat in a
    # pointer slot and the read dereferenced it, so the binary segfaulted.
    f = _lowered_fn(
        "scalar_bare",
        "obj Plain[T] {\n"
        "    has value: T,\n"
        "        tag: int = 3;\n"
        "}\n"
        "def get(k: int) -> int {\n"
        "    d = Plain[int](value=k);\n"
        "    return d.value + d.tag;\n"
        "}\n",
        "get"
    );
    assert f(9) == 12;
    assert f(0) == 3;
}


test "an inferred scalar type argument boxes the same as a written one" {
    # No subscript at the call site: the checker solves `T` from the
    # argument, and the box follows the argument's own representation.
    f = _lowered_fn(
        "scalar_inferred",
        "obj Ctx[T] {\n"
        "    has value: (T | None) = None;\n"
        "}\n"
        "def go(k: int) -> int {\n"
        "    c = Ctx(value=k);\n"
        "    if c.value is not None {\n"
        "        return c.value;\n"
        "    }\n"
        "    return -1;\n"
        "}\n",
        "go"
    );
    assert f(5) == 5;
    assert f(0) == 0;
}


test "an inferred archetype type argument still lowers" {
    fx = _mir_src(
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
    assert not fx.is_demoted("go") , (
        f"the gate must not refuse an inferred type argument that is sound: {fx.demoted()}"
    );
}


test "every type parameter an erased slot can hold is boxed, not just the first" {
    # `(T | U | None)` is one erased pointer that either parameter can fill;
    # a scalar in the second parameter boxes exactly like one in the first.
    f = _lowered_fn(
        "multi_tv_scalar",
        "obj Leaf {\n"
        "    has num: int = 0;\n"
        "}\n"
        "obj Choice[T, U] {\n"
        "    has value: (T | U | None) = None,\n"
        "        tag: int = 0;\n"
        "}\n"
        "def go(k: int) -> int {\n"
        "    c = Choice[Leaf, int](value=k, tag=1);\n"
        "    if c.value is not None {\n"
        "        return c.tag;\n"
        "    }\n"
        "    return -1;\n"
        "}\n",
        "go"
    );
    assert f(0) == 1 , "a boxed 0 in the second parameter read as None";
}


test "a multi-parameter erased slot still lowers when every argument is a reference" {
    fx = _mir_src(
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
    assert not fx.is_demoted("go") , (
        "the widened check must not refuse a slot whose parameters are all "
        f"references: {fx.demoted()}"
    );
}


test "an archetype type argument is still accepted for a bare `T` slot" {
    fx = _mir_src(
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
    assert not fx.is_demoted("get") , (
        f"the gate must not refuse the erasure that is actually sound: {fx.demoted()}"
    );
}


test "a `list[T]` slot on a generic archetype stays loud" {
    # Not fixed here and not silently broken either: it is refused and
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
    fx = _mir_src("list_tv", _src);
    assert fx.is_demoted("go") , (
        f"the unlowerable container must demote its callable: {fx.demoted()}"
    );
    assert "list" in fx.reason("go") , (
        f"a list over an unsolved type parameter must keep reporting: {fx.reason('go')}"
    );
}
