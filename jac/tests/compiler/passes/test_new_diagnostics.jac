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

Diagnostics that are not yet implemented are tracked as unlisted rows in
the IMPLEMENTED_REJECT / IMPLEMENTED_VALIDATE sets below, which gate the two
parametrized reject suites. Tests are organized to match the implementation
milestones in _planning/diagnostics_implementation_progress.md.
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang;

import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.parser.frontend { parse }
import from jaclang.testing.test { parametrize }
import from jaclang.compiler.driver.pass_driver { run_pass }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "fixtures"),
     CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "checker"
     ),
     NEW_DIAG_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "new_diagnostics"
     );

# ──────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────
"""Compile a fixture with type checking and static analysis. Returns (program, module)."""
def compile_and_check(fixture_name: str) -> tuple[any, ...] {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    path = os.path.join(NEW_DIAG_FIXTURES, fixture_name);
    program = JacProgram();
    mod = program.compile(path, options=CompileOptions(default_codespace='server'));
    return (program, mod);
}

"""Compile a fixture without type checking. Returns (program, module)."""
def compile_only(fixture_name: str) -> tuple[any, ...] {
    path = os.path.join(NEW_DIAG_FIXTURES, fixture_name);
    program = JacProgram();
    mod = program.compile(path);
    return (program, mod);
}

"""Parse source string with diagnostic capture: returns (program, had_error)."""
def parse_with_prog(source: str) -> tuple[JacProgram, bool] {
    prog = JacProgram();
    try {
        (_, had_error) = parse(source, "/tmp/test.jac", prog=prog);
        return (prog, had_error);
    } except Exception {
        return (prog, True);
    }
}

"""Parse source string, return (has_errors: bool, program: JacProgram)."""
def parse_and_validate(source: str) -> tuple[any, ...] {
    try {
        (module, had_error) = parse(source, "/tmp/test.jac");
        if had_error or module is None {
            return (True, None);
        }
        prog = JacProgram();
        run_pass(ASTValidationPass, module, prog);
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

"""How many times `code` fired in `prog`; W codes are warnings, the rest errors."""
def fired(prog: JacProgram, code: str) -> int {
    return count_diagnostic_code(prog, code, in_warnings=code.startswith("W"));
}

"""The code a fixture is named for: parser_E0065_duplicate_kwarg.jac -> E0065."""
def code_of(fixture: str) -> str {
    return fixture.split("_")[1];
}

"""Compile a source string as test.jac."""
def compile_str(source: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(use_str=source, file_path="test.jac");
    return prog;
}

"""The sources that do not parse cleanly: a parse error or any diagnostic."""
def unclean(sources: list[str]) -> list[str] {
    bad: list[str] = [];
    for src in sources {
        (prog, had_error) = parse_with_prog(src);
        if had_error or prog.errors_had {
            bad.append(src);
        }
    }
    return bad;
}

"""The entries of `want` whose count came out different, as
{key: (got, expected)}. `count` computes the count for a key."""
def wrong_counts(
    count: Callable[[str], int], want: dict[str, int]
) -> dict[str, tuple[int, int]] {
    got = {key: count(key) for key in want};
    return {
        key: (got[key], want[key])
        for key in want
        if got[key] != want[key]
    };
}

"""The error codes ASTValidationPass reports for `source`, or None when it
does not parse."""
def validation_errors(source: str) -> (list[str] | None) {
    (_, prog) = parse_and_validate(source);
    if prog is None {
        return None;
    }
    return [a.code.code if a.code is not None else a.msg for a in prog.errors_had];
}

test "W0100: an invalid escape warns once each; valid escapes and raw strings do not" {
    wrong = wrong_counts(
        lambda (src: str) { fired(compile_str(src), "W0100"); },
        {
            'with entry { x = "press \\q now"; }': 1,
            'with entry { x = "\\q then \\e"; }': 2,
            'with entry { x = "tab\\there\\nline\\x41"; }': 0,
            'with entry { x = r"press \\q"; }': 0
        }
    );
    assert not wrong , wrong;
}

# ══════════════════════════════════════════════════════════════════
#  PHASE 2: PARSER / SYNTAX DIAGNOSTICS (E0052-E0078)
#  Infrastructure: INFRA-8 for E0055-E0058
#  Milestone: 1 (Context Validity) + 4 (Parser/Lexer Hardening)
# ══════════════════════════════════════════════════════════════════

test "E0013: keyword as a field name carries prefix help" {
    (prog, _) = parse_with_prog("obj X { has match: int = 1; }");
    assert has_diagnostic_code(prog, "E0013");
    hlp = [
        a.help_text
        for a in prog.errors_had
        if a.code is not None and a.code.code == "E0013"
    ];
    assert hlp[0] is not None;
    assert "prefix" in hlp[0];
    assert "{" not in hlp[0];
}

test "E0013: message no longer advertises a closing backtick" {
    (prog, _) = parse_with_prog("obj X { has match: int = 1; }");
    msgs = [
        a.msg
        for a in prog.errors_had
        if a.code is not None and a.code.code == "E0013"
    ];
    assert "`match)" not in msgs[0];
}

test "E0014: a backtick on a non-keyword still errors" {
    (prog, _) = parse_with_prog("obj X { has `total: int = 1; }");
    assert has_diagnostic_code(prog, "E0014");
}

test "kwesc: the prefix form parses clean" {
    (prog, had_error) = parse_with_prog("obj X { has `match: int = 1; }");
    assert not had_error;
    assert len(prog.errors_had) == 0;
}

test "E0013: a keyword after a dot is an attribute, no escape needed" {
    # #8982 item 9: `sys.exit(0)` is the idiom every CLI ends with.
    for src in [
        "import sys; with entry { sys.exit(0); }",
        "with entry { m = re.match; x = obj_.entry; y = cfg.default; }",
        "with entry { z = a.b.node.edge.walker; }"
    ] {
        (prog, had_error) = parse_with_prog(src);
        assert not had_error , src;
        assert not has_diagnostic_code(prog, "E0013") , src;
    }
}

test "E0013: a keyword still cannot bind a name, and names the escape" {
    for src in [
        "with entry { exit = 1; }",
        "def f(match: int) {}",
        "obj X { has entry: int = 1; }",
        "def g(own: int, mut: int, imm: int, awaiting: int) {}"
    ] {
        (prog, _) = parse_with_prog(src);
        assert has_diagnostic_code(prog, "E0013") , src;
    }
}

# ── E0025: JS arrow function syntax (=>) ───────────────────────────
test "E0025: each js-style arrow is one error; >= and lambda are not arrows" {
    wrong = wrong_counts(
        lambda (src: str) { fired(parse_with_prog(src)[0], "E0025"); },
        {
            # jsx attribute and child slots
            'cl { def:pub Foo() -> JsxElement { return <button onClick={e => doThing(e)}>Click</button>; } }': 1,
            'cl { def:pub Foo() -> JsxElement { return <div>{e => fn(e)}</div>; } }': 1,
            'glob f = x => x + 1;': 1,
            'with entry { f = x => { print(x); }; }': 1,
            'with entry { f = a => b => c; }': 2,
            'with entry { s = f"{x => y}"; }': 1,
            # an empty body recovers without a crash
            'with entry { f = x =>; }': 1,
            # '=' and '>' apart are not an arrow; the source is invalid for other reasons
            'with entry { x = a = > b; }': 0
        }
    );
    assert not wrong , wrong;
    bad = unclean(
        [
            'with entry { x = (a >= b); }',
            'with entry { f = lambda (x: int) { x + 1; }; }'
        ]
    );
    assert not bad , bad;
}

# ── E0027/E0028: typed connection missing its closer ─────────────────
test "E0027/E0028: an edge connect missing its closer errors; the full form parses clean" {
    wrong = wrong_counts(
        lambda (fx: str) { fired(compile_only(fx)[0], code_of(fx)); },
        {
            "parser_E0027_forward_missing_close.jac": 1,
            "parser_E0028_backward_missing_close.jac": 1
        }
    );
    assert not wrong , wrong;
    bad = unclean(
        [
            'node N {} edge F {} with entry { n1=N(); n2=N(); n1 +>: F :+> n2; }',
            'node N {} edge F {} with entry { n1=N(); n2=N(); n1 <+: F :<+ n2; }'
        ]
    );
    assert not bad , bad;
}

test "ASTValidationPass: each source gets exactly these errors" {
    # None: the source does not parse. The yield/break/continue-outside-a-loop,
    # bare-except and duplicate-base cases are rows of the "new reject" and
    # "new validate reject" suites below.
    want = {
        # E0052: parameters need a type; lambda params do not
        'def foo(x) { }': ["E0052"],
        'def foo(x, y) { }': ["E0052", "E0052"],
        'def foo(x: int) -> int { return x; }': [],
        'with entry { f = lambda (x) { x + 1; }; }': [],
        'obj Foo { def bar(self: Foo, x: int) -> int { return x; } }': [],
        # E0058: a loop's else belongs to the enclosing loop
        'with entry { for i in [1,2] { } else { continue; } }': ["E0058"],
        'with entry { for i in [1,2] { } else { break; } }': ["E0058"],
        'with entry { for r in [1] { for i in [1,2] { } else { continue; } } }': [],
        'with entry { while True { for i in [1,2] { } else { break; } } }': [],
        'with entry { for i in [1,2] { break; } }': [],
        'with entry { for i in [1,2,3] { if i == 2 { break; } } }': [],
        'with entry { for i in [1,2,3] { if i == 2 { continue; } } }': [],
        'with entry { for i in [1,2] { if i == 1 { } else { continue; } } }': [],
        # the removed nonlocal directive
        'with entry { nonlocal x; }': None,
        # valid code is not flagged
        'glob x: int = 5;': [],
        'def foo() -> int { return 42; }': [],
        'def foo(x: int) -> int { if x > 0 { return x; } else { return -x; } }': [],
        'def foo(a: int, b: int) -> int { return a + b; }\nwith entry { foo(a=1, b=2); }': [],
        'obj Base { }\nobj Child(Base) { }': [],
        'with entry { try { x = 1; } except ValueError as e { print(e); } }': [],
        'with entry { name = "world"; x = f"hello {name}"; }': []
    };
    got = {src: validation_errors(src) for src in want};
    assert got == want , {
        src: (got[src], want[src])
        for src in want
        if got[src] != want[src]
    };
}

test "E0057: return inside any function body is valid" {
    for src in [
        'def f -> int { return 1; }',
        'obj A { has n: int = 0; def get -> int { return self.n; } }',
        'obj A { has n: int = 0; def get -> int; }\nimpl A.get -> int { return self.n; }',
        'walker W { can go with Root entry { if True { return; } } }',
        'test "early exit" { if True { return; } }',
        'with entry { def g -> int { return 2; } f = lambda -> int { return 3; }; }'
    ] {
        (has_err, prog) = parse_and_validate(src);
        errors = [str(e) for e in prog.errors_had] if prog else ["parse failed"];
        assert not has_err , f"{src!r}: {errors}";
    }
}

test "checker fixtures fire their code the expected number of times" {
    wrong = wrong_counts(
        lambda (fx: str) { fired(compile_and_check(fx)[0], code_of(fx)); },
        {
            "parser_E0065_duplicate_kwarg.jac": 2,
            # foo(a=1, 2, 3) has two positionals after the keyword
            "parser_E0066_pos_after_kw.jac": 3,
            "parser_E0076_duplicate_method.jac": 1,
            # the method 'grow', the ability 'rise' and the impl-block 'grow'
            "parser_E0078_field_method_clash.jac": 3,
            # property accessors and init/postinit beside same-named fields
            "parser_E0078_distinct_members.jac": 0,
            "context_E2055_return_in_finally.jac": 1,
            "context_E2083_disengage_outside_walker.jac": 1,
            # one per decorator; the @property in the Python-compat class is exempt
            "semantic_W2029_property_decorators.jac": 4,
            "semantic_W2058_none_eq.jac": 2,
            "semantic_W2063_self_assignment.jac": 1,
            "semantic_W2070_div_by_zero.jac": 3,
            "semantic_W2074_fstring_no_expr.jac": 1,
            "semantic_W2075_redundant_bool.jac": 2,
            # identity/equality against True over any-typed operands discriminates
            "semantic_W2075_any_identity_ok.jac": 0
        }
    );
    assert not wrong , wrong;
}

test "E0076: Python __init__ and init are distinct methods" {
    # Issue #6556: a Python class with both `__init__` and a plain `init`
    # method (e.g. Pillow's PIL.ImageFile.PyCodec) is valid Python; raising
    # `__init__` to Jac's `init` constructor must not collide with it.
    (prog, _) = compile_only("parser_E0076_py_init_distinct.py");
    assert not has_diagnostic_code(prog, "E0076");
}

test "E0078: a Python class is not checked" {
    prog = JacProgram();
    prog.compile(
        use_str="class Box:\n    grow: int = 3\n\n    def grow(self) -> int:\n        return 7\n",
        file_path="clash.py"
    );
    assert not has_diagnostic_code(prog, "E0078");
}

test "E2036: a second module-level definition of a name is rejected" {
    (prog, _) = compile_and_check("scope_E2036_duplicate_def.jac");
    assert count_diagnostic_code(prog, "E2036") == 2 , "the second 'foo' and the second 'Bar'";
}

test "E2036: the call the checker passed against the first def is now an error" {
    # The later def wins at run time, so `resolve("edit")` used to check clean
    # and then fail with "takes 0 positional arguments but 1 was given".
    prog = JacProgram();
    prog.compile(
        use_str='def resolve(capability: str = "") -> str { return "first:" + capability; }\n'
            + 'def resolve() -> str { return "second"; }\n'
            + 'with entry { print(resolve("edit")); }',
        file_path="dup.jac"
    );
    assert count_diagnostic_code(prog, "E2036") == 1;
}

test "E2036: an impl, overloads, a self-import and a glob assignment are not duplicates" {
    (prog, _) = compile_only("scope_E2036_allowed_redefinitions.jac");
    assert not has_diagnostic_code(prog, "E2036");
}

test "E2036: a Python module may redefine a name" {
    prog = JacProgram();
    prog.compile(
        use_str="from os.path import join\nfrom shlex import join\n\n\n"
            + "def pick() -> int:\n    return 1\n\n\ndef pick() -> int:\n    return 2\n",
        file_path="redefine.py"
    );
    assert not has_diagnostic_code(prog, "E2036");
}

test "E2036: a local def, obj or glob that reuses an imported name is rejected" {
    # `def Thing -> int;` used to lose to the imported record: the checker typed
    # `Thing()` as the record and the program constructed it instead of
    # calling the def.
    (prog, _) = compile_and_check("scope_E2036_import_shadow.jac");
    messages = [
        e.msg
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E2036"
    ];
    assert len(messages) == 3 , messages;
    assert "Duplicate definition of 'Thing': the import on line 2 binds it too."
        in messages , messages;
    assert any("'Other'" in m for m in messages) , messages;
    assert any("'Knob'" in m for m in messages) , messages;
}

test "E2036: an import after the local definition still collides" {
    # Imports of one name in one scope must agree; one inside a branch is checked, not recorded.
    allowed = [
        "import from os.path { join } import from os.path { join }",
        "import os; import os.path; import os as os;",
        "import os.path as p; import from os { path as p }",
        "include b; import from c { b }",
        "import from b { A } def f -> None { import from c { A } }",
        "obj C { with entry { import from os.path { join } } } import from shlex { join }",
        "def f(x: bool) -> None { if x { import from b { A } } else { import from c { A } } }",
        "with entry { try { import from b { A } } except ImportError { import from c { A } } }"
    ];
    clashes = [
        "def Thing -> int {\n    return 7;\n}\n\nimport from rec { Thing }\n",
        "import from os.path { join } import from shlex { join }",
        "import from b { A } import from b { A } import from c { A }",
        "import from b { A as X } import from b { C as X }",
        "import from .b { A } import from pkg.b { A }",
        "import os.path as p; import shlex as p;",
        "import from os.path { join } with entry { import from shlex { join } }",
        "with entry { import from b { A } } import from c { A }",
        "def f(x: bool) -> None { import from b { A } if x { import from c { A } } }",
        "def f(x: bool) -> None { if x { import from c { A } } import from b { A } }",
        "def join -> int { return 1; } def f(x: bool) -> None { import from .test { join } if x { import from shlex { join } } }",
        "def join -> int { return 1; } with entry { if True { import from shlex { join } } }"
    ];
    # The self-import is the local join, so it clashes with shlex as the def does.
    self_import = [
        "def join -> int { return 1; } with entry { if True { import from .test { join } } import from shlex { join } }"
    ];
    for (expected, sources) in [(0, allowed), (1, clashes), (2, self_import)] {
        for source in sources {
            (_, prog) = parse_and_validate(source);
            got = count_diagnostic_code(prog, "E2036");
            assert got == expected , f"{source}: expected {expected} E2036, got {got}";
        }
    }
}

test "E2036: a module import and an enum or type alias collide too" {
    (_, prog) = parse_and_validate(
        "import os;\nimport from rec { Kind, Alias }\n\n"
            + "enum Kind { A, B }\n\ntype Alias = int;\n\n"
            + "def os -> int {\n    return 0;\n}\n"
    );
    assert count_diagnostic_code(prog, "E2036") == 3;
}

test "E2036: an include does not collide with a local definition" {
    # A module's own definition shadows a name an `include` brings in.
    (_, prog) = parse_and_validate(
        "include rec;\nimport from rec { Thing as Widget }\n\n"
            + "obj Thing {}\n\ndef Widget2 -> int {\n    return 1;\n}\n"
    );
    assert not has_diagnostic_code(prog, "E2036");
}

test "E0063: glob in statement position is always rejected" {
    sources = [
        "with entry { glob a = 90; }",
        "with entry { glob a = 90 }",
        "with entry { glob a = }",
        "with entry { glob a }",
        "with entry { glob }",
        "def foo() -> int { glob a = 1; return a; }",
        "test \"t\" { glob sneaky = 1; assert True; }"
    ];
    for src in sources {
        (has_err, _) = parse_and_validate(src);
        assert has_err , f"Expected error for: {src}";
    }
}

test "removed placement-marker blocks raise the migration error" {
    # cl/sv/na blocks were removed with #7772; the parser points authors at
    # 'jac fix placement' instead of a bare syntax error.
    for src in ["cl { glob counter: int = 0; }", "sv { glob token = \"x\"; }"] {
        (has_err, _) = parse_and_validate(src);
        assert has_err , f"Expected the marker-removal error for: {src}";
    }
}

test "E0063: glob inside a function blocks codegen and points at the rebinding idiom" {
    # Detected by ASTValidationPass (not the parser), and the structural
    # error must block codegen so the invalid module cannot silently execute.
    prog = JacProgram();
    mod = prog.compile(
        file_path="/tmp/test_e0063_gate.jac",
        use_str="def foo() -> int { glob a = 1; return a; }"
    );
    assert has_diagnostic_code(prog, "E0063");
    assert not mod.gen.py_bytecode;
    # Jac has no `global` statement; a function rebinds a module glob by
    # plain assignment, so a hint that says "global" leads to a parse error (#8612).
    alert = [
        a
        for a in prog.errors_had
        if a.code is not None and a.code.code == "E0063"
    ][0];
    assert "global" not in alert.msg;
    assert alert.help_text is not None;
    assert "assignment" in alert.help_text and "no global statement" in alert.help_text;
}

# ══════════════════════════════════════════════════════════════════
#  PHASE 4: TYPE SYSTEM DIAGNOSTICS (E/W 1100-1183)
#  Infrastructure: INFRA-3 (exhaustiveness), INFRA-4 (null safety),
#                  INFRA-9 (generics)
#  Milestones: 7, 8, 11
# ══════════════════════════════════════════════════════════════════

test "E1042: calling an async function without await" {
    # An `async def` call is a coroutine, not its return value. Assigning it
    # without `await` is a type error; the awaited forms must stay clean.
    (prog, _) = compile_and_check("type_E1042_missing_await.jac");
    assert count_diagnostic_code(prog, "E1042") == 2 , f"expected 2 E1042 (the two un-awaited calls), got "
    f"{count_diagnostic_code(prog, 'E1042')}; "
    f"errors={[str(e) for e in prog.errors_had]}";
}

test "E1042: missing await on a bridged server call (issue #6236)" {
    # Server functions imported into client context (a CLIENT_BRIDGE) are
    # async RPC stubs; calling one without `await` assigns a coroutine to a
    # typed field and crashes at runtime. `jac check` must flag it.
    (prog, _) = compile_and_check("type_E1042_sv_missing_await.jac");
    assert has_diagnostic_code(prog, "E1042") , f"expected E1042 for the un-awaited bridged call; "
    f"errors={[str(e) for e in prog.errors_had]}";
}

test "E1042: a same-app server->server call is synchronous, not a coroutine" {
    # A server module importing another server module of the same app is a
    # LOCAL import (no app boundary, no bridge), so binding its result to a
    # concrete type without `await` is correct and must NOT raise E1042.
    # Uses the SAME provider as the client fixture above, which still must
    # raise it -- the check is sensitive to the importing module's context,
    # not to the shape of the import statement. The cross-app server case
    # (SERVICE_BRIDGE, which IS a coroutine) is covered in
    # tests/compiler/test_cross_app_import.jac.
    (prog, _) = compile_and_check("type_E1042_sv_sync_call_server.jac");
    assert count_diagnostic_code(prog, "E1042") == 0 , f"same-app server call must not be flagged as a missing-await coroutine; "
    f"errors={[str(e) for e in prog.errors_had]}";
}

# ══════════════════════════════════════════════════════════════════
#  PHASE 5: SEMANTIC ANALYSIS DIAGNOSTICS (E/W 2040-2087)
#  Infrastructure: INFRA-7 (archetype contracts), INFRA-1 (def-use),
#                  INFRA-2 (dominance), INFRA-8 (context)
#  Milestones: 1, 5, 9, 10
# ══════════════════════════════════════════════════════════════════

# --- Data Flow / Values ---

# --- Context Validity (INFRA-8) ---

test "E2085: await outside async function or ability (issue #8998)" {
    # jac check must catch what only jac run's bytecode compile caught before:
    # a plain `can`/`def` body that awaits is invalid, and the checker had no
    # opinion on it at all -- `await` was never visited by any checking pass.
    (prog, _) = compile_and_check("context_E2085_await_outside_async.jac");
    assert count_diagnostic_code(prog, "E2085") == 1 , f"expected exactly 1 E2085 (the plain 'can', not the 'async can'), got "
    f"{count_diagnostic_code(prog, 'E2085')}; errors={[
        str(e) for e in prog.errors_had
    ]}";
}

# ══════════════════════════════════════════════════════════════════
#  PHASE 6: LINT DIAGNOSTICS (W3020-W3037)
#  Infrastructure: None required (pure AST patterns)
#  Milestone: 3 (Lint Pass Extensions)
# ══════════════════════════════════════════════════════════════════
test "lint fixtures fire their code the expected number of times" {
    wrong = wrong_counts(
        lambda (fx: str) { fired(
            JacProgram.jac_file_formatter(
                os.path.join(NEW_DIAG_FIXTURES, fx), auto_lint=True
            ),
            code_of(fx)
        ); },
        {
            "lint_W3020_unnecessary_pass.jac": 1,
            "lint_W3021_unnecessary_else.jac": 1,
            "lint_W3022_nested_if_to_elif.jac": 1,
            "lint_W3023_return_bool.jac": 1,
            "lint_W3024_repeated_condition.jac": 1,
            "lint_W3025_identical_branches.jac": 1,
            # 3 if/else pairs: 2 differ, 1 truly matches with a subscript target
            "lint_W3025_identical_branches_false_positive.jac": 1,
            "lint_W3030_too_many_params.jac": 1,
            "lint_W3035_is_with_literal.jac": 1,
            "lint_W3036_mutable_default.jac": 2,
            "lint_W3040_filter_tautology.jac": 1
        }
    );
    assert not wrong , wrong;
}

# ══════════════════════════════════════════════════════════════════
#  REMOVED PAREN FILTER SYNTAX (E0048)
# ══════════════════════════════════════════════════════════════════
test "E0048: each removed (?:...) filter errors; the [?:...] form does not" {
    wrong = wrong_counts(
        lambda (fx: str) { fired(compile_only(fx)[0], code_of(fx)); },
        {
            "parser_E0048_removed_paren_filter.jac": 1,
            "parser_E0048_bracket_filter_ok.jac": 0
        }
    );
    wrong.update(
        wrong_counts(
            lambda (src: str) { fired(compile_str(src), "E0048"); },
            {
                'with entry { x = [1,2](?a<1); y = [3,4](?a>2); }': 2,
                # after an edge ref, and inside an edge chain
                'walker W { can go with entry { visit [-->](?:Foo); } }': 1,
                'walker W { can go with entry { visit [-->][?:Foo]; } }': 0,
                'walker W { can go with entry { visit [-->(?:Foo)]; } }': 1,
                'walker W { can go with entry { visit [-->[?:Foo]]; } }': 0
            }
        )
    );
    assert not wrong , wrong;
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
         "E0071_bare_except_first": "with entry { try { x=1; } except { } except ValueError as e { } }",
         "E0075_dup_base": "obj A { }\nobj B(A, A) { }",
         "E0077_empty_fstring": 'with entry { x = f"{}"; }'
     },
     MUST_VALIDATE_NEW: dict[str, str] = {
         "E0055_yield_in_entry": "with entry { yield 5; }",
         "E0057_return_in_entry": "with entry { return; }",
         "E0057_return_in_entry_if": "with entry { x = 1; if x { return; } }",
         "E0057_return_in_entry_loop": "with entry { for i in [1] { return i; } }",
         "E0057_return_in_archetype_entry": "obj Holder { with entry { return; } }",
         "E0058_break_no_loop": "with entry { break; }",
         "E0058_continue_no_loop": "with entry { continue; }"
     };

glob IMPLEMENTED_REJECT: set[str] = {
         "E0063_glob_inside_func",
         "E0071_bare_except_first",
         "E0075_dup_base"
     },
     IMPLEMENTED_VALIDATE: set[str] = {
         "E0055_yield_in_entry",
         "E0057_return_in_entry",
         "E0057_return_in_entry_if",
         "E0057_return_in_entry_loop",
         "E0057_return_in_archetype_entry",
         "E0058_break_no_loop",
         "E0058_continue_no_loop"
     };

def reject_test(name_snippet: tuple[any, ...]) {
    (name, snippet) = name_snippet;
    if name not in IMPLEMENTED_REJECT {
        testskip(f"{name} not yet implemented");
    }
    # For implemented checks, parse then validate — errors come from ASTValidationPass
    (has_errors, _) = parse_and_validate(snippet);
    assert has_errors , f"Validation must reject '{name}': {snippet}";
}

def validate_reject_test(name_snippet: tuple[any, ...]) {
    (name, snippet) = name_snippet;
    if name not in IMPLEMENTED_VALIDATE {
        testskip(f"{name} not yet implemented");
    }
    (has_errors, prog) = parse_and_validate(snippet);
    assert has_errors , f"Validation must reject '{name}': {snippet}";
    code = name.split("_")[0];
    assert prog is not None and count_diagnostic_code(prog, code) == 1 , (
        name,
        [str(e) for e in prog.errors_had] if prog else "parse failed"
    );
}

# ══════════════════════════════════════════════════════════════════
#  POSITIVE TESTS (ensure valid code is NOT flagged)
#  These should pass even before implementation, confirming no
#  false positives on valid patterns.
# ══════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════
#  view_body_check — `view` declarator body rules (ViewLowerPass)
# ══════════════════════════════════════════════════════════════════
test "view body check flags a value-returning return (E2019)" {
    (program, _) = compile_and_check("view_body_rules.jac");
    assert has_diagnostic_code(program, "E2019") , (
        "a `return <value>;` in a view body should raise E2019"
    );
}

test "view body check flags bare return; in any slot position (E2020)" {
    (program, _) = compile_and_check("view_body_rules.jac");
    # Bare `return;` is now forbidden ANYWHERE inside a slot body — the
    # "use `skip;`" guidance applies in loops, outside loops, and nested
    # under control flow (`match` / `try` / etc.). Fixture has three
    # call sites: ReturnInLoop, ReturnAtTopLevel, ReturnInLoopUnderMatch.
    n = count_diagnostic_code(program, "E2020");
    assert n >= 3 , (
        f"E2020 should fire for each bare `return;` in a slot body (loop, top-level, and nested), got {n}"
    );
}

test "view body check flags break inside a template loop (E2021)" {
    (program, _) = compile_and_check("view_body_rules.jac");
    # Shallow `for { break; }` AND nested `for { try { break; } except: ... }`
    # should both fire — verifies `_check_body` recurses through `try`.
    # `skip;` is NO LONGER in E2021 (it's the slot early-exit now).
    n = count_diagnostic_code(program, "E2021");
    assert n >= 2 , (
        f"E2021 should fire for both shallow and nested `break;` in loops, got {n}"
    );
}

test "redundant `{...}` slot wrapping inside slot body raises E2023" {
    (program, _) = compile_and_check("view_body_rules.jac");
    # `RedundantSlotWrap` has two redundant `{...}` slots inside the
    # outer slot body (`{if ... }}` and `{for ... }}`) — each drives
    # E2023, and no cascade of E0001/E0002 parse errors should fire.
    n = count_diagnostic_code(program, "E2023");
    assert n >= 2 , (
        f"E2023 should fire once per redundant inner `{{...}}` slot, got {n}"
    );
    # Critically, the recovery path must NOT produce a parse-error
    # cascade — the redundant-slot diagnostic replaces it.
    parse_cascade = count_diagnostic_code(program, "E0002");
    assert parse_cascade == 0 , (
        f"E2023 recovery must avoid the E0001/E0002 parse cascade, got {parse_cascade} E0002 errors"
    );
}

test "implicit return outside function tail position raises E2084" {
    (program, _) = compile_and_check("implicit_return_rules.jac");
    # `misplaced_in_if` (tail of an `if` body) and the module-level
    # `with entry` tail should each fire E2084; the function-tail
    # implicit returns must not.
    n = count_diagnostic_code(program, "E2084");
    assert n == 2 , (
        f"E2084 should fire for if-body and module-level tails only, got {n}"
    );
    # The recovery path must not produce an E0002 parse-error cascade —
    # the placement diagnostic replaces it entirely.
    assert count_diagnostic_code(program, "E0002") == 0 , (
        "tail-expression recovery must not cascade into E0002"
    );
}

test "implicit return participates in return-type checking" {
    (program, _) = compile_and_check("implicit_return_rules.jac");
    # `wrong_type_tail` returns a string from `-> int` via implicit return.
    assert has_diagnostic_code(program, "E1002") , (
        "implicit return must be type-checked like an explicit return"
    );
    # `ok_tail`'s implicit return satisfies the all-paths-return analysis.
    assert not has_diagnostic_code(program, "E1004") , (
        "a tail implicit return must count as returning on all paths"
    );
}

test "redundant `{expr}` slot wrapping inside slot body raises E2028 (issue #6733)" {
    # `RedundantExprSlotWrap` re-wraps three *expression* bodies — a string
    # literal `{"none"}`, an arithmetic expr `{n + 1}` and a JSX element
    # `{<li>{n}</li>}`. Before #6733 these fell through to the misleading
    # `E0002 Missing ';'` (pointing at the *next* line). The parser now
    # recovers the wrap and reports the redundancy as E2028 at the `{` — the
    # expression sibling of the control-flow E2023, co-located in the parser —
    # with no E0002 cascade.
    (program, _) = compile_and_check("view_body_rules.jac");
    n = count_diagnostic_code(program, "E2028");
    assert n >= 3 , (
        f"E2028 should fire once per redundant single-expression wrap, got {n}"
    );
    # The two statement wraps (`RedundantSlotWrap`) stay the E2023 error; the
    # expression wraps must not inflate that count.
    e2023 = count_diagnostic_code(program, "E2023");
    assert e2023 == 2 , (
        f"only the two control-flow wraps stay E2023 errors, got {e2023}"
    );
    parse_cascade = count_diagnostic_code(program, "E0002");
    assert parse_cascade == 0 , (
        f"E2028 recovery must avoid the E0002 parse cascade, got {parse_cascade} E0002 errors"
    );
}

test "genuine collection literals in a slot body are not mistaken for slot wraps" {
    # A multi-element set `{1, 2}` and a dict `{a: 1}` are real collection
    # expressions, not redundant single-expression slot wraps — the `,`/`:`
    # disambiguates them, so the parser leaves them as collection literals and
    # must NOT raise E2028. Uses `parse_with_prog` so the parser diagnostics
    # (E2028 is parser-emitted) are captured.
    src = 'def:pub C(a: int) -> JsxElement { '
        + 'return <ul>{for x in [a] { {1, 2}; {a: 1}; }}</ul>; }';
    (prog, _) = parse_with_prog(src);
    n = count_diagnostic_code(prog, "E2028");
    assert n == 0 , f"genuine collection literals must not raise E2028, got {n}";
}

test "view body check warns on a keyless while (W2019)" {
    (program, _) = compile_and_check("view_body_rules.jac");
    # Shallow `while { <span/> }` AND nested `while { try { <span/> } }` AND
    # `while { switch { case _: <span/> } }` should all fire — verifies
    # `_emits_keyless_jsx` recurses through `try` and `switch`.
    n = count_diagnostic_code(program, "W2019", in_warnings=True);
    assert n >= 3 , (
        f"W2019 should fire for shallow, try-wrapped, and switch-wrapped keyless `while`, got {n}"
    );
}

# ══════════════════════════════════════════════════════════════════
#  ENTRY POINT — register parametrized tests
# ══════════════════════════════════════════════════════════════════
with entry {
    parametrize(
        "new reject",
        list(MUST_REJECT_NEW.items()),
        reject_test,
        id_fn=lambda (x: tuple[str, str]) { x[0]; }
    );
    parametrize(
        "new validate reject",
        list(MUST_VALIDATE_NEW.items()),
        validate_reject_test,
        id_fn=lambda (x: tuple[str, str]) { x[0]; }
    );
}

test "E2085 permits async client functions and implicit async client tests" {
    prog = JacProgram();
    prog.compile(
        use_str='import from "@jac/runtime" { jacLogin }\n'
        'async def app -> JsxElement { await jacLogin("a", "b"); return <div/>; }\n'
        'test "login" { await jacLogin("a", "b"); }\n',
        file_path="await_client.jac",
        no_cgen=True
    );
    assert not prog.errors_had , str(prog.errors_had);
}

test "E2085 rejects plain client functions and lambdas inside async tests" {
    prog = JacProgram();
    prog.compile(
        use_str='import from "@jac/runtime" { jacLogin }\n'
        'def app -> JsxElement { await jacLogin("a", "b"); return <div/>; }\n'
        'test "login" { callback = lambda { await jacLogin("a", "b"); }; }\n',
        file_path="invalid_await_client.jac",
        no_cgen=True
    );
    assert count_diagnostic_code(prog, "E2085") == 2;
}
