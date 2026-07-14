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
import from jaclang.jac0core.modresolver {
    resolve_client_npm_package,
    resolve_client_npm_declarations
}
import from .checker_npm_harness {
    check_npm_file,
    make_npm_client_project,
    pretty_checker_errors
}

test "generated cn() type-checks cleanly against declared npm types" {
    with TemporaryDirectory() as td {
        proj = make_npm_client_project(Path(td));
        util = proj / "lib" / "utils.cl.jac";
        util.write_text(
            'cl import from "clsx" { clsx }\n'
            'cl import from "tailwind-merge" { twMerge }\n\n'
            'def:pub cn(*inputs: any) -> str {\n'
            '    return twMerge(clsx(inputs));\n'
            '}\n'
        );
        (program, err_codes, warn_codes) = check_npm_file(util);
        assert len(program.errors_had) == 0 , f"Expected no errors, got: {pretty_checker_errors(
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
        proj = make_npm_client_project(Path(td));
        bad = proj / "lib" / "misuse.cl.jac";
        bad.write_text(
            'cl import from "clsx" { clsx }\n\n'
            'def:pub bad() -> int {\n'
            '    return clsx("a");\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(bad);
        # clsx's d.ts declares `(...inputs) => string`; returning it as int
        # must fail -- proving declared types flow, not just gradual any.
        assert "E1002" in err_codes , f"str->int misuse of a declared npm import must error, got "
        f"codes={err_codes}:\n{pretty_checker_errors(program)}";
    }
}

test "undeclared npm imports stay gradual with W1102" {
    with TemporaryDirectory() as td {
        proj = make_npm_client_project(Path(td));
        f = proj / "lib" / "untyped.cl.jac";
        f.write_text(
            'cl import from "untyped-pkg" { mystery }\n\n'
            'def:pub use() -> str {\n'
            '    return mystery(1);\n'
            '}\n'
        );
        (program, err_codes, warn_codes) = check_npm_file(f);
        assert len(program.errors_had) == 0 , f"foreign any must flow gradually, got: {pretty_checker_errors(
            program
        )}";
        assert "W1102" in warn_codes , f"untyped fallback must warn W1102, codes={warn_codes}";
    }
}

test "strict knob escalates untyped external imports to E1120" {
    with TemporaryDirectory() as td {
        proj = make_npm_client_project(Path(td), strict=True);
        f = proj / "lib" / "untyped.cl.jac";
        f.write_text(
            'cl import from "untyped-pkg" { mystery }\n\n'
            'def:pub use() -> str {\n'
            '    return mystery(1);\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
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
        (program2, err_codes2, _) = check_npm_file(ok);
        assert len(program2.errors_had) == 0 , f"declared imports must pass strict mode: {pretty_checker_errors(
            program2
        )}";
    }
}

test "missing module warns W1100 without cascading E1002" {
    with TemporaryDirectory() as td {
        proj = make_npm_client_project(Path(td));
        f = proj / "lib" / "missing.cl.jac";
        f.write_text(
            'cl import from "not-installed-pkg" { ghost }\n\n'
            'def:pub g() -> str {\n'
            '    return ghost();\n'
            '}\n'
        );
        (program, err_codes, warn_codes) = check_npm_file(f);
        assert "W1100" in warn_codes , f"missing module must warn W1100, codes={warn_codes}";
        assert "E1002" not in err_codes , "the already-diagnosed missing-module Unknown must not "
        f"re-escalate into E1002, got codes={err_codes}:\n{pretty_checker_errors(
            program
        )}";
    }
}

test "npm resolver handles exports maps, scoped packages, and @types" {
    with TemporaryDirectory() as td {
        proj = make_npm_client_project(Path(td));
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
