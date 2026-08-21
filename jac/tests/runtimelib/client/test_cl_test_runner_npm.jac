"""Project-aware npm resolution in the cl test runner.

Each bare specifier resolves through ordered tiers -- mock, `@jac/*` virtual
module, then a universal Proxy stub -- materialized as a generated tsconfig.
"""

import json;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.cl_test_runner {
    ClImportPlan,
    module_is_client,
    run_cl_test_file,
    _mock_sources_for,
    _render_tsconfig,
    _report_stubbed,
    _resolve_relative_source,
    _scan_import_specs,
    _scan_relative_specs
}
import from jaclang.project.config { get_config }
import jaclang.project.config as config_mod;

glob FIXTURES = Path(__file__).parent / "fixtures";

test "the scanner classifies every import form exactly" {
    src = 'import { widget, tool as t } from "pkg-named";\n'
        + 'import def from "pkg-default";\n'
        + 'import mixed, { extra } from "pkg-mixed";\n'
        + 'import * as ns from "pkg-ns";\n'
        + 'import "pkg-side/theme.css";\n'
        + 'export { helper } from "pkg-reexport";\n'
        + 'export * from "pkg-star";\n'
        + 'export * as bundled from "pkg-star-as";\n'
        + 'const lazy = await import("pkg-dynamic");\n'
        + 'const cjs = require("pkg-require");\n'
        + 'import { join } from "node:path";\n'
        + 'import { bt } from "bun:test";\n'
        + 'import { near } from "./local.js";\n'
        + 'import { far } from "../shared/label.js";\n';

    expected = {
        "pkg-named": {"named": {"tool", "widget"}, "default": False, "star": False},
        "pkg-default": {"named": set(), "default": True, "star": False},
        "pkg-mixed": {"named": {"extra"}, "default": True, "star": False},
        "pkg-ns": {"named": set(), "default": False, "star": False},
        "pkg-side/theme.css": {"named": set(), "default": False, "star": False},
        "pkg-reexport": {"named": {"helper"}, "default": False, "star": False},
        "pkg-star": {"named": set(), "default": False, "star": True},
        "pkg-star-as": {"named": set(), "default": False, "star": False},
        "pkg-dynamic": {"named": set(), "default": False, "star": False},
        "pkg-require": {"named": set(), "default": False, "star": False}
    };
    assert _scan_import_specs(src) == expected , f"classification drifted: {_scan_import_specs(
        src
    )}";
    assert _scan_relative_specs(src) == ["../shared/label.js", "./local.js"];
}

test "the generated tsconfig maps every spec and nothing else" {
    # A bare "*" mapping makes bun silently no-op: exit 0, nothing executed.
    paths = {
        "vscode": "./__mocks__/vscode.js",
        "@scope/pkg": "./__mocks__/@scope/pkg.js",
        "react": "./__jac_npm_stub.js"
    };
    doc = json.loads(_render_tsconfig(paths));
    assert doc
        == {
            "compilerOptions": {
                "baseUrl": ".",
                "paths": {
                    "@scope/pkg": ["./__mocks__/@scope/pkg.js"],
                    "react": ["./__jac_npm_stub.js"],
                    "vscode": ["./__mocks__/vscode.js"]
                }
            }
        } , f"tsconfig shape drifted: {doc}";
}

test "mocks come from the convention, and config entries win over it" {
    with TemporaryDirectory() as td {
        Path(td, "jac.toml").write_text(
            '[project]\nname = "x"\n\n[test.client.mocks]\n'
                + 'vscode = "doubles/editor.js"\n',
            encoding="utf-8"
        );
        scoped = Path(td, "tests", "__mocks__", "@scope");
        scoped.mkdir(parents=True);
        (scoped / "pkg.jac").write_text("glob:pub A = 1;\n", encoding="utf-8");
        Path(td, "tests", "__mocks__", "vscode.js").write_text("export const a=1;\n");
        Path(td, "tests", "__mocks__", "plain.js").write_text("export const b=2;\n");
        Path(td, "doubles").mkdir();
        Path(td, "doubles", "editor.js").write_text("export const c=3;\n");
        found = _mock_sources_for(str(Path(td, "test_x.jac")));
        assert sorted(found.keys()) == ["@scope/pkg", "plain", "vscode"] , f"got {sorted(
            found.keys()
        )}";
        assert found["@scope/pkg"].endswith("tests/__mocks__/@scope/pkg.jac");
        assert found["plain"].endswith("tests/__mocks__/plain.js");
        assert found["vscode"].endswith("doubles/editor.js") , (
            f"the config entry lost to the convention: {found['vscode']}"
        );
    }
    assert _mock_sources_for(str(FIXTURES / "cl_npm" / "test_npm_only.jac")) == {};
    assert _mock_sources_for(None) == {};
}

test "a bad [test.client.mocks] entry says which entry and why" {
    def reject(rel: str, make: bool) -> str {
        with TemporaryDirectory() as td {
            Path(td, "jac.toml").write_text(
                '[project]\nname = "x"\n\n[test.client.mocks]\n'
                    + f'vscode = "{rel}"\n',
                encoding="utf-8"
            );
            if make {
                target = Path(td, rel);
                target.parent.mkdir(parents=True, exist_ok=True);
                target.write_text("export const a=1;\n");
            }
            try {
                _mock_sources_for(str(Path(td, "test_x.jac")));
            } except Exception as exc {
                return str(exc).replace(td, "<proj>");
            }
            return "";
        }
    }

    missing = reject("doubles/missing.js", False);
    assert "vscode" in missing , f"error did not name the spec: {missing}";
    assert "doubles/missing.js" in missing , f"error did not name the path: {missing}";
    assert "<proj>" in missing , f"error did not name the search dir: {missing}";

    wrong = reject("doubles/editor.ts", True);
    assert "vscode" in wrong , f"error did not name the spec: {wrong}";
    assert ".js or .jac" in wrong , f"error did not explain the suffix rule: {wrong}";
}

test "a mock's relative imports resolve the way node would" {
    with TemporaryDirectory() as td {
        base = Path(td, "tests", "__mocks__");
        (base / "support").mkdir(parents=True);
        (base / "vscode.js").write_text("export const w=1;\n");
        (base / "esm.mjs").write_text("export const m=1;\n");
        (base / "legacy.cjs").write_text("module.exports={};\n");
        (base / "support" / "ids.js").write_text("export const n=1;\n");
        (base / "support" / "ids").mkdir();
        (base / "support" / "ids" / "index.js").write_text("export const bad=1;\n");
        (base / "pkgdir").mkdir();
        (base / "pkgdir" / "index.js").write_text("export const p=1;\n");
        here = str(base);
        def resolved(spec: str) -> str {
            found = _resolve_relative_source(here, spec);
            assert found is not None , f"{spec} did not resolve";
            return str(Path(found).relative_to(Path(here).resolve()).as_posix());
        }
        assert resolved("./vscode.js") == "vscode.js";
        assert resolved("./esm") == "esm.mjs" , "an .mjs sibling must resolve";
        assert resolved("./legacy") == "legacy.cjs" , "a .cjs sibling must resolve";
        assert resolved("./support/ids") == "support/ids.js" , (
            "a file must win over a same-named directory index"
        );
        assert resolved("./pkgdir") == "pkgdir/index.js" , "a directory index must resolve";
        assert _resolve_relative_source(here, "./nope") is None;
    }
}

test "on_stub escalates from note to failure, and names what needs a mock" {
    def report_with(setting: str, stubbed: list, starred: list) -> str {
        plan = ClImportPlan();
        plan.stubbed = stubbed;
        plan.star_stubbed = starred;
        with TemporaryDirectory() as td {
            Path(td, "jac.toml").write_text(
                '[project]\nname = "x"\n\n[test.client]\n' + f'on_stub = "{setting}"\n',
                encoding="utf-8"
            );
            try {
                _report_stubbed(str(Path(td, "test_x.jac")), plan);
            } except Exception as exc {
                return str(exc);
            }
            return "";
        }
    }

    assert report_with("note", ["react"], []) == "" , "note must not raise";
    assert report_with("warn", ["react"], []) == "" , "warn must not raise";

    raised = report_with("error", ["react", "zod"], []);
    assert "react" in raised and "zod" in raised , f"stubbed specs unnamed: {raised}";

    starred = report_with("error", ["pkg-a", "pkg-b"], ["pkg-a"]);
    assert "export * from" in starred , f"no export-star guidance: {starred}";
    assert "pkg-a" in starred , f"the starred spec went unnamed: {starred}";

    assert report_with("error", [], []) == "" , "a fully resolved run must stay silent";
    _report_stubbed(None, ClImportPlan());
}

test "a profile-supplied on_stub reaches the runner" {
    # `jac test --profile ci` overlays onto the process config without marking
    # it explicit; reading [test.client] off disk would ignore the profile.
    plan = ClImportPlan();
    plan.stubbed = ["react"];
    with TemporaryDirectory() as td {
        Path(td, "jac.toml").write_text(
            '[project]\nname = "x"\n\n[test.client]\non_stub = "note"\n\n'
                + '[environments.ci.test.client]\non_stub = "error"\n',
            encoding="utf-8"
        );
        config_mod._config = None;
        config_mod._config_explicit = False;
        config_mod._config_by_root = {};
        cfg = get_config(start_path=Path(td), force_discover=True);
        assert cfg is not None;
        cfg.apply_profile_overlay("ci");
        caught = "";
        try {
            _report_stubbed(str(Path(td, "test_x.jac")), plan);
        } except Exception as exc {
            caught = str(exc);
        }
        config_mod._config = None;
        config_mod._config_by_root = {};
        assert "react" in caught , f"the profile's on_stub was ignored: {caught}";
    }
}

test "a client test importing only an npm module runs under bun" {
    # Regression guard: npm handling used to sit inside the `@jac/runtime`
    # branch, so a test with no backend import never reached it.
    fixture = str(FIXTURES / "cl_npm" / "test_npm_only.jac");
    assert module_is_client(fixture) , f"{fixture} is not in the client codespace";
    results = run_cl_test_file(fixture);
    assert results , "cl test runner discovered no client tests";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "mocked modules behave while unmapped ones keep the proxy" {
    fixture = str(FIXTURES / "cl_npm_mock" / "test_mocked.jac");
    results = run_cl_test_file(fixture);
    assert len(results) == 4 , f"expected 4 client tests, got {len(results)}";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "a mock may re-export, side-effect import, and carry its own files" {
    fixture = str(FIXTURES / "cl_npm_forms" / "test_forms.jac");
    results = run_cl_test_file(fixture);
    assert len(results) == 2 , f"expected 2 client tests, got {len(results)}";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "__mocks__ modules are not collected as tests themselves" {
    import from jaclang.runtimelib.test_runner { _under_support_dir }
    assert _under_support_dir(
        os.sep.join(["", "p", "tests", "__mocks__", "vscode.jac"])
    );
    assert _under_support_dir(os.sep.join(["", "p", "tests", "fixtures", "thing.jac"]));
    assert not _under_support_dir(os.sep.join(["", "p", "tests", "test_real.jac"]));
}
