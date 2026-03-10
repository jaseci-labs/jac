"""Jac Auto Lint Pass tests – migrated from test_jac_auto_lint_pass.py."""

import contextlib;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.project.config { JacConfig, CheckConfig, LintConfig, set_config }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     AUTO_LINT_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "tool", "fixtures", "auto_lint"
     ),
     STRESS_TEST_PATH = os.path.join(
         JAC_ROOT, "jaclang", "tests", "fixtures", "comment_normalize_stress_test.jac"
     );

"""Return the path to an auto_lint fixture file."""
def auto_lint_fixture_path(filename: str) -> str {
    return os.path.join(AUTO_LINT_FIXTURES, filename);
}

# ── TestJacAutoLintPass ──────────────────────────────────────────────────
test "auto lint full extraction" {
    input_path = auto_lint_fixture_path("extractable.jac");

    # Format with linting enabled
    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Should contain glob declarations for all extracted values
    # Note: consecutive globs with same modifiers are now combined
    assert "glob x = 5,\n     y = " in formatted;
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
    def_pos = formatted.find("def main");
    assert import_pos < glob_pos < def_pos;
}

test "auto lint no lint flag" {
    input_path = auto_lint_fixture_path("extractable.jac");

    # Format with linting disabled
    prog = JacProgram.jac_file_formatter(input_path, auto_lint=False);
    formatted = prog.mod.main.gen.jac;

    # Should still contain with entry block
    assert "with entry" in formatted;

    # Should NOT contain glob declarations for extracted values
    assert "glob x" not in formatted;
    assert "glob int_val" not in formatted;
}

test "auto lint mixed extraction" {
    input_path = auto_lint_fixture_path("mixed_extraction.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Extractable assignments should become globs
    assert "glob x = 5;" in formatted;
    assert "glob y = 10;" in formatted;

    # Non-extractable statement should stay in with entry
    assert "with entry" in formatted;
    assert "print(" in formatted;
}

test "auto lint all assignments extracted" {
    input_path = auto_lint_fixture_path("non_extractable.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # All assignments should become globs (even function calls, attr access, etc.)
    # Note: consecutive globs with same modifiers are now combined
    assert "result = some_function()" in formatted;
    assert "value = obj.attr" in formatted;
    assert "item = arr[0]" in formatted;

    # The unnamed with entry block should be removed (all assignments extracted)
    # Only named entry block should remain
    assert "with entry:__main__" in formatted or "with entry :__main__" in formatted;
}

test "auto lint named entry not modified" {
    input_path = auto_lint_fixture_path("non_extractable.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Named entry block should be preserved
    assert "with entry:__main__" in formatted or "with entry :__main__" in formatted;

    # Assignment inside named entry should NOT become glob
    assert "glob named_x" not in formatted;
}

test "auto lint existing globs preserved" {
    input_path = auto_lint_fixture_path("non_extractable.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Should preserve existing glob declarations
    # Note: consecutive globs with same modifiers are now combined
    # Format is now multiline with all assignments indented
    assert "glob existing_x = 5,\n     existing_y = " in formatted;
    assert "existing_y = " in formatted;
    assert "existing_z = " in formatted;
}

test "auto lint class entry not extracted" {
    input_path = auto_lint_fixture_path("class_entry.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Class with entry should be preserved (glob doesn't work in classes)
    assert "class MyClass" in formatted;

    # The class should still have its with entry block
    # Check that class body assignments did NOT become module-level globs
    assert "glob instance_var" not in formatted;
    assert "glob another_var" not in formatted;
    assert "glob list_var" not in formatted;

    # Module-level with entry SHOULD be fully extracted (all assignments)
    # Note: consecutive globs with same modifiers are now combined
    # Format is now multiline with all assignments indented
    assert "glob module_var = 100,\n     cls_obj = MyClass();" in formatted;

    # Module-level with entry containing TYPE_CHECKING blocks should extract
    # assignments to glob while keeping if blocks in with entry (since if
    # statements cannot be at bare module level in Jac)
    assert "glob a = 5;" in formatted;
    assert "glob b = 6;" in formatted;
    # The if TYPE_CHECKING blocks must stay inside with entry
    assert "with entry {\n    if TYPE_CHECKING" in formatted;
    assert "import from math { SupportsFloat }" in formatted;
    assert "import from math { SupportsIndex }" in formatted;
}

test "auto lint init postinit conversion" {
    input_path = auto_lint_fixture_path("init_conversion.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Method definitions converted
    assert "def __init__" not in formatted;
    assert "def __post_init__" not in formatted;
    assert "def init" in formatted;
    assert "def postinit" in formatted;

    # Regular methods unchanged
    assert "def greet" in formatted;

    # Other __init__ usages preserved (not method definitions)
    assert "super.__init__" in formatted;
    assert "Person().__init__" in formatted;
    assert "__init__ = 5" in formatted;
    assert "print(__init__)" in formatted;
}

# ── TestCombineConsecutiveHas ────────────────────────────────────────────
test "combine has consecutive" {
    input_path = auto_lint_fixture_path("consecutive_has.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

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
    input_path = auto_lint_fixture_path("ability_has.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

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
test "combine glob consecutive" {
    input_path = auto_lint_fixture_path("consecutive_glob.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Consecutive glob statements should be combined into one
    # The three separate glob statements become one with commas
    # Format is now multiline with all assignments indented
    assert "glob x = 1,\n     y = 2,\n     z = 3;" in formatted;

    # Public glob statements should be combined separately
    assert "glob:pub a = 10,\n     b = 20;" in formatted;

    # Protected glob statements should be combined separately
    assert "glob:protect c = 100,\n     d = 200,\n     e = 300;" in formatted;

    # Mixed modifiers should NOT be combined together
    # Each should be its own statement
    assert "glob m1 = 1;" in formatted;
    assert "glob:pub m2 = 2;" in formatted;
    assert "glob:protect m3 = 3;" in formatted;

    # Non-consecutive globs should NOT be combined
    assert "glob before = 0;" in formatted;
    assert "glob after = 99;" in formatted;
}

test "combine glob disabled without lint" {
    input_path = auto_lint_fixture_path("consecutive_glob.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=False);
    formatted = prog.mod.main.gen.jac;

    # Without linting, globs should remain separate
    assert "glob x = 1;" in formatted;
    assert "glob y = 2;" in formatted;
    assert "glob z = 3;" in formatted;
}

# ── TestStaticmethodConversion ───────────────────────────────────────────
test "staticmethod to static" {
    input_path = auto_lint_fixture_path("staticmethod_decorator.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

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

test "staticmethod already static not modified" {
    input_path = auto_lint_fixture_path("staticmethod_decorator.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Should still have static keyword
    assert "static def already_static" in formatted;
}

test "staticmethod multiple decorators preserved" {
    input_path = auto_lint_fixture_path("staticmethod_decorator.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Other decorators should be preserved
    assert "@some_decorator" in formatted;

    # Should be static now
    assert "static def decorated_static" in formatted;
}

test "staticmethod no lint preserves decorator" {
    input_path = auto_lint_fixture_path("staticmethod_decorator.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=False);
    formatted = prog.mod.main.gen.jac;

    # Should still have @staticmethod decorator
    assert "@staticmethod" in formatted;
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
test "unnecessary escape removed" {
    input_path = auto_lint_fixture_path("unnecessary_escape.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Regular variable names should NOT have backtick escaping
    assert "`foo" not in formatted;
    assert "`bar" not in formatted;
    assert "`myvar" not in formatted;
    assert "`count" not in formatted;
    assert "`data" not in formatted;
    assert "`name" not in formatted;
    assert "`value" not in formatted;
    assert "`item" not in formatted;
    assert "`result" not in formatted;
    assert "`input_val" not in formatted;
    assert "`output_val" not in formatted;
    assert "`total" not in formatted;

    # But the actual names should still be present (without backtick)
    assert "foo = 1" in formatted;
    assert "bar = 2" in formatted;
    assert "myvar = 3" in formatted;

    # Jac keywords SHOULD still have backtick escaping
    assert "`node = 10" in formatted;
    assert "`edge = 20" in formatted;
    assert "`walker = 30" in formatted;
}

# ── TestRemoveEmptyParens ────────────────────────────────────────────────
test "empty parens removed" {
    input_path = auto_lint_fixture_path("empty_parens.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Functions with no params should have parens removed
    assert "def no_params {" in formatted;
    assert "def no_params()" not in formatted;

    # Functions with params should keep parens
    assert "def with_params(x: int)" in formatted;

    # Functions with no params but return type should have parens removed
    assert "def no_params_with_return -> int" in formatted;
    assert "def no_params_with_return()" not in formatted;

    # Functions with params and return type should keep parens
    assert "def with_params_and_return(" in formatted;
    assert "x: int" in formatted;
}

test "empty parens method preserved when has self" {
    input_path = auto_lint_fixture_path("empty_parens.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Methods with self should keep parens
    assert "def method_with_self(self: MyClass)" in formatted;

    # Methods with self and other params should keep parens
    assert "def method_with_params(self: MyClass, a: int, b: int) -> int" in formatted;
}

test "empty parens obj method removed" {
    input_path = auto_lint_fixture_path("empty_parens.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # obj methods with no params should have parens removed
    assert "def reset {" in formatted;
    assert "def reset()" not in formatted;

    # obj methods with params should keep parens
    assert "def increment(amount: int)" in formatted;

    # obj methods with no params but return type should have parens removed
    assert "def get_count -> int" in formatted;
    assert "def get_count()" not in formatted;
}

test "empty parens impl removed" {
    input_path = auto_lint_fixture_path("empty_parens.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Impl with no params but return type - parens should be removed
    assert "impl Calculator.compute -> int" in formatted;
    assert "impl Calculator.compute()" not in formatted;

    # Impl with params - parens should stay
    assert "impl Calculator.process(x: int)" in formatted;

    # Impl with no params and no return type - parens should be removed
    # Note: formatter may or may not add space before {
    assert "impl Calculator.run{" in formatted or "impl Calculator.run {" in formatted;
    assert "impl Calculator.run()" not in formatted;
}

# ── TestHasattrConversion ────────────────────────────────────────────────
test "hasattr to null ok" {
    input_path = auto_lint_fixture_path("hasattr_conversion.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Basic hasattr in if-else should be converted
    assert "instance?.value" in formatted;
    assert "instance?.name" in formatted;

    # hasattr calls in safe patterns (ternary, guard-and-use) should be converted
    assert 'hasattr(instance, "value")' not in formatted;
    assert "hasattr(instance, 'value')" not in formatted;

    # hasattr in standalone boolean context (or False) should NOT be converted
    # because hasattr() returns bool while obj?.attr returns the value
    assert 'hasattr(instance, "name") or False' in formatted;

    # The if-else expressions with hasattr should be converted to or expressions
    # Pattern: obj.attr if hasattr(obj, "attr") else default
    # Step 1: becomes obj?.attr if obj?.attr else default
    # Step 2: becomes obj?.attr or default (ternary-to-or optimization)
    assert "instance?.value or 0" in formatted;
    assert 'instance?.name or "default"' in formatted;
    assert "instance?.name" in formatted;

    # Check that we don't have "instance.value if" (non-null-safe value with null-safe condition)
    assert "instance.value if instance?.value" not in formatted;
    assert "instance.name if instance?.name" not in formatted;
    assert "instance?.name or None" not in formatted;

    # Binary expressions with hasattr should be converted
    assert "instance?.value and" in formatted
    or "?.value and instance.value" in formatted;

    # Variable attribute name should NOT be converted (attr_name is a variable)
    assert "hasattr(instance, attr_name)" in formatted;

    # Regular function call that looks like hasattr should NOT be converted
    assert "hasattr_lookalike(instance" in formatted;
}

test "hasattr no lint preserves" {
    input_path = auto_lint_fixture_path("hasattr_conversion.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=False);
    formatted = prog.mod.main.gen.jac;

    # Without linting, hasattr should remain
    assert "hasattr(instance" in formatted;
    # No null-safe conversions should happen
    assert "instance?." not in formatted;
}

# ── TestTernaryToOrConversion ────────────────────────────────────────────
test "ternary to or" {
    input_path = auto_lint_fixture_path("ternary_to_or.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Basic ternary with identical value and condition should be converted
    assert "instance.value or 0" in formatted;
    assert "instance.value if instance.value else 0" not in formatted;

    # Null-safe ternary should be converted
    assert 'instance?.name or "default"' in formatted;
    assert 'instance?.name if instance?.name else "default"' not in formatted;

    # Null-safe ternary with None default should be converted
    assert "instance?.value" in formatted;
    assert "instance?.value or None" not in formatted;

    # Different value and condition should NOT be converted
    assert "if instance.name else" in formatted;

    # Null-safe with int default should be converted
    assert "instance?.value or -1" in formatted
    or "instance?.value or (- 1)" in formatted;
}

test "ternary no lint preserves" {
    input_path = auto_lint_fixture_path("ternary_to_or.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=False);
    formatted = prog.mod.main.gen.jac;

    # Without linting, ternary should remain (may be multi-line in formatted output)
    assert "if instance.value" in formatted and "else 0" in formatted;
}

# ── TestSignatureMismatchFix ─────────────────────────────────────────────
test "signature mismatch fixed" {
    input_path = auto_lint_fixture_path("sig_mismatch.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);

    # Verify impl module is discovered
    assert len(prog.mod.main.impl_mod) == 1 , "Should have one impl module";

    # Check the impl signatures were fixed by examining the AST nodes directly
    impl_mod = prog.mod.main.impl_mod[0];

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
    input_path = auto_lint_fixture_path("nested_class_sig.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);

    # Verify impl module is discovered
    assert len(prog.mod.main.impl_mod) == 1 , "Should have one impl module";

    impl_mod = prog.mod.main.impl_mod[0];

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
    assert inner_init_params == ["self", "name"] , f"OuterClass.InnerClass.init should be FIXED to [self, name] "
    f"(matching InnerClass.init decl), got: {inner_init_params}. "
    f"Original impl had [self, a, b]. "
    f"If you got [self, shared, private], the bug is that auto-lint looked up "
    f"OuterClass.init instead of InnerClass.init.";

    # OuterClass.AnotherInner.init should be FIXED from (self, foo) to (self, x, y)
    # (plus kwonly z, but we only check positional params here)
    assert "OuterClass.AnotherInner.init" in impl_defs , "OuterClass.AnotherInner.init impl not found";
    another_init_params = get_impl_params(impl_defs["OuterClass.AnotherInner.init"]);
    assert another_init_params == ["self", "x", "y"] , f"OuterClass.AnotherInner.init should be FIXED to [self, x, y] "
    f"(matching AnotherInner.init decl), got: {another_init_params}. "
    f"Original impl had [self, foo].";

    # OuterClass.process should be FIXED from (wrong) to (data)
    assert "OuterClass.process" in impl_defs , "OuterClass.process impl not found";
    process_params = get_impl_params(impl_defs["OuterClass.process"]);
    assert process_params == ["data"] , f"OuterClass.process should be FIXED to [data] "
    f"(matching process decl), got: {process_params}. "
    f"Original impl had [wrong].";
}

# ── TestRemoveImportSemicolons ───────────────────────────────────────────
test "import from semicolons removed" {
    input_path = auto_lint_fixture_path("import_semicolon.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # import from {} style imports inside functions should NOT have semicolons
    # The semicolons (which become standalone Semi statements) should be removed
    assert "import from typing { List }" in formatted;
    assert "import from sys { argv }" in formatted;

    # There should be no standalone semicolons after these imports
    # Check that we don't have "}\n    ;" pattern (import followed by semicolon)
    assert "}\n    ;" not in formatted;

    # Statement-level imports should still have semicolons
    assert "import json;" in formatted;
    assert "import math;" in formatted;

    # Other code should be preserved
    assert "obj MyClass" in formatted;
    assert "def main" in formatted;
}

test "import semicolons preserved without lint" {
    input_path = auto_lint_fixture_path("import_semicolon.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=False);
    formatted = prog.mod.main.gen.jac;

    # Without linting, standalone semicolons should remain
    assert "import from typing" in formatted;
    assert ";" in formatted;
}

# ── TestRemoveFutureAnnotations ──────────────────────────────────────────
test "future annotations removed" {
    input_path = auto_lint_fixture_path("future_annotations.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # The __future__ annotations import statement should be removed
    # (note: __future__ may still appear in the docstring, so check import statement)
    assert "import from __future__" not in formatted;

    # Other imports should be preserved
    assert "import from os" in formatted;

    # Rest of the code should be preserved
    assert "obj Person" in formatted;
    assert "def greet" in formatted;
    assert "def main" in formatted;
}

test "future annotations preserved without lint" {
    input_path = auto_lint_fixture_path("future_annotations.jac");

    prog = JacProgram.jac_file_formatter(input_path, auto_lint=False);
    formatted = prog.mod.main.gen.jac;

    # Without linting, __future__ import should remain
    assert "__future__" in formatted;
    assert "annotations" in formatted;
}

# ── TestCommentPreservation ──────────────────────────────────────────────
test "comment glob comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Standalone comments around glob statements should be preserved
    assert "# Comment before first glob" in formatted;
    assert "# Comment between glob statements" in formatted;
    assert "# Comment before third glob" in formatted;
    # Private glob comment
    assert "# Inline on private glob" in formatted;
}

test "comment has comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Standalone comments in obj body should be preserved
    assert "# Comment before first has" in formatted;
    assert "# Comment between has statements" in formatted;
    assert "# Comment before third has" in formatted;
    # Private has inline
    assert "# Inline on private has" in formatted;
}

test "comment method and impl comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Method declaration comments
    assert "# Comment before method declaration" in formatted;
    assert "# Comment before staticmethod" in formatted;
    assert "# Comment before init" in formatted;
    # Impl comments
    assert "# Implementation comments" in formatted;
    assert "# Comment inside impl body" in formatted;
    assert "# Inline return comment" in formatted;
    assert "# Comment on staticmethod impl" in formatted;
    assert "# Comment inside helper" in formatted;
}

test "comment enum comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Enum comments
    assert "# Enum with consecutive assignments and comments" in formatted;
    assert "# Comment before GREEN" in formatted;
    assert "# Comment before BLUE" in formatted;
}

test "comment hasattr conversion comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Comments around hasattr usage
    assert "# Test hasattr conversion with comments" in formatted;
    assert "# Comment before hasattr usage" in formatted;
    assert "# Comment inside if block" in formatted;
    assert "# Comment after if" in formatted;
}

test "comment ternary conversion comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Comments around ternary expressions
    assert "# Test ternary to or simplification with comments" in formatted;
    assert "# Comment before ternary that should become or" in formatted;
    assert "# Comment after ternary" in formatted;
}

test "comment entry block comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Entry block comments
    assert "# Test with entry block transformation" in formatted;
    assert "# Comment at start of entry" in formatted;
    assert "# Comment between statements" in formatted;
    assert "# Comment before print" in formatted;
}

test "comment escaped name comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Comments around escaped names
    assert "# Test backtick escaped names with comments" in formatted;
    assert "# Comment before escaped name" in formatted;
    assert "# Method with escaped param" in formatted;
}

test "comment nested obj comments preserved" {
    prog = JacProgram.jac_file_formatter(STRESS_TEST_PATH, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    # Nested obj comments
    assert "# Nested obj with comments" in formatted;
    assert "# Comment in inner obj has" in formatted;
}

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

test "comment no print error" {
    input_path = auto_lint_fixture_path("no_print.jac");

    # Enable all rules including no-print
    config = JacConfig();
    config.check = CheckConfig(lint=LintConfig(select=["all"]));
    set_config(config);
    try {
        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    } finally {
        set_config(None);
    }

    # Should have errors for bare print() calls
    error_msgs = [e.msg for e in prog.errors_had];
    no_print_errors = [
        m
        for m in error_msgs
        if "[no-print]" in m
    ];
    # There are 2 bare print() calls in the fixture
    assert len(no_print_errors) == 2 , f"Expected 2 no-print errors, got {len(
        no_print_errors
    )}: {no_print_errors}";
}

test "comment no print ignores qualified calls" {
    input_path = auto_lint_fixture_path("no_print.jac");

    # Enable all rules including no-print
    config = JacConfig();
    config.check = CheckConfig(lint=LintConfig(select=["all"]));
    set_config(config);
    try {
        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True);
    } finally {
        set_config(None);
    }

    # Should NOT flag console.print()
    error_msgs = [e.msg for e in prog.errors_had];
    no_print_errors = [
        m
        for m in error_msgs
        if "[no-print]" in m
    ];
    # Only the 2 bare print() calls, not the console.print() call
    assert len(no_print_errors) == 2;
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
