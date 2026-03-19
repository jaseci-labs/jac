"""Test suite for all missing diagnostics identified in the gap analysis.

Covers 145 new diagnostic codes across 8 categories:
  - Phase 1: Lexer (E0110-E0117)
  - Phase 2: Parser / Syntax (E0052-E0078)
  - Phase 3: Name Resolution / Scope (E/W 2020-2037)
  - Phase 4: Type System (E/W 1100-1183)
  - Phase 5: Semantic Analysis (E/W 2040-2087)
  - Phase 6: Lint (W3020-W3037)
  - Phase 7: Import (E/W 4001-4010)
  - Phase 8: Codegen (E/W 5080-5083)

Each test calls pytest.skip() until its diagnostic is implemented.
Tests are organized to match the implementation milestones in
_planning/diagnostics_implementation_progress.md.
"""

import os;
import from pathlib { Path }
import pytest;
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.parser.parser { parse }
import from jaclang.runtimelib.test { parametrize }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "checker"
     ),
     NEW_DIAG_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "new_diagnostics"
     );

# ──────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────
def assert_error_pretty_found(needle: str, haystack: str) {
    for line in [
        line.strip()
        for line in needle.splitlines()
        if line.strip()
    ] {
        assert line in haystack , f"Expected line '{line}' not found in:\n{haystack}";
    }
}

"""Compile a fixture with type checking and static analysis. Returns (program, module)."""
def compile_and_check(fixture_name: str) -> tuple {
    path = os.path.join(NEW_DIAG_FIXTURES, fixture_name);
    program = JacProgram();
    mod = program.compile(path, type_check=True);
    return (program, mod);
}

"""Compile a fixture without type checking. Returns (program, module)."""
def compile_only(fixture_name: str) -> tuple {
    path = os.path.join(NEW_DIAG_FIXTURES, fixture_name);
    program = JacProgram();
    mod = program.compile(path);
    return (program, mod);
}

"""Parse source string, return (has_errors: bool, program: JacProgram)."""
def parse_and_validate(source: str) -> tuple {
    try {
        (module, had_error) = parse(source, "/tmp/test.jac");
        if had_error or module is None {
            return (True, None);
        }
        prog = JacProgram();
        ASTValidationPass(ir_in=module, prog=prog);
        return (len(prog.errors_had) > 0, prog);
    } except Exception {
        return (True, None);
    }
}

"""Check that a diagnostic with a specific code was emitted."""
def has_diagnostic_code(
    program: JacProgram, code: str, in_warnings: bool = False
) -> bool {
    alerts = program.warnings_had if in_warnings else program.errors_had;
    for alert in alerts {
        if alert.code is not None and alert.code.code == code {
            return True;
        }
    }
    return False;
}

"""Count diagnostics with a specific code."""
def count_diagnostic_code(
    program: JacProgram, code: str, in_warnings: bool = False
) -> int {
    alerts = program.warnings_had if in_warnings else program.errors_had;
    count = 0;
    for alert in alerts {
        if alert.code is not None and alert.code.code == code {
            count += 1;
        }
    }
    return count;
}


# ══════════════════════════════════════════════════════════════════
#  PHASE 1: LEXER DIAGNOSTICS (E0110-E0117)
#  Infrastructure: None required
#  Milestone: 4 (Parser/Lexer Hardening)
# ══════════════════════════════════════════════════════════════════
test "E0110: invalid numeric literal" {
    pytest.skip("E0110 not yet implemented");
    (has_err, _) = parse_and_validate('with entry { x = 0b102; }');
    assert has_err;
}

test "E0111: invalid escape sequence" {
    pytest.skip("E0111 not yet implemented");
    (has_err, prog) = parse_and_validate('with entry { x = "hello\\q"; }');
    assert has_err;
}

test "E0112: octal escape warning" {
    pytest.skip("E0112 not yet implemented");
    (_, prog) = parse_and_validate('with entry { x = "\\177"; }');
    assert prog is not None and has_diagnostic_code(prog, "E0112", in_warnings=True);
}

test "E0113: unicode escape out of range" {
    pytest.skip("E0113 not yet implemented");
    (has_err, _) = parse_and_validate('with entry { x = "\\U00110000"; }');
    assert has_err;
}

test "E0114: digit separator in invalid position" {
    pytest.skip("E0114 not yet implemented");
    (has_err, _) = parse_and_validate('with entry { x = 1__0; }');
    assert has_err;
}

test "E0115: confusable unicode in identifier" {
    pytest.skip("E0115 not yet implemented");
    # Cyrillic 'а' (U+0430) looks like Latin 'a'
    (has_err, _) = parse_and_validate('with entry { \u0430 = 5; }');
    assert has_err;
}

test "E0116: BOM in source file" {
    pytest.skip("E0116 not yet implemented");
    (_, prog) = parse_and_validate('\ufeffwith entry { x = 1; }');
    assert prog is not None and has_diagnostic_code(prog, "E0116", in_warnings=True);
}

test "E0117: mixed tabs and spaces" {
    pytest.skip("E0117 not yet implemented");
    (_, prog) = parse_and_validate("with entry {\n\t x = 1;\n}");
    assert prog is not None and has_diagnostic_code(prog, "E0117", in_warnings=True);
}


# ══════════════════════════════════════════════════════════════════
#  PHASE 2: PARSER / SYNTAX DIAGNOSTICS (E0052-E0078)
#  Infrastructure: INFRA-8 for E0055-E0058
#  Milestone: 1 (Context Validity) + 4 (Parser/Lexer Hardening)
# ══════════════════════════════════════════════════════════════════
test "E0052: missing type annotation on parameter" {
    (has_err, prog) = parse_and_validate('def foo(x) { }');
    assert has_err or (prog is not None and has_diagnostic_code(prog, "E0052"));
}

test "E0052: missing type annotation on multiple params" {
    (has_err, prog) = parse_and_validate('def foo(x, y) { }');
    assert has_err or (prog is not None and count_diagnostic_code(prog, "E0052") == 2);
}

test "E0052: typed parameter is valid" {
    (has_err, _) = parse_and_validate('def foo(x: int) -> int { return x; }');
    assert not has_err;
}

test "E0052: lambda params do not require annotations" {
    (has_err, _) = parse_and_validate('with entry { f = lambda x: x + 1; }');
    assert not has_err;
}

test "E0052: method self param requires annotation" {
    (has_err, _) = parse_and_validate(
        'obj Foo { def bar(self: Foo, x: int) -> int { return x; } }'
    );
    assert not has_err;
}

test "E0053: duplicate *args" {
    pytest.skip("E0053 not yet implemented");
    (has_err, _) = parse_and_validate('def foo(*a: int, *b: str) { }');
    assert has_err;
}

test "E0055: yield outside function" {
    (has_err, prog) = parse_and_validate('with entry { yield 5; }');
    assert has_err or (prog is not None and has_diagnostic_code(prog, "E0055"));
}

test "E0056: await outside async function" {
    pytest.skip("E0056 not yet implemented — needs INFRA-8");
    (has_err, _) = parse_and_validate(
        'import from asyncio { sleep }\ndef foo() { await sleep(1); }'
    );
    assert has_err;
}

test "E0058: break outside loop" {
    (has_err, prog) = parse_and_validate('with entry { break; }');
    assert has_err or (prog is not None and has_diagnostic_code(prog, "E0058"));
}

test "E0058: continue outside loop" {
    (has_err, prog) = parse_and_validate('with entry { continue; }');
    assert has_err or (prog is not None and has_diagnostic_code(prog, "E0058"));
}

test "E0058: break inside loop is valid" {
    (has_err, _) = parse_and_validate('with entry { for i in [1,2] { break; } }');
    assert not has_err;
}

test "E0059: invalid assignment target" {
    pytest.skip("E0059 not yet implemented");
    (has_err, _) = parse_and_validate('with entry { 1 + 2 = x; }');
    assert has_err;
}

test "E0065: duplicate keyword argument" {
    (prog, _) = compile_and_check("parser_E0065_duplicate_kwarg.jac");
    assert has_diagnostic_code(prog, "E0065");
}

test "E0066: positional after keyword argument" {
    (prog, _) = compile_and_check("parser_E0066_pos_after_kw.jac");
    assert has_diagnostic_code(prog, "E0066");
}

test "E0069: decorator on invalid statement" {
    pytest.skip("E0069 not yet implemented");
    (has_err, _) = parse_and_validate('with entry { @foo x = 5; }');
    assert has_err;
}

test "E0070: duplicate decorator" {
    pytest.skip("E0070 not yet implemented");
    (has_err, prog) = parse_and_validate('@staticmethod\n@staticmethod\ndef foo() { }');
    assert has_err
    or (prog is not None and has_diagnostic_code(prog, "E0070", in_warnings=True));
}

test "E0071: bare except not last" {
    (has_err, prog) = parse_and_validate(
        'with entry { try { x=1; } except { y=2; } except ValueError as e { z=3; } }'
    );
    assert has_err or (prog is not None and has_diagnostic_code(prog, "E0071"));
}

test "E0075: duplicate base class" {
    (has_err, prog) = parse_and_validate('obj Base { }\nobj Bad(Base, Base) { }');
    assert has_err or (prog is not None and has_diagnostic_code(prog, "E0075"));
}

test "E0076: duplicate method definition" {
    pytest.skip("E0076 not yet implemented");
    (prog, _) = compile_and_check("parser_E0076_duplicate_method.jac");
    assert has_diagnostic_code(prog, "E0076");
}

test "E0077: empty f-string expression" {
    pytest.skip("E0077 not yet implemented");
    (has_err, _) = parse_and_validate('with entry { x = f"hello {}"; }');
    assert has_err;
}

test "E0062: nonlocal at module level" {
    (has_err, prog) = parse_and_validate('with entry { nonlocal x; }');
    assert has_err or (prog is not None and has_diagnostic_code(prog, "E0062"));
}


# ══════════════════════════════════════════════════════════════════
#  PHASE 3: NAME RESOLUTION / SCOPE DIAGNOSTICS (E/W 2020-2037)
#  Infrastructure: INFRA-5 (shadowing), INFRA-6 (imports), INFRA-1 (def-use)
#  Milestone: 2 (Symbol Shadowing) + 6 (Import Graph)
# ══════════════════════════════════════════════════════════════════
test "E2020: use before definition" {
    pytest.skip("E2020 not yet implemented — needs INFRA-1/INFRA-5");
    (prog, _) = compile_and_check("scope_E2020_use_before_def.jac");
    assert has_diagnostic_code(prog, "E2020");
}

test "E2022: circular import" {
    pytest.skip("E2022 not yet implemented — needs INFRA-6");
    (prog, _) = compile_only("import_E4001_circular.jac");
    assert has_diagnostic_code(prog, "E4001") or has_diagnostic_code(prog, "E2022");
}

test "W2025: wildcard import warning" {
    pytest.skip("W2025 not yet implemented");
    (_, prog) = parse_and_validate('import from os { * }');
    assert prog is not None and has_diagnostic_code(prog, "W2025", in_warnings=True);
}

test "W2027: variable shadows outer scope" {
    pytest.skip("W2027 not yet implemented — needs INFRA-5");
    (prog, _) = compile_and_check("scope_W2027_variable_shadow.jac");
    assert has_diagnostic_code(prog, "W2027", in_warnings=True);
}

test "E2029: self outside archetype method" {
    pytest.skip("E2029 not yet implemented — needs INFRA-8");
    (prog, _) = compile_and_check("context_E2029_self_outside_method.jac");
    assert has_diagnostic_code(prog, "E2029");
}

test "E2030: super outside archetype method" {
    pytest.skip("E2030 not yet implemented — needs INFRA-8");
    (has_err, _) = parse_and_validate('def foo() { super().__init__(); }');
    assert has_err;
}

test "W2031: unused import" {
    pytest.skip("W2031 not yet implemented — needs INFRA-5");
    (prog, _) = compile_and_check("scope_W2031_unused_import.jac");
    assert has_diagnostic_code(prog, "W2031", in_warnings=True);
}

test "W2032: duplicate import" {
    pytest.skip("W2032 not yet implemented — needs INFRA-6");
    (prog, _) = compile_and_check("scope_W2032_duplicate_import.jac");
    assert has_diagnostic_code(prog, "W2032", in_warnings=True);
}

test "E2034: private member access" {
    pytest.skip("E2034 not yet implemented — needs INFRA-6");
    (has_err, _) = parse_and_validate(
        'obj Foo { has _secret: int = 5; }\nwith entry { f = Foo(); print(f._secret); }'
    );
    assert has_err;
}

test "E2036: duplicate definition in scope" {
    pytest.skip("E2036 not yet implemented — needs INFRA-5");
    (prog, _) = compile_and_check("scope_E2036_duplicate_def.jac");
    assert has_diagnostic_code(prog, "E2036");
}


# ══════════════════════════════════════════════════════════════════
#  PHASE 4: TYPE SYSTEM DIAGNOSTICS (E/W 1100-1183)
#  Infrastructure: INFRA-3 (exhaustiveness), INFRA-4 (null safety),
#                  INFRA-9 (generics)
#  Milestones: 7, 8, 11
# ══════════════════════════════════════════════════════════════════

# --- Null Safety (INFRA-4) ---
test "E1100: possibly None" {
    pytest.skip("E1100 not yet implemented — needs INFRA-4");
    (prog, _) = compile_and_check("type_E1100_possibly_none.jac");
    assert has_diagnostic_code(prog, "E1100");
}

test "W1102: redundant None check" {
    pytest.skip("W1102 not yet implemented — needs INFRA-4");
    (prog, _) = compile_and_check("type_W1102_redundant_none_check.jac");
    assert has_diagnostic_code(prog, "W1102", in_warnings=True);
}

test "W1104: condition always true or false" {
    pytest.skip("W1104 not yet implemented — needs INFRA-4");
    (prog, _) = compile_and_check("type_W1104_always_true.jac");
    assert has_diagnostic_code(prog, "W1104", in_warnings=True);
}

# --- Generics (INFRA-9) ---
test "E1110: generic without type parameters" {
    pytest.skip("E1110 not yet implemented — needs INFRA-9");
    (prog, _) = compile_and_check("type_E1110_generic_no_args.jac");
    assert has_diagnostic_code(prog, "E1110");
}

test "E1111: wrong type argument count" {
    pytest.skip("E1111 not yet implemented — needs INFRA-9");
    (prog, _) = compile_and_check("type_E1111_wrong_type_arg_count.jac");
    assert has_diagnostic_code(prog, "E1111");
}

test "E1113: instantiate abstract archetype" {
    pytest.skip("E1113 not yet implemented — needs INFRA-7");
    (prog, _) = compile_and_check("type_E1113_instantiate_abstract.jac");
    assert has_diagnostic_code(prog, "E1113");
}

# --- Protocols ---
test "E1120: missing protocol member" {
    pytest.skip("E1120 not yet implemented");
    (prog, _) = compile_and_check("type_E1120_missing_protocol_member.jac");
    assert has_diagnostic_code(prog, "E1120");
}

# --- Union Types ---
test "E1130: union attr not on all members" {
    pytest.skip("E1130 not yet implemented");
    (prog, _) = compile_and_check("type_E1130_union_attr.jac");
    assert has_diagnostic_code(prog, "E1130");
}

# --- Enum Types ---
test "E1140: enum has no member" {
    pytest.skip("E1140 not yet implemented");
    (prog, _) = compile_and_check("type_E1140_enum_no_member.jac");
    assert has_diagnostic_code(prog, "E1140");
}

# --- Numeric ---
test "W1153: float equality comparison" {
    pytest.skip("W1153 not yet implemented");
    (prog, _) = compile_and_check("type_W1153_float_equality.jac");
    assert has_diagnostic_code(prog, "W1153", in_warnings=True);
}

# --- Pattern Matching (INFRA-3) ---
test "E1160: non-exhaustive match" {
    pytest.skip("E1160 not yet implemented — needs INFRA-3");
    (prog, _) = compile_and_check("type_E1160_nonexhaustive_match.jac");
    assert has_diagnostic_code(prog, "E1160");
}

test "W1161: unreachable match case" {
    pytest.skip("W1161 not yet implemented — needs INFRA-3");
    (prog, _) = compile_and_check("type_W1161_unreachable_case.jac");
    assert has_diagnostic_code(prog, "W1161", in_warnings=True);
}

# --- Async ---
test "W1172: missing await on coroutine" {
    pytest.skip("W1172 not yet implemented");
    (prog, _) = compile_and_check("type_W1172_missing_await.jac");
    assert has_diagnostic_code(prog, "W1172", in_warnings=True);
}

# --- Collections ---
test "E1180: tuple index out of range" {
    pytest.skip("E1180 not yet implemented");
    (prog, _) = compile_and_check("type_E1180_tuple_index_oor.jac");
    assert has_diagnostic_code(prog, "E1180");
}

test "E1182: unhashable dict key" {
    pytest.skip("E1182 not yet implemented");
    (prog, _) = compile_and_check("type_E1182_unhashable_key.jac");
    assert has_diagnostic_code(prog, "E1182");
}


# ══════════════════════════════════════════════════════════════════
#  PHASE 5: SEMANTIC ANALYSIS DIAGNOSTICS (E/W 2040-2087)
#  Infrastructure: INFRA-7 (archetype contracts), INFRA-1 (def-use),
#                  INFRA-2 (dominance), INFRA-8 (context)
#  Milestones: 1, 5, 9, 10
# ══════════════════════════════════════════════════════════════════

# --- Archetype / OOP (INFRA-7) ---
test "E2044: unimplemented abstract abilities" {
    pytest.skip("E2044 not yet implemented — needs INFRA-7");
    (prog, _) = compile_and_check("semantic_E2044_unimplemented_abstract.jac");
    assert has_diagnostic_code(prog, "E2044");
}

test "W2041: incompatible method override" {
    pytest.skip("W2041 not yet implemented — needs INFRA-7");
    (prog, _) = compile_and_check("semantic_W2041_incompatible_override.jac");
    assert has_diagnostic_code(prog, "W2041", in_warnings=True);
}

test "E2042: inherit from final archetype" {
    pytest.skip("E2042 not yet implemented — needs INFRA-7");
    (prog, _) = compile_and_check("semantic_E2042_inherit_final.jac");
    assert has_diagnostic_code(prog, "E2042");
}

test "W2047: __eq__ without __hash__" {
    pytest.skip("W2047 not yet implemented — needs INFRA-7");
    (prog, _) = compile_and_check("semantic_W2047_eq_without_hash.jac");
    assert has_diagnostic_code(prog, "W2047", in_warnings=True);
}

# --- Control Flow (INFRA-2) ---
test "W2050: missing return on non-None function" {
    pytest.skip("W2050 not yet implemented — needs INFRA-2");
    (prog, _) = compile_and_check("semantic_W2050_missing_return.jac");
    assert has_diagnostic_code(prog, "W2050", in_warnings=True);
}

test "W2052: overly broad except" {
    (prog, _) = compile_and_check("semantic_W2052_broad_except.jac");
    assert has_diagnostic_code(prog, "W2052", in_warnings=True);
    # Verify underline is clamped to the token, not the entire Except block
    for w in prog.warnings_had {
        if "W2052" in w.msg {
            output = w.pretty_print();
            for line in output.split('\n') {
                caret_count = line.count('^');
                assert caret_count <= len("Exception") , f"Underline too wide ({caret_count} carets): {repr(
                    line
                )}";
            }
        }
    }
}

test "E2055: return in finally block" {
    (prog, _) = compile_and_check("context_E2055_return_in_finally.jac");
    assert has_diagnostic_code(prog, "E2055");
}

test "W2058: None comparison with ==" {
    (prog, _) = compile_and_check("semantic_W2058_none_eq.jac");
    assert has_diagnostic_code(prog, "W2058", in_warnings=True);
}

# --- Mutability / Assignment (INFRA-1) ---
test "W2062: dead store" {
    pytest.skip("W2062 not yet implemented — needs INFRA-1");
    (prog, _) = compile_and_check("semantic_W2062_dead_store.jac");
    assert has_diagnostic_code(prog, "W2062", in_warnings=True);
}

test "W2063: self-assignment" {
    (prog, _) = compile_and_check("semantic_W2063_self_assignment.jac");
    assert has_diagnostic_code(prog, "W2063", in_warnings=True);
}

# --- Data Flow / Values ---
test "W2070: division by zero" {
    (prog, _) = compile_and_check("semantic_W2070_div_by_zero.jac");
    assert has_diagnostic_code(prog, "W2070", in_warnings=True);
}

test "W2074: f-string with no expressions" {
    (prog, _) = compile_and_check("semantic_W2074_fstring_no_expr.jac");
    assert has_diagnostic_code(prog, "W2074", in_warnings=True);
}

test "W2075: redundant boolean comparison" {
    (prog, _) = compile_and_check("semantic_W2075_redundant_bool.jac");
    assert has_diagnostic_code(prog, "W2075", in_warnings=True);
}

# --- Context Validity (INFRA-8) ---
test "E2083: disengage outside walker" {
    (prog, _) = compile_and_check("context_E2083_disengage_outside_walker.jac");
    assert has_diagnostic_code(prog, "E2083");
}

# --- Jac-Specific ---
test "W2085: walker has no visit statements" {
    pytest.skip("W2085 not yet implemented");
    (prog, _) = compile_and_check("semantic_W2085_walker_no_visit.jac");
    assert has_diagnostic_code(prog, "W2085", in_warnings=True);
}

test "E2080: walker visits unhandled node type" {
    pytest.skip("E2080 not yet implemented — needs INFRA-7");
    (prog, _) = compile_and_check("semantic_E2080_walker_unhandled_node.jac");
    assert has_diagnostic_code(prog, "E2080");
}


# ══════════════════════════════════════════════════════════════════
#  PHASE 6: LINT DIAGNOSTICS (W3020-W3037)
#  Infrastructure: None required (pure AST patterns)
#  Milestone: 3 (Lint Pass Extensions)
# ══════════════════════════════════════════════════════════════════
test "W3020: unnecessary pass in non-empty body" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3020_unnecessary_pass.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3020", in_warnings=True);
}

test "W3021: unnecessary else after return" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3021_unnecessary_else.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3021", in_warnings=True);
}

test "W3022: nested if can be elif" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3022_nested_if_to_elif.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3022", in_warnings=True);
}

test "W3023: return True/False simplification" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3023_return_bool.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3023", in_warnings=True);
}

test "W3024: repeated condition in if/elif" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3024_repeated_condition.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3024", in_warnings=True);
}

test "W3025: identical if/else branches" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3025_identical_branches.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3025", in_warnings=True);
}

test "W3026: not (a == b) should be a != b" {
    pytest.skip("W3026 not yet implemented");
    (_, prog) = parse_and_validate('with entry { x = 5; y = not (x == 3); }');
    # This would be a lint warning, not a parse error
    assert prog is not None;
}

test "W3030: too many parameters" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3030_too_many_params.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3030", in_warnings=True);
}

test "W3035: is with literal" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3035_is_with_literal.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3035", in_warnings=True);
}

test "W3036: mutable default argument" {
    path = os.path.join(NEW_DIAG_FIXTURES, "lint_W3036_mutable_default.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert has_diagnostic_code(prog, "W3036", in_warnings=True);
}


# ══════════════════════════════════════════════════════════════════
#  PHASE 7: IMPORT DIAGNOSTICS (E/W 4001-4010)
#  Infrastructure: INFRA-6 (import graph)
#  Milestone: 6 (Import Graph & Cycle Detection)
# ══════════════════════════════════════════════════════════════════
test "E4001: circular import" {
    pytest.skip("E4001 not yet implemented — needs INFRA-6");
    (prog, _) = compile_only("import_E4001_circular.jac");
    assert has_diagnostic_code(prog, "E4001");
}

test "W4004: unused import" {
    pytest.skip("W4004 not yet implemented — needs INFRA-5");
    (prog, _) = compile_and_check("scope_W2031_unused_import.jac");
    assert (
        has_diagnostic_code(prog, "W4004", in_warnings=True)
        or has_diagnostic_code(prog, "W2031", in_warnings=True)
    );
}

test "W4005: duplicate import" {
    pytest.skip("W4005 not yet implemented — needs INFRA-6");
    (prog, _) = compile_and_check("scope_W2032_duplicate_import.jac");
    assert (
        has_diagnostic_code(prog, "W4005", in_warnings=True)
        or has_diagnostic_code(prog, "W2032", in_warnings=True)
    );
}


# ══════════════════════════════════════════════════════════════════
#  PHASE 8: CODEGEN DIAGNOSTICS (E/W 5080-5083)
#  Infrastructure: None / INFRA-2
#  Milestone: 12 (Remaining)
# ══════════════════════════════════════════════════════════════════
test "E5080: unsupported feature in backend" {
    pytest.skip("E5080 not yet implemented");
    # Placeholder — needs a feature that exists in one backend but not another
    assert False , "E5080 test needs backend-specific fixture";
}


# ══════════════════════════════════════════════════════════════════
#  PARSER DEPRECATION WARNINGS (W0061)
# ══════════════════════════════════════════════════════════════════
test "W0061: deprecated paren filter syntax" {
    (prog, _) = compile_only("parser_W0061_deprecated_paren_filter.jac");
    assert has_diagnostic_code(prog, "W0061", in_warnings=True) , "Old (?:...) filter syntax should emit W0061 deprecation warning";
}

test "W0061: bracket filter no warning" {
    (prog, _) = compile_only("parser_W0061_bracket_filter_ok.jac");
    assert not has_diagnostic_code(prog, "W0061", in_warnings=True) , "New [?:...] bracket filter syntax should not emit W0061";
}

test "W0061: multiple deprecated filters emit multiple warnings" {
    prog = JacProgram();
    prog.compile(
        use_str='with entry { x = [1,2](?a<1); y = [3,4](?a>2); }',
        file_path="test.jac"
    );
    assert count_diagnostic_code(prog, "W0061", in_warnings=True) == 2 , "Each deprecated filter occurrence should emit its own W0061";
}

test "W0061: edge ref with deprecated filter" {
    prog = JacProgram();
    prog.compile(
        use_str='walker W { can go with entry { visit [-->](?:Foo); } }',
        file_path="test.jac"
    );
    assert has_diagnostic_code(prog, "W0061", in_warnings=True) , "Deprecated filter inside edge ref should emit W0061";
}

test "W0061: edge ref with bracket filter no warning" {
    prog = JacProgram();
    prog.compile(
        use_str='walker W { can go with entry { visit [-->][?:Foo]; } }',
        file_path="test.jac"
    );
    assert not has_diagnostic_code(prog, "W0061", in_warnings=True) , "Bracket filter after edge ref should not emit W0061";
}

test "W0061: filter inside edge chain warns" {
    prog = JacProgram();
    prog.compile(
        use_str='walker W { can go with entry { visit [-->(?:Foo)]; } }',
        file_path="test.jac"
    );
    assert has_diagnostic_code(prog, "W0061", in_warnings=True) , "(?:...) inside edge chain should also emit W0061 deprecation";
}

test "W0061: bracket filter inside edge chain no warning" {
    prog = JacProgram();
    prog.compile(
        use_str='walker W { can go with entry { visit [-->[?:Foo]]; } }',
        file_path="test.jac"
    );
    assert not has_diagnostic_code(prog, "W0061", in_warnings=True) , "Bracket filter [?:...] inside edge chain should not emit W0061";
}


# ══════════════════════════════════════════════════════════════════
#  INLINE SNIPPET PARAMETRIZED TESTS
#  These test simple patterns that don't need fixture files
# ══════════════════════════════════════════════════════════════════
glob MUST_REJECT_NEW: dict[str, str] = {
         "E0053_double_args": "def foo(*a: int, *b: str) { }",
         "E0053_double_kwargs": "def foo(**a: int, **b: str) { }",
         "E0059_literal_lhs": "with entry { 42 = x; }",
         "E0059_binop_lhs": "with entry { a + b = x; }",
         "E0062_nonlocal_module": "with entry { nonlocal x; }",
         "E0071_bare_except_first": "with entry { try { x=1; } except { } except ValueError as e { } }",
         "E0075_dup_base": "obj A { }\nobj B(A, A) { }",
         "E0077_empty_fstring": 'with entry { x = f"{}"; }'
     },
     MUST_VALIDATE_NEW: dict[str, str] = {
         "E0055_yield_in_entry": "with entry { yield 5; }",
         "E0058_break_no_loop": "with entry { break; }",
         "E0058_continue_no_loop": "with entry { continue; }"
     };

glob IMPLEMENTED_REJECT: set[str] = {"E0062_nonlocal_module","E0071_bare_except_first","E0075_dup_base"},
     IMPLEMENTED_VALIDATE: set[str] = {"E0055_yield_in_entry","E0058_break_no_loop","E0058_continue_no_loop"};

def reject_test(name_snippet: tuple) -> None {
    (name, snippet) = name_snippet;
    if name not in IMPLEMENTED_REJECT {
        pytest.skip(f"{name} not yet implemented");
    }
    # For implemented checks, parse then validate — errors come from ASTValidationPass
    (has_errors, _) = parse_and_validate(snippet);
    assert has_errors , f"Validation must reject '{name}': {snippet}";
}

def validate_reject_test(name_snippet: tuple) -> None {
    (name, snippet) = name_snippet;
    if name not in IMPLEMENTED_VALIDATE {
        pytest.skip(f"{name} not yet implemented");
    }
    (has_errors, _) = parse_and_validate(snippet);
    assert has_errors , f"Validation must reject '{name}': {snippet}";
}


# ══════════════════════════════════════════════════════════════════
#  POSITIVE TESTS (ensure valid code is NOT flagged)
#  These should pass even before implementation, confirming no
#  false positives on valid patterns.
# ══════════════════════════════════════════════════════════════════
test "valid: break inside loop" {
    (has_err, _) = parse_and_validate(
        'with entry { for i in [1,2,3] { if i == 2 { break; } } }'
    );
    assert not has_err;
}

test "valid: continue inside loop" {
    (has_err, _) = parse_and_validate(
        'with entry { for i in [1,2,3] { if i == 2 { continue; } } }'
    );
    assert not has_err;
}

test "valid: return inside function" {
    (has_err, _) = parse_and_validate('def foo() -> int { return 42; }');
    assert not has_err;
}

test "valid: distinct keyword args" {
    (has_err, _) = parse_and_validate(
        'def foo(a: int, b: int) -> int { return a + b; }\nwith entry { foo(a=1, b=2); }'
    );
    assert not has_err;
}

test "valid: single base class" {
    (has_err, _) = parse_and_validate('obj Base { }\nobj Child(Base) { }');
    assert not has_err;
}

test "valid: except with specific type" {
    (has_err, _) = parse_and_validate(
        'with entry { try { x = 1; } except ValueError as e { print(e); } }'
    );
    assert not has_err;
}

test "valid: non-empty f-string" {
    (has_err, _) = parse_and_validate(
        'with entry { name = "world"; x = f"hello {name}"; }'
    );
    assert not has_err;
}

test "valid: function with return on all paths" {
    (has_err, _) = parse_and_validate(
        'def foo(x: int) -> int { if x > 0 { return x; } else { return -x; } }'
    );
    assert not has_err;
}


# ══════════════════════════════════════════════════════════════════
#  ENTRY POINT — register parametrized tests
# ══════════════════════════════════════════════════════════════════
with entry {
    parametrize(
        "new reject", list(MUST_REJECT_NEW.items()), reject_test, id_fn=lambda x : x[0]
    );
    parametrize(
        "new validate reject",
        list(MUST_VALIDATE_NEW.items()),
        validate_reject_test,
        id_fn=lambda x : x[0]
    );
}
