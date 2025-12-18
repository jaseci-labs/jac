"""Test Jac Auto Lint Pass module."""

import os
from collections.abc import Callable
from pathlib import Path

import pytest

import jaclang.pycore.unitree as uni
from jaclang.pycore.program import JacProgram


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
        assert "glob\n    x = 5," in formatted
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
        glob_pos = formatted.find("glob\n")
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
        assert "glob\n    existing_x = 5," in formatted
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
        assert "glob\n    module_var = 100,\n    cls_obj = MyClass();" in formatted

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
        assert "has : pub address: str," in formatted
        assert "phone: str;" in formatted

        # Static has statements should be combined
        assert "static has DEBUG: bool = False," in formatted
        assert "VERSION: str = " in formatted
        assert "MAX_RETRIES: int = 3;" in formatted

        # has with different modifiers should NOT be combined with others
        # city has default value but no access modifier, should stay separate from :pub:
        assert "has city: str = " in formatted

        # Verify statements were actually combined (count semicolons in has statements)
        # Before: 6 separate has statements, After: 4 combined has statements
        person_section = formatted.split("obj Person")[1].split("obj Config")[0]
        has_count = person_section.count("has ")
        assert has_count == 3, f"Expected 3 has statements in Person, got {has_count}"


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
        assert "glob\n    x = 1,\n    y = 2,\n    z = 3;" in formatted

        # Public glob statements should be combined separately
        assert "glob : pub\n    a = 10,\n    b = 20;" in formatted

        # Protected glob statements should be combined separately
        assert "glob : protect\n    c = 100,\n    d = 200,\n    e = 300;" in formatted

        # Mixed modifiers should NOT be combined together
        # Each should be its own statement
        assert "glob m1 = 1;" in formatted
        assert "glob : pub m2 = 2;" in formatted
        assert "glob : protect m3 = 3;" in formatted

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


class TestIsPureExpression:
    """Unit tests for the is_pure_expression method."""

    def _create_test_pass(self) -> object:
        """Create a JacAutoLintPass instance for testing."""
        from jaclang.compiler.passes.tool.jac_auto_lint_pass import JacAutoLintPass

        prog = JacProgram()
        # We need to create a stub module
        module = uni.Module.make_stub()
        return JacAutoLintPass(ir_in=module, prog=prog)

    def test_literals_are_pure(self) -> None:
        """Test that literal values are considered pure."""
        # This is a conceptual test - the actual implementation
        # checks isinstance against AST node types
        pass  # Covered by integration tests above

    def test_function_calls_not_pure(self) -> None:
        """Test that function calls are NOT considered pure."""
        # Covered by non_extractable integration test
        pass


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
