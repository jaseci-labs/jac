"""Type checker tests for client `cl` npm imports (issue #7152).

Coverage for the full npm-import typing stack:

1. Resolution -- installed packages resolve from `.jac/client/node_modules`,
   including modern exports-map-only packages (conditions, no main/module).
2. Declaration ingestion -- packages that ship `.d.ts` type as their real
   declared types (a `(...) => string` import returns `str`), so jac-shadcn's
   generated `cn()` checks clean with zero diagnostics and misuse of a typed
   import is a genuine error.
3. Gradual fallback -- packages without declarations type as a *foreign* any
   (W1102) that flows gradually, like untyped JS in TypeScript.
4. Strict knob -- `[check] untyped-external = "error"` escalates the untyped
   fallback to E1120.
5. Cascade suppression -- a W1100 missing-module Unknown no longer escalates
   into hard E1002 errors downstream.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.modresolver {
    resolve_client_npm_package,
    resolve_client_npm_declarations
}

"""Materialize a client project with installed npm packages.

- clsx: classic package (main/module + exports with types condition + d.ts)
- tailwind-merge: exports-map-only package (no main/module) with typed d.ts
- untyped-pkg: package with no declarations at all
- @scoped/tool: scoped package, types via @types/scoped__tool

Returns the project root.
"""
def _make_npm_client_project(proj_dir: Path, strict: bool = False) -> Path {
    node_modules = proj_dir / ".jac" / "client" / "node_modules";

    clsx_dir = node_modules / "clsx";
    (clsx_dir / "dist").mkdir(parents=True, exist_ok=True);
    (clsx_dir / "package.json").write_text(
        '{"name":"clsx","version":"2.1.1",'
        '"exports":{".":{"types":"./clsx.d.mts","import":"./dist/clsx.mjs",'
        '"default":"./dist/clsx.js"}},'
        '"main":"dist/clsx.js","module":"dist/clsx.mjs","types":"clsx.d.mts"}'
    );
    (clsx_dir / "dist" / "clsx.mjs").write_text("export function clsx() {}\n");
    (clsx_dir / "dist" / "clsx.js").write_text(
        "module.exports.clsx = function () {};\n"
    );
    (clsx_dir / "clsx.d.mts").write_text(
        "export type ClassValue = ClassArray | ClassDictionary | string | number"
        " | bigint | null | boolean | undefined;\n"
        "export type ClassDictionary = Record<string, any>;\n"
        "export type ClassArray = ClassValue[];\n"
        "export declare function clsx(...inputs: ClassValue[]): string;\n"
        "export default clsx;\n"
    );

    tw_dir = node_modules / "tailwind-merge";
    (tw_dir / "dist").mkdir(parents=True, exist_ok=True);
    (tw_dir / "package.json").write_text(
        '{"name":"tailwind-merge","version":"2.5.0",'
        '"exports":{".":{"types":"./dist/types.d.ts",'
        '"import":"./dist/bundle-mjs.mjs"}}}'
    );
    (tw_dir / "dist" / "bundle-mjs.mjs").write_text("export function twMerge() {}\n");
    (tw_dir / "dist" / "types.d.ts").write_text(
        "declare const twMerge: (...classLists: Array<string | undefined | null"
        " | false>) => string;\n"
        "export { twMerge };\n"
    );

    untyped_dir = node_modules / "untyped-pkg";
    untyped_dir.mkdir(parents=True, exist_ok=True);
    (untyped_dir / "package.json").write_text(
        '{"name":"untyped-pkg","version":"1.0.0","main":"index.js"}'
    );
    (untyped_dir / "index.js").write_text("module.exports.mystery = function () {};\n");

    scoped_dir = node_modules / "@scoped" / "tool";
    scoped_dir.mkdir(parents=True, exist_ok=True);
    (scoped_dir / "package.json").write_text(
        '{"name":"@scoped/tool","version":"1.0.0","main":"index.js"}'
    );
    (scoped_dir / "index.js").write_text("module.exports.run = function () {};\n");
    at_types_dir = node_modules / "@types" / "scoped__tool";
    at_types_dir.mkdir(parents=True, exist_ok=True);
    (at_types_dir / "index.d.ts").write_text(
        "export declare function run(cmd: string): number;\n"
    );

    strict_block = '\n[check]\nuntyped-external = "error"\n' if strict else '';
    (proj_dir / "jac.toml").write_text(
        '[project]\nname = "npmfixture"\nversion = "0.1.0"\n'
        'entry-point = "lib/utils.cl.jac"\n\n'
        '[dependencies.npm]\nclsx = "^2.1.1"\ntailwind-merge = "^2.5.0"\n' + strict_block
    );

    (proj_dir / "lib").mkdir(parents=True, exist_ok=True);
    return proj_dir;
}

def _check_file(path: Path) -> tuple[JacProgram, list[str], list[str]] {
    program = JacProgram();
    mod = program.compile(str(path));
    TypeCheckPass(ir_in=mod, prog=program);
    err_codes = [
        e.code.code
        for e in program.errors_had
        if e.code is not None
    ];
    warn_codes = [
        w.code.code
        for w in program.warnings_had
        if w.code is not None
    ];
    return (program, err_codes, warn_codes);
}

def _pretty(program: JacProgram) -> str {
    return "\n".join([e.pretty_print() for e in program.errors_had]);
}

test "generated cn() type-checks cleanly against declared npm types" {
    with TemporaryDirectory() as td {
        proj = _make_npm_client_project(Path(td));
        util = proj / "lib" / "utils.cl.jac";
        util.write_text(
            'cl import from "clsx" { clsx }\n'
            'cl import from "tailwind-merge" { twMerge }\n\n'
            'def:pub cn(*inputs: any) -> str {\n'
            '    return twMerge(clsx(inputs));\n'
            '}\n'
        );
        (program, err_codes, warn_codes) = _check_file(util);
        assert len(program.errors_had) == 0 , f"Expected no errors, got: {_pretty(
            program
        )}";
        # With .d.ts declarations ingested the imports are *typed*, not
        # foreign-any: no W1100 (resolution) and no W1102 (untyped fallback).
        assert "W1100" not in warn_codes , f"npm packages must resolve, codes={warn_codes}";
        assert "W1102" not in warn_codes , "declared npm imports must not fall back to foreign any, "
        f"codes={warn_codes}";
    }
}

test "declared npm types are real: misuse is a genuine type error" {
    with TemporaryDirectory() as td {
        proj = _make_npm_client_project(Path(td));
        bad = proj / "lib" / "misuse.cl.jac";
        bad.write_text(
            'cl import from "clsx" { clsx }\n\n'
            'def:pub bad() -> int {\n'
            '    return clsx("a");\n'
            '}\n'
        );
        (program, err_codes, _) = _check_file(bad);
        # clsx's d.ts declares `(...inputs) => string`; returning it as int
        # must fail -- proving declared types flow, not just gradual any.
        assert "E1002" in err_codes , f"str->int misuse of a declared npm import must error, got "
        f"codes={err_codes}:\n{_pretty(program)}";
    }
}

test "undeclared npm imports stay gradual with W1102" {
    with TemporaryDirectory() as td {
        proj = _make_npm_client_project(Path(td));
        f = proj / "lib" / "untyped.cl.jac";
        f.write_text(
            'cl import from "untyped-pkg" { mystery }\n\n'
            'def:pub use() -> str {\n'
            '    return mystery(1);\n'
            '}\n'
        );
        (program, err_codes, warn_codes) = _check_file(f);
        assert len(program.errors_had) == 0 , f"foreign any must flow gradually, got: {_pretty(
            program
        )}";
        assert "W1102" in warn_codes , f"untyped fallback must warn W1102, codes={warn_codes}";
    }
}

test "strict knob escalates untyped external imports to E1120" {
    with TemporaryDirectory() as td {
        proj = _make_npm_client_project(Path(td), strict=True);
        f = proj / "lib" / "untyped.cl.jac";
        f.write_text(
            'cl import from "untyped-pkg" { mystery }\n\n'
            'def:pub use() -> str {\n'
            '    return mystery(1);\n'
            '}\n'
        );
        (program, err_codes, _) = _check_file(f);
        assert "E1120" in err_codes , '[check] untyped-external = "error" must escalate to E1120, '
        f"got codes={err_codes}";
        # Declared imports are unaffected by strict mode.
        ok = proj / "lib" / "ok.cl.jac";
        ok.write_text(
            'cl import from "clsx" { clsx }\n\n'
            'def:pub c() -> str {\n'
            '    return clsx("a");\n'
            '}\n'
        );
        (program2, err_codes2, _) = _check_file(ok);
        assert len(program2.errors_had) == 0 , f"declared imports must pass strict mode: {_pretty(
            program2
        )}";
    }
}

test "missing module warns W1100 without cascading E1002" {
    with TemporaryDirectory() as td {
        proj = _make_npm_client_project(Path(td));
        f = proj / "lib" / "missing.cl.jac";
        f.write_text(
            'cl import from "not-installed-pkg" { ghost }\n\n'
            'def:pub g() -> str {\n'
            '    return ghost();\n'
            '}\n'
        );
        (program, err_codes, warn_codes) = _check_file(f);
        assert "W1100" in warn_codes , f"missing module must warn W1100, codes={warn_codes}";
        assert "E1002" not in err_codes , "the already-diagnosed missing-module Unknown must not "
        f"re-escalate into E1002, got codes={err_codes}:\n{_pretty(program)}";
    }
}

test "npm resolver handles exports maps, scoped packages, and @types" {
    with TemporaryDirectory() as td {
        proj = _make_npm_client_project(Path(td));
        base = str(proj / "lib" / "x.cl.jac");
        # Classic package: ESM module entry preferred via exports "import".
        clsx_entry = resolve_client_npm_package("clsx", base);
        assert clsx_entry is not None and clsx_entry.endswith("clsx.mjs") , f"clsx entry: {clsx_entry}";
        # Exports-map-only package (no main/module fallback available).
        tw_entry = resolve_client_npm_package("tailwind-merge", base);
        assert tw_entry is not None and tw_entry.endswith("bundle-mjs.mjs") , f"tailwind-merge entry: {tw_entry}";
        # Declarations via exports "types" condition.
        clsx_dts = resolve_client_npm_declarations("clsx", base);
        assert clsx_dts is not None and clsx_dts.endswith("clsx.d.mts") , f"clsx dts: {clsx_dts}";
        tw_dts = resolve_client_npm_declarations("tailwind-merge", base);
        assert tw_dts is not None and tw_dts.endswith("types.d.ts") , f"tw dts: {tw_dts}";
        # Scoped package resolves; its declarations come from @types/scoped__tool.
        scoped_entry = resolve_client_npm_package("@scoped/tool", base);
        assert scoped_entry is not None and scoped_entry.endswith("index.js") , f"scoped entry: {scoped_entry}";
        scoped_dts = resolve_client_npm_declarations("@scoped/tool", base);
        assert scoped_dts is not None
        and scoped_dts.endswith(os.path.join("@types", "scoped__tool", "index.d.ts")) , f"scoped dts: {scoped_dts}";
        # Negative cases.
        assert resolve_client_npm_package("not-installed", base) is None;
        assert resolve_client_npm_package("./local", base) is None;
        assert resolve_client_npm_declarations("untyped-pkg", base) is None;
    }
}
