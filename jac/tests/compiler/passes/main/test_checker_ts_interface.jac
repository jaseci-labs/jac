"""Type checker tests for structural TS interface mapping.

An imported `.d.ts` `interface` is synthesized into a structural ClassType so
that field access resolves with real types (autocomplete + type checking),
instead of collapsing to a foreign `any`. Uses the shared npm harness in
checker_npm_harness.jac (issue #7152).
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from typing { cast }
import from .checker_npm_harness {
    check_npm_file,
    make_iface_npm_project,
    pretty_checker_errors
}

test "interface field access resolves with correct types" {
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
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
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , f"Interface field access should type-check cleanly, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "whole-object assignment of a synthetic interface stays lenient" {
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "lenient.cl.jac";
        # A synthetic interface *value* (source) flowing into a mismatched Jac
        # annotation must NOT error (Phase 4-v1 src-side gradual typing),
        # replicating the foreign-any suppressor it replaces. Member access
        # (proven precise in the sibling tests) is unaffected.
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub use() -> str {\n'
            '    x: str = getConfig();\n'
            '    return x;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , f"Whole-object assignment of a synthetic interface should be "
        f"lenient, got {len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(
            program
        )}";
    }
}

test "assigning a concrete Jac value into a synthetic interface annotation errors" {
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "dest_strict.cl.jac";
        # Dest-side synthetic annotations must still reject incompatible Jac
        # values (str/int into Config). Leniency is only for external sources.
        f.write_text(
            'cl import from "cfgpkg" { Config }\n\n'
            'def:pub bad() -> None {\n'
            '    c: Config = "hello";\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) > 0 , f"Expected a type error assigning str into Config, got none";
        assert any(c in ("E1001", "E1002", "E1035") for c in err_codes) , f"Expected an assignment type error, got codes {err_codes}:\n{pretty_checker_errors(
            program
        )}";
    }
}

test "interface imported directly as a type annotation resolves fields" {
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
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
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , f"Interface used directly as an annotation should resolve, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "an any-typed interface field flows gradually like untyped JS" {
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
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
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , f"An any-typed interface field should flow gradually, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "accessing a nonexistent interface field errors" {
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "bad.cl.jac";
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub bad() -> str {\n'
            '    c = getConfig();\n'
            '    return c.nonexistent_field;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert "E1030" in err_codes , f"Expected E1030 (no attribute) for a bogus field, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}
