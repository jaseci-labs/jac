"""Test ast build pass module."""

import ast as ast3
import os
from collections.abc import Callable
from difflib import unified_diff

import pytest

import jaclang.pycore.unitree as uni
from conftest import get_micro_jac_files
from jaclang.pycore.helpers import add_line_numbers
from jaclang.pycore.program import JacProgram


def compare_files(
    fixture_path: Callable[[str], str],
    original_file: str,
    formatted_file: str | None = None,
) -> None:
    """Compare the original file with a provided formatted file or a new formatted version."""
    try:
        original_path = fixture_path(original_file)
        with open(original_path) as file:
            original_file_content = file.read()
        if formatted_file is None:
            prog = JacProgram.jac_file_formatter(original_path)
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


def micro_suite_test(filename: str) -> None:
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
    """
    code_gen_pure = JacProgram().compile(filename)
    format_prog = JacProgram.jac_file_formatter(filename)
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
