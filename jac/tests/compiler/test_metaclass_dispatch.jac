"""A class object is an instance of its metaclass, so len(), calls, protocol
matching and subscript assignment on a class look at the metaclass."""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="metadispatch.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [f"{e.code.code if e.code else ''}: {e}" for e in prog.errors_had];
}

def has_code(errors: list[str], code: str) -> bool {
    return any(code in e for e in errors);
}

glob META_LEN: str = "import from typing { Sized }\n"
         + "class Meta(type) {\n"
         + "    def __len__(cls: Meta) -> int {\n        return 3;\n    }\n"
         + "}\n"
         + "class Foo(metaclass=Meta) {}\n",
     META_CALL: str = "class Meta(type) {\n"
         + "    def __call__(cls: Meta) -> str {\n        return \"s\";\n    }\n"
         + "}\n"
         + "class Foo(metaclass=Meta) {}\n",
     META_SETITEM: str = "class Meta(type) {\n"
         + "    def __setitem__(cls: Meta, key: str, val: int) -> None {}\n"
         + "}\n"
         + "class Foo(metaclass=Meta) {}\n";

test "len() of a class reads the metaclass __len__" {
    errors = check_src(META_LEN + "def probe -> int {\n    return len(Foo);\n}\n");
    assert errors == [] , errors;
}

test "a class satisfies a protocol its metaclass implements" {
    errors = check_src(META_LEN + "def probe -> Sized {\n    return Foo;\n}\n");
    assert errors == [] , errors;
}

test "a class is an instance of its own metaclass" {
    errors = check_src(META_LEN + "def probe -> Meta {\n    return Foo;\n}\n");
    assert errors == [] , errors;
}

test "a class with no metaclass is hashable through type" {
    errors = check_src(
        "import from typing { Hashable }\n"
            + "class Plain {}\n"
            + "def probe -> Hashable {\n    return Plain;\n}\n"
    );
    assert errors == [] , errors;
}

test "len() of a class whose metaclass has no __len__ is still an error" {
    errors = check_src(
        "class Plain {}\ndef probe -> int {\n    return len(Plain);\n}\n"
    );
    assert has_code(errors, "E1053") , errors;
}

test "a class is not an instance of an unrelated type" {
    errors = check_src(META_LEN + "def probe -> str {\n    return Foo;\n}\n");
    assert has_code(errors, "E1002") , errors;
}

test "a metaclass __call__ returning any still checks the class init" {
    errors = check_src(
        "class Meta(type) {\n"
            + "    def __call__(cls: Meta, *args: any, **kwargs: any) -> any {\n"
            + "        return super().__call__(*args, **kwargs);\n    }\n"
            + "}\n"
            + "class Foo(metaclass=Meta) {\n"
            + "    def init(self: Foo, n: int) -> None {}\n"
            + "}\n"
            + "def probe -> Foo {\n    return Foo(\"x\");\n}\n"
    );
    assert errors , "a wrong init argument was accepted";
}

test "calling a class returns what the metaclass __call__ returns" {
    errors = check_src(META_CALL + "def probe -> str {\n    return Foo();\n}\n");
    assert errors == [] , errors;
}

test "a class is a callable with the metaclass __call__ signature" {
    errors = check_src(
        META_CALL + "def probe -> Callable[[], str] {\n    return Foo;\n}\n"
    );
    assert errors == [] , errors;
}

test "calling an enum class still gives an enum member" {
    errors = check_src(
        "import from enum { Enum }\n"
            + "enum Color { RED = \"r\" }\n"
            + "def probe -> Color {\n    return Color(\"r\");\n}\n"
    );
    assert errors == [] , errors;
}

test "a subscript assignment on a class uses the metaclass __setitem__" {
    errors = check_src(META_SETITEM + "def probe -> None {\n    Foo[\"a\"] = 1;\n}\n");
    assert errors == [] , errors;
}

test "a wrong value for the metaclass __setitem__ is still an error" {
    errors = check_src(
        META_SETITEM + "def probe -> None {\n    Foo[\"a\"] = \"x\";\n}\n"
    );
    assert has_code(errors, "E1001") , errors;
}

test "a subscript assignment on a class with no __setitem__ is still an error" {
    errors = check_src(
        "class Plain {}\ndef probe -> None {\n    Plain[\"a\"] = 1;\n}\n"
    );
    assert has_code(errors, "E1001") , errors;
}
