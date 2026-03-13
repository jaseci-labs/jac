"""Tests for the LayoutPass CType struct contract.

Validates that the layout pass correctly identifies layout-compatible
and incompatible field types on obj archetypes, and that FieldInfo
tracks function pointer fields.
"""

import from jaclang.compiler.passes.main.layout_pass {
    LAYOUT_COMPATIBLE_PRIMITIVES,
    FieldInfo,
    ArchetypeLayout,
    LayoutRegistry,
    LayoutPass,
    get_layout_registry
}
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import os;
import from pathlib { Path }
import jaclang;

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "main" / "fixtures" / "layout"
     );

"""Compile a .jac fixture through semantic analysis and return the LayoutRegistry."""
def get_registry(fixture: str) -> LayoutRegistry {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    return get_layout_registry(ir);
}

# ── LAYOUT_COMPATIBLE_PRIMITIVES ──────────────────────────────
test "LAYOUT_COMPATIBLE_PRIMITIVES contains all expected types" {
    expected = {"int","float","bool","str","bytes","i8","u8","i16","u16","i32","u32","i64","u64","f32","f64"};
    assert LAYOUT_COMPATIBLE_PRIMITIVES == expected;
}

# ── FieldInfo.is_func_ptr ────────────────────────────────────
test "FieldInfo default is_func_ptr is False" {
    fi = FieldInfo(name="x", index=0, type_tag="int");
    assert fi.is_func_ptr == False;
}

test "FieldInfo is_func_ptr can be set True" {
    fi = FieldInfo(name="cb", index=0, type_tag="fn", is_func_ptr=True);
    assert fi.is_func_ptr == True;
}

# ── Layout registry: primitive fields ────────────────────────
test "obj with int fields produces correct layout" {
    reg = get_registry("valid_primitives.jac");
    layout = reg.get_layout("IntFields");
    assert layout is not None;
    assert len(layout.fields) == 3;
    names = [f.name for f in layout.fields];
    assert "x" in names;
    assert "y" in names;
    assert "z" in names;
}

test "obj with all primitive types produces layout" {
    reg = get_registry("valid_primitives.jac");
    layout = reg.get_layout("AllPrimitives");
    assert layout is not None;
    assert len(layout.fields) == 5;
}

# ── Layout registry: obj reference fields ────────────────────
test "obj with other obj field produces layout" {
    reg = get_registry("valid_obj_refs.jac");
    layout = reg.get_layout("Line");
    assert layout is not None;
    names = [f.name for f in layout.fields];
    assert "start" in names;
    assert "end" in names;
    assert "label" in names;
}

# ── Layout registry: typed collections ───────────────────────
test "obj with typed list field produces layout" {
    reg = get_registry("valid_collections.jac");
    layout = reg.get_layout("WithList");
    assert layout is not None;
    assert len(layout.fields) == 1;
    assert layout.fields[0].name == "items";
}

test "obj with typed dict field produces layout" {
    reg = get_registry("valid_collections.jac");
    layout = reg.get_layout("WithDict");
    assert layout is not None;
    assert len(layout.fields) == 1;
    assert layout.fields[0].name == "entries";
}

# ── Layout registry: optional fields ─────────────────────────
test "obj with optional field produces layout" {
    reg = get_registry("valid_optional.jac");
    layout = reg.get_layout("OptionalFields");
    assert layout is not None;
    names = [f.name for f in layout.fields];
    assert "maybe_int" in names;
    assert "maybe_str" in names;
}

# ── Layout registry: enum fields ─────────────────────────────
test "obj with enum field produces layout" {
    reg = get_registry("valid_enum.jac");
    layout = reg.get_layout("Colored");
    assert layout is not None;
    names = [f.name for f in layout.fields];
    assert "color" in names;
}

# ── Layout registry: inheritance ─────────────────────────────
test "child obj inherits parent fields in MRO order" {
    reg = get_registry("valid_inheritance.jac");
    layout = reg.get_layout("Child");
    assert layout is not None;
    names = [f.name for f in layout.fields];
    assert names[0] == "parent_field";
    assert names[1] == "child_field";
}

# ── Validation warnings: bad types ──────────────────────────
test "obj with Any field triggers warning" {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, "invalid_any.jac")));
    # Should compile (warnings, not errors) but produce a warning
    warnings = [str(w) for w in prog.warnings_had] if prog.warnings_had else [];
    found = any("layout-compatible" in w for w in warnings);
    assert found , f"Expected layout-compatible warning, got: {warnings}";
}

test "layout warnings report correct line numbers for fields" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "invalid_any_multifield.jac"))
    );
    layout_warnings = [
        w
        for w in (prog.warnings_had or [])
        if "layout-compatible" in str(w)
    ];
    assert len(layout_warnings) == 2 , f"Expected 2 layout warnings, got {len(
        layout_warnings
    )}: {layout_warnings}";
    warning_lines = sorted([w.loc.first_line for w in layout_warnings]);
    # bad_field1 is on line 7, bad_field2 is on line 8
    assert warning_lines == [7, 8] , f"Expected warnings on lines [7, 8], got {warning_lines}";
}
