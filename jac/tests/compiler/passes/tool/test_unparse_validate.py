"""Test ast build pass module."""

import ast as ast3
import os
from collections.abc import Callable
from difflib import unified_diff

import pytest

from conftest import get_micro_jac_files
from jaclang.pycore.program import JacProgram


def test_double_unparse(examples_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    try:
        code_gen_pure = JacProgram().compile(examples_path("manual_code/circle.jac"))
        x = code_gen_pure.unparse()
        y = code_gen_pure.unparse()
        assert x == y
    except Exception as e:
        print("\n".join(unified_diff(x.splitlines(), y.splitlines())))
        raise e


def micro_suite_test(filename: str) -> None:
    """Parse micro jac file."""
    code_gen_pure = JacProgram().compile(
        filename,
    )
    before = ast3.dump(code_gen_pure.gen.py_ast[0], indent=2)
    x = code_gen_pure.unparse()
    code_gen_jac = JacProgram().compile(
        use_str=x,
        file_path=filename,
    )
    after = ast3.dump(code_gen_jac.gen.py_ast[0], indent=2)
    if "circle_clean_tests.jac" in filename:
        assert (
            len(
                [
                    i
                    for i in unified_diff(before.splitlines(), after.splitlines(), n=0)
                    if "test" not in i
                ]
            )
            == 5
        )
    else:
        try:
            assert (
                len("\n".join(unified_diff(before.splitlines(), after.splitlines())))
                == 0
            )
        except Exception as e:
            print(
                "\n".join(unified_diff(before.splitlines(), after.splitlines(), n=10))
            )
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
    """Test micro jac file with unparse."""
    micro_suite_test(micro_jac_file)
