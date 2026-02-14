"""Test Jac Auto Lint Pass module."""

import contextlib
import os
import shutil
import tempfile
from collections.abc import Callable
from pathlib import Path

import pytest

import jaclang.jac0core.unitree as uni
from jaclang.jac0core.program import JacProgram


# Fixture path helper
@pytest.fixture
def auto_lint_fixture_path() -> Callable[[str], str]:
    """Return a function that returns the path to an auto_lint fixture file."""
    base_dir = os.path.dirname(__file__)
    fixtures_dir = os.path.join(base_dir, "fixtures", "auto_lint")

    def get_path(filename: str) -> str:
        return os.path.join(fixtures_dir, filename)

    return get_path


class TestJacAutoLintPass:
    """Tests for the Jac Auto Lint Pass."""

    def test_full_extraction(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test extracting all assignments from with entry block."""
        input_path = auto_lint_fixture_path("extractable.jac")

        # Format with linting enabled
        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Should contain glob declarations for all extracted values
        # Note: consecutive globs with same modifiers are now combined
        assert "glob x = 5,\n     y = " in formatted
        assert "y = " in formatted
        assert "z = " in formatted
        assert "int_val" in formatted
        assert "float_val" in formatted
        assert "str_val" in formatted
        assert "bool_val" in formatted
        assert "null_val" in formatted
        assert "list_val" in formatted
        assert "dict_val" in formatted
        assert "tuple_val" in formatted
        assert "set_val" in formatted
        assert "sum_val" in formatted
        assert "product" in formatted
        assert "neg_val" in formatted
        assert "not_val" in formatted

        # Should NOT contain with entry block syntax (it was fully extracted)
        assert "with entry {" not in formatted

        # Globs should come after imports
        import_pos = formatted.find("import from os")
        glob_pos = formatted.find("glob x = ")
        def_pos = formatted.find("def main")
        assert import_pos < glob_pos < def_pos

    def test_no_lint_flag(self, auto_lint_fixture_path: Callable[[str], str]) -> None:
        """Test that auto_lint=False preserves with entry blocks."""
        input_path = auto_lint_fixture_path("extractable.jac")

        # Format with linting disabled
        prog = JacProgram.jac_file_formatter(input_path, auto_lint=False)
        formatted = prog.mod.main.gen.jac

        # Should still contain with entry block
        assert "with entry" in formatted

        # Should NOT contain glob declarations for extracted values
        assert "glob x" not in formatted
        assert "glob int_val" not in formatted

    def test_mixed_extraction(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test partial extraction when some statements can't be extracted."""
        input_path = auto_lint_fixture_path("mixed_extraction.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Extractable assignments should become globs
        assert "glob x = 5;" in formatted
        assert "glob y = 10;" in formatted

        # Non-extractable statement should stay in with entry
        assert "with entry" in formatted
        assert "print(" in formatted

    def test_all_assignments_extracted(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that ALL assignments (including non-pure) are extracted to globs."""
        input_path = auto_lint_fixture_path("non_extractable.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # All assignments should become globs (even function calls, attr access, etc.)
        # Note: consecutive globs with same modifiers are now combined
        assert "result = some_function()" in formatted
        assert "value = obj.attr" in formatted
        assert "item = arr[0]" in formatted

        # The unnamed with entry block should be removed (all assignments extracted)
        # Only named entry block should remain
        assert "with entry:__main__" in formatted or "with entry :__main__" in formatted

    def test_named_entry_not_modified(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that named entry blocks are NOT modified."""
        input_path = auto_lint_fixture_path("non_extractable.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Named entry block should be preserved
        assert "with entry:__main__" in formatted or "with entry :__main__" in formatted

        # Assignment inside named entry should NOT become glob
        assert "glob named_x" not in formatted

    def test_existing_globs_preserved(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test file that already uses glob - existing globs are preserved."""
        input_path = auto_lint_fixture_path("non_extractable.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Should preserve existing glob declarations
        # Note: consecutive globs with same modifiers are now combined
        # Format is now multiline with all assignments indented
        assert "glob existing_x = 5,\n     existing_y = " in formatted
        assert "existing_y = " in formatted
        assert "existing_z = " in formatted

    def test_class_entry_not_extracted(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that with entry inside a class body is NOT extracted to glob."""
        input_path = auto_lint_fixture_path("class_entry.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Class with entry should be preserved (glob doesn't work in classes)
        assert "class MyClass" in formatted

        # The class should still have its with entry block
        # Check that class body assignments did NOT become module-level globs
        assert "glob instance_var" not in formatted
        assert "glob another_var" not in formatted
        assert "glob list_var" not in formatted

        # Module-level with entry SHOULD be fully extracted (all assignments)
        # Note: consecutive globs with same modifiers are now combined
        # Format is now multiline with all assignments indented
        assert "glob module_var = 100,\n     cls_obj = MyClass();" in formatted

        # Module-level with entry containing TYPE_CHECKING blocks should extract
        # assignments to glob while keeping if blocks in with entry (since if
        # statements cannot be at bare module level in Jac)
        assert "glob a = 5;" in formatted
        assert "glob b = 6;" in formatted
        # The if TYPE_CHECKING blocks must stay inside with entry
        assert "with entry {\n    if TYPE_CHECKING" in formatted
        assert "import from math { SupportsFloat }" in formatted
        assert "import from math { SupportsIndex }" in formatted

    def test_init_postinit_conversion(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that __init__ and __post_init__ are converted to init/postinit."""
        input_path = auto_lint_fixture_path("init_conversion.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Method definitions converted
        assert "def __init__" not in formatted
        assert "def __post_init__" not in formatted
        assert "def init" in formatted
        assert "def postinit" in formatted

        # Regular methods unchanged
        assert "def greet" in formatted

        # Other __init__ usages preserved (not method definitions)
        assert "super.__init__" in formatted
        assert "Person().__init__" in formatted
        assert "__init__ = 5" in formatted
        assert "print(__init__)" in formatted


class TestCombineConsecutiveHas:
    """Tests for combining consecutive has statements."""

    def test_consecutive_has_combined(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that consecutive has statements with same modifiers are combined."""
        input_path = auto_lint_fixture_path("consecutive_has.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Consecutive has statements should be combined into one
        # The three separate has statements become one with commas
        assert "has name: str," in formatted
        assert "age: int," in formatted
        assert "email: str;" in formatted

        # Public has statements should be combined separately
        assert "has:pub address: str," in formatted
        assert "phone: str;" in formatted

        # Static has statements should be combined
        assert "static has DEBUG: bool = False," in formatted
        assert "VERSION: str = " in formatted
        assert "MAX_RETRIES: int = 3;" in formatted

        # has with different modifiers should NOT be combined with others
        # city has default value but no access modifier, should stay separate from :pub:
        assert "has city: str = " in formatted

        # Verify statements were actually combined (count semicolons in has statements)
        # Before: 6 separate has statements, After: 3 combined has statements
        person_section = formatted.split("obj Person")[1].split("obj Config")[0]
        # Count both "has " and "has:" patterns (access modifiers use has:pub format)
        has_count = person_section.count("has ") + person_section.count("has:")
        assert has_count == 3, f"Expected 3 has statements in Person, got {has_count}"

    def test_consecutive_has_combined_in_ability(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that consecutive has statements in abilities (functions) are combined."""
        input_path = auto_lint_fixture_path("ability_has.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # has statements in app function should be combined
        assert "has count: int = 0," in formatted
        assert "name: str = " in formatted
        assert "enabled: bool = True;" in formatted

        # has statements in client-side counter function should be combined
        assert "has value: int = 0," in formatted
        assert "label: str = " in formatted
        assert "visible: bool = True;" in formatted

        # has statements in Widget.render method should be combined
        assert "has prefix: str = " in formatted
        assert "suffix: str = " in formatted
        assert "content: str = " in formatted

        # Verify statements were actually combined (count has statements)
        # app function: 1 combined has statement (originally 3)
        app_section = formatted.split("def app")[1].split("}")[0]
        app_has_count = sum(
            1 for line in app_section.splitlines() if line.lstrip().startswith("has ")
        )
        assert app_has_count == 1, (
            f"Expected 1 has statement in app, got {app_has_count}"
        )

        # render method: 1 combined has statement (originally 3)
        render_section = formatted.split("def render")[1].split("}")[0]
        render_has_count = sum(
            1
            for line in render_section.splitlines()
            if line.lstrip().startswith("has ")
        )
        assert render_has_count == 1, (
            f"Expected 1 has statement in render, got {render_has_count}"
        )


class TestCombineConsecutiveGlob:
    """Tests for combining consecutive glob statements."""

    def test_consecutive_glob_combined(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that consecutive glob statements with same modifiers are combined."""
        input_path = auto_lint_fixture_path("consecutive_glob.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Consecutive glob statements should be combined into one
        # The three separate glob statements become one with commas
        # Format is now multiline with all assignments indented
        assert "glob x = 1,\n     y = 2,\n     z = 3;" in formatted

        # Public glob statements should be combined separately
        assert "glob:pub a = 10,\n     b = 20;" in formatted

        # Protected glob statements should be combined separately
        assert "glob:protect c = 100,\n     d = 200,\n     e = 300;" in formatted

        # Mixed modifiers should NOT be combined together
        # Each should be its own statement
        assert "glob m1 = 1;" in formatted
        assert "glob:pub m2 = 2;" in formatted
        assert "glob:protect m3 = 3;" in formatted

        # Non-consecutive globs should NOT be combined
        assert "glob before = 0;" in formatted
        assert "glob after = 99;" in formatted

    def test_glob_combining_disabled_without_lint(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that glob combining is disabled when auto_lint=False."""
        input_path = auto_lint_fixture_path("consecutive_glob.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=False)
        formatted = prog.mod.main.gen.jac

        # Without linting, globs should remain separate
        assert "glob x = 1;" in formatted
        assert "glob y = 2;" in formatted
        assert "glob z = 3;" in formatted


class TestStaticmethodConversion:
    """Tests for converting @staticmethod decorator to static keyword."""

    def test_staticmethod_to_static(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that @staticmethod decorator is converted to static keyword."""
        input_path = auto_lint_fixture_path("staticmethod_decorator.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Should use static keyword instead of @staticmethod decorator
        assert "static def add" in formatted
        assert "static def multiply" in formatted

        # Should NOT have @staticmethod decorator in code (may be in docstring)
        # Count occurrences - should only appear in the docstring
        assert formatted.count("@staticmethod") == 1  # Only in docstring
        assert "@staticmethod\n" not in formatted  # No decorator usage

        # Instance method should remain unchanged
        assert "def instance_method" in formatted
        assert "static def instance_method" not in formatted

    def test_already_static_not_modified(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that methods with static keyword already are not affected."""
        input_path = auto_lint_fixture_path("staticmethod_decorator.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Should still have static keyword
        assert "static def already_static" in formatted

    def test_multiple_decorators_preserved(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that other decorators are preserved when @staticmethod is removed."""
        input_path = auto_lint_fixture_path("staticmethod_decorator.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Other decorators should be preserved
        assert "@some_decorator" in formatted

        # Should be static now
        assert "static def decorated_static" in formatted

    def test_staticmethod_no_lint_preserves_decorator(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that auto_lint=False preserves @staticmethod decorator."""
        input_path = auto_lint_fixture_path("staticmethod_decorator.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=False)
        formatted = prog.mod.main.gen.jac

        # Should still have @staticmethod decorator
        assert "@staticmethod" in formatted


class TestFormatCommandIntegration:
    """Integration tests for the format CLI command."""

    def test_format_with_lint_default(
        self, auto_lint_fixture_path: Callable[[str], str], tmp_path: Path
    ) -> None:
        """Test that format applies linting when auto_lint=True."""
        import shutil

        # Copy fixture to temp location
        src = auto_lint_fixture_path("extractable.jac")
        dst = tmp_path / "test.jac"
        shutil.copy(src, dst)

        # Format the file with auto_lint enabled
        prog = JacProgram.jac_file_formatter(str(dst), auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Linting should have been applied
        assert "glob" in formatted

    def test_format_auto_formats_impl_files(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that CLI format command writes both main and impl files."""
        from jaclang.cli.commands import analysis  # type: ignore[attr-defined]

        # Copy fixture files to temp directory
        fixture_dir = os.path.dirname(auto_lint_fixture_path("sig_mismatch.jac"))
        with tempfile.TemporaryDirectory() as tmpdir:
            # Copy main file
            main_src = auto_lint_fixture_path("sig_mismatch.jac")
            main_dst = os.path.join(tmpdir, "sig_mismatch.jac")
            shutil.copy2(main_src, main_dst)

            # Copy impl file (create impl subdirectory)
            impl_dir = os.path.join(tmpdir, "impl")
            os.makedirs(impl_dir)
            impl_src = os.path.join(fixture_dir, "impl", "sig_mismatch.impl.jac")
            impl_dst = os.path.join(impl_dir, "sig_mismatch.impl.jac")
            shutil.copy2(impl_src, impl_dst)

            # Read original impl content (has wrong param names)
            with open(impl_dst) as f:
                original_impl = f.read()
            assert "impl Calculator.add(a: int, b: int)" in original_impl

            # Run CLI lint command with --fix
            with contextlib.suppress(SystemExit):
                analysis.lint([main_dst], fix=True)

            # Read the updated impl file
            with open(impl_dst) as f:
                updated_impl = f.read()

            # The impl file should have been fixed: param names changed from a,b to x,y
            assert ".add(x: int, y: int)" in updated_impl, (
                f"Impl file should have been updated with fixed params.\n"
                f"Got: {updated_impl}"
            )

    def test_format_lintfix_reports_no_print(
        self, auto_lint_fixture_path: Callable[[str], str], tmp_path: Path
    ) -> None:
        """Test that format --lintfix respects no-print rule from jac.toml config."""
        from jaclang.cli.commands import analysis  # type: ignore[attr-defined]
        from jaclang.project.config import JacConfig, set_config

        # Copy no_print fixture to temp location
        src = auto_lint_fixture_path("no_print.jac")
        dst = tmp_path / "no_print.jac"
        shutil.copy(src, dst)

        # Simulate jac.toml with no-print enabled via select = ["all"]
        config = JacConfig.from_toml_str('[check.lint]\nselect = ["all"]\n')
        set_config(config)
        try:
            # Run format with --lintfix (should report no-print errors and exit 1)
            result = analysis.format([str(dst)], lintfix=True)
        finally:
            set_config(None)

        # no-print errors are unfixable, so format --lintfix should fail
        assert result == 1, (
            "format --lintfix should return 1 when unfixable lint errors exist"
        )


class TestRemoveUnnecessaryEscape:
    """Tests for removing unnecessary backtick escaping from names."""

    def test_unnecessary_escape_removed(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that unnecessary backtick escaping is removed from non-keyword names."""
        input_path = auto_lint_fixture_path("unnecessary_escape.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Regular variable names should NOT have backtick escaping
        assert "`foo" not in formatted
        assert "`bar" not in formatted
        assert "`myvar" not in formatted
        assert "`count" not in formatted
        assert "`data" not in formatted
        assert "`name" not in formatted
        assert "`value" not in formatted
        assert "`item" not in formatted
        assert "`result" not in formatted
        assert "`input_val" not in formatted
        assert "`output_val" not in formatted
        assert "`total" not in formatted

        # But the actual names should still be present (without backtick)
        assert "foo = 1" in formatted
        assert "bar = 2" in formatted
        assert "myvar = 3" in formatted

        # Jac keywords SHOULD still have backtick escaping
        assert "`node = 10" in formatted
        assert "`edge = 20" in formatted
        assert "`walker = 30" in formatted


class TestRemoveEmptyParens:
    """Tests for removing empty parentheses from function declarations."""

    def test_empty_parens_removed(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that empty parentheses are removed from function declarations."""
        input_path = auto_lint_fixture_path("empty_parens.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Functions with no params should have parens removed
        assert "def no_params {" in formatted
        assert "def no_params()" not in formatted

        # Functions with params should keep parens
        assert "def with_params(x: int)" in formatted

        # Functions with no params but return type should have parens removed
        assert "def no_params_with_return -> int" in formatted
        assert "def no_params_with_return()" not in formatted

        # Functions with params and return type should keep parens
        assert "def with_params_and_return(" in formatted
        assert "x: int" in formatted

    def test_method_parens_preserved_when_has_self(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that method parentheses are preserved when they have self parameter."""
        input_path = auto_lint_fixture_path("empty_parens.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Methods with self should keep parens
        assert "def method_with_self(self: MyClass)" in formatted

        # Methods with self and other params should keep parens
        assert (
            "def method_with_params(self: MyClass, a: int, b: int) -> int" in formatted
        )

    def test_obj_method_parens_removed(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that empty parentheses are removed from obj method declarations."""
        input_path = auto_lint_fixture_path("empty_parens.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # obj methods with no params should have parens removed
        assert "def reset {" in formatted
        assert "def reset()" not in formatted

        # obj methods with params should keep parens
        assert "def increment(amount: int)" in formatted

        # obj methods with no params but return type should have parens removed
        assert "def get_count -> int" in formatted
        assert "def get_count()" not in formatted

    def test_impl_empty_parens_removed(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that empty parentheses are removed from impl blocks."""
        input_path = auto_lint_fixture_path("empty_parens.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Impl with no params but return type - parens should be removed
        assert "impl Calculator.compute -> int" in formatted
        assert "impl Calculator.compute()" not in formatted

        # Impl with params - parens should stay
        assert "impl Calculator.process(x: int)" in formatted

        # Impl with no params and no return type - parens should be removed
        # Note: formatter may or may not add space before {
        assert (
            "impl Calculator.run{" in formatted or "impl Calculator.run {" in formatted
        )
        assert "impl Calculator.run()" not in formatted


class TestHasattrConversion:
    """Tests for converting hasattr(obj, 'attr') to obj?.attr."""

    def test_hasattr_to_null_ok(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that hasattr(obj, 'attr') is converted to obj?.attr."""
        input_path = auto_lint_fixture_path("hasattr_conversion.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Basic hasattr in if-else should be converted
        assert "instance?.value" in formatted
        assert "instance?.name" in formatted

        # hasattr calls in safe patterns (ternary, guard-and-use) should be converted
        assert 'hasattr(instance, "value")' not in formatted
        assert "hasattr(instance, 'value')" not in formatted

        # hasattr in standalone boolean context (or False) should NOT be converted
        # because hasattr() returns bool while obj?.attr returns the value
        assert 'hasattr(instance, "name") or False' in formatted

        # The if-else expressions with hasattr should be converted to or expressions
        # Pattern: obj.attr if hasattr(obj, "attr") else default
        # Step 1: becomes obj?.attr if obj?.attr else default
        # Step 2: becomes obj?.attr or default (ternary-to-or optimization)
        assert "instance?.value or 0" in formatted
        assert 'instance?.name or "default"' in formatted
        assert "instance?.name" in formatted

        # Check that we don't have "instance.value if" (non-null-safe value with null-safe condition)
        assert "instance.value if instance?.value" not in formatted
        assert "instance.name if instance?.name" not in formatted
        assert "instance?.name or None" not in formatted

        # Binary expressions with hasattr should be converted
        assert (
            "instance?.value and" in formatted
            or "?.value and instance.value" in formatted
        )

        # Variable attribute name should NOT be converted (attr_name is a variable)
        assert "hasattr(instance, attr_name)" in formatted

        # Regular function call that looks like hasattr should NOT be converted
        assert "hasattr_lookalike(instance" in formatted

    def test_hasattr_no_lint_preserves(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that auto_lint=False preserves hasattr calls."""
        input_path = auto_lint_fixture_path("hasattr_conversion.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=False)
        formatted = prog.mod.main.gen.jac

        # Without linting, hasattr should remain
        assert "hasattr(instance" in formatted
        # No null-safe conversions should happen
        assert "instance?." not in formatted


class TestTernaryToOrConversion:
    """Tests for converting x if x else default to x or default."""

    def test_ternary_to_or(self, auto_lint_fixture_path: Callable[[str], str]) -> None:
        """Test that identical ternary expressions are converted to or."""
        input_path = auto_lint_fixture_path("ternary_to_or.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Basic ternary with identical value and condition should be converted
        assert "instance.value or 0" in formatted
        assert "instance.value if instance.value else 0" not in formatted

        # Null-safe ternary should be converted
        assert 'instance?.name or "default"' in formatted
        assert 'instance?.name if instance?.name else "default"' not in formatted

        # Null-safe ternary with None default should be converted
        assert "instance?.value" in formatted
        assert "instance?.value or None" not in formatted

        # Different value and condition should NOT be converted
        assert "if instance.name else" in formatted

        # Null-safe with int default should be converted
        assert (
            "instance?.value or -1" in formatted
            or "instance?.value or (- 1)" in formatted
        )

    def test_ternary_no_lint_preserves(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that auto_lint=False preserves ternary expressions."""
        input_path = auto_lint_fixture_path("ternary_to_or.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=False)
        formatted = prog.mod.main.gen.jac

        # Without linting, ternary should remain (may be multi-line in formatted output)
        assert "if instance.value" in formatted and "else 0" in formatted


class TestSignatureMismatchFix:
    """Tests for fixing signature mismatches between decls and impls."""

    def test_signature_mismatch_fixed(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that impl signatures are fixed to match declarations."""

        input_path = auto_lint_fixture_path("sig_mismatch.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)

        # Verify impl module is discovered
        assert len(prog.mod.main.impl_mod) == 1, "Should have one impl module"

        # Check the impl signatures were fixed by examining the AST nodes directly
        impl_mod = prog.mod.main.impl_mod[0]

        # Helper to get param names from an ImplDef
        def get_impl_params(impl_def: uni.ImplDef) -> list[str]:
            if isinstance(impl_def.spec, uni.FuncSignature):
                return [p.name.value for p in impl_def.spec.params]
            return []

        # Find all impl definitions by name
        impl_defs: dict[str, uni.ImplDef] = {}
        for stmt in impl_mod.body:
            if isinstance(stmt, uni.ImplDef):
                # Get the method name (last part of target)
                method_name = stmt.target[-1].sym_name
                impl_defs[method_name] = stmt

        # add should have x, y params (from decl), not a, b
        assert "add" in impl_defs, "add impl not found"
        add_params = get_impl_params(impl_defs["add"])
        assert add_params == ["x", "y"], (
            f"add should have x, y params from decl, got: {add_params}"
        )

        # multiply should have a, b params (from decl)
        assert "multiply" in impl_defs, "multiply impl not found"
        multiply_params = get_impl_params(impl_defs["multiply"])
        assert multiply_params == ["a", "b"], (
            f"multiply should have a, b params from decl, got: {multiply_params}"
        )

        # no_change should remain unchanged (already matches)
        assert "no_change" in impl_defs, "no_change impl not found"
        no_change_params = get_impl_params(impl_defs["no_change"])
        assert no_change_params == ["val"], (
            f"no_change should have val param, got: {no_change_params}"
        )

        # reset should have no params (impl had extra param that should be removed)
        assert "reset" in impl_defs, "reset impl not found"
        reset_params = get_impl_params(impl_defs["reset"])
        assert reset_params == [], (
            f"reset should have no params from decl, got: {reset_params}"
        )


class TestNestedClassSignatureFix:
    """Tests for fixing nested class impl signatures.

    The auto-lint should properly fix nested class impl signatures to match
    their nested class declarations, NOT the parent class declarations.
    For example, `impl OuterClass.InnerClass.init` should be fixed to match
    `InnerClass.init`, NOT `OuterClass.init`.
    """

    def test_nested_class_impl_signature_fixed(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that nested class impl signatures are fixed to match their declarations.

        The impl file has intentionally wrong signatures:
        - OuterClass.InnerClass.init has (self, a, b) but decl has (self, name)
        - OuterClass.AnotherInner.init has (self, foo) but decl has (self, x, y, *, z=0)
        - OuterClass.process has (wrong) but decl has (data)

        This is a regression test for a bug where the auto-lint would look up
        declarations using only the first and last elements of the target path,
        e.g., for `impl OuterClass.InnerClass.init`, it would look up
        `OuterClass.init` instead of `OuterClass.InnerClass.init`.
        """

        input_path = auto_lint_fixture_path("nested_class_sig.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)

        # Verify impl module is discovered
        assert len(prog.mod.main.impl_mod) == 1, "Should have one impl module"

        impl_mod = prog.mod.main.impl_mod[0]

        # Helper to get the full target path as a string
        def get_target_path(impl_def: uni.ImplDef) -> str:
            return ".".join(t.sym_name for t in impl_def.target if t)

        # Helper to get param names from an ImplDef
        def get_impl_params(impl_def: uni.ImplDef) -> list[str]:
            if isinstance(impl_def.spec, uni.FuncSignature):
                return [p.name.value for p in impl_def.spec.params]
            return []

        # Find all impl definitions by full target path
        impl_defs: dict[str, uni.ImplDef] = {}
        for stmt in impl_mod.body:
            if isinstance(stmt, uni.ImplDef):
                target_path = get_target_path(stmt)
                impl_defs[target_path] = stmt

        # OuterClass.init should have: self, shared, private (already correct)
        assert "OuterClass.init" in impl_defs, "OuterClass.init impl not found"
        outer_init_params = get_impl_params(impl_defs["OuterClass.init"])
        assert outer_init_params == ["self", "shared", "private"], (
            f"OuterClass.init should have [self, shared, private], got: {outer_init_params}"
        )

        # OuterClass.InnerClass.init should be FIXED from (self, a, b) to (self, name)
        # NOT: (self, shared, private) which would happen if bug exists
        assert "OuterClass.InnerClass.init" in impl_defs, (
            "OuterClass.InnerClass.init impl not found"
        )
        inner_init_params = get_impl_params(impl_defs["OuterClass.InnerClass.init"])
        assert inner_init_params == ["self", "name"], (
            f"OuterClass.InnerClass.init should be FIXED to [self, name] "
            f"(matching InnerClass.init decl), got: {inner_init_params}. "
            f"Original impl had [self, a, b]. "
            f"If you got [self, shared, private], the bug is that auto-lint looked up "
            f"OuterClass.init instead of InnerClass.init."
        )

        # OuterClass.AnotherInner.init should be FIXED from (self, foo) to (self, x, y)
        # (plus kwonly z, but we only check positional params here)
        assert "OuterClass.AnotherInner.init" in impl_defs, (
            "OuterClass.AnotherInner.init impl not found"
        )
        another_init_params = get_impl_params(impl_defs["OuterClass.AnotherInner.init"])
        assert another_init_params == ["self", "x", "y"], (
            f"OuterClass.AnotherInner.init should be FIXED to [self, x, y] "
            f"(matching AnotherInner.init decl), got: {another_init_params}. "
            f"Original impl had [self, foo]."
        )

        # OuterClass.process should be FIXED from (wrong) to (data)
        assert "OuterClass.process" in impl_defs, "OuterClass.process impl not found"
        process_params = get_impl_params(impl_defs["OuterClass.process"])
        assert process_params == ["data"], (
            f"OuterClass.process should be FIXED to [data] "
            f"(matching process decl), got: {process_params}. "
            f"Original impl had [wrong]."
        )


class TestRemoveImportSemicolons:
    """Tests for removing semicolons from import from {} style imports.

    When `import from X { ... };` appears inside a function/ability body,
    the semicolon is parsed as a separate Semi statement. This lint rule
    removes those standalone semicolons that follow import from {} statements.
    """

    def test_import_from_semicolons_removed(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that semicolons are removed from import from {} style imports."""
        input_path = auto_lint_fixture_path("import_semicolon.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # import from {} style imports inside functions should NOT have semicolons
        # The semicolons (which become standalone Semi statements) should be removed
        assert "import from typing { List }" in formatted
        assert "import from sys { argv }" in formatted

        # There should be no standalone semicolons after these imports
        # Check that we don't have "}\n    ;" pattern (import followed by semicolon)
        assert "}\n    ;" not in formatted

        # Statement-level imports should still have semicolons
        assert "import json;" in formatted
        assert "import math;" in formatted

        # Other code should be preserved
        assert "obj MyClass" in formatted
        assert "def main" in formatted

    def test_import_semicolons_preserved_without_lint(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that auto_lint=False preserves import semicolons."""
        input_path = auto_lint_fixture_path("import_semicolon.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=False)
        formatted = prog.mod.main.gen.jac

        # Without linting, standalone semicolons should remain
        assert "import from typing" in formatted
        assert ";" in formatted  # Semicolons should still be present


class TestRemoveFutureAnnotations:
    """Tests for removing `import from __future__ { annotations }`."""

    def test_future_annotations_removed(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that `import from __future__ { annotations }` is removed."""
        input_path = auto_lint_fixture_path("future_annotations.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # The __future__ annotations import statement should be removed
        # (note: __future__ may still appear in the docstring, so check import statement)
        assert "import from __future__" not in formatted

        # Other imports should be preserved
        assert "import from os" in formatted

        # Rest of the code should be preserved
        assert "obj Person" in formatted
        assert "def greet" in formatted
        assert "def main" in formatted

    def test_future_annotations_preserved_without_lint(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that auto_lint=False preserves __future__ annotations import."""
        input_path = auto_lint_fixture_path("future_annotations.jac")

        prog = JacProgram.jac_file_formatter(input_path, auto_lint=False)
        formatted = prog.mod.main.gen.jac

        # Without linting, __future__ import should remain
        assert "__future__" in formatted
        assert "annotations" in formatted


class TestCommentPreservation:
    """Tests for comment preservation during auto-lint transformations.

    The auto-lint pass performs various transformations (combining statements,
    converting hasattr to null-safe access, etc.) which historically lost comments.
    These tests verify that comments are preserved after transformations.

    Uses the comprehensive stress test fixture that covers many edge cases:
    - Consecutive glob statement combining
    - Consecutive has statement combining
    - @staticmethod -> static conversion
    - __init__/__post_init__ -> init/postinit conversion
    - hasattr() -> null-safe access
    - Ternary -> or simplification
    - Angle bracket escape removal

    Note: When statements are merged (e.g., multiple has statements combined into one),
    standalone comments that appeared between the merged statements will appear after
    the combined statement. This is expected behavior since we can't interleave comments
    within a single combined statement.
    """

    @pytest.fixture
    def stress_test_path(self) -> str:
        """Return the path to the comment stress test fixture."""
        return os.path.join(
            os.path.dirname(__file__),
            "..",
            "..",
            "..",
            "..",
            "jaclang",
            "tests",
            "fixtures",
            "comment_normalize_stress_test.jac",
        )

    def test_glob_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments around glob statements are preserved during combining."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Standalone comments around glob statements should be preserved
        assert "# Comment before first glob" in formatted
        assert "# Comment between glob statements" in formatted
        assert "# Comment before third glob" in formatted
        # Private glob comment
        assert "# Inline on private glob" in formatted

    def test_has_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments around has statements are preserved during combining."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Standalone comments in obj body should be preserved
        assert "# Comment before first has" in formatted
        assert "# Comment between has statements" in formatted
        assert "# Comment before third has" in formatted
        # Private has inline
        assert "# Inline on private has" in formatted

    def test_method_and_impl_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments on methods and impl blocks are preserved."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Method declaration comments
        assert "# Comment before method declaration" in formatted
        assert "# Comment before staticmethod" in formatted
        assert "# Comment before init" in formatted
        # Impl comments
        assert "# Implementation comments" in formatted
        assert "# Comment inside impl body" in formatted
        assert "# Inline return comment" in formatted
        assert "# Comment on staticmethod impl" in formatted
        assert "# Comment inside helper" in formatted

    def test_enum_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments in enum definitions are preserved."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Enum comments
        assert "# Enum with consecutive assignments and comments" in formatted
        assert "# Comment before GREEN" in formatted
        assert "# Comment before BLUE" in formatted

    def test_hasattr_conversion_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments are preserved during hasattr -> null-safe conversion."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Comments around hasattr usage
        assert "# Test hasattr conversion with comments" in formatted
        assert "# Comment before hasattr usage" in formatted
        assert "# Comment inside if block" in formatted
        assert "# Comment after if" in formatted

    def test_ternary_conversion_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments are preserved during ternary -> or conversion."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Comments around ternary expressions
        assert "# Test ternary to or simplification with comments" in formatted
        assert "# Comment before ternary that should become or" in formatted
        assert "# Comment after ternary" in formatted

    def test_entry_block_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments are preserved during with entry block transformation."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Entry block comments
        assert "# Test with entry block transformation" in formatted
        assert "# Comment at start of entry" in formatted
        assert "# Comment between statements" in formatted
        assert "# Comment before print" in formatted

    def test_escaped_name_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments are preserved when removing unnecessary escaping."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Comments around escaped names
        assert "# Test backtick escaped names with comments" in formatted
        assert "# Comment before escaped name" in formatted
        assert "# Method with escaped param" in formatted

    def test_nested_obj_comments_preserved(self, stress_test_path: str) -> None:
        """Test that comments in nested obj definitions are preserved."""
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

        # Nested obj comments
        assert "# Nested obj with comments" in formatted
        assert "# Comment in inner obj has" in formatted

    def test_no_orphaned_comments_at_eof(self, stress_test_path: str) -> None:
        """Test that critical comments aren't lost - inline comments on merged statements may become orphans.

        When statements are merged (e.g., `has a: int; # inline` + `has b: str; # inline`
        becomes `has a: int, b: str;`), the inline comments on the merged statements
        don't have a natural place in the combined statement and may appear at the end.

        This test verifies that:
        1. Standalone comments (full-line comments) are preserved in-place
        2. Comments in code bodies are preserved
        3. The first statement in a merged group keeps its inline comment

        The orphaned comments at the end are inline comments from merged statements -
        this is a known limitation when combining statements.
        """
        prog = JacProgram.jac_file_formatter(stress_test_path, auto_lint=True)
        formatted = prog.mod.main.gen.jac

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
            "# Comment before hasattr usage",
        ]

        for comment in critical_standalone_comments:
            # Find the position of this comment
            pos = formatted.find(comment)
            assert pos != -1, f"Comment not found: {comment}"

            # Check that it's NOT in the last 500 characters (orphan section)
            assert pos < len(formatted) - 500, (
                f"Critical standalone comment appears to be orphaned at end: {comment}"
            )

        # Also verify the final legitimate comment is near the end but not orphaned
        final_comment_pos = formatted.find("# Final comment at end of file")
        assert final_comment_pos != -1, "Final comment should be present"
        # It should be in the last third of the file (normal position)
        assert final_comment_pos > len(formatted) * 0.5, (
            "Final comment should be near the end of file, not moved earlier"
        )

    def test_no_print_error(self, auto_lint_fixture_path: Callable[[str], str]) -> None:
        """Test that bare print() calls produce errors with no-print rule."""
        from jaclang.project.config import (
            CheckConfig,
            JacConfig,
            LintConfig,
            set_config,
        )

        input_path = auto_lint_fixture_path("no_print.jac")

        # Enable all rules including no-print
        config = JacConfig()
        config.check = CheckConfig(lint=LintConfig(select=["all"]))
        set_config(config)
        try:
            prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        finally:
            set_config(None)

        # Should have errors for bare print() calls
        error_msgs = [e.msg for e in prog.errors_had]
        no_print_errors = [m for m in error_msgs if "[no-print]" in m]
        # There are 2 bare print() calls in the fixture
        assert len(no_print_errors) == 2, (
            f"Expected 2 no-print errors, got {len(no_print_errors)}: {no_print_errors}"
        )

    def test_no_print_ignores_qualified_calls(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that qualified calls like console.print() are not flagged."""
        from jaclang.project.config import (
            CheckConfig,
            JacConfig,
            LintConfig,
            set_config,
        )

        input_path = auto_lint_fixture_path("no_print.jac")

        # Enable all rules including no-print
        config = JacConfig()
        config.check = CheckConfig(lint=LintConfig(select=["all"]))
        set_config(config)
        try:
            prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        finally:
            set_config(None)

        # Should NOT flag console.print()
        error_msgs = [e.msg for e in prog.errors_had]
        no_print_errors = [m for m in error_msgs if "[no-print]" in m]
        # Only the 2 bare print() calls, not the console.print() call
        assert len(no_print_errors) == 2

    def test_no_print_disabled_by_default(
        self, auto_lint_fixture_path: Callable[[str], str]
    ) -> None:
        """Test that no-print rule is not active with default select."""
        from jaclang.project.config import (
            JacConfig,
            set_config,
        )

        input_path = auto_lint_fixture_path("no_print.jac")

        # Explicitly use default config (select=["default"]) to isolate from project jac.toml
        config = JacConfig()
        set_config(config)
        try:
            prog = JacProgram.jac_file_formatter(input_path, auto_lint=True)
        finally:
            set_config(None)

        error_msgs = [e.msg for e in prog.errors_had]
        no_print_errors = [m for m in error_msgs if "[no-print]" in m]
        assert len(no_print_errors) == 0, (
            f"Expected no no-print errors by default, got: {no_print_errors}"
        )
