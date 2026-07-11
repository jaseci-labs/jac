"""Type checker tests for class modifiers and overload degradation.

Guards the synthesis-side fixes for:
- static/private/protected members being mis-modeled as public instance fields
  (they are now skipped rather than exposed on the synthesized instance)
- duplicate method signatures (overloads) collapsing to the last (wrong)
  signature (they now degrade to foreign any)

Uses the shared npm harness in checker_npm_harness.jac.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from typing { cast }
import from .checker_npm_harness {
    check_npm_file,
    make_modifiers_npm_project,
    pretty_checker_errors
}

test "static private and protected members are not exposed on the instance" {
    # Regression: parse_members used to discard modifiers and synthesize every
    # member as a public instance field, so `static version`, `private secret`,
    # and `protected internal` were all reachable on instances. They are now
    # skipped; only the public instance `value` resolves.
    with TemporaryDirectory() as td {
        proj = make_modifiers_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "app.cl.jac";
        f.write_text(
            'cl import from "modpkg" { getWidget }\n\n'
            'def:pub use() -> None {\n'
            '    w = getWidget();\n'
            '    v: str = w.value;\n'
            '    a = w.version;\n'
            '    b = w.secret;\n'
            '    c = w.internal;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        # value (public instance) resolves cleanly; the skipped
        # static/private/protected members are absent and each access reports
        # E1030 (no attribute) -- and nothing else.
        assert err_codes.count("E1030") == 3 , (
            f"Expected 3 E1030 errors for skipped members, got {err_codes}:\n"
            f"{pretty_checker_errors(program)}"
        );
        assert all(c == "E1030" for c in err_codes) , (
            f"Expected only E1030 errors, got {err_codes}:\n"
            f"{pretty_checker_errors(program)}"
        );
    }
}

test "overloaded methods degrade to any instead of picking the wrong signature" {
    # Regression: duplicate method/property names overwrote each other during
    # synthesis, collapsing `get` to the last signature (get(x: number):
    # number). That made `a.get("x")` raise an argument-type error and
    # `s: str = a.get("x")` raise an assignment error. Degrading to foreign
    # any keeps both overload call sites gradual (no false positives).
    with TemporaryDirectory() as td {
        proj = make_modifiers_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "over.cl.jac";
        f.write_text(
            'cl import from "modpkg" { getApi }\n\n'
            'def:pub use() -> None {\n'
            '    a = getApi();\n'
            '    s: str = a.get("x");\n'
            '    n: float = a.get(1);\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , (
            f"Expected no errors for degraded overloads, got {err_codes}:\n"
            f"{pretty_checker_errors(program)}"
        );
    }
}
