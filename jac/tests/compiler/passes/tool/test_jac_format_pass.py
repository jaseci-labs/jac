"""Test ast build pass module."""

import ast as ast3
import os
from collections.abc import Callable
from difflib import unified_diff

import pytest

import jaclang.jac0core.unitree as uni
from conftest import get_micro_jac_files
from jaclang.jac0core.helpers import add_line_numbers
from jaclang.jac0core.program import JacProgram


def compare_files(
    fixture_path: Callable[[str], str],
    original_file: str,
    formatted_file: str | None = None,
    auto_lint: bool = False,
) -> None:
    """Compare the original file with a provided formatted file or a new formatted version.

    Args:
        fixture_path: Function to get the path to a fixture file.
        original_file: The original file to compare.
        formatted_file: Optional expected formatted file to compare against.
        auto_lint: Whether to apply auto-linting during formatting. Defaults to False
                   for idempotency tests since we're testing the formatter, not the linter.
    """
    try:
        original_path = fixture_path(original_file)
        with open(original_path) as file:
            original_file_content = file.read()
        if formatted_file is None:
            prog = JacProgram.jac_file_formatter(original_path, auto_lint=auto_lint)
            formatted_content = prog.mod.main.gen.jac
        else:
            with open(fixture_path(formatted_file)) as file:
                formatted_content = file.read()
        diff = "\n".join(
            unified_diff(
                original_file_content.splitlines(),
                formatted_content.splitlines(),
                fromfile="original",
                tofile="formatted" if formatted_file is None else formatted_file,
            )
        )

        if diff:
            print(f"Differences found in comparison:\n{diff}")
            raise AssertionError("Files differ after formattinclearg.")

    except FileNotFoundError:
        print(f"File not found: {original_file} or {formatted_file}")
        raise
    except Exception as e:
        print(f"Error comparing files: {e}")
        raise


def test_simple_walk_fmt(fixture_path: Callable[[str], str]) -> None:
    """Tests if the file matches a particular format."""
    compare_files(
        fixture_path,
        os.path.join(fixture_path(""), "simple_walk_fmt.jac"),
    )


def test_tagbreak(fixture_path: Callable[[str], str]) -> None:
    """Tests if the file matches a particular format."""
    compare_files(
        fixture_path,
        os.path.join(fixture_path(""), "tagbreak.jac"),
    )


def test_has_fmt(fixture_path: Callable[[str], str]) -> None:
    """Tests if the file matches a particular format."""
    compare_files(
        fixture_path,
        os.path.join(fixture_path(""), "has_frmt.jac"),
    )


def test_import_fmt(fixture_path: Callable[[str], str]) -> None:
    """Tests if the file matches a particular format."""
    compare_files(
        fixture_path,
        os.path.join(fixture_path(""), "import_fmt.jac"),
    )


def test_archetype(fixture_path: Callable[[str], str]) -> None:
    """Tests if the file matches a particular format."""
    compare_files(
        fixture_path,
        os.path.join(fixture_path(""), "archetype_frmt.jac"),
    )


def micro_suite_test(filename: str, auto_lint: bool = False) -> None:
    """
    Tests the Jac formatter by:
    1. Compiling a given Jac file.
    2. Formatting the Jac file content.
    3. Compiling the formatted content.
    4. Asserting that the AST of the original compilation and the
       AST of the formatted compilation are identical.
    This ensures that the formatting process does not alter the
    syntactic structure of the code.
    Includes a specific token check for 'circle_clean_tests.jac'.

    Args:
        filename: The path to the Jac file to test.
        auto_lint: Whether to apply auto-linting during formatting. Defaults to False
                   for existing tests to maintain backward compatibility.
    """
    code_gen_pure = JacProgram().compile(filename)
    format_prog = JacProgram.jac_file_formatter(filename, auto_lint=auto_lint)
    code_gen_format = format_prog.mod.main.gen.jac
    code_gen_jac = JacProgram().compile(use_str=code_gen_format, file_path=filename)
    if "circle_clean_tests.jac" in filename:
        tokens = code_gen_format.split()
        num_test = 0
        for i in range(len(tokens)):
            if tokens[i] == "test":
                num_test += 1
                assert tokens[i + 1] == "{"
        assert num_test == 3
        return
    before = ""
    after = ""
    try:
        before = ast3.dump(code_gen_pure.gen.py_ast[0], indent=2)
        after = ast3.dump(code_gen_jac.gen.py_ast[0], indent=2)
        assert isinstance(code_gen_pure, uni.Module) and isinstance(
            code_gen_jac, uni.Module
        ), "Parsed objects are not modules."

        diff = "\n".join(unified_diff(before.splitlines(), after.splitlines()))
        assert not diff, "AST structures differ after formatting."

    except Exception as e:
        print(f"Error in {filename}: {e}")
        print(add_line_numbers(code_gen_pure.source.code))
        print("\n+++++++++++++++++++++++++++++++++++++++\n")
        print(add_line_numbers(code_gen_format))
        print("\n+++++++++++++++++++++++++++++++++++++++\n")
        if before and after:
            print("\n".join(unified_diff(before.splitlines(), after.splitlines())))
        raise e


def test_fstring_comment_not_injected(fixture_path: Callable[[str], str]) -> None:
    """Test that comments near f-strings with escaped braces are not displaced.

    Regression test for two CommentInjectionPass bugs caused by escaped-brace
    tokens ({{ / }}) in f-strings having loc (0,0):
    1. Comments injected *inside* f-strings (corrupting output).
    2. Comments preceding f-string statements displaced *after* them.
    """
    path = os.path.join(fixture_path(""), "fstring_comment.jac")
    prog = JacProgram.jac_file_formatter(path, auto_lint=True)
    formatted = prog.mod.main.gen.jac
    lines = formatted.splitlines()

    # --- Check 1: Module-level comment must not end up inside an f-string ---
    assert "# Standalone comment" in formatted, "Module comment was lost"
    in_fstring = False
    for line in lines:
        stripped = line.strip()
        if 'f"' in stripped or "f'" in stripped:
            in_fstring = True
        if in_fstring and "# Standalone comment" in line:
            raise AssertionError(
                "Comment was injected inside an f-string:\n" + formatted
            )
        if in_fstring and '";' in stripped:
            in_fstring = False

    # --- Check 2: Body-level comments must stay next to their statements ---
    # "Comment before" must appear BEFORE the f-string append, not after it.
    before_idx = next(
        (i for i, ln in enumerate(lines) if "# Comment before" in ln), None
    )
    fstring_idx = next(
        (i for i, ln in enumerate(lines) if "function guard()" in ln), None
    )
    after_idx = next((i for i, ln in enumerate(lines) if "# Comment after" in ln), None)
    assert before_idx is not None, "'# Comment before' was lost"
    assert fstring_idx is not None, "f-string statement was lost"
    assert after_idx is not None, "'# Comment after' was lost"
    assert before_idx < fstring_idx, (
        f"Comment before f-string was displaced after it "
        f"(comment at line {before_idx + 1}, f-string at line {fstring_idx + 1}):\n"
        + formatted
    )
    assert after_idx > fstring_idx, (
        f"Comment after f-string was displaced before it "
        f"(comment at line {after_idx + 1}, f-string at line {fstring_idx + 1}):\n"
        + formatted
    )

    # --- Check 3: Idempotency ---
    prog2 = JacProgram.jac_file_formatter(path, auto_lint=True)
    formatted2 = prog2.mod.main.gen.jac
    assert formatted == formatted2, "Formatting is not idempotent"


def test_jsx_hash_text_preserved(fixture_path: Callable[[str], str]) -> None:
    """Test that # inside JSX text is treated as content, not a comment.

    Regression test: the lexer's scan_jsx_content called
    skip_whitespace_and_comments(), which consumed # as a comment start.
    In JSX, # is a regular text character (like HTML).
    """
    path = os.path.join(fixture_path(""), "jsx_hash_text.jac")
    prog = JacProgram.jac_file_formatter(path, auto_lint=True)
    formatted = prog.mod.main.gen.jac

    # The # text must remain inside the <p> element, not displaced
    assert "# for client-side routing." in formatted, (
        "Hash-prefixed JSX text was lost:\n" + formatted
    )

    # It must appear BEFORE </p>, not at the end of the file
    lines = formatted.splitlines()
    hash_idx = next(
        (i for i, ln in enumerate(lines) if "# for client-side routing." in ln),
        None,
    )
    close_p_idx = next(
        (i for i, ln in enumerate(lines) if "</p>" in ln),
        None,
    )
    assert hash_idx is not None and close_p_idx is not None, (
        "Could not find hash text or </p> in formatted output:\n" + formatted
    )
    assert hash_idx < close_p_idx, (
        f"Hash text at line {hash_idx + 1} should be before </p> at "
        f"line {close_p_idx + 1}:\n" + formatted
    )

    # Idempotency
    prog2 = JacProgram.jac_file_formatter(path, auto_lint=True)
    assert formatted == prog2.mod.main.gen.jac, "Formatting is not idempotent"


# Generate micro suite tests dynamically
def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    """Generate test cases for all micro jac files."""
    if "micro_jac_file" in metafunc.fixturenames:
        files = get_micro_jac_files()
        metafunc.parametrize(
            "micro_jac_file", files, ids=lambda f: f.replace(os.sep, "_")
        )


def test_micro_suite(micro_jac_file: str) -> None:
    """Test micro jac file with formatter."""
    micro_suite_test(micro_jac_file)
