"""Compile-time guard on a relative import that names no module.

`shared/ui/field.jac` in the in-tree jaclang.org site carried
`import from .label { Label }` while `shared/ui/label.jac` had been dropped.
Nothing objected at compile time: the checker warned W1100 ("Module not
found"), boundary classification could not see a client module behind the
unresolvable path and left the import statement in the server codespace, and
the ECMAScript backend, which emits only client statements, dropped it. The
client bundle was emitted with the import silently gone and the failure
surfaced in the browser as `ReferenceError: Label is not defined`.

A relative import names a file inside the author's own project, so an
unresolvable one is a defect in the program and is reported as an error.
Imports that are legitimately absent from the emitted bundle for a known
reason -- npm packages, `import type`, comptime-erased imports -- keep
compiling.
"""

import os;
import shutil;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }


glob _FIELD_SRC: str = (
         "import from .label { Label }\n"
         "\n"
         "def:pub Field(text: str) -> any {\n"
         "    return <div><Label text={text} /></div>;\n"
         "}\n"
     ),
     _LABEL_SRC: str = (
         "def:pub Label(text: str) -> any {\n" "    return <span>{text}</span>;\n" "}\n"
     ),
     _SERVER_SRC: str = (
         "import from .helper { thing }\n"
         "\n"
         "def run -> int {\n"
         "    return thing();\n"
         "}\n"
     );


"""Write a one-file project under a fresh temp dir; return the module path."""
def _project(source: str, name: str = "field.jac") -> tuple[str, str] {
    base = tempfile.mkdtemp(prefix="jac_missing_import_");
    with open(os.path.join(base, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"missingimp\"\nkind = \"web-app\"\n");
    }
    mod_path = os.path.join(base, name);
    with open(mod_path, "w") as f {
        f.write(source);
    }
    return (base, mod_path);
}


def _codes(prog: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in prog.errors_had
        if e.code
    ];
}


def _warn_codes(prog: JacProgram) -> list[str] {
    return [
        w.code.code
        for w in prog.warnings_had
        if w.code
    ];
}


test "a client module importing a missing sibling fails to compile" {
    (base, mod_path) = _project(_FIELD_SRC);
    try {
        prog = JacProgram();
        mod = prog.compile(mod_path);
        codes = _codes(prog);
        assert "E1134" in codes , f"expected E1134, got errors {codes}"
        f" and warnings {_warn_codes(prog)}";
        named = [
            str(e)
            for e in prog.errors_had
            if e.code and e.code.code == "E1134"
        ];
        assert any([".label" in m for m in named]) , named;
        assert any(["field.jac" in m for m in named]) , named;
        assert "Label" not in mod.gen.js , (
            "a module that fails to compile must not emit a bundle that"
            f" references the missing import: {mod.gen.js}"
        );
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a server module importing a missing sibling fails to compile" {
    (base, mod_path) = _project(_SERVER_SRC, name="svc.jac");
    try {
        prog = JacProgram();
        prog.compile(mod_path);
        codes = _codes(prog);
        assert "E1134" in codes , f"expected E1134, got errors {codes}"
        f" and warnings {_warn_codes(prog)}";
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "the same import compiles once the sibling exists" {
    (base, mod_path) = _project(_FIELD_SRC);
    try {
        with open(os.path.join(base, "label.jac"), "w") as f {
            f.write(_LABEL_SRC);
        }
        prog = JacProgram();
        mod = prog.compile(mod_path);
        assert "E1134" not in _codes(prog) , _codes(prog);
        assert 'from "./label.js"' in mod.gen.js , mod.gen.js;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "an unresolvable npm package stays a warning" {
    (base, mod_path) = _project(
        "import from 'fake-widgets-not-installed' { makeWidget }\n"
        "\n"
        "def:pub Widget -> any {\n"
        "    return makeWidget();\n"
        "}\n"
    );
    try {
        prog = JacProgram();
        prog.compile(mod_path);
        assert "E1134" not in _codes(prog) , _codes(prog);
        assert "W1100" in _warn_codes(prog) , _warn_codes(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a type-only import of a missing sibling stays a warning" {
    (base, mod_path) = _project(
        "import type from .label { Label }\n"
        "\n"
        "def:pub Field(text: str) -> any {\n"
        "    lbl: Label = text;\n"
        "    return lbl;\n"
        "}\n"
    );
    try {
        prog = JacProgram();
        prog.compile(mod_path);
        assert "E1134" not in _codes(prog) , _codes(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "an optional dependency guarded by try/except ImportError stays a warning" {
    (base, mod_path) = _project(
        "def:pub Widget -> any {\n"
        "    try {\n"
        "        import from .optional_plugin { make }\n"
        "        return make();\n"
        "    } except ImportError {\n"
        "        return None;\n"
        "    }\n"
        "}\n"
    );
    try {
        prog = JacProgram();
        prog.compile(mod_path);
        assert "E1134" not in _codes(prog) , (
            "an import whose failure the author handles must not be a compile"
            f" error: {_codes(prog)}"
        );
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a missing sibling outside the guarded try is still an error" {
    (base, mod_path) = _project(
        "import from .label { Label }\n"
        "\n"
        "def:pub Widget -> any {\n"
        "    try {\n"
        "        import from .optional_plugin { make }\n"
        "        return make();\n"
        "    } except ImportError {\n"
        "        return Label;\n"
        "    }\n"
        "}\n"
    );
    try {
        prog = JacProgram();
        prog.compile(mod_path);
        codes = _codes(prog);
        assert "E1134" in codes , codes;
        named = [
            str(e)
            for e in prog.errors_had
            if e.code and e.code.code == "E1134"
        ];
        assert len(named) == 1 , named;
        assert any([".label" in m for m in named]) , named;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
