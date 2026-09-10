"""Container element-type inference congruence for the native backend (jac#7967 N5).

Two properties are pinned here.

1. Adding or omitting a container element annotation must not change the
   answer. Every case in `container_elem_infer.jac` is written twice, once
   idiomatically untyped and once annotated, and the test asserts the two forms
   agree with each other AND with the sv/bytecode run of the same fixture. A
   hardcoded expected value would not catch the failure mode this exists for:
   the untyped form quietly lowering to a different element representation and
   producing a different (or invalid) result.

2. When the element type is genuinely un-inferable the backend must pick ONE
   representation and stay congruent with it -- tagged elements compared
   against unboxed peers get the peer boxed too -- or refuse the lowering with
   E5090. Silently comparing a `{tag, payload}` element against a raw i64 field
   is the outcome this forbids.

Before the fix, `container_elem_unknown.jac` and the untyped enum list both
died in the LLVM verifier with `icmp eq %"JacVal" %"list.get", 2`, and
`typed_float_from_int_literal` returned 0 instead of 250 because the backend
took the first element's lowered type (i64, from the literal `1`) in place of
the checker's `float`.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile a fixture through the native pipeline and return (engine, LLVM IR)."""
def native_compile(fixture: str) -> tuple[object, str] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, str(ir.gen.llvm_ir));
}

"""Compile a fixture through the native pipeline and return its JIT engine."""
def native_engine(fixture: str) -> object {
    return native_compile(fixture)[0];
}

"""Call a no-argument int-returning function out of the JIT engine."""
def native_call(eng: any, name: str) -> int {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}

"""Run the same fixture through the sv pathway and return its module globals."""
def sv_funcs(fixture: str) -> dict {
    path = str(os.path.join(FIXTURES, fixture));
    prog = JacProgram();
    ir = prog.compile(
        file_path=path, options=CompileOptions(default_codespace='server')
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"sv compilation errors in {fixture}: {errors}";
    ns: dict = {};
    exec(compile(ir.gen.py, path, "exec"), ns);
    return ns;
}

"""Compile a snippet through the native pipeline and return the program."""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES, f"_elem_infer_{label}.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return prog;
}

"""Like `compile_na_inline`, but also hand back the compiled module so a
granular demotion (epic #8201) is observable through the native layout."""
def compile_na_inline_ir(label: str, code: str) -> tuple {
    path = os.path.join(FIXTURES, f"_elem_infer_{label}.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return (prog, ir, );
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

glob PAIRS: list[tuple[str, str]] = [
         ("untyped_field_cmp", "typed_field_cmp"),
         ("untyped_iter_sum", "typed_iter_sum"),
         ("untyped_membership", "typed_membership"),
         ("untyped_index_len", "typed_index_len"),
         ("untyped_literal_sum", "typed_literal_sum"),
         ("untyped_enum_pick", "typed_enum_pick"),
         ("untyped_enum_scan", "typed_enum_scan"),
         ("untyped_float_from_float_literal", "typed_float_from_int_literal")
     ];

test "container elem inference: the annotation cannot change the answer" {
    eng = native_engine("container_elem_infer.jac");
    sv = sv_funcs("container_elem_infer.jac");
    for (untyped, typed) in PAIRS {
        na_u = native_call(eng, untyped);
        na_t = native_call(eng, typed);
        assert na_u == na_t , (
            f"native {untyped}() == {na_u} but {typed}() == {na_t}: "
            + "omitting the element annotation changed the lowering"
        );
        sv_u = int(sv[untyped]());
        sv_t = int(sv[typed]());
        assert sv_u == sv_t , f"sv {untyped}() == {sv_u} but {typed}() == {sv_t}";
        assert na_u == sv_u , (f"native {untyped}() == {na_u} but sv gives {sv_u}");
        assert na_t == sv_t , f"native {typed}() == {na_t} but sv gives {sv_t}";
    }
}

test "container elem inference: untyped enum list is not boxed away from congruence" {
    (eng, llvm) = native_compile("container_elem_infer.jac");
    assert native_call(eng, "untyped_enum_pick") == 1 , (
        "c[1] == Color.GREEN on an untyped enum list"
    );
    assert native_call(eng, "untyped_enum_scan") == 1 , (
        "exactly one Color.BLUE in the untyped enum list"
    );
    # Every container in this fixture has an element type the checker knows,
    # so none of them may fall back to tagged {tag, payload} storage. The
    # untyped enum list is the one that used to: its inferred element type is
    # a union of enum-member types, which the backend could not lower.
    assert "List.jacval" not in llvm , (
        "a container with a known element type fell back to tagged storage"
    );
    assert "List.f64" in llvm , "list[float] must keep unboxed f64 storage";
}

test "container elem inference: list[float] keeps f64 storage past an int literal" {
    eng = native_engine("container_elem_infer.jac");
    assert native_call(eng, "typed_float_from_int_literal") == 250 , (
        "`list[float] = [1, 2.5]` must store 2.5, not truncate to i64 storage"
    );
}

test "un-inferable elem type: tagged elements still compare congruently" {
    eng = native_engine("container_elem_unknown.jac");
    sv = sv_funcs("container_elem_unknown.jac");
    for fn in [
        "mixed_elem_eq",
        "mixed_elem_eq_miss",
        "mixed_elem_ne",
        "mixed_elem_lt",
        "mixed_elem_str_eq"
    ] {
        na_v = native_call(eng, fn);
        sv_v = int(sv[fn]());
        assert na_v == sv_v , f"native {fn}() == {na_v} but sv gives {sv_v}";
    }
}

test "un-inferable elem type: ordering a tagged element checks its tag at runtime" {
    eng = native_engine("container_elem_unknown.jac");
    sv = sv_funcs("container_elem_unknown.jac");
    # Ordering has no congruent answer the way equality does: boxing both sides
    # makes a tag mismatch compare unequal, which is what sv does for `==`, but
    # `"seven" < 9` has no order at all. CPython raises TypeError, so native
    # must raise TypeError too rather than ordering on the payload bits.
    for fn in [
        "mixed_ord_str_vs_int",
        "mixed_ord_str_vs_float",
        "mixed_ord_int_vs_int",
        "mixed_ord_int_vs_float",
        "mixed_ord_float_vs_int",
        "mixed_ord_float_vs_int_false"
    ] {
        na_v = native_call(eng, fn);
        sv_v = int(sv[fn]());
        assert na_v == sv_v , f"native {fn}() == {na_v} but sv gives {sv_v}";
    }
    # -1 is the `except TypeError` arm of the fixture, so agreeing on -1 pins
    # the exception TYPE on both pathways, not merely that something raised.
    assert native_call(eng, "mixed_ord_str_vs_int") == -1 , (
        "ordering a str-tagged element against an int must raise TypeError"
    );
    assert native_call(eng, "mixed_ord_str_vs_float") == -1 , (
        "ordering a str-tagged element against a float must raise TypeError"
    );
    # The numerically-tagged cases must stay green: the tag check may not tax
    # the ordering that legitimately works.
    assert native_call(eng, "mixed_ord_int_vs_int") == 1 , "7 < 9";
    assert native_call(eng, "mixed_ord_int_vs_float") == 1 , "7 < 9.5";
    # A float-tagged payload must be read as a double, not as its raw bits.
    assert native_call(eng, "mixed_ord_float_vs_int") == 1 , "2.5 < 9";
    assert native_call(eng, "mixed_ord_float_vs_int_false") == 0 , "not 20.5 < 9";
}

test "un-inferable elem type: equality against an unboxable peer is refused" {
    # The equality branch boxes the unboxed peer, but _box_to_jacval only
    # represents scalars and pointers. An aggregate peer -- here a by-value
    # tuple literal -- has no tagged representation, and its old catch-all
    # stored tag=0/payload=0, so `x[0] == (1, 2)` compared a real element
    # against a null-ish tagged value and could answer True for `0 == (0, 0)`.
    # The guard is now symmetric with the ordering branch: unboxable peers
    # refuse to lower, and the refusal demotes the owning function to a seam.
    (prog, ir) = compile_na_inline_ir(
        "eq_tuple",
        "def f -> int {\n"
            + "    x = [];\n"
            + "    x.append(7);\n"
            + "    x.append(\"seven\");\n"
            + "    if x[0] == (1, 2) {\n"
            + "        return 1;\n"
            + "    }\n"
            + "    return 0;\n"
            + "}\n"
    );
    assert not prog.errors_had , (
        "the unboxable-peer refusal is owned by f(), which must demote, got "
        + f"{[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "f" not in ir.gen.native_layout.functions , (
        "the refused comparison's function must be demoted out of the layout, "
        + "never answer True for 0 == (0, 0)"
    );
}

test "un-inferable elem type: an unorderable mixed comparison is refused, not guessed" {
    (prog, ir) = compile_na_inline_ir(
        "order_str",
        "def f() -> int {\n"
            + "    x = [];\n"
            + "    x.append(7);\n"
            + "    x.append(\"seven\");\n"
            + "    if x[1] < \"zebra\" {\n"
            + "        return 1;\n"
            + "    }\n"
            + "    return 0;\n"
            + "}\n"
    );
    assert not prog.errors_had , (
        "the unorderable-comparison refusal is owned by f(), which must "
        + f"demote, got {[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "f" not in ir.gen.native_layout.functions , (
        "the refused comparison's function must be demoted out of the layout, "
        + "never guessed"
    );
}

test "isinstance-narrowed any container unboxes at the boxed-boundary flavor" {
    # jac#8052: `isinstance(x, list)` on an `any` narrows to the BARE `list`,
    # whose default lowering is the unboxed i64 flavor; the narrowed unbox
    # must instead take the canonical heterogeneous layout every any-consume
    # site assumes, or the value dies at its `list[any]` destination.
    eng = native_engine("container_any_narrow.jac");
    sv = sv_funcs("container_any_narrow.jac");
    for fn in [
        "narrowed_list_miss",
        "narrowed_list_consume",
        "narrowed_dict_consume",
        "narrowed_dict_miss"
    ] {
        na_v = native_call(eng, fn);
        sv_v = int(sv[fn]());
        assert na_v == sv_v , f"native {fn}() == {na_v} but sv gives {sv_v}";
    }
    # Pin the values too, so the two pathways cannot agree on a shared wrong
    # answer: 3 elements, first == 7, int elements sum to 11; keys "ab"/"c"
    # total 3 chars across 2 entries.
    assert native_call(eng, "narrowed_list_consume") == 3081 , (
        "narrowed list consume must read len, index, and elements congruently"
    );
    assert native_call(eng, "narrowed_dict_consume") == 32 , (
        "narrowed dict consume must iterate keys and read len congruently"
    );
    assert native_call(eng, "narrowed_list_miss") == -1 , "non-list any misses";
    assert native_call(eng, "narrowed_dict_miss") == -1 , "non-dict any misses";
}
