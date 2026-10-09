"""Dynamic import lowering: `__import__` becomes a JS `import()` in client code.
The path is resolved at build time and the target registered for compilation."""

import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.driver.program { JacProgram }

glob _CARD_SRC = "def:pub MessageCard(text: str) -> any {\n    return <p>{text}</p>;\n}\n";


def _emit(body: str) -> tuple[str, list[str], dict[str, str]] {
    with tempfile.TemporaryDirectory(prefix="jac_dynimport_") as tmp {
        base = Path(tmp).resolve();
        (base / "jac.toml").write_text(
            '[project]\nname = "dynimport"\nkind = "web-app"\n'
        );
        (base / "components").mkdir();
        (base / "MessageCard.jac").write_text(_CARD_SRC);
        (base / "components" / "MessageCard.jac").write_text(_CARD_SRC);
        widget = base / "widget.jac";
        widget.write_text(
            "def:pub Widget -> any {\n    " + body + "\n    return <div>{m}</div>;\n}\n"
        );
        prog = JacProgram();
        mod = prog.compile(str(widget), options=CompileOptions(no_cgen=True));
        inst = run_pass(EsastGenPass, mod, prog);
        codes = [
            str(e.code.code)
            for e in prog.errors_had
            if e.code
        ];
        return (str(mod.gen.js), codes, dict(inst.module_import_paths));
    }
}


test "a relative path gains the .js extension and is registered for the build" {
    (js, codes, registered) = _emit('m = __import__("./MessageCard");');
    assert codes == [] , codes;
    assert 'import("./MessageCard.js")' in js , js;
    assert registered.get("./MessageCard.js", "").endswith(
        "MessageCard.jac"
    ) , registered;
}


test "a jac module path resolves to its compiled location" {
    (js, codes, _) = _emit('m = __import__(".components.MessageCard");');
    assert codes == [] , codes;
    assert 'import("./components/MessageCard.js")' in js , js;
}


test "the component named after the file becomes the default export" {
    (js, codes, _) = _emit('m = __import__("./MessageCard");');
    assert codes == [] , codes;
    assert 'import("./MessageCard.js").then((m) => ({...m, default: m.MessageCard}))'
        in js , js;
}


test "fromlist picks which export becomes the default" {
    (js, codes, _) = _emit('m = __import__("./MessageCard", fromlist=["CardBody"]);');
    assert codes == [] , codes;
    assert 'import("./MessageCard.js").then((m) => ({...m, default: m.CardBody}))'
        in js , js;
}


test "an import the bundler cannot act on is rejected" {
    unsplittable = [
        'p = "./MessageCard"; m = __import__(p);',
        'm = __import__(f"./Message{1}");',
        'm = __import__("os.path");',
        'm = __import__("./MessageCard", fromlist=["my-card"]);',
        'm = __import__("./MessageCard", level=1);'
    ];
    accepted = [
        body
        for body in unsplittable
        if "E5113" not in _emit(body)[1]
    ];
    assert accepted == [] , f"not rejected with E5113: {accepted}";
}
