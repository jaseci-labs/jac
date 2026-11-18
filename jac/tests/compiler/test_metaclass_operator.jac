"""An operator declared on a metaclass is dispatched from the class object.

A class is an instance of its metaclass, so `Foo * 3` runs
`type(Foo).__mul__` and `Foo[k]` runs `type(Foo).__getitem__`. Magic-method
lookup searched only the class's own MRO, so a metaclass operator was never
found -- while a plain metaclass *method* reached through attribute access
already resolved.

ctypes builds every array type this way: `_CType_Type.__mul__(cls, n)` is
what makes `c_char_p * argc` a type, so all of it was unusable.

Subscript was the last class-object operator that never asked the metaclass:
it went straight to generic specialization, so `Tokens["A"]` on an enum read
as `Tokens[Literal["A"]]`. Python only falls back to `__class_getitem__`
(generic specialization) when the metaclass has no `__getitem__` -- except in
a type-annotation position, where a subscript is always specialization and
the metaclass never runs.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob META_GETITEM: str = "class Meta(type) {\n"
         + "    def __getitem__(cls: Meta, key: str) -> int {\n        return len(key);\n    }\n"
         + "}\n"
         + "class Foo(metaclass=Meta) {}\n",
     ANN_PROBE: str = "def probe -> None {\n"
         + "    b: Box[int] = Box(item=1);\n    assert b.item == 1;\n}\n",
     VAL_PROBE: str = ANN_PROBE
         + "def probe_val -> Box[int] {\n    return Box[int](item=3);\n}\n";

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="metaop.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "a metaclass operator is reachable from the class object" {
    cases = [
        (
            "__mul__",
            "class Meta(type) {\n"
                + "    def __mul__(cls: Meta, other: int) -> str {\n"
                + "        return str(other);\n    }\n"
                + "}\n"
                + "class Foo(metaclass=Meta) {}\n"
                + "def probe -> str {\n    return Foo * 3;\n}\n"
        ),
        (
            "__getitem__",
            META_GETITEM + "def probe -> int {\n    return Foo['abc'];\n}\n"
        ),
        (
            "an enum member by name keeps that enum's own type",
            "import from enum { StrEnum }\n"
                + "class Tokens(StrEnum) {\n    A = 'a';\n}\n"
                + "class Other(StrEnum) {\n    B = 'b';\n}\n"
                + "def probe -> Tokens {\n    return Tokens['A'];\n}\n"
        )
    ];
    for (label, src) in cases {
        errs = check_src(src);
        assert not errs , f"{label} not dispatched: {errs}";
    }
}

test "invalid arguments to a metaclass operator are reported" {
    for key in ["123", "1:3"] {
        errs = check_src(
            META_GETITEM + "def probe -> None {\n    x = Foo[" + key + "];\n}\n"
        );
        assert errs and "parameter 'key'" in " ".join(errs) , (key, errs);
    }
}

test "a metaclass __getitem__ does not capture generic specialization" {
    meta = "class Meta(type) {\n"
        + "    def __getitem__(cls: Meta, key: KEY) -> int {\n        return 1;\n    }\n"
        + "}\n";
    cases = [
        ("no metaclass", "", "class Box[T] {\n    has item: T;\n}\n", VAL_PROBE),
        (
            "an ABC base",
            "import from abc { ABC }\n",
            "class Box[T](ABC) {\n    has item: T;\n}\n",
            VAL_PROBE
        ),
        (
            "a metaclass keyed on type",
            meta.replace("KEY", "type"),
            "class Box[T](metaclass=Meta) {\n    has item: T;\n}\n",
            ANN_PROBE
        ),
        (
            "a metaclass keyed on any",
            meta.replace("KEY", "any"),
            "class Box[T](metaclass=Meta) {\n    has item: T;\n}\n",
            ANN_PROBE
        )
    ];
    for (label, prelude, decl, probe) in cases {
        errs = check_src(prelude + decl + probe);
        assert not errs , f"Box[int] with {label} stopped specializing: {errs}";
    }
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


glob META_CLASSES: str = "import from typing { Hashable, Sized, overload }\n"
         + "glob T = TypeVar(\"T\");\n"
         + "class Meta(type) {\n"
         + "    def __len__(cls: Meta) -> int {\n        return 3;\n    }\n"
         + "    def __setitem__(cls: Meta, key: str, val: int) -> None {}\n"
         + "    @overload\n    def __call__(cls: Meta, n: int) -> str;\n"
         + "    @overload\n    def __call__(cls: Meta, s: str) -> int;\n"
         + "    def __call__(cls: Meta, x: int | str) -> (int | str) {\n"
         + "        return x;\n    }\n"
         + "}\n"
         + "class Foo(metaclass=Meta) {}\n"
         + "class Plain {}\n"
         + "class OnlyInt(type) {\n"
         + "    def __call__(cls: OnlyInt, n: int) -> str {\n        return \"s\";\n    }\n"
         + "}\n"
         + "class Takes(metaclass=OnlyInt) {\n"
         + "    def init(self: Takes, s: str) -> None {}\n"
         + "}\n"
         + "class Lazy(type) {\n"
         + "    def __call__(cls: Lazy, *args: any, **kwargs: any) -> any {\n"
         + "        return super().__call__(*args, **kwargs);\n    }\n"
         + "}\n"
         + "class Box(metaclass=Lazy) {\n    def init(self: Box, n: int) -> None {}\n}\n"
         + "class Single(type) {\n"
         + "    def __call__(cls: type[T], *args: any, **kwargs: any) -> T {\n"
         + "        return super().__call__(*args, **kwargs);\n    }\n"
         + "}\n"
         + "class Svc(metaclass=Single) {\n    def init(self: Svc, n: int) -> None {}\n}\n"
         + "enum Color { RED = \"r\" }\n";

test "a class object is an instance of its metaclass" {
    errs = check_src(
        META_CLASSES
            + "def probe -> None {\n"
            + "    n: int = len(Foo);\n"
            + "    s: Sized = Foo;\n"
            + "    m: Meta = Foo;\n"
            + "    h: Hashable = Plain;\n"
            + "    a: str = Foo(1);\n"
            + "    b: int = Foo(\"a\");\n"
            + "    f: Callable[[int], str] = Foo;\n"
            + "    g: Callable[[str], int] = Foo;\n"
            + "    t: str = Takes(1);\n"
            + "    Foo[\"a\"] = 1;\n"
            + "    c: Color = Color(\"r\");\n"
            + "    k: Callable[[str], Color] = Color;\n"
            + "    v: Svc = Svc(1);\n"
            + "    w: Box = Box(1);\n"
            + "}\n"
    );
    assert not errs , errs;
}

test "metaclass dispatch still reports real errors" {
    cases = [
        ("len(Plain)", "of type Sized"),
        ("x: str = Foo", "Cannot assign Foo to str"),
        ("Foo[\"a\"] = \"x\"", "Literal[\"x\"]"),
        ("Plain[\"a\"] = 1", "Cannot assign int to Plain"),
        ("Takes(\"bad\")", "parameter 'n'"),
        ("Box(\"x\")", "parameter 'n'"),
        ("Svc(\"x\")", "parameter 'n'")
    ];
    for (stmt, expected) in cases {
        errs = check_src(META_CLASSES + "def probe -> None {\n    " + stmt + ";\n}\n");
        assert len(errs) == 1 and expected in errs[0] , (stmt, errs);
    }
}
