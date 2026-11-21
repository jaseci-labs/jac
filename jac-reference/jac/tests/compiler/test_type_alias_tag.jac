"""An explicit TypeAlias tag is recognized however it is spelled.

`X: TypeAlias = <type expression>` declares X as an alias for that expression.
Recognizing it by matching the literal token "TypeAlias" only works for a bare
imported name -- but typeshed itself writes the tag dotted, as
`typing_extensions.TypeAlias`, and code is free to import it under an alias.

When the tag goes unrecognized the symbol keeps the *annotation's* type instead.
`TypeAlias` is declared `_SpecialForm`, so every use of the alias then reports
"Cannot assign ... to parameter of type _SpecialForm" -- which is what made
`typing.get_type_hints` uncallable with any argument at all.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="alias_tag.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "get_type_hints accepts an argument" {
    src = "import from typing { get_type_hints }\n"
        + "def probe(x: object) -> None {\n"
        + "    hints = get_type_hints(x);\n"
        + "    assert hints is not None;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"get_type_hints rejected its argument: {errs}";
}

test "a dotted TypeAlias tag resolves to the aliased type" {
    src = "import from typing { ByteString }\n"
        + "def probe(b: ByteString) -> None {\n"
        + "    assert b is not None;\n"
        + "}\n"
        + "with entry {\n"
        + "    probe(b'x');\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"dotted TypeAlias tag not honored: {errs}";
}
