"""`isinstance` against an enum class, with a union operand.

An enum member boxes as an int, so it carries jacval tag 0, and the check
lowers to a tag compare exactly when the operand's static union gives the
named enum sole ownership of that tag. `_enum_union_tags` decides that, and
it decided it by asking each union member `m.is_enum_class` -- the *uncalled*
method, which is a bound method object and therefore always truthy. Every
member then classified as an enum owning tag 0, the sole-ownership test found
a clash in every union with two or more members, and the tag path never fired
on a union. It looked green only because a non-union operand yields a single
row with nothing to clash against, which is the shape it was validated on.

Everything here is asserted by value through the JIT, not by seam count: a
wrong classification either refuses a union it should lower (the positive
tests below stop resolving) or answers a tag compare it has no right to (the
clash test below stops being refused). A seam count would pass for the wrong
reason in both directions.

Refs #8067, #8039
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    compile_native,
    get_func,
    has_error_code,
    native_force_opts
}
import jaclang;

import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "an enum arm over an enum/object/None union answers by tag" {
    (eng, _) = compile_native("isinstance_enum_union.jac");
    f = get_func(eng, "chk_enum", ctypes.c_bool, ctypes.c_int64);
    assert f(1) is True , "an enum member must match its own enum class";
    assert f(2) is False , "an object must not match the enum class";
    assert f(0) is False , "None is an instance of nothing";
}

test "the object arm of the same union is unaffected by the enum member" {
    (eng, _) = compile_native("isinstance_enum_union.jac");
    f = get_func(eng, "chk_node", ctypes.c_bool, ctypes.c_int64);
    assert f(2) is True , "the object must match its own archetype";
    assert f(1) is False , (
        "an enum member must not match an archetype -- its payload is an "
        "ordinal, so a vtable walk over it would read garbage"
    );
    assert f(0) is False , "None is an instance of nothing";
}

test "UniScopeNode.insert's access-spec resolution answers correctly" {
    (eng, _) = compile_native("isinstance_enum_union.jac");
    f = get_func(eng, "resolve_access", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 1 , "a bare Access member resolves to itself (PUBLIC)";
    assert f(2) == 2 , "a node resolves through its access_type (PROTECTED)";
    assert f(0) == 0 , "an absent spec falls back to the default (PRIVATE)";
}

test "the same resolution with the union declared on the parameter" {
    # The two union shapes reach `_enum_union_tags` differently: a branch
    # assigning `Access.PUBLIC` leaves an EnumMemberType in the joined union,
    # while a declared parameter leaves the enum ClassType. Both have to
    # classify as the enum that owns the tag.
    (eng, _) = compile_native("isinstance_enum_union.jac");
    f = get_func(eng, "resolve_access_param", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 1 , "a bare Access member resolves to itself (PUBLIC)";
    assert f(2) == 2 , "a node resolves through its access_type (PROTECTED)";
    assert f(0) == 0 , "an absent spec falls back to the default (PRIVATE)";
}

test "an enum against bool still owns the int tag alone" {
    (eng, _) = compile_native("isinstance_enum_union.jac");
    f = get_func(eng, "chk_enum_over_bool", ctypes.c_bool, ctypes.c_int64);
    assert f(1) is True , "the enum member matches";
    assert f(2) is False , "True is tag 7, not the enum's tag 0";
    assert f(0) is False , "False is tag 7, not the enum's tag 0";
}

test "an enum sharing the int tag is refused, not answered by tag" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "isinstance_enum_tag_clash.jac")),
        options=native_force_opts()
    );
    # `int` claims tag 0 as well, so a tag compare would report `True` for a
    # plain int. Refusing is the only correct answer until the enum ordinal
    # is discriminated some other way; the refusal demotes the asking
    # function to its Python implementation instead of failing the module.
    assert not prog.errors_had , (
        "the tag-clash refusal is owned by chk_enum_over_int(), which must "
        f"demote to a seam, got: {[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "chk_enum_over_int" not in ir.gen.native_layout.functions , (
        "isinstance against an enum that shares the int tag must demote the "
        "asking function out of the native layout, never answer by tag"
    );
}
