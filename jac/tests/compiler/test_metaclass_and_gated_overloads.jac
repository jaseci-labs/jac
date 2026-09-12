"""A class object exposes its real metaclass, and version-gated overloads count.

A class is an instance of its metaclass, so attribute lookup on a class object
falls back to that metaclass. The fallback was hardcoded to `type`, so members
a real metaclass adds -- `EnumMeta.__members__` being the common one -- were
invisible on every class that had one.

Separately, typeshed splits overload sets across `if sys.version_info` guards.
Member lookup returned as soon as it found the name in the class body, so the
gated half of an overload set was never collected. Only genuine @overload
declarations merge across a guard: version-gated `__new__`/`__init__` pairs
are alternatives, not additions, and merging those would break construction.
"""

import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="meta.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "a class object exposes members its metaclass declares" {
    src = "import enum;\n"
        + "class Color(enum.Enum) {\n"
        + "    RED = 1;\n"
        + "}\n"
        + "def probe -> None {\n"
        + "    assert Color.__members__ is not None;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"metaclass member invisible on class object: {errs}";
}

test "version-gated alternatives do not merge into an overload set" {
    src = "import from pathlib { Path }\n"
        + "def probe(base: str) -> Path {\n"
        + "    return Path(base) / 'sub';\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"gated constructor alternatives broke construction: {errs}";
}
