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
    decorator_warnings = [
        w
        for w in warning_msgs
        if "@classmethod" in w or "@staticmethod" in w
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

test "redundant typing imports warn on the import line" {
    file_path = os.path.join(FIXTURES, "redundant_typing_imports.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);

    w1103 = [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == "W1103"
    ];
    w1104 = [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == "W1104"
    ];

    # Three ambient names imported plain:
    #   Callable, Mapping  -- from `typing` (typing re-exports the abc names)
    #   Iterable           -- from `collections.abc` (canonical source)
    # Aliased Callable (as Cb), non-ambient cast and TYPE_CHECKING must not warn.
    assert len(w1103) == 3 , f"Expected 3 W1103 warnings (Callable, Mapping, Iterable), got: {[
        str(w) for w in w1103
    ]}";
    w1103_msgs = [w.msg for w in w1103];
    assert any("'Callable'" in m and "'typing'" in m for m in w1103_msgs) , f"Expected W1103 for Callable from typing, got: {w1103_msgs}";
    assert any("'Mapping'" in m and "'typing'" in m for m in w1103_msgs) , f"Expected W1103 for Mapping from typing, got: {w1103_msgs}";
    assert any("'Iterable'" in m and "'collections.abc'" in m for m in w1103_msgs) , f"Expected W1103 for Iterable from collections.abc (proves per-module registry), got: {w1103_msgs}";

    # Any gets a distinct W1104 pointing at the lowercase 'any' builtin.
    assert len(w1104) == 1 , f"Expected 1 W1104 warning for Any, got: {[
        str(w) for w in w1104
    ]}";
    assert "any" in w1104[0].msg , f"Expected W1104 message to mention lowercase 'any', got: {w1104[
        0
    ].msg}";

    # cast and TYPE_CHECKING are runtime, not ambient -- must not trip either warning.
    runtime_only_warns = [
        w
        for w in (w1103 + w1104)
        if "'cast'" in w.msg or "'TYPE_CHECKING'" in w.msg
    ];
    assert len(runtime_only_warns) == 0 , f"runtime-only typing names should not warn, got: {[
        str(w) for w in runtime_only_warns
    ]}";

    # No errors should be produced.
    error_msgs = [str(e) for e in prog.errors_had];
    assert len(error_msgs) == 0 , f"Expected no errors, got: {error_msgs}";
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
