"""Static analysis pass tests."""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "static_analysis"
     );

test "unused variable produces warning" {
    file_path = os.path.join(FIXTURES, "unused_var.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("'x' is defined but never used" in w for w in warning_msgs) , f"Expected unused variable warning for 'x', got: {warning_msgs}";
}

test "used variables produce no warnings" {
    file_path = os.path.join(FIXTURES, "used_var.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unused_warnings = [
        w
        for w in warning_msgs
        if "defined but never used" in w
    ];
    assert len(unused_warnings) == 0 , f"Expected no unused variable warnings, got: {unused_warnings}";
}

test "skip patterns produce no warnings" {
    file_path = os.path.join(FIXTURES, "skip_patterns.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unused_warnings = [
        w
        for w in warning_msgs
        if "defined but never used" in w
    ];
    assert len(unused_warnings) == 0 , f"Expected no warnings for skip patterns, got: {unused_warnings}";
}

test "unreachable code after return" {
    file_path = os.path.join(FIXTURES, "unreachable_after_return.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("Unreachable" in w for w in warning_msgs) , f"Expected unreachable code warning, got: {warning_msgs}";
}

test "all reachable code produces no unreachable warnings" {
    file_path = os.path.join(FIXTURES, "all_reachable.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unreachable_warnings = [
        w
        for w in warning_msgs
        if "Unreachable" in w
    ];
    assert len(unreachable_warnings) == 0 , f"Expected no unreachable warnings, got: {unreachable_warnings}";
}

test "impl file warnings: undefined name and unreachable code are reported" {
    file_path = os.path.join(FIXTURES, "impl_checks.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("'bad_name' may be undefined" in w for w in warning_msgs) , f"Expected undefined name warning from impl file, got: {warning_msgs}";
    assert any("Unreachable" in w for w in warning_msgs) , f"Expected unreachable code warning from impl file, got: {warning_msgs}";
}

test "by-llm ability params produce no unused warnings" {
    file_path = os.path.join(FIXTURES, "genai_ability_params.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unused_warnings = [
        w
        for w in warning_msgs
        if "defined but never used" in w
    ];
    assert len(unused_warnings) == 0 , f"Expected no unused warnings for by-llm params, got: {unused_warnings}";
}

test "classmethod and staticmethod on obj produce warnings" {
    file_path = os.path.join(FIXTURES, "classmethod_on_obj.jac");
    prog = JacProgram();
    prog.compile(file_path);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("@classmethod" in w and "'obj'" in w for w in warning_msgs) , f"Expected @classmethod warning for obj, got: {warning_msgs}";
    assert any("@staticmethod" in w and "'obj'" in w for w in warning_msgs) , f"Expected @staticmethod warning for obj, got: {warning_msgs}";
}

test "classmethod and staticmethod on class produce no warnings" {
    file_path = os.path.join(FIXTURES, "classmethod_on_class.jac");
    prog = JacProgram();
    prog.compile(file_path);
    warning_msgs = [str(w) for w in prog.warnings_had];
    # W2006/W2007 (semantic analysis) skip Python `class`; W3001 (lint) still
    # suggests `static` for @staticmethod and must not be counted here.
    decorator_warnings = [
        w
        for w in warning_msgs
        if "not recommended" in w and ("@classmethod" in w or "@staticmethod" in w)
    ];
    assert len(decorator_warnings) == 0 , f"Expected no decorator warnings for class, got: {decorator_warnings}";
}

test "classmethod on node warns with correct archetype name" {
    file_path = os.path.join(FIXTURES, "classmethod_on_node.jac");
    prog = JacProgram();
    prog.compile(file_path);
    warning_msgs = [str(w) for w in prog.warnings_had];
    assert any("@classmethod" in w and "'node'" in w for w in warning_msgs) , f"Expected @classmethod warning mentioning 'node', got: {warning_msgs}";
}

test "cl def has variables reassigned in nested abilities produce no unused warnings" {
    file_path = os.path.join(FIXTURES, "cl_def_has_var.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unused_warnings = [
        w
        for w in warning_msgs
        if "defined but never used" in w
    ];
    assert len(unused_warnings) == 1 , f"Expected exactly 1 unused warning (for var in nested def), got: {unused_warnings}";
    assert "'var' is defined but never used" in unused_warnings[0] , f"Expected warning for 'var', got: {unused_warnings[
        0
    ]}";
}

test "ambient typing names resolve without import" {
    file_path = os.path.join(FIXTURES, "ambient_typing.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    error_msgs = [str(e) for e in prog.errors_had];
    typing_names = ["Callable", "Mapping", "Sequence", "Iterable", "Protocol"];
    for tname in typing_names {
        undef = [
            w
            for w in warning_msgs
            if f"'{tname}' may be undefined" in w
        ];
        assert len(undef) == 0 , f"{tname} should be ambient: got {undef}";
    }
    assert len(error_msgs) == 0 , f"Expected no errors, got: {error_msgs}";
    py_code = prog.compile(file_path).gen.py;
    assert py_code is not None , "Expected Python codegen to succeed";
    assert "from typing import" in py_code , f"Expected typing import auto-injected, got:\n{py_code[:500]}";
    for tname in typing_names {
        assert tname in py_code , f"Expected {tname} in injected typing import";
    }
}

test "ambient typing names resolve in .impl.jac annex files" {
    # Ambient typing names (Callable, Sequence, ...) are injected into the
    # module's parent (builtins) scope by the TypeEvaluator, so _check_undefined_names
    # suppresses W2001 for them via the parent-scope check. This fixture pair
    # exercises that path across both the decl signature and the .impl.jac body,
    # and also confirms the guard does not over-suppress: a genuinely undefined
    # name referenced in the same .impl.jac annex still produces W2001.
    file_path = os.path.join(FIXTURES, "ambient_typing_impl.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    error_msgs = [str(e) for e in prog.errors_had];
    for tname in ["Callable", "Sequence"] {
        undef = [
            w
            for w in warning_msgs
            if f"'{tname}' may be undefined" in w
        ];
        assert len(undef) == 0 , f"{tname} should be ambient in .impl.jac: got {undef}";
    }
    # Negative control: genuinely undefined names in .impl.jac still warn.
    bad = [
        w
        for w in warning_msgs
        if "'totally_undefined_thing' may be undefined" in w
    ];
    assert len(bad) > 0 , "genuinely undefined name in .impl.jac should still warn (W2001)";
    assert len(error_msgs) == 0 , f"Expected no errors, got: {error_msgs}";
}

test "ambient-name imports are refused on the import line with E1125" {
    file_path = os.path.join(FIXTURES, "redundant_typing_imports.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);

    e1125 = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E1125"
    ];
    # Three ambient names imported plain:
    #   Callable, Mapping  -- from `typing` (typing re-exports the abc names)
    #   Iterable           -- from `collections.abc` (canonical source)
    # Aliased Callable (as Cb), non-ambient cast and TYPE_CHECKING must not fire.
    assert len(e1125) == 3 , f"Expected 3 E1125 errors (Callable, Mapping, Iterable), got: {[
        str(e) for e in e1125
    ]}";
    e1125_msgs = [e.msg for e in e1125];
    assert any("'Callable'" in m and "'typing'" in m for m in e1125_msgs) , f"Expected E1125 for Callable from typing, got: {e1125_msgs}";
    assert any("'Mapping'" in m and "'typing'" in m for m in e1125_msgs) , f"Expected E1125 for Mapping from typing, got: {e1125_msgs}";
    assert any("'Iterable'" in m and "'collections.abc'" in m for m in e1125_msgs) , f"Expected E1125 for Iterable from collections.abc (proves per-module registry), got: {e1125_msgs}";

    # cast and TYPE_CHECKING are runtime, not ambient -- must not trip the refusal.
    runtime_only = [
        e
        for e in e1125
        if "'cast'" in e.msg or "'TYPE_CHECKING'" in e.msg
    ];
    assert len(runtime_only) == 0 , f"runtime-only typing names should not be refused, got: {[
        str(e) for e in runtime_only
    ]}";

    # The advisory tier is fully vacated outside the bootstrap tree.
    w1103 = [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == "W1103"
    ];
    assert len(w1103) == 0 , f"W1103 must not fire where E1125 does, got: {[
        str(w) for w in w1103
    ]}";
}

test "bootstrap-compiled modules keep the ambient-import advisory" {
    # jac0.py resolves names solely through real imports: for the modules it
    # compiles (jaclang/jac0core/), an ambient-name import is load-bearing, so
    # the escalation carves them out -- W1103 stays advisory there, E1125 never
    # fires. The predicate is path-shaped; pin its boundary on both sides.
    import from jaclang.compiler.passes.main.static_analysis_pass {
        is_bootstrap_compiled_module
    }
    assert is_bootstrap_compiled_module("/repo/jac/jaclang/jac0core/runtime.jac");
    assert is_bootstrap_compiled_module(
        "/repo/jac/jaclang/jac0core/passes/uni_pass.jac"
    );
    assert is_bootstrap_compiled_module(
        "C:\\repo\\jac\\jaclang\\jac0core\\runtime.jac"
    );
    assert not is_bootstrap_compiled_module(
        "/repo/jac/jaclang/compiler/passes/main/layout_pass.jac"
    );
    assert not is_bootstrap_compiled_module("/repo/apps/jac0core/module.jac");
    assert not is_bootstrap_compiled_module("");
}

test "the ambient provider module keeps its typing imports" {
    # jaclang/runtimelib/builtin.jac is the runtime side of the ambient set,
    # and its own typing imports are its export surface: JcirGenPass routes
    # synthesized names (builtin_name('ClassVar'), 'override',
    # 'abstractmethod') through `from jaclang.runtimelib.builtin import ...`,
    # which resolves only because builtin.jac imports those names itself.
    # Stripping them breaks every module whose codegen wraps a static field in
    # ClassVar. The predicate mirrors JcirGenPass.exit_module's
    # is_builtin_module test exactly.
    import from jaclang.compiler.passes.main.static_analysis_pass {
        is_ambient_provider_module
    }
    assert is_ambient_provider_module("/repo/jac/jaclang/runtimelib/builtin.jac");
    assert is_ambient_provider_module("/x/jaclang/runtimelib/builtin.py");
    assert not is_ambient_provider_module("/repo/jac/jaclang/runtimelib/server.jac");
    assert not is_ambient_provider_module("/repo/apps/builtin.jac");
    assert not is_ambient_provider_module("");
}

test "every import shape binding typing.Any is refused with E1122" {
    file_path = os.path.join(FIXTURES, "typing_any_refused.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);

    e1122 = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E1122"
    ];

    # Four binding shapes in the fixture: lone `{ Any }`, `Any` inside a
    # multi-name list, the `as` alias (which the retired W1104 skipped), and a
    # multi-line list. Each is one refusal, pointed at the `Any` name itself.
    assert len(e1122) == 4 , f"Expected 4 E1122 errors (plain, in-list, as-alias, multi-line), got: {[
        str(e) for e in e1122
    ]}";

    # The remedy has to be in the message the author reads, not just the help.
    for e in e1122 {
        assert "any" in e.msg , f"E1122 must name jac's builtin `any`, got: {e.msg}";
    }

    # Only `Any` is refused -- the rest of typing stays importable.
    other_refusals = [
        e
        for e in prog.errors_had
        if e.code is not None
            and e.code.code == "E1122"
            and (
                "Optional" in str(e)
                or "Callable" in str(e)
                or "cast" in str(e)
                or "TYPE_CHECKING" in str(e)
            )
    ];
    assert len(other_refusals) == 0 , f"Only 'Any' may be refused, got: {[
        str(e) for e in other_refusals
    ]}";
}

test "module-form typing.Any stays legal as the reflection escape hatch" {
    file_path = os.path.join(FIXTURES, "typing_any_module_form.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);

    e1122 = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E1122"
    ];
    assert len(e1122) == 0 , f"`import typing;` + `typing.Any` binds no bare 'Any' and must not be refused, got: {[
        str(e) for e in e1122
    ]}";
}

test "every import shape binding a deprecated typing alias is refused with E1123" {
    file_path = os.path.join(FIXTURES, "typing_alias_refused.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);

    e1123 = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E1123"
    ];

    # Six deprecated names across five statements: a lone `{ List }`, `Dict`
    # inside a multi-name list, the `as` alias, `Set`+`FrozenSet` from one
    # statement, and `Type`. Each is one refusal, pointed at the name itself.
    assert len(e1123) == 6 , f"Expected 6 E1123 errors (List, Dict, Tuple-as-alias, Set, FrozenSet, Type), got: {[
        str(e) for e in e1123
    ]}";

    # The remedy has to be in the message the author reads, not just the help.
    refused = {};
    for e in e1123 {
        for (alias, builtin) in [
            ("List", "list"),
            ("Dict", "dict"),
            ("Tuple", "tuple"),
            ("Set", "set"),
            ("FrozenSet", "frozenset"),
            ("Type", "type")
        ] {
            if f"'{alias}'" in e.msg {
                refused[alias] = e.msg;
                assert f"`{builtin}`" in e.msg , f"E1123 for '{alias}' must name the builtin `{builtin}`, got: {e.msg}";
            }
        }
    }
    assert len(refused) == 6 , f"Every deprecated alias must be named in its own message, got: {sorted(
        refused.keys()
    )}";

    # `FrozenSet` must not be mistaken for `Set`: the longer name owns its own
    # remedy, and a substring match would hand it `set` instead of `frozenset`.
    assert "`frozenset`" in refused["FrozenSet"] , f"FrozenSet must map to `frozenset`, got: {refused[
        'FrozenSet'
    ]}";

    # Only the deprecated aliases are refused -- the rest of typing stays importable.
    other_refusals = [
        e
        for e in e1123
        if "Optional" in str(e) or "Callable" in str(e) or "cast" in str(e)
    ];
    assert len(other_refusals) == 0 , f"Only deprecated aliases may be refused, got: {[
        str(e) for e in other_refusals
    ]}";
}

test "module-form typing.List stays legal as the runtime-object escape hatch" {
    file_path = os.path.join(FIXTURES, "typing_alias_module_form.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);

    e1123 = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E1123"
    ];
    assert len(e1123) == 0 , f"`import typing;` + `typing.List` binds no bare alias and must not be refused, got: {[
        str(e) for e in e1123
    ]}";
}

test "lowercase boolean and null literals carry a did-you-mean hint" {
    # Issue #6357: `true`/`false`/`null`/`none` parse as undefined names. The
    # W2001 warning must point the author at the right Python-style literal
    # (`True`/`False`/`None`) so a common cross-language slip is a one-line fix
    # instead of a confusing "Cannot return <Unknown>" dead end.
    file_path = os.path.join(FIXTURES, "lowercase_bool_literals.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    w2001 = [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == "W2001"
    ];

    def hint_for(name: str) -> (str | None) {
        for w in w2001 {
            if f"'{name}'" in w.msg {
                return w.help_text;
            }
        }
        return None;
    }

    true_hint = hint_for("true");
    false_hint = hint_for("false");
    null_hint = hint_for("null");
    none_hint = hint_for("none");

    assert true_hint is not None and "True" in true_hint , f"Expected 'did you mean True' hint for `true`, got: {true_hint!r} (all W2001: {[
        str(w) for w in w2001
    ]})";
    assert false_hint is not None and "False" in false_hint , f"Expected 'did you mean False' hint for `false`, got: {false_hint!r}";
    assert null_hint is not None and "None" in null_hint , f"Expected 'did you mean None' hint for `null`, got: {null_hint!r}";
    assert none_hint is not None and "None" in none_hint , f"Expected 'did you mean None' hint for `none`, got: {none_hint!r}";
}

test "obj bare assignment to has var name still warns as unused" {
    file_path = os.path.join(FIXTURES, "obj_bare_has_assign.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warning_msgs = [str(w) for w in prog.warnings_had];
    unused_warnings = [
        w
        for w in warning_msgs
        if "defined but never used" in w
    ];
    assert len(unused_warnings) > 0 , "Expected unused variable warning for bare 'x' in obj method, got none";
}
