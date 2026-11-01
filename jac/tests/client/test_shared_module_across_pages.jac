"""A module shared by several pages is written with what every page pulls.

A kernel session places one root's closure: a shared module exports to the
client what that root pulls from it, and a later root that pulls more grows
the module's held artifact. A bundle that kept the first page's file failed in
Vite on a later page's import of another name (jaclang.org's `tokens.jac`,
written for the layout without the `spacing` the mobile theme on the tech demo
imports), and a grown module's new import must be emitted with it. The compile
function here grows the shared module the way a kernel session does, so the
case needs no kernel."""
import os;
import shutil;
import from pathlib { Path }
import from tempfile { mkdtemp }

import from jaclang.client.jac_client_compiler { JacClientCompiler }
import from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }

glob PAGE: str = 'def:pub page -> JsxPage {\n    return <div/>;\n}\n';

def _write(path: Path, body: str) {
    path.parent.mkdir(parents=True, exist_ok=True);
    path.write_text(body, encoding="utf-8");
}

def _artifact(
    js: str,
    exports: list[str],
    imports: (dict[str, str] | None) = None,
    runtime_imports: (dict[str, list[str]] | None) = None
) -> ClientArtifact {
    return ClientArtifact(
        js=js,
        manifest=ClientManifest(
            exports=exports,
            has_client=True,
            imports=imports or {},
            runtime_imports=runtime_imports or {}
        )
    );
}

test "a shared module a later page grows is written with every page's pulls" {
    proj = Path(mkdtemp(prefix="jac-shared-pages-")).resolve();
    try {
        main = proj / "main.jac";
        shared = proj / "shared.jac";
        mid = proj / "mid.jac";
        helper = proj / "helper.jac";
        first = proj / "pages" / "a.jac";
        second = proj / "pages" / "b.jac";
        _write(proj / "jac.toml", '[project]\nname = "shared-pages"\n');
        for path in [main, shared, mid, helper] {
            _write(path, "");
        }
        for path in [first, second] {
            _write(path, PAGE);
        }
        compiled: list[Path] = [];
        def compile_to_js(
            path: Path, source_root: (Path | None) = None
        ) -> ClientArtifact {
            path = path.resolve();
            compiled.append(path);
            if path == shared {
                grown = second in compiled;
                names = ["avatar_of", "name_of"] if grown else ["avatar_of"];
                body = "".join(
                    f"export function {name}(u) {{ return u; }}\n" for name in names
                );
                if grown {
                    return _artifact(
                        f'import {{ fmt }} from "./helper.js";\n{body}',
                        names,
                        {"helper": str(helper)},
                        {str(helper): ["fmt"]}
                    );
                }
                return _artifact(body, names);
            }
            if path == helper {
                return _artifact("export function fmt(u) { return u; }\n", ["fmt"]);
            }
            if path == mid {
                return _artifact(
                    'import { name_of } from "./shared.js";\nexport function Label() {}\n',
                    ["Label"],
                    {"shared": str(shared)},
                    {str(shared): ["name_of"]}
                );
            }
            if path == first {
                return _artifact(
                    'import { avatar_of } from "../shared.js";\nexport function page() {}\n',
                    ["page"],
                    {"shared": str(shared)},
                    {str(shared): ["avatar_of"]}
                );
            }
            if path == second {
                return _artifact(
                    'import { Label } from "../mid.js";\nexport function page() {}\n',
                    ["page"],
                    {"mid": str(mid)},
                    {str(mid): ["Label"]}
                );
            }
            return _artifact("export function app() {}\n", ["app"]);
        }
        jcc = JacClientCompiler(
            project_dir=proj,
            runtime_path=None,
            compile_to_js_func=compile_to_js,
            extract_exports_func=lambda (
                manifest: (ClientManifest | None)
            ) -> list[str] { return list(manifest.exports)
                if manifest is not None
                else []; },
            extract_globals_func=lambda (
                manifest: any, module: any
            ) -> dict[str, any] { return {}; },
            compiled_dir=proj / "compiled"
        );
        (exports, _) = jcc.compile(None, main);
        written = (proj / "compiled" / "shared.js").read_text(encoding="utf-8");
        helper_emitted = (proj / "compiled" / "helper.js").is_file();
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    assert "function avatar_of(" in written , written;
    assert "function name_of(" in written , (
        "shared.js must carry name_of, which the second page pulls through mid.jac "
        + f"after the first page wrote the module; got:\n{written}"
    );
    assert "name_of" in exports;
    assert helper_emitted , (
        "helper.js must be emitted: shared.js imports it only after the second page "
        "grew the module, so no earlier walk reached it"
    );
}
