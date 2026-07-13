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
    make_generic_npm_project,
    make_cyclic_npm_project,
    make_callable_npm_project,
    make_degrade_npm_project,
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
            '    extra_val: float = d.extra;\n'
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

test "interface method call type-checks with correct argument types" {
    # Regression for issue where the .d.ts parser captured method signatures
    # but the synthesizer dropped them, so `c.onChange("x")` errored with
    # E1030 ("Type Config has no attribute onChange"). Methods now synthesize
    # as FunctionType members of the structural class symbol table.
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "method_ok.cl.jac";
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub use() -> str {\n'
            '    c = getConfig();\n'
            '    c.onChange("ready");\n'
            '    greeting: str = c.greet("world");\n'
            '    return greeting;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Interface method call should type-check cleanly, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "interface method call with a wrong argument type errors" {
    # A method's parameters are real, not any: passing a number where a string
    # is declared must raise an argument-type error. Guards against the method
    # signature silently collapsing to a callable-any.
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "method_bad_arg.cl.jac";
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub bad() -> None {\n'
            '    c = getConfig();\n'
            '    c.onChange(5);\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) > 0 , "Expected an argument-type error calling onChange with a number, got none";
        assert "E1030" not in err_codes , f"Method onChange should be resolvable (no E1030), got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "interface method return type is checked, not any" {
    # The declared return type flows precisely: `greet` returns `string`, so
    # assigning its result into a `float` must error (the return is not any).
    with TemporaryDirectory() as td {
        proj = make_iface_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "method_ret_bad.cl.jac";
        f.write_text(
            'cl import from "cfgpkg" { getConfig }\n\n'
            'def:pub bad() -> None {\n'
            '    c = getConfig();\n'
            '    n: float = c.greet("world");\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) > 0 , "Expected a type error assigning greet's string result into a float, got none";
        assert any(c in ("E1001", "E1002", "E1035") for c in err_codes) , f"Expected an assignment type error, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "optional recursive interface field narrows to its real member type" {
    # `Node.parent?: Node` resolves to `Node | None` (not foreign any), so a
    # None-narrow recovers the real `Node` and `parent.value` is a `number`.
    with TemporaryDirectory() as td {
        proj = make_relational_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "opt_ok.cl.jac";
        f.write_text(
            'cl import from "relpkg" { getHead }\n\n'
            'def:pub use() -> float {\n'
            '    n = getHead();\n'
            '    p = n.parent;\n'
            '    if p is not None {\n'
            '        v: float = p.value;\n'
            '        return v;\n'
            '    }\n'
            '    return 0.0;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Optional recursive field should narrow to its real Node type, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "accessing through an optional interface field without narrowing errors" {
    # Regression guard: an optional interface reference must NOT collapse to
    # foreign any. `parent` is `Node | None`, so a bare `parent.nope` is a
    # nullable-deref error (E1099); `parent` itself stays a recognized member
    # (no E1030). If this regressed to any, the access would pass silently.
    with TemporaryDirectory() as td {
        proj = make_relational_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "opt_bad.cl.jac";
        f.write_text(
            'cl import from "relpkg" { getHead }\n\n'
            'def:pub bad() -> str {\n'
            '    n = getHead();\n'
            '    return n.parent.nope;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) > 0 , "Optional interface field should not collapse to any; expected an error, got none";
        assert "E1099" in err_codes , f"Expected E1099 (nullable attribute access) for parent.nope, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
        assert "E1030" not in err_codes , f"`parent` must be a recognized member (no E1030), got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "generic heritage degrades gracefully to gradual any" {
    # `Derived extends Base<string>` is documented degradation: the type
    # argument is dropped, so `Base<T>`'s `id: T` resolves to gradual `any`
    # (assignable to str), while Derived's own `extra` stays a precise number.
    with TemporaryDirectory() as td {
        proj = make_generic_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "gen_ok.cl.jac";
        f.write_text(
            'cl import from "genpkg" { getDerived }\n\n'
            'def:pub use() -> str {\n'
            '    d = getDerived();\n'
            '    extra_val: float = d.extra;\n'
            '    s: str = d.id;\n'
            '    return s;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Generic heritage should degrade gracefully (id -> any), got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "generic-derived synthetic class still rejects unknown fields" {
    # Even though the type argument degrades, the structural class symbol
    # table stays precise: a field that is neither inherited nor declared
    # must raise E1030 (guards against the whole interface collapsing to any).
    with TemporaryDirectory() as td {
        proj = make_generic_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "gen_bad.cl.jac";
        f.write_text(
            'cl import from "genpkg" { getDerived }\n\n'
            'def:pub bad() -> str {\n'
            '    d = getDerived();\n'
            '    return d.totallybogus;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert "E1030" in err_codes , f"Expected E1030 for a bogus field on a generic-derived interface, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "cyclic interface heritage degrades without crashing" {
    # `CycA extends CycB` and `CycB extends CycA` is a heritage cycle, which
    # is impossible in real Jac archetypes but reachable from arbitrary .d.ts
    # input. The synthesizer must break the cycle so C3 linearization
    # terminates (previously: RecursionError) and own members still resolve.
    with TemporaryDirectory() as td {
        proj = make_cyclic_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "cyc_ok.cl.jac";
        f.write_text(
            'cl import from "cycpkg" { getCycA }\n\n'
            'def:pub use() -> float {\n'
            '    x = getCycA();\n'
            '    n: float = x.a;\n'
            '    return n;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Cyclic heritage should degrade without crashing; own member must resolve. Got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "callable interface is callable with a typed return and keeps its fields" {
    # `interface Handler { (x: string): number; label: string; }` carries a
    # call signature synthesized as `__call__`, so the instance is callable
    # with a float (number) return while `label` stays a precise str.
    with TemporaryDirectory() as td {
        proj = make_callable_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "call_ok.cl.jac";
        f.write_text(
            'cl import from "callpkg" { getHandler }\n\n'
            'def:pub use() -> float {\n'
            '    h = getHandler();\n'
            '    n: float = h("x");\n'
            '    s: str = h.label;\n'
            '    return n;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "Callable interface should call cleanly with a typed return and str field. Got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "index-signature interface synthesizes no fields, so keyed access errors" {
    # `interface Dict { [key: string]: number }` has only an index signature,
    # which is not modeled. The synthesized class has no members, so any keyed
    # access raises E1030 rather than resolving to a number. Documents the
    # degradation (index signatures are unsupported) instead of pretending the
    # value is a precise map.
    with TemporaryDirectory() as td {
        proj = make_degrade_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "idx.cl.jac";
        f.write_text(
            'cl import from "degpkg" { getDict }\n\n'
            'def:pub bad() -> None {\n'
            '    d = getDict();\n'
            '    x = d.anything;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert "E1030" in err_codes , f"Expected E1030 for keyed access on an index-signature interface, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "an implicit-any interface member flows gradually" {
    # `loose;` has no type annotation (implicit any). Like an explicit `any`
    # member, it resolves to a foreign any and flows into a concrete-typed
    # local, while a sibling annotated member stays precise.
    with TemporaryDirectory() as td {
        proj = make_degrade_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "loose.cl.jac";
        f.write_text(
            'cl import from "degpkg" { getCfg }\n\n'
            'def:pub use() -> str {\n'
            '    c = getCfg();\n'
            '    s: str = c.loose;\n'
            '    return c.theme;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) == 0 , "An implicit-any member should flow gradually, got "
        f"{len(program.errors_had)} diagnostic(s):\n{pretty_checker_errors(program)}";
    }
}

test "an abstract class synthesizes like a normal structural class" {
    # `declare abstract class Base` is synthesized structurally: `abstract` is
    # transparent, so a declared field resolves precisely while a bogus field
    # still raises exactly one E1030.
    with TemporaryDirectory() as td {
        proj = make_degrade_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "abs.cl.jac";
        f.write_text(
            'cl import from "degpkg" { getBase }\n\n'
            'def:pub use() -> str {\n'
            '    b = getBase();\n'
            '    n: str = b.name;\n'
            '    z = b.nope;\n'
            '    return n;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert err_codes.count("E1030") == 1 , f"Expected exactly one E1030 (only the bogus field) on an abstract class, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "merged interface declarations do not combine members" {
    # TS declaration merging (`interface Merged` declared twice) is not
    # supported: only one block's members survive synthesis, so a field from
    # the other block raises E1030. Documents the limitation rather than
    # silently exposing a partial union.
    with TemporaryDirectory() as td {
        proj = make_degrade_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "merge.cl.jac";
        f.write_text(
            'cl import from "degpkg" { getMerged }\n\n'
            'def:pub bad() -> None {\n'
            '    m = getMerged();\n'
            '    x = m.a;\n'
            '    y = m.b;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert "E1030" in err_codes , f"Expected E1030 from an unmerged declaration's field, got codes {err_codes}:"
        f"\n{pretty_checker_errors(program)}";
    }
}

test "callable interface enforces its call-signature return type" {
    # The `__call__` return is `number` -> float, so assigning it to a str
    # must be rejected -- proving the call signature is modeled with a real
    # type rather than dropped to gradual any.
    with TemporaryDirectory() as td {
        proj = make_callable_npm_project(Path(cast(str, td)));
        f = proj / "lib" / "call_bad.cl.jac";
        f.write_text(
            'cl import from "callpkg" { getHandler }\n\n'
            'def:pub bad() -> str {\n'
            '    h = getHandler();\n'
            '    s: str = h("x");\n'
            '    return s;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert len(program.errors_had) > 0 , "Assigning a float call-return to a str must error; got none:"
        f"\n{pretty_checker_errors(program)}";
    }
}
