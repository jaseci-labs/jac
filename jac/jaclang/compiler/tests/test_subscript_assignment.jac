"""Type-checker tests for subscript (``__setitem__``) assignment.

Regression coverage for the slice-assignment class of false positives
(see issue #7160): ``container[slice] = value`` must dispatch on the index
type through ``__setitem__`` instead of comparing the RHS against the
``__getitem__`` read type. A ``bytearray`` slice legitimately accepts any
buffer / iterable of ints (``ident[0:4] = b"..."``), which the old
element-assignment model rejected.
"""

import from jaclang.jac0core.program { JacProgram }


"""Type-check a Jac source string and return the emitted error messages."""
def check_errors(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(file_path="subscript_test_src.jac", use_str=src, type_check=True);
    return [str(e) for e in prog.errors_had];
}


test "bytearray slice assignment from bytes type-checks" {
    src = "def f -> None {\n"
    "    ident = bytearray(16);\n"
    "    ident[0:4] = b\"\\x7fELF\";\n"
    "}\n";
    errors = check_errors(src);
    assert errors == [] , errors;
}


test "bytearray element assignment from int type-checks" {
    src = "def f -> None {\n"
    "    ident = bytearray(16);\n"
    "    ident[0] = 65;\n"
    "}\n";
    errors = check_errors(src);
    assert errors == [] , errors;
}


test "list slice assignment from an iterable of the element type" {
    src = "def f -> None {\n"
    "    xs: list[int] = [1, 2, 3, 4];\n"
    "    xs[0:2] = (9, 8);\n"
    "}\n";
    errors = check_errors(src);
    assert errors == [] , errors;
}


test "bytearray slice assignment from a non-buffer still errors" {
    src = "def f -> None {\n"
    "    ident = bytearray(16);\n"
    "    ident[0:4] = 5;\n"
    "}\n";
    errors = check_errors(src);
    assert len(errors) == 1 , errors;
    assert "assign" in errors[0].lower() , errors;
}


test "list slice assignment from a non-iterable still errors" {
    src = "def f -> None {\n"
    "    xs: list[int] = [1, 2, 3, 4];\n"
    "    xs[0:2] = 5;\n"
    "}\n";
    errors = check_errors(src);
    assert len(errors) == 1 , errors;
}


test "dict element assignment with a wrong value type still errors" {
    src = "def f -> None {\n"
    "    m: dict[str, int] = {};\n"
    "    m[\"a\"] = \"x\";\n"
    "}\n";
    errors = check_errors(src);
    assert len(errors) == 1 , errors;
}


test "augmented slice assignment type-checks via the aug path" {
    # The __setitem__ probe is scoped to plain (`=`) slice writes; augmented
    # writes go through the augmented-operator path, which already accepts
    # these buffer/iterable extends. Guards the current behavior.
    src = "def f -> None {\n"
    "    b = bytearray(4);\n"
    "    b[0:2] += b\"\\x01\\x02\";\n"
    "    xs: list[int] = [1, 2, 3];\n"
    "    xs[0:2] += [9, 8];\n"
    "}\n";
    errors = check_errors(src);
    assert errors == [] , errors;
}
