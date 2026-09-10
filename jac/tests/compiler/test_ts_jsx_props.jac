import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from tests.compiler.passes.checker_npm_harness {
    check_npm_file,
    client_node_modules,
    install_npm_pkg,
    pretty_checker_errors,
    write_client_jac_project
}

test "destructured TypeScript component parameters validate JSX props" {
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        install_npm_pkg(
            client_node_modules(project),
            "jsx-props",
            '{"name":"jsx-props","version":"1.0.0","main":"index.js","types":"index.d.ts"}',
            {
                "index.js": "export function BrowserRouter(props) { return props.children; }",
                "index.d.ts": "export interface RouterProps { basename?: string; children?: any; }\n"
                    + "export declare function BrowserRouter({basename, children}: RouterProps): any;\n"
            }
        );
        write_client_jac_project(
            project, "jsxprops", "lib.app", 'jsx-props = "1.0.0"\n'
        );
        for (name, attributes, expected) in [
            ("valid", 'basename="docs"', []),
            ("invalid_type", 'basename={123}', ["E1100"]),
            ("invalid_name", 'missing="docs"', ["E1101"])
        ] {
            source = project / "lib" / f"{name}.jac";
            source.write_text(
                'import from "jsx-props" { BrowserRouter as Router }\n'
                    + 'def:pub app -> JsxElement { return <Router '
                    + attributes
                    + '><span>content</span></Router>; }\n'
            );
            (program, errors, _) = check_npm_file(source);
            assert errors == expected , pretty_checker_errors(program);
        }
    }
}
