"""An operator declared on a metaclass is dispatched from the class object.

A class is an instance of its metaclass, so `Foo * 3` runs
`type(Foo).__mul__`. Magic-method lookup searched only the class's own MRO,
so a metaclass operator was never found -- while a plain metaclass *method*
reached through attribute access already resolved.

ctypes builds every array type this way: `_CType_Type.__mul__(cls, n)` is
what makes `c_char_p * argc` a type, so all of it was unusable.
"""

import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="metaop.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "a metaclass operator is reachable from the class object" {
    src = "class Meta(type) {\n"
        + "    def __mul__(cls: Meta, other: int) -> str {\n"
        + "        return str(other);\n"
        + "    }\n"
        + "}\n"
        + "class Foo(metaclass=Meta) {}\n"
        + "def probe -> str {\n"
        + "    return Foo * 3;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"metaclass operator not dispatched: {errs}";
}

test "a ctypes array type can be built" {
    src = "import ctypes;\n"
        + "def probe(n: int) -> None {\n"
        + "    arr = ctypes.c_char_p * n;\n"
        + "    assert arr is not None;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"ctypes array construction rejected: {errs}";
}

test "a metaclass operator wins over one on the class itself" {
    src = "class Meta(type) {\n"
        + "    def __mul__(cls: Meta, other: int) -> str {\n"
        + "        return 'meta';\n"
        + "    }\n"
        + "}\n"
        + "class Both(metaclass=Meta) {\n"
        + "    def __mul__(self: Both, other: int) -> int {\n"
        + "        return 0;\n"
        + "    }\n"
        + "}\n"
        + "def probe -> str {\n"
        + "    return Both * 3;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"class __mul__ shadowed the metaclass one: {errs}";
}
