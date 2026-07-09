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
    make_relational_npm_project,
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
        assert len(program.errors_had) == 0 , "Interface field access should type-check cleanly, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "whole-object assignment of a synthetic interface to an unrelated type errors" {
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "strict_src.cl.jac";
        # Synthetic interface values keep precise field types; whole-object
        # assignment into an unrelated Jac annotation must fail (unlike the
        # old foreign-any suppressor). Member access and matching annotations
        # remain valid in the sibling tests.
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub use() -> str {\n'
            '    x: str = getConfig();\n'
            '    return x;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) > 0 , "Expected a type error assigning Config into str, got none";
        assert any(c in ("E1001", "E1002", "E1035") for c in err_codes) , f"Expected an assignment type error, got codes {err_codes}:\n{pretty_checker_errors(
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
        assert len(program.errors_had) > 0 , "Expected a type error assigning str into Config, got none";
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
        assert len(program.errors_had) == 0 , "Interface used directly as an annotation should resolve, got "
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
        assert len(program.errors_had) == 0 , "An any-typed interface field should flow gradually, got "
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

test "cross-interface field keeps the sibling interface's real type" {
    with TemporaryDirectory() as td {
        proj = make_relational_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "sibling_ok.cl.jac";
        # `Parent.child` references sibling `Child`. Before the shell-threading
        # fix this collapsed to foreign `any`; now `child.name` resolves to a
        # real `string`.
        f.write_text(
            'cl import from "relpkg" { getParent }\n\n'
            'def:pub use() -> str {\n'
            '    p = getParent();\n'
            '    name: str = p.child.name;\n'
            '    return name;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Sibling interface field should resolve with its real type, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "cross-interface bogus field through a sibling ref errors" {
    with TemporaryDirectory() as td {
        proj = make_relational_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "sibling_bad.cl.jac";
        # The key regression guard: with the old foreign-`any` collapse this
        # produced no error at all. Now `child` is the real `Child` shell, so a
        # bogus attribute must raise E1030.
        f.write_text(
            'cl import from "relpkg" { getParent }\n\n'
            'def:pub bad() -> str {\n'
            '    p = getParent();\n'
            '    return p.child.nope;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert "E1030" in err_codes , f"Expected E1030 for a bogus field through a sibling ref, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "recursive interface field resolves with its own type" {
    with TemporaryDirectory() as td {
        proj = make_relational_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "rec_ok.cl.jac";
        # `Node.next` is typed `Node` (self-reference). It must resolve to the
        # shell instance, so `next.value` is a real `number`.
        f.write_text(
            'cl import from "relpkg" { getHead }\n\n'
            'def:pub use() -> float {\n'
            '    n = getHead();\n'
            '    v: float = n.next.value;\n'
            '    return v;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Recursive interface field should resolve with its own type, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "recursive interface field bogus access errors" {
    with TemporaryDirectory() as td {
        proj = make_relational_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "rec_bad.cl.jac";
        f.write_text(
            'cl import from "relpkg" { getHead }\n\n'
            'def:pub bad() -> str {\n'
            '    n = getHead();\n'
            '    return n.next.nope;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert "E1030" in err_codes , f"Expected E1030 for a bogus field through a recursive ref, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "array of interface refs resolves element field types" {
    with TemporaryDirectory() as td {
        proj = make_relational_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "arr_ok.cl.jac";
        # `Parent.children` is `Child[]`. Subscripting yields the real `Child`
        # element type, so `children[0].name` is a `string`. Exercises the
        # array branch of _map_ts_type with threaded shells.
        f.write_text(
            'cl import from "relpkg" { getParent }\n\n'
            'def:pub use() -> str {\n'
            '    p = getParent();\n'
            '    first = p.children[0];\n'
            '    name: str = first.name;\n'
            '    return name;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Array element interface field should resolve, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "interface field typed via a typealias resolves" {
    with TemporaryDirectory() as td {
        proj = make_relational_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "alias_ok.cl.jac";
        # `Holder.wrapped` is typed via `type Wrapped = Child`. The typealias
        # resolution path must also thread shells so `wrapped.name` resolves to
        # a `string`.
        f.write_text(
            'cl import from "relpkg" { getHolder }\n\n'
            'def:pub use() -> str {\n'
            '    h = getHolder();\n'
            '    name: str = h.wrapped.name;\n'
            '    return name;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Typealias-to-interface field should resolve, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}
