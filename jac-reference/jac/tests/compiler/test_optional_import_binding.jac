"""An import binds in the enclosing function or module scope, not its block.

Jac models block statements (try, if, while, with, ...) as scopes so that name
lookup can walk outward. An `import` inside one of those blocks must still bind
its name where Python binds it: in the nearest function, class or module scope.

Binding it to the block instead splits the optional-dependency idiom into two
unrelated symbols -- the one the `try` imports and the one the `except` sets to
None -- so every later member access resolves against NoneType and reports.
This is the idiom every `_optdeps` module is built on.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="opt_import.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "an import in a try block is reachable from the module scope" {
    src = "with entry {\n"
        + "    try {\n"
        + "        import json;\n"
        + "    } except ImportError {\n"
        + "        json = None;\n"
        + "    }\n"
        + "}\n"
        + "def use -> str {\n"
        + "    if json is None {\n"
        + "        raise ImportError('no json');\n"
        + "    }\n"
        + "    return json.dumps({});\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"optional-import idiom reported: {errs}";
}

test "a from-import in a try block binds in the module scope" {
    src = "with entry {\n"
        + "    try {\n"
        + "        import from json { dumps }\n"
        + "    } except ImportError {\n"
        + "        dumps = None;\n"
        + "    }\n"
        + "}\n"
        + "def use -> str {\n"
        + "    if dumps is None {\n"
        + "        raise ImportError('no json');\n"
        + "    }\n"
        + "    return dumps({});\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"optional from-import idiom reported: {errs}";
}

test "an aliased import in a try block binds in the module scope" {
    src = "with entry {\n"
        + "    try {\n"
        + "        import json as j;\n"
        + "    } except ImportError {\n"
        + "        j = None;\n"
        + "    }\n"
        + "}\n"
        + "def use -> str {\n"
        + "    if j is None {\n"
        + "        raise ImportError('no json');\n"
        + "    }\n"
        + "    return j.dumps({});\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"optional aliased-import idiom reported: {errs}";
}
