"""Dynamic import lowering: `__import__` becomes a JS `import()` in client code.
The path is resolved at build time and the target registered for compilation.
"""

import os;
import shutil;
import tempfile;
import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.driver.program { JacProgram }


glob _CARD_SRC: str = (
         "def:pub MessageCard(text: str) -> any {\n" "    return <p>{text}</p>;\n" "}\n"
     );


def _project(widget_body: str) -> tuple[str, str] {
    base = os.path.realpath(tempfile.mkdtemp(prefix="jac_dynimport_"));
    with open(os.path.join(base, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"dynimport\"\nkind = \"web-app\"\n");
    }
    os.makedirs(os.path.join(base, "components"), exist_ok=True);
    with open(os.path.join(base, "components", "MessageCard.jac"), "w") as f {
        f.write(_CARD_SRC);
    }
    with open(os.path.join(base, "MessageCard.jac"), "w") as f {
        f.write(_CARD_SRC);
    }
    widget = os.path.join(base, "widget.jac");
    with open(widget, "w") as f {
        f.write(
            "def:pub Widget -> any {\n"
                + widget_body
                + "    return <div>{m}</div>;\n}\n"
        );
    }
    return (base, widget);
}


def _emit(widget_body: str) -> tuple[str, list[str], any] {
    (base, widget) = _project(widget_body);
    try {
        prog = JacProgram();
        mod = prog.compile(widget, options=CompileOptions(no_cgen=True));
        inst = run_pass(EsastGenPass, mod, prog);
        codes = [
            str(e.code.code)
            for e in prog.errors_had
            if e.code
        ];
        return (str(mod.gen.js), codes, inst);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a relative path gains the compiled .js extension" {
    (js, codes, inst) = _emit("    m = __import__(\"./MessageCard\");\n");
    assert codes == [] , codes;
    assert 'import("./MessageCard.js")' in js , js;
}


test "a jac module path resolves to its compiled location" {
    (js, codes, inst) = _emit("    m = __import__(\".components.MessageCard\");\n");
    assert codes == [] , codes;
    assert 'import("./components/MessageCard.js")' in js , js;
}


test "fromlist emits the default-export mapping react lazy needs" {
    (js, codes, inst) = _emit(
        "    m = __import__(\"./MessageCard\", fromlist=[\"MessageCard\"]);\n"
    );
    assert codes == [] , codes;
    assert 'import("./MessageCard.js").then((m) => ({default: m.MessageCard}))'
        in js , js;
}


test "the target is registered so the build compiles it" {
    (js, codes, inst) = _emit("    m = __import__(\"./MessageCard\");\n");
    assert codes == [] , codes;
    registered = inst.module_import_paths;
    assert "./MessageCard.js" in registered , registered;
    assert registered["./MessageCard.js"].endswith("MessageCard.jac") , registered;
}


test "a path built at runtime is rejected" {
    (js, codes, inst) = _emit("    p = \"./MessageCard\";\n    m = __import__(p);\n");
    assert "E5113" in codes , codes;
}


test "an f-string path is rejected" {
    (js, codes, inst) = _emit("    m = __import__(f\"./Message{1}\");\n");
    assert "E5113" in codes , codes;
}


test "a path naming no jac module is rejected" {
    (js, codes, inst) = _emit("    m = __import__(\"os.path\");\n");
    assert "E5113" in codes , codes;
}


test "python-only import parameters are rejected" {
    (js, codes, inst) = _emit("    m = __import__(\"./MessageCard\", level=1);\n");
    assert "E5113" in codes , codes;
}
