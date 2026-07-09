"""Type checker tests for structural TS interface mapping.

An imported `.d.ts` `interface` is synthesized into a structural ClassType so
that field access resolves with real types (autocomplete + type checking),
instead of collapsing to a foreign `any`. Mirrors the npm-project harness in
test_checker_npm_imports.jac (issue #7152).
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

"""Materialize a client project with one npm package shipping interface d.ts."""
def _make_iface_project(proj_dir: Path) -> Path {
    node_modules = proj_dir / ".jac" / "client" / "node_modules";
    pkg = node_modules / "cfgpkg";
    (pkg / "dist").mkdir(parents=True, exist_ok=True);
    (pkg / "package.json").write_text(
        '{"name":"cfgpkg","version":"1.0.0",'
        '"exports":{".":{"types":"./dist/index.d.ts",'
        '"import":"./dist/index.mjs"}}}'
    );
    (pkg / "dist" / "index.mjs").write_text(
        "export function getConfig() {}\nexport function getDerived() {}\n"
    );
    (pkg / "dist" / "index.d.ts").write_text(
        "export interface Config {\n"
        "    theme: string;\n"
        "    retries: number;\n"
        "    debug?: boolean;\n"
        "    tags: string[];\n"
        "    payload: any;\n"
        "}\n"
        "export interface Base { id: string; }\n"
        "export interface Derived extends Base { extra: number; }\n"
        "export declare function getConfig(): Config;\n"
        "export declare function getDerived(): Derived;\n"
    );
    (proj_dir / "jac.toml").write_text(
        '[project]\nname = "ifacefixture"\nversion = "0.1.0"\n'
        'entry-point = "lib/app.cl.jac"\n\n'
        '[dependencies.npm]\ncfgpkg = "^1.0.0"\n'
    );
    (proj_dir / "lib").mkdir(parents=True, exist_ok=True);
    return proj_dir;
}

def _check(path: Path) -> tuple[JacProgram, list[str]] {
    program = JacProgram();
    mod = program.compile(str(path));
    TypeCheckPass(ir_in=mod, prog=program);
    codes = [
        e.code.code
        for e in program.errors_had
        if e.code is not None
    ];
    return (program, codes);
}

def _pretty(program: JacProgram) -> str {
    return "\n".join([e.pretty_print() for e in program.errors_had]);
}

test "interface field access resolves with correct types" {
    with TemporaryDirectory() as td {
        proj = _make_iface_project(Path(td));
        f = proj / "lib" / "app.cl.jac";
        f.write_text(
            'cl import from "cfgpkg" { getConfig, getDerived }\n\n'
            'def:pub use() -> str {\n'
            '    c = getConfig();\n'
            '    theme: str = c.theme;\n'
            '    retries: float = c.retries;\n'
            '    d = getDerived();\n'
            '    inherited: str = d.id;\n'
            '    own: float = d.extra;\n'
            '    return theme;\n'
            '}\n'
        );
        (program, codes) = _check(f);
        assert len(program.errors_had) == 0 , f"Interface field access should type-check cleanly, got "
        f"{len(program.errors_had)} diagnostic(s):\n{_pretty(program)}";
    }
}

test "whole-object assignment of a synthetic interface stays lenient" {
    with TemporaryDirectory() as td {
        proj = _make_iface_project(Path(td));
        f = proj / "lib" / "lenient.cl.jac";
        # A synthetic interface value flowing across a whole-object boundary
        # into a mismatched annotation must NOT error (Phase 4-v1 leniency),
        # replicating the foreign-any suppressor it replaces. Member access
        # (proven precise in the sibling tests) is unaffected.
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub use() -> str {\n'
            '    x: str = getConfig();\n'
            '    return x;\n'
            '}\n'
        );
        (program, codes) = _check(f);
        assert len(program.errors_had) == 0 , f"Whole-object assignment of a synthetic interface should be "
        f"lenient, got {len(program.errors_had)} diagnostic(s):\n{_pretty(program)}";
    }
}

test "interface imported directly as a type annotation resolves fields" {
    with TemporaryDirectory() as td {
        proj = _make_iface_project(Path(td));
        f = proj / "lib" / "annot.cl.jac";
        # Config is imported and used directly as an annotation (type position),
        # not just inferred from a return type. Field access on the annotated
        # local must resolve precisely.
        f.write_text(
            'cl import from "cfgpkg" { getConfig, Config }\n\n'
            'def:pub use() -> str {\n'
            '    c: Config = getConfig();\n'
            '    theme: str = c.theme;\n'
            '    return theme;\n'
            '}\n'
        );
        (program, codes) = _check(f);
        assert len(program.errors_had) == 0 , f"Interface used directly as an annotation should resolve, got "
        f"{len(program.errors_had)} diagnostic(s):\n{_pretty(program)}";
    }
}

test "an any-typed interface field flows gradually like untyped JS" {
    with TemporaryDirectory() as td {
        proj = _make_iface_project(Path(td));
        f = proj / "lib" / "gradual.cl.jac";
        # `payload: any` resolves to a *foreign* any (not the opaque `object`
        # that rejects everything), so it flows gradually into a concrete-typed
        # local -- the same gradualness untyped external JS values get. Access
        # itself is precise (a bogus field still errors; see below).
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub use() -> str {\n'
            '    c = getConfig();\n'
            '    s: str = c.payload;\n'
            '    return s;\n'
            '}\n'
        );
        (program, codes) = _check(f);
        assert len(program.errors_had) == 0 , f"An any-typed interface field should flow gradually, got "
        f"{len(program.errors_had)} diagnostic(s):\n{_pretty(program)}";
    }
}

test "accessing a nonexistent interface field errors" {
    with TemporaryDirectory() as td {
        proj = _make_iface_project(Path(td));
        f = proj / "lib" / "bad.cl.jac";
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub bad() -> str {\n'
            '    c = getConfig();\n'
            '    return c.nonexistent_field;\n'
            '}\n'
        );
        (program, codes) = _check(f);
        assert "E1030" in codes , f"Expected E1030 (no attribute) for a bogus field, got codes {codes}:"
        f"\n{_pretty(program)}";
    }
}
