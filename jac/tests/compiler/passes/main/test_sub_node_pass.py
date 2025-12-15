"""Test sub node pass module."""

from collections.abc import Callable

from jaclang.compiler.passes import UniPass
from jaclang.pycore.program import JacProgram


def test_sub_node_pass(examples_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    code_gen = (out := JacProgram()).compile(
        file_path=examples_path("manual_code/circle.jac")
    )
    for i in code_gen.kid[1].kid:
        for k, v in i._sub_node_tab.items():
            for n in v:
                assert n in UniPass.get_all_sub_nodes(i, k, brute_force=True)
    assert not out.errors_had
