"""Client artifacts must reflect placement discovered by the current program."""

import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }


test "a cached partial helper is regenerated when a new client root pulls another export" {
    with tempfile.TemporaryDirectory(prefix="jac-client-placement-") as tmp {
        files = {
            "jac.toml": "[project]\nname = \"placement-cache\"\n",
            "format.jac": "def:pub handle_of(username: str) -> str { return username.split(\"@\")[0]; }\n",
            "identity.jac": "import from .format { handle_of }\ndef:pub name_of(username: str) -> str { return handle_of(username); }\ndef:pub avatar_of(username: str) -> str { return username; }\n",
            "first.jac": "import from .identity { avatar_of }\ndef:pub app -> JsxElement { return <div>{avatar_of(\"a\")}</div>; }\n",
            "second.jac": "import from .identity { name_of }\ndef:pub app -> JsxElement { return <div>{name_of(\"a\")}</div>; }\n"
        };
        for (name, source) in files.items() {
            with open(os.path.join(tmp, name), "w") as f {
                f.write(source);
            }
        }
        identity = os.path.join(tmp, "identity.jac");
        first = os.path.join(tmp, "first.jac");
        second = os.path.join(tmp, "second.jac");
        cold = JacProgram();
        cold.compile(first);
        partial = cold.get_client_artifact(identity);
        assert partial is not None;
        assert "function avatar_of(" in partial.js;
        assert "function name_of(" not in partial.js;
        assert not cold.errors_had , [str(e) for e in cold.errors_had];
        warm = JacProgram();
        assert warm.get_client_artifact(first) is not None;
        caller = warm.get_client_artifact(second);
        assert caller is not None;
        assert 'import { name_of } from "./identity.js"' in caller.js;
        complete = warm.get_client_artifact(identity);
        assert complete is not None;
        assert "function name_of(" in complete.js , (
            "a source-fresh artifact can still be placement-stale: " + complete.js
        );
        assert "__jacCallFunction" not in caller.js;
        assert not warm.errors_had , [str(e) for e in warm.errors_had];
    }
}


test "the final JS audit rejects an imported value whose binding was dropped" {
    import from unittest.mock { patch }
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    import from jaclang.compiler.driver.pass_driver { run_pass }
    import jaclang.compiler.backends.es.estree as es;
    import jaclang.compiler.backends.es.esast_gen_pass as esgen;
    with tempfile.TemporaryDirectory(prefix="jac-import-audit-") as tmp {
        path = os.path.join(tmp, "app.jac");
        with open(path, "w") as f {
            f.write(
                "import from \"mermaid\" { default as mermaid }\n"
                "glob diagram: any = mermaid;\n"
                "def:pub app -> JsxElement { return <div>{diagram}</div>; }\n"
            );
        }
        prog = JacProgram();
        mod = prog.compile(path, no_cgen=True);
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        # Simulate the dropped-import lowering observed in MermaidDiagram.js.
        # The audit must inspect emitted bindings even for resolved imports.
        original = getattr(esgen, "es_to_js");
        def drop_import(program: es.Node) -> str {
            if isinstance(program, es.Program) {
                program.body = [
                    stmt
                    for stmt in program.body
                    if not (
                        isinstance(stmt, es.ImportDeclaration)
                        and stmt.source is not None
                        and stmt.source.value == "mermaid"
                    )
                ];
            }
            return original(program);
        }
        with patch.object(esgen, "es_to_js", drop_import) {
            run_pass(EsastGenPass, mod, prog);
        }
        assert 'import mermaid from "mermaid"' not in mod.gen.js;
        assert "let diagram = mermaid" in mod.gen.js;
        errors = [
            e
            for e in prog.errors_had
            if e.code is not None and e.code.code == "E5101"
        ];
        assert len(errors) == 1 , [str(e) for e in prog.errors_had];
        assert "mermaid" in str(errors[0]);
    }
}
