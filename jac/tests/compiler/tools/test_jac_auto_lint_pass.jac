"""Jac Auto Lint Pass tests – migrated from test_jac_auto_lint_pass.py."""

import contextlib;
import os;
import shutil;
import tempfile;
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.project.config { JacConfig, CheckConfig, LintConfig, set_config }

glob AUTO_LINT_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "tools", "fixtures", "auto_lint"
     ),
     STRESS_TEST_PATH = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "tools",
         "fixtures",
         "comment_normalize_stress_test.jac"
     );

"""Return the path to an auto_lint fixture file."""
def auto_lint_fixture_path(filename: str) -> str {
    return os.path.join(AUTO_LINT_FIXTURES, filename);
}

# ── TestJacAutoLintPass ──────────────────────────────────────────────────
test "auto lint full extraction" {
    formatted = lint_fmt("extractable.jac");

    # Should contain glob declarations for all extracted values
    # Note: consecutive globs with same modifiers are now combined; leading
    # comments stay attached to their assignment inside the combined glob
    assert ("glob x = 5,\n     y = " in formatted)
        or ("x = 5,\n     y = " in formatted);
    assert "y = " in formatted;
    assert "z = " in formatted;
    assert "int_val" in formatted;
    assert "float_val" in formatted;
    assert "str_val" in formatted;
    assert "bool_val" in formatted;
    assert "null_val" in formatted;
    assert "list_val" in formatted;
    assert "dict_val" in formatted;
    assert "tuple_val" in formatted;
    assert "set_val" in formatted;
    assert "sum_val" in formatted;
    assert "product" in formatted;
    assert "neg_val" in formatted;
    assert "not_val" in formatted;

    # Should NOT contain with entry block syntax (it was fully extracted)
    assert "with entry {" not in formatted;

    # Globs should come after imports
    import_pos = formatted.find("import from os");
    glob_pos = formatted.find("glob x = ");
    if (glob_pos < 0) {
        glob_pos = formatted.find("x = 5");
    }
    def_pos = formatted.find("def main");
    assert import_pos < glob_pos < def_pos;
}

# Lint-format an auto_lint fixture: mode "lint", "plain" (no lint), or a select list,
# which sets an explicit config because the repo jac.toml excludes tests from lint fixes.
def lint_prog(fixture: str, mode: (str | list[str]) = "lint") -> JacProgram {
    if isinstance(mode, list) {
        config = JacConfig();
        config.check = CheckConfig(lint=LintConfig(select=mode));
        set_config(config);
    }
    try {
        return JacProgram.jac_file_formatter(
            auto_lint_fixture_path(fixture), auto_lint=mode != "plain"
        );
    } finally {
        if isinstance(mode, list) {
            set_config(None);
        }
    }
}

def lint_fmt(fixture: str, mode: (str | list[str]) = "lint") -> str {
    return lint_prog(fixture, mode).mod.main.gen.jac;
}

# Strings a text lacks (a tuple means any one of them) and strings it must not have.
def text_problems(text: str, present: list[any], absent: list[str]) -> str {
    missing = [
        p
        for p in present
        if not (any(a in text for a in p) if isinstance(p, tuple) else p in text)
    ];
    leaked = [
        a
        for a in absent
        if a in text
    ];
    return f"missing {missing}, unexpected {leaked}" if missing or leaked else "";
}

# (case, fixture, mode, text the output must contain, text it must not contain)
glob LINT_CASES: list[tuple[str, str, any, list[any], list[str]]] = [
         (
             "auto lint no lint flag",
             "extractable.jac",
             "plain",
             ["with entry"],
             ["glob x", "glob int_val"]
         ),
         (
             "auto lint mixed extraction",
             "mixed_extraction.jac",
             "lint",
             ["glob x = 5;", "glob y = 10;", "with entry", "print("],
             []
         ),
         (
             "auto lint all assignments extracted",
             "non_extractable.jac",
             "lint",
             [
                 "result = some_function()",
                 "value = obj.attr",
                 "item = arr[0]",
                 ("with entry:__main__", "with entry :__main__")
             ],
             []
         ),
         (
             "auto lint named entry not modified",
             "non_extractable.jac",
             "lint",
             [("with entry:__main__", "with entry :__main__")],
             ["glob named_x"]
         ),
         (
             "auto lint existing globs preserved",
             "non_extractable.jac",
             "lint",
             [
                 "glob existing_x = 5,\n     existing_y = ",
                 "existing_y = ",
                 "existing_z = "
             ],
             []
         ),
         (
             "auto lint class entry not extracted",
             "class_entry.jac",
             "lint",
             [
                 "class MyClass",
                 "glob module_var = 100;",
                 "cls_obj = MyClass();",
                 "glob a = 5;",
                 "glob b = 6;",
                 "with entry {\n    if TYPE_CHECKING",
                 "import from math { SupportsFloat }",
                 "import from math { SupportsIndex }"
             ],
             ["glob instance_var", "glob another_var", "glob list_var", "glob cls_obj"]
         ),
         (
             "auto lint reassigned entry var not globalized",
             "reassigned_entry.jac",
             "lint",
             ["glob once = 5;", "with entry", "count = 0;", "count = count + 1;"],
             ["glob count"]
         ),
         (
             "auto lint entry reassignment of existing glob not globalized",
             "entry_reassigns_glob.jac",
             "lint",
             ["with entry", "config = 2;", "glob fresh = 10;"],
             []
         ),
         (
             "auto lint init postinit conversion",
             "init_conversion.jac",
             "lint",
             [
                 "def init",
                 "def postinit",
                 "def greet",
                 "super.__init__",
                 "Person().__init__",
                 "__init__ = 5",
                 "print(__init__)"
             ],
             ["def __init__", "def __post_init__"]
         ),
         (
             "combine glob consecutive",
             "consecutive_glob.jac",
             "lint",
             [
                 "glob x = 1,\n     y = 2,\n     z = 3;",
                 "glob:pub a = 10,\n     b = 20;",
                 "glob:protect c = 100,\n     d = 200,\n     e = 300;",
                 "glob m1 = 1;",
                 "glob:pub m2 = 2;",
                 "glob:protect m3 = 3;",
                 "glob before = 0;",
                 "glob after = 99;"
             ],
             []
         ),
         (
             "combine glob disabled without lint",
             "consecutive_glob.jac",
             "plain",
             ["glob x = 1;", "glob y = 2;", "glob z = 3;"],
             []
         ),
         (
             "staticmethod already static not modified",
             "staticmethod_decorator.jac",
             "lint",
             ["static def already_static"],
             []
         ),
         (
             "staticmethod multiple decorators preserved",
             "staticmethod_decorator.jac",
             "lint",
             ["@some_decorator", "static def decorated_static"],
             []
         ),
         (
             "staticmethod no lint preserves decorator",
             "staticmethod_decorator.jac",
             "plain",
             ["@staticmethod"],
             []
         ),
         (
             "unnecessary escape removed",
             "unnecessary_escape.jac",
             "lint",
             [
                 "foo = 1",
                 "bar = 2",
                 "myvar = 3",
                 "`node = 10",
                 "`edge = 20",
                 "`walker = 30"
             ],
             [
                 "`foo",
                 "`bar",
                 "`myvar",
                 "`count",
                 "`data",
                 "`name",
                 "`value",
                 "`item",
                 "`result",
                 "`input_val",
                 "`output_val",
                 "`total"
             ]
         ),
         (
             "empty parens removed",
             "empty_parens.jac",
             "lint",
             [
                 "def no_params {",
                 "def with_params(x: int)",
                 "def no_params_with_return -> int",
                 "def with_params_and_return(",
                 "x: int"
             ],
             ["def no_params()", "def no_params_with_return()"]
         ),
         (
             "empty parens method preserved when has self",
             "empty_parens.jac",
             "lint",
             [
                 "def method_with_self(self: MyClass)",
                 "def method_with_params(self: MyClass, a: int, b: int) -> int"
             ],
             []
         ),
         (
             "empty parens obj method removed",
             "empty_parens.jac",
             "lint",
             ["def reset {", "def increment(amount: int)", "def get_count -> int"],
             ["def reset()", "def get_count()"]
         ),
         (
             "empty parens impl removed",
             "empty_parens.jac",
             "lint",
             [
                 "impl Calculator.compute -> int",
                 "impl Calculator.process(x: int)",
                 ("impl Calculator.run{", "impl Calculator.run {")
             ],
             ["impl Calculator.compute()", "impl Calculator.run()"]
         ),
         (
             "hasattr to null ok",
             "hasattr_conversion.jac",
             "lint",
             [
                 "instance?.value",
                 "instance?.name",
                 'hasattr(instance, "name") or False',
                 "instance?.value or 0",
                 'instance?.name or "default"',
                 "instance?.name",
                 ("instance?.value and", "?.value and instance.value"),
                 "hasattr(instance, attr_name)",
                 "hasattr_lookalike(instance"
             ],
             [
                 'hasattr(instance, "value")',
                 "hasattr(instance, 'value')",
                 "instance.value if instance?.value",
                 "instance.name if instance?.name",
                 "instance?.name or None"
             ]
         ),
         (
             "hasattr no lint preserves",
             "hasattr_conversion.jac",
             "plain",
             ["hasattr(instance"],
             ["instance?."]
         ),
         (
             "getattr to null ok",
             "getattr_conversion.jac",
             "lint",
             [
                 "instance?.value",
                 "instance?.name",
                 "instance?.value is None",
                 "return o?.name",
                 "echo(instance?.name)",
                 "if instance?.value {",
                 'getattr(instance, "value", 0)',
                 'getattr(instance, "value")',
                 "getattr(instance, attr_name, None)",
                 'getattr(instance, "not-an-ident", None)',
                 'getattr(instance, "class", None)',
                 "getattr_lookalike(instance"
             ],
             [
                 'getattr(instance, "value", None)',
                 "getattr(instance, 'name', None)",
                 'getattr(instance, "name", None)',
                 'getattr(obj, "name", None)'
             ]
         ),
         (
             "getattr no lint preserves",
             "getattr_conversion.jac",
             "plain",
             ["getattr(instance"],
             ["instance?."]
         ),
         (
             "ternary to or",
             "ternary_to_or.jac",
             "lint",
             [
                 "instance.value or 0",
                 'instance?.name or "default"',
                 "instance?.value",
                 "if instance.name else",
                 ("instance?.value or -1", "instance?.value or (- 1)")
             ],
             [
                 "instance.value if instance.value else 0",
                 'instance?.name if instance?.name else "default"',
                 "instance?.value or None"
             ]
         ),
         (
             "ternary no lint preserves",
             "ternary_to_or.jac",
             "plain",
             ["if instance.value", "else 0"],
             []
         ),
         (
             "import from semicolons removed",
             "import_semicolon.jac",
             "lint",
             [
                 "import from typing { Optional }",
                 "import from sys { argv }",
                 "import json;",
                 "import math;",
                 "obj MyClass",
                 "def main"
             ],
             ["}\n    ;"]
         ),
         (
             "import semicolons preserved without lint",
             "import_semicolon.jac",
             "plain",
             ["import from typing", ";"],
             []
         ),
         (
             "future annotations removed",
             "future_annotations.jac",
             "lint",
             ["import from os", "obj Person", "def greet", "def main"],
             ["import from __future__"]
         ),
         (
             "future annotations preserved without lint",
             "future_annotations.jac",
             "plain",
             ["__future__", "annotations"],
             []
         ),
         (
             "W3037 auto-fix removes unnecessary -> None from abilities",
             "unnecessary_none_return.jac",
             "lint",
             [
                 "def no_return_with_none {",
                 "def with_params(x: int, y: str) {",
                 "def method(self: Foo) {",
                 "def has_return_with_none -> None",
                 "def no_return_with_type -> int"
             ],
             []
         ),
         (
             "W3037 auto-fix removes unnecessary -> None from lambdas",
             "unnecessary_none_return.jac",
             "lint",
             ["lambda (e: str) {", "lambda (x: int", "y: int) {", "lambda {"],
             []
         ),
         (
             "W3038 auto-fix converts useState to has declaration",
             "usestate_to_has.jac",
             "lint",
             [
                 "has count: int = 0",
                 "label: str = \"hello\"",
                 "count = count + 1;",
                 "label = \"clicked\";"
             ],
             ["setCount", "setLabel", "= useState(", "import from \"react\""]
         ),
         (
             "W3038 removes useState from partial import without breaking commas",
             "usestate_partial_import.jac",
             "lint",
             [
                 "has name: str = \"\"",
                 "name = str(e.target.value);",
                 "import from \"react\"",
                 "JsxElement",
                 "useEffect"
             ],
             ["setName", "= useState(", "{ useState", "useState,", ", }", "{ ,"]
         ),
         (
             "W3038 does not remove import when useState call is not a destructure assignment",
             "usestate_calls_remain.jac",
             "lint",
             ["useState(", "import from \"react\"", "useState"],
             []
         ),
         (
             "W3042 converts map lambda to list comprehension",
             "map_lambda_to_comprehension.jac",
             "lint",
             [
                 "for hour in hours",
                 "[<div className=\"text-xs text-center\">{hour}</div> for hour in hours]",
                 "items.map(",
                 "lambda (a: any",
                 "b: any)"
             ],
             ["for a in items", "for a, b in items"]
         ),
         (
             "W3042 filter-map chain converts to filtered comprehension",
             "filter_map_lambda_to_comprehension.jac",
             "lint",
             [
                 "<li className=\"active\">{item.name}</li>",
                 "for item in items",
                 "if item.active"
             ],
             [".map(", ".filter("]
         ),
         (
             "W3050 strip-comments removes all comments when selected",
             "deslop.jac",
             ["default", "strip-comments"],
             ["Module docstring to deslop", "Archetype docstring to deslop"],
             ["# standalone comment", "# inline comment", "# field comment"]
         ),
         (
             "W3050 strip-comments keeps jac:ignore directives",
             "deslop.jac",
             ["default", "strip-comments"],
             ["# jac:ignore[E1053]"],
             ["# field comment"]
         ),
         (
             "W3051 strip-docstrings removes all docstrings when selected",
             "deslop.jac",
             ["default", "strip-docstrings"],
             ["# standalone comment", "# inline comment"],
             ["Module docstring to deslop", "Archetype docstring to deslop"]
         ),
         (
             "W3051 strip-docstrings removes string statements inside bodies",
             "deslop_string_stmts.jac",
             ["default", "strip-docstrings"],
             [
                 "KEPT_FSTRING",
                 "KEPT_SUPPRESSED",
                 "KEPT_LONE_CASE",
                 "KEPT_LAMBDA_RETURN",
                 "KEPT_BEFORE_LONE_EXPR",
                 "KEPT_SLOT_CONTENT",
                 "return m;"
             ],
             [
                 "FIRST_STMT_DOC",
                 "MID_BODY_DOC",
                 "SINGLE_QUOTED_NOTE",
                 "MULTI_",
                 "NESTED_NOTE",
                 "CASE_NOTE",
                 "LAMBDA_NOTE"
             ]
         ),
         (
             "deslop rules fire under select all",
             "deslop.jac",
             ["all"],
             ["# jac:ignore[E1053]"],
             [
                 "# standalone comment",
                 "Module docstring to deslop",
                 "Archetype docstring to deslop"
             ]
         ),
         (
             "property-to-native folds '@x.getter' into the accessor block",
             "property_getter_decorator.jac",
             ["all"],
             [
                 "has val: int {",
                 "return self._val + 1;",
                 "setter(new_val: int)",
                 "@Container.val.setter"
             ],
             ["@property", "@val.getter", "@val.setter"]
         )
     ];

test "each lint case formats its fixture as expected" {
    failed: list[str] = [];
    for (label, fixture, mode, present, absent) in LINT_CASES {
        problems = text_problems(lint_fmt(fixture, mode), present, absent);
        if problems {
            failed.append(f"{label}: {problems}");
        }
    }
    assert not failed , "\n".join(failed);
}

# Comments the auto-lint pass must keep when it rewrites the comment stress file.
glob STRESS_COMMENTS: list[tuple[str, list[str]]] = [
         (
             "comment glob comments preserved",
             [
                 "# Comment before first glob",
                 "# Comment between glob statements",
                 "# Comment before third glob",
                 "# Inline on private glob"
             ]
         ),
         (
             "comment has comments preserved",
             [
                 "# Comment before first has",
                 "# Comment between has statements",
                 "# Comment before third has",
                 "# Inline on private has"
             ]
         ),
         (
             "comment method and impl comments preserved",
             [
                 "# Comment before method declaration",
                 "# Comment before staticmethod",
                 "# Comment before init",
                 "# Implementation comments",
                 "# Comment inside impl body",
                 "# Inline return comment",
                 "# Comment on staticmethod impl",
                 "# Comment inside helper"
             ]
         ),
         (
             "comment enum comments preserved",
             [
                 "# Enum with consecutive assignments and comments",
                 "# Comment before GREEN",
                 "# Comment before BLUE"
             ]
         ),
         (
             "comment hasattr conversion comments preserved",
             [
                 "# Test hasattr conversion with comments",
                 "# Comment before hasattr usage",
                 "# Comment inside if block",
                 "# Comment after if"
             ]
         ),
         (
             "comment ternary conversion comments preserved",
             [
                 "# Test ternary to or simplification with comments",
                 "# Comment before ternary that should become or",
                 "# Comment after ternary"
             ]
         ),
         (
             "comment entry block comments preserved",
             [
                 "# Test with entry block transformation",
                 "# Comment at start of entry",
                 "# Comment between statements",
                 "# Comment before print"
             ]
         ),
         (
             "comment escaped name comments preserved",
             [
                 "# Test backtick escaped names with comments",
                 "# Comment before escaped name",
                 "# Method with escaped param"
             ]
         ),
         (
             "comment nested obj comments preserved",
             ["# Nested obj with comments", "# Comment in inner obj has"]
         )
     ];

test "each comment in the stress file survives auto-lint" {
    formatted = JacProgram.jac_file_formatter(
        STRESS_TEST_PATH, auto_lint=True
    ).mod.main.gen.jac;
    failed: list[str] = [];
    for (label, comments) in STRESS_COMMENTS {
        problems = text_problems(formatted, comments, []);
        if problems {
            failed.append(f"{label}: {problems}");
        }
    }
    assert not failed , "\n".join(failed);
}

# (case, fixture, how many [no-print] errors it reports under select ["all"])
glob NO_PRINT_COUNTS: list[tuple[str, str, int]] = [
         ("comment no print error", "no_print.jac", 2),
         ("comment no print ignores qualified calls", "no_print.jac", 2),
         (
             "inline suppress wrong code does not suppress",
             "inline_suppress_wrong_code.jac",
             1
         ),
         ("inline suppress multiple codes", "inline_suppress.jac", 1)
     ];

test "each no-print case reports the expected error count" {
    failed: list[str] = [];
    for (label, fixture, expected) in NO_PRINT_COUNTS {
        found = [
            e.msg
            for e in lint_prog(fixture, ["all"]).errors_had
            if "[no-print]" in e.msg
        ];
        if len(found) != expected {
            failed.append(f"{label}: expected {expected}, got {len(found)}: {found}");
        }
    }
    assert not failed , "\n".join(failed);
}

# (case, line a jac:ignore suppresses, line that must still report no-print)
glob SUPPRESS_LINES: list[tuple[str, int, int]] = [
         ("inline suppress by code", 4, 5),
         ("inline suppress by alias", 9, 5)
     ];

test "inline jac:ignore suppresses no-print only on its own line" {
    prog = lint_prog("inline_suppress.jac", ["all"]);
    lines = [
        e.loc.first_line
        for e in prog.errors_had
        if "[no-print]" in e.msg
    ];
    failed = [
        f"{label}: line {off} still reported or line {on} not reported: {lines}"
        for (label, off, on) in SUPPRESS_LINES
        if off in lines or on not in lines
    ];
    assert not failed , "\n".join(failed);
}

# ── TestCombineConsecutiveHas ────────────────────────────────────────────
test "combine has consecutive" {
    formatted = lint_fmt("consecutive_has.jac");

    # Consecutive has statements should be combined into one
    # The three separate has statements become one with commas
    assert "has name: str," in formatted;
    assert "age: int," in formatted;
    assert "email: str;" in formatted;

    # Public has statements should be combined separately
    assert "has:pub address: str," in formatted;
    assert "phone: str;" in formatted;

    # Static has statements should be combined
    assert "static has DEBUG: bool = False," in formatted;
    assert "VERSION: str = " in formatted;
    assert "MAX_RETRIES: int = 3;" in formatted;

    # has with different modifiers should NOT be combined with others
    # city has default value but no access modifier, should stay separate from :pub:
    assert "has city: str = " in formatted;

    # Verify statements were actually combined (count semicolons in has statements)
    # Before: 6 separate has statements, After: 3 combined has statements
    person_section = formatted.split("obj Person")[1].split("obj Config")[0];
    # Count both "has " and "has:" patterns (access modifiers use has:pub format)
    has_count = person_section.count("has ") + person_section.count("has:");
    assert has_count == 3 , f"Expected 3 has statements in Person, got {has_count}";
}

test "combine has consecutive in ability" {
    formatted = lint_fmt("ability_has.jac");

    # has statements in app function should be combined
    assert "has count: int = 0," in formatted;
    assert "name: str = " in formatted;
    assert "enabled: bool = True;" in formatted;

    # has statements in client-side counter function should be combined
    assert "has value: int = 0," in formatted;
    assert "label: str = " in formatted;
    assert "visible: bool = True;" in formatted;

    # has statements in Widget.render method should be combined
    assert "has prefix: str = " in formatted;
    assert "suffix: str = " in formatted;
    assert "content: str = " in formatted;

    # Verify statements were actually combined (count has statements)
    # app function: 1 combined has statement (originally 3)
    app_section = formatted.split("def app")[1].split("}")[0];
    app_has_count = sum(
        [
            1
            for line in app_section.splitlines()
            if line.lstrip().startswith("has ")
        ]
    );
    assert app_has_count == 1 , f"Expected 1 has statement in app, got {app_has_count}";

    # render method: 1 combined has statement (originally 3)
    render_section = formatted.split("def render")[1].split("}")[0];
    render_has_count = sum(
        [
            1
            for line in render_section.splitlines()
            if line.lstrip().startswith("has ")
        ]
    );
    assert render_has_count == 1 , f"Expected 1 has statement in render, got {render_has_count}";
}

# ── TestCombineConsecutiveGlob ───────────────────────────────────────────
# ── TestStaticmethodConversion ───────────────────────────────────────────
test "staticmethod to static" {
    formatted = lint_fmt("staticmethod_decorator.jac");

    # Should use static keyword instead of @staticmethod decorator
    assert "static def add" in formatted;
    assert "static def multiply" in formatted;

    # Should NOT have @staticmethod decorator in code (may be in docstring)
    # Count occurrences - should only appear in the docstring
    assert formatted.count("@staticmethod") == 1 , "Only in docstring";
    assert "@staticmethod\n" not in formatted;

    # Instance method should remain unchanged
    assert "def instance_method" in formatted;
    assert "static def instance_method" not in formatted;
}

# ── TestFormatCommandIntegration ─────────────────────────────────────────
test "format with lint default" {
    # Copy fixture to temp location
    src = auto_lint_fixture_path("extractable.jac");
    tmp_dir = tempfile.mkdtemp();
    try {
        dst = os.path.join(tmp_dir, "test.jac");
        shutil.copy(src, dst);

        # Format the file with auto_lint enabled
        prog = JacProgram.jac_file_formatter(dst, auto_lint=True);
        formatted = prog.mod.main.gen.jac;

        # Linting should have been applied
        assert "glob" in formatted;
    } finally {
        shutil.rmtree(tmp_dir);
    }
}

test "format auto formats impl files" {
    import from jaclang.cli.commands { analysis }

    # Copy fixture files to temp directory
    fixture_dir = os.path.dirname(auto_lint_fixture_path("sig_mismatch.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        # Copy main file
        main_src = auto_lint_fixture_path("sig_mismatch.jac");
        main_dst = os.path.join(tmpdir, "sig_mismatch.jac");
        shutil.copy2(main_src, main_dst);
        # Copy impl file (create impl subdirectory)
        impl_dir = os.path.join(tmpdir, "impl");
        os.makedirs(impl_dir);
        impl_src = os.path.join(fixture_dir, "impl", "sig_mismatch.impl.jac");
        impl_dst = os.path.join(impl_dir, "sig_mismatch.impl.jac");
        shutil.copy2(impl_src, impl_dst);
        # Read original impl content (has wrong param names)
        with open(impl_dst) as f {
            original_impl = f.read();
        }
        assert "impl Calculator.add(a: int, b: int)" in original_impl;
        # Run CLI lint command with --fix
        with contextlib.suppress(SystemExit) {
            analysis.lint([main_dst], fix=True);
        }
        # Read the updated impl file
        with open(impl_dst) as f {
            updated_impl = f.read();
        }
        # The impl file should have been fixed: param names changed from a,b to x,y
        assert ".add(x: int, y: int)" in updated_impl , f"Impl file should have been updated with fixed params.\nGot: {updated_impl}";
    }
}

test "format lintfix reports no print" {
    import from jaclang.cli.commands { analysis }

    # Copy no_print fixture to temp location
    src = auto_lint_fixture_path("no_print.jac");
    tmp_dir = tempfile.mkdtemp();
    try {
        dst = os.path.join(tmp_dir, "no_print.jac");
        shutil.copy(src, dst);

        # Simulate jac.toml with no-print enabled via select = ["all"]
        config = JacConfig.from_toml_str('[check.lint]\nselect = ["all"]\n');
        set_config(config);
        try {
            # Run format with --lintfix (should report no-print errors and exit 1)
            result = analysis.format([dst], lintfix=True);
        } finally {
            set_config(None);
        }

        # no-print errors are unfixable, so format --lintfix should fail
        assert result == 1 , "format --lintfix should return 1 when unfixable lint errors exist";
    } finally {
        shutil.rmtree(tmp_dir);
    }
}

# ── TestRemoveUnnecessaryEscape ──────────────────────────────────────────
# ── TestRemoveEmptyParens ────────────────────────────────────────────────
test "paren-less zero-arg def emits no W3005" {
    src = "def already_clean {\n    return;\n}\n\n"
    "def clean_with_return -> int {\n    return 1;\n}\n";
    (fd, path) = tempfile.mkstemp(suffix=".jac");
    os.close(fd);
    with open(path, "w") as f {
        f.write(src);
    }
    try {
        prog = JacProgram.jac_file_formatter(path, auto_lint=True);
        formatted = prog.mod.main.gen.jac;
        assert "def already_clean {" in formatted;
        assert "def clean_with_return -> int {" in formatted;
        for w in (prog.warnings_had or []) {
            assert "remove-empty-parens" not in str(w) , (
                f"false W3005 on paren-less def: {w}"
            );
        }
    } finally {
        os.remove(path);
    }
}

# ── TestHasattrConversion ────────────────────────────────────────────────
# ── TestGetattrConversion ────────────────────────────────────────────────
# ── TestTernaryToOrConversion ────────────────────────────────────────────
# ── TestSignatureMismatchFix ─────────────────────────────────────────────
test "signature mismatch fixed" {
    # Annex files are formatted as their own tool programs now; the auto-lint
    # pass loads the base file's decls on demand to fix mismatched impl
    # signatures, so we format the .impl.jac annex directly.
    prog = lint_prog(os.path.join("impl", "sig_mismatch.impl.jac"), ["all"]);

    # Check the impl signatures were fixed by examining the AST nodes directly
    impl_mod = prog.mod.main;

    # Helper to get param names from an ImplDef
    def get_impl_params(impl_def: uni.ImplDef) -> list[str] {
        if isinstance(impl_def.spec, uni.FuncSignature) {
            return [p.name.value for p in impl_def.spec.params];
        }
        return [];
    }

    # Find all impl definitions by name
    impl_defs: dict[str, uni.ImplDef] = {};
    for stmt in impl_mod.body {
        if isinstance(stmt, uni.ImplDef) {
            # Get the method name (last part of target)
            method_name = stmt.target[-1].sym_name;
            impl_defs[method_name] = stmt;
        }
    }

    # add should have x, y params (from decl), not a, b
    assert "add" in impl_defs , "add impl not found";
    add_params = get_impl_params(impl_defs["add"]);
    assert add_params == ["x", "y"] , f"add should have x, y params from decl, got: {add_params}";

    # multiply should have a, b params (from decl)
    assert "multiply" in impl_defs , "multiply impl not found";
    multiply_params = get_impl_params(impl_defs["multiply"]);
    assert multiply_params == ["a", "b"] , f"multiply should have a, b params from decl, got: {multiply_params}";

    # no_change should remain unchanged (already matches)
    assert "no_change" in impl_defs , "no_change impl not found";
    no_change_params = get_impl_params(impl_defs["no_change"]);
    assert no_change_params == ["val"] , f"no_change should have val param, got: {no_change_params}";

    # reset should have no params (impl had extra param that should be removed)
    assert "reset" in impl_defs , "reset impl not found";
    reset_params = get_impl_params(impl_defs["reset"]);
    assert reset_params == [] , f"reset should have no params from decl, got: {reset_params}";
}

# ── TestNestedClassSignatureFix ──────────────────────────────────────────
test "nested class impl signature fixed" {
    # Format the .impl.jac annex directly; the auto-lint pass resolves nested
    # archetype decls (OuterClass.InnerClass.init, ...) from the base file.
    prog = lint_prog(os.path.join("impl", "nested_class_sig.impl.jac"), ["all"]);

    impl_mod = prog.mod.main;

    # Helper to get the full target path as a string
    def get_target_path(impl_def: uni.ImplDef) -> str {
        return ".".join(
            [
                t.sym_name
                for t in impl_def.target
                if t
            ]
        );
    }

    # Helper to get param names from an ImplDef
    def get_impl_params(impl_def: uni.ImplDef) -> list[str] {
        if isinstance(impl_def.spec, uni.FuncSignature) {
            return [p.name.value for p in impl_def.spec.params];
        }
        return [];
    }

    # Find all impl definitions by full target path
    impl_defs: dict[str, uni.ImplDef] = {};
    for stmt in impl_mod.body {
        if isinstance(stmt, uni.ImplDef) {
            target_path = get_target_path(stmt);
            impl_defs[target_path] = stmt;
        }
    }

    # OuterClass.init should have: self, shared, private (already correct)
    assert "OuterClass.init" in impl_defs , "OuterClass.init impl not found";
    outer_init_params = get_impl_params(impl_defs["OuterClass.init"]);
    assert outer_init_params == ["self", "shared", "private"] , f"OuterClass.init should have [self, shared, private], got: {outer_init_params}";

    # OuterClass.InnerClass.init should be FIXED from (self, a, b) to (self, name)
    # NOT: (self, shared, private) which would happen if bug exists
    assert "OuterClass.InnerClass.init" in impl_defs , "OuterClass.InnerClass.init impl not found";
    inner_init_params = get_impl_params(impl_defs["OuterClass.InnerClass.init"]);
    assert inner_init_params == ["self", "name"] , "OuterClass.InnerClass.init should be FIXED to [self, name] "
    f"(matching InnerClass.init decl), got: {inner_init_params}. "
    "Original impl had [self, a, b]. "
    "If you got [self, shared, private], the bug is that auto-lint looked up "
    "OuterClass.init instead of InnerClass.init.";

    # OuterClass.AnotherInner.init should be FIXED from (self, foo) to (self, x, y)
    # (plus kwonly z, but we only check positional params here)
    assert "OuterClass.AnotherInner.init" in impl_defs , "OuterClass.AnotherInner.init impl not found";
    another_init_params = get_impl_params(impl_defs["OuterClass.AnotherInner.init"]);
    assert another_init_params == ["self", "x", "y"] , "OuterClass.AnotherInner.init should be FIXED to [self, x, y] "
    f"(matching AnotherInner.init decl), got: {another_init_params}. "
    "Original impl had [self, foo].";

    # OuterClass.process should be FIXED from (wrong) to (data)
    assert "OuterClass.process" in impl_defs , "OuterClass.process impl not found";
    process_params = get_impl_params(impl_defs["OuterClass.process"]);
    assert process_params == ["data"] , "OuterClass.process should be FIXED to [data] "
    f"(matching process decl), got: {process_params}. "
    "Original impl had [wrong].";
}

# ── TestRemoveImportSemicolons ───────────────────────────────────────────
# ── TestRemoveRedundantSemis ─────────────────────────────────────────────
test "redundant semicolons removed from all bodies" {
    formatted = lint_fmt("redundant_semi.jac");

    # Lone-semicolon blocks collapse to empty blocks
    assert "def empty_fn {}" in formatted;
    assert "def method {}" in formatted;
    assert "can act with Root entry {}" in formatted;
    assert "if flag {}" in formatted;
    assert "else {}" in formatted;
    assert "while flag {}" in formatted;
    assert "for i in range(1) {}" in formatted;
    assert "try {}" in formatted;
    assert "except Exception {}" in formatted;
    assert "finally {}" in formatted;
    assert "test {}" in formatted;
    assert "named {}" in formatted;

    # Stray semicolons between statements are gone; real terminators stay
    assert ";;" not in formatted;
    semi_only_lines = [
        ln
        for ln in formatted.splitlines()
        if ln.strip() == ";"
    ];
    assert not semi_only_lines , f"stray semicolon lines remain: {semi_only_lines}";
    assert "x = 1;" in formatted;
    assert "y = 2;" in formatted;
    assert "{ }" not in formatted;
}

test "match case keeps its required lone semicolon" {
    formatted = lint_fmt("redundant_semi_match.jac");

    # An empty case body is not parseable, so the lone semicolon must survive
    # (one per case); only the surplus one in `case 2: ;;` is removed.
    semi_only_lines = [
        ln
        for ln in formatted.splitlines()
        if ln.strip() == ";"
    ];
    assert len(semi_only_lines) == 2 , f"expected 2 kept semis, got: {semi_only_lines}";
    assert ";;" not in formatted;
}

test "redundant semicolons preserved without lint" {
    formatted = lint_fmt("redundant_semi.jac", "plain");

    semi_only_lines = [
        ln
        for ln in formatted.splitlines()
        if ln.strip() == ";"
    ];
    assert semi_only_lines , "plain formatting must not delete standalone semicolons";
}

# ── TestRemoveFutureAnnotations ──────────────────────────────────────────
# ── TestCommentPreservation ──────────────────────────────────────────────
test "comment no orphaned comments at eof" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Critical check: standalone comments should appear BEFORE the code they precede,
    # not at the end of the file
    critical_standalone_comments = [
        "# Comment before first glob",
        "# Comment between glob statements",
        "# Comment before first has",
        "# Comment between has statements",
        "# Comment before method declaration",
        "# Comment inside impl body",
        "# Test hasattr conversion with comments",
        "# Comment before hasattr usage"
    ];

    for comment in critical_standalone_comments {
        # Find the position of this comment
        pos = formatted.find(comment);
        assert pos != -1 , f"Comment not found: {comment}";

        # Check that it's NOT in the last 500 characters (orphan section)
        assert pos < len(formatted) - 500 , f"Critical standalone comment appears to be orphaned at end: {comment}";
    }

    # Also verify the final legitimate comment is near the end but not orphaned
    final_comment_pos = formatted.find("# Final comment at end of file");
    assert final_comment_pos != -1 , "Final comment should be present";
    # It should be in the last third of the file (normal position)
    assert final_comment_pos > len(formatted) * 0.5 , "Final comment should be near the end of file, not moved earlier";
}

test "comment no print disabled by default" {
    input_path = auto_lint_fixture_path("no_print.jac");

    # Explicitly use default config (select=["default"]) to isolate from project jac.toml
    config = JacConfig();
    set_config(config);
    try {
        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    } finally {
        set_config(None);
    }

    error_msgs = [e.msg for e in prog.errors_had];
    no_print_errors = [
        m
        for m in error_msgs
        if "[no-print]" in m
    ];
    assert len(no_print_errors) == 0 , f"Expected no no-print errors by default, got: {no_print_errors}";
}

# ── Inline Suppression Tests ───────────────────────────────────────────
# ── TestW3037UnnecessaryNoneReturn ───────────────────────────────────────
# ── TestW3038UseStateToHas ────────────────────────────────────────────────
# ── W3042: map(lambda → JSX) to list comprehension ──────────────────────────
test "W0060 flags every string statement in a body, not only the first" {
    prog = JacProgram();
    prog.compile(file_path=auto_lint_fixture_path("deslop_string_stmts.jac"));
    lines = sorted(
        w.loc.first_line
        for w in prog.warnings_had
        if w.code is not None and w.code.code == "W0060"
    );
    assert lines == [2, 8, 9, 10, 12, 14, 29] , f"W0060 lines: {lines}";
}

"""Format the separate_impls fixture under the given lint select list."""
def format_separate_impls(select: list[str]) -> str {
    config = JacConfig();
    config.check = CheckConfig(lint=LintConfig(select=select));
    set_config(config);
    try {
        prog = JacProgram.jac_file_formatter(
            auto_lint_fixture_path("separate_impls.jac"), auto_lint=True
        );
        return prog.mod.main.gen.jac;
    } finally {
        set_config(None);
    }
}

test "W3055 separate-impls moves bodies into impls at the bottom of the module" {
    formatted = format_separate_impls(["separate-impls"]);
    assert "    def bar(x: int, y: str = \"s\") -> int;\n" in formatted;
    assert "        def deep -> int;\n" in formatted;
    assert "    static def make -> Foo;\n" in formatted;
    assert "    can visit_root with Root entry;\n" in formatted;
    assert "\ndef top(a: int) -> int;\n" in formatted;
    tail = formatted[formatted.index("with entry {"):];
    assert "impl Foo.bar(x: int, y: str = \"s\") -> int {" in tail;
    assert "impl Foo.Inner.deep -> int {\n    return 3;\n}" in tail;
    assert "impl Foo.make -> Foo {" in tail;
    assert "impl W.visit_root with Root entry {\n    visit [-->];\n}" in tail;
    assert "impl top(a: int) -> int {\n    def helper(b: int) -> int {" in tail;
    # Comments travel with the code they sit on.
    assert "    # bar comment\n    def bar(" in formatted;
    assert "-> int {\n    # inner comment\n    return x + self.a;" in tail;
    # The impls keep the order their declarations appear in.
    assert tail.index("impl Foo.bar") < tail.index("impl Foo.Inner.deep");
    assert tail.index("impl Foo.make") < tail.index("impl W.visit_root");
    assert tail.index("impl W.visit_root") < tail.index("impl top(");
    assert "\n) -> str {\n    return beta_parameter;" in tail;
    assert "impl Foo.quiet_hook(\n" in tail;
    assert "impl Foo.tiny {}" in tail;
}

test "W3055 leaves bodies that an impl cannot name in place" {
    formatted = format_separate_impls(["separate-impls"]);
    # Nameless abilities and nested functions stay inline.
    assert "    can with Root entry {\n        disengage;" in formatted;
    assert "impl helper" not in formatted;
    assert formatted.count("impl Foo.declared") == 1;
    # A field sharing the method's name would capture the impl's target.
    assert "    def init(self: Field, flag: bool) {" in formatted;
    assert "impl Field.init" not in formatted;
}

test "W3055 separates generic bodies and restates their type parameters" {
    formatted = format_separate_impls(["separate-impls"]);
    assert "    def generic[T](x: T) -> T;\n" in formatted;
    assert "impl Foo.generic[T](x: T) -> T {\n    return x;" in formatted;
}

test "W3055 separates client component bodies like any other" {
    formatted = format_separate_impls(["separate-impls"]);
    assert "\ndef badge(label: str) -> JsxElement;\n" in formatted;
    assert "impl badge(label: str) -> JsxElement {\n    return <span>{label}</span>;"
        in formatted;
    assert "\ndef counter;\n" in formatted;
    assert "impl counter {\n    has clicks: int = 0;" in formatted;
}

test "W3055 separate-impls is idempotent" {
    formatted = format_separate_impls(["separate-impls"]);
    with tempfile.TemporaryDirectory() as tmpdir {
        path = os.path.join(tmpdir, "again.jac");
        with open(path, "w") as f {
            f.write(formatted);
        }
        config = JacConfig();
        config.check = CheckConfig(lint=LintConfig(select=["separate-impls"]));
        set_config(config);
        try {
            again = JacProgram.jac_file_formatter(
                path, auto_lint=True
            ).mod.main.gen.jac;
        } finally {
            set_config(None);
        }
    }
    assert again == formatted;
}

test "W3055 separate-impls is on under all and off under default" {
    assert "impl Foo.bar(" in format_separate_impls(["all"]);
    assert "impl Foo.bar(" not in format_separate_impls(["default"]);
    assert "impl Foo.bar(" not in format_separate_impls(["default", "strip-comments"]);
}

"""Lint-format `source` as mod.jac under `select`; return the text and W3056 count."""
def format_impls_in_annex(source: str, select: list[str]) -> tuple[str, int] {
    config = JacConfig();
    config.check = CheckConfig(lint=LintConfig(select=select));
    set_config(config);
    try {
        with tempfile.TemporaryDirectory() as tmpdir {
            path = os.path.join(tmpdir, "mod.jac");
            with open(path, "w") as f {
                f.write(source);
            }
            prog = JacProgram.jac_file_formatter(path, auto_lint=True);
            flagged = [
                w
                for w in prog.warnings_had
                if w.code is not None and w.code.code == "W3056"
            ];
            return (prog.mod.main.gen.jac, len(flagged));
        }
    } finally {
        set_config(None);
    }
}

glob IMPLS_IN_MODULE = (
         "obj Foo {\n    def bar -> int;\n    def baz -> int;\n}\n\n"
         "impl Foo.bar -> int {\n    return 1;\n}\n\n"
         "glob LIMIT: int = 3;\n\n"
         "impl Foo.baz -> int {\n    return 2;\n}\n\n"
         "def top -> int;\n"
     );

test "W3056 impls-in-annex flags each impl and sinks them below the module" {
    (formatted, flagged) = format_impls_in_annex(IMPLS_IN_MODULE, ["impls-in-annex"]);
    assert flagged == 2 , flagged;
    head = formatted[:formatted.index("impl Foo.bar")];
    assert "glob LIMIT: int = 3;" in head and "def top -> int;" in head , formatted;
    assert formatted.index("impl Foo.bar") < formatted.index("impl Foo.baz");
    assert formatted.rstrip().endswith("return 2;\n}") , formatted;
}

test "W3056 impls-in-annex is on under all and off under default" {
    assert format_impls_in_annex(IMPLS_IN_MODULE, ["all"])[1] == 2;
    assert format_impls_in_annex(IMPLS_IN_MODULE, ["default"])[1] == 0;
    assert format_impls_in_annex(IMPLS_IN_MODULE, ["separate-impls"])[1] == 0;
}

test "deslop rules are disabled under default select" {
    input_path = auto_lint_fixture_path("deslop.jac");
    config = JacConfig();
    set_config(config);
    try {
        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
        formatted = prog.mod.main.gen.jac;
    } finally {
        set_config(None);
    }
    assert "# standalone comment" in formatted;
    assert "Module docstring to deslop" in formatted;
}

test "property-to-native re-targets impl-separated accessor bodies" {
    import from jaclang.cli.commands { analysis }

    # The declaring object and its impl file are linted as two separate runs, so the
    # impl side has to read the accessors back out of the file it annexes. A getter
    # impl and a setter impl share the dotted target 'Temperature.celsius', so only
    # their signatures say which accessor each one fills.
    fixture_dir = os.path.dirname(auto_lint_fixture_path("property_impl_split.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        main_dst = os.path.join(tmpdir, "property_impl_split.jac");
        shutil.copy2(auto_lint_fixture_path("property_impl_split.jac"), main_dst);
        impl_dir = os.path.join(tmpdir, "impl");
        os.makedirs(impl_dir);
        impl_dst = os.path.join(impl_dir, "property_impl_split.impl.jac");
        shutil.copy2(
            os.path.join(fixture_dir, "impl", "property_impl_split.impl.jac"), impl_dst
        );
        with contextlib.suppress(SystemExit) {
            analysis.lint([main_dst], fix=True);
        }
        with open(main_dst) as f {
            updated_main = f.read();
        }
        with open(impl_dst) as f {
            updated_impl = f.read();
        }
        # Declarations collapse into one native accessor block.
        assert "has celsius: float {" in updated_main , updated_main;
        assert "@property" not in updated_main , updated_main;
        assert "@celsius.setter" not in updated_main , updated_main;
        # Impl bodies are re-targeted to dotted-impl form so they still bind.
        assert "impl Temperature.celsius.getter" in updated_impl , updated_impl;
        assert "impl Temperature.celsius.setter" in updated_impl , updated_impl;
    }
}
