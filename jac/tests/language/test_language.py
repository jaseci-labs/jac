"""Test Jac language generally."""

import io
import os
import subprocess
import sys
import tempfile
from collections.abc import Callable, Generator
from contextlib import AbstractContextManager
from pathlib import Path
from unittest.mock import patch

import pytest

from jaclang import JacRuntime as Jac
from jaclang.cli.commands import execution, transform  # type: ignore[attr-defined]
from jaclang.pycore.program import JacProgram
from jaclang.runtimelib.utils import read_file_with_encoding


@pytest.fixture(autouse=True)
def setup_jac_runtime(
    fixture_path: Callable[[str], str],
    fresh_jac_context: Path,  # Provides isolated Jac context
) -> Generator[None, None, None]:
    """Set up and tear down Jac runtime for each test."""
    Jac.attach_program(JacProgram())
    yield


def test_sub_abilities(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("sub_abil_sep.jac"))

    stdout_value = captured_output.getvalue()

    # Assertions or verifications
    assert stdout_value == "Hello, world!\nI'm a ninja Myca!\n"


def test_sub_abilities_multi(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("sub_abil_sep_multilev.jac"))  # type: ignore

    stdout_value = captured_output.getvalue()

    # Assertions or verifications
    assert stdout_value == "Hello, world!\nI'm a ninja Myca!\n"


def test_simple_jac_red(
    examples_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import(
            "micro.simple_walk",
            base_path=examples_path(""),
            override_name="__main__",
        )
    stdout_value = captured_output.getvalue()
    assert (
        stdout_value == "Value: -1\nValue: 0\nValue: 1\nValue: 2\nValue: 3\nValue: 4"
        "\nValue: 5\nValue: 6\nValue: 7\nFinal Value: 8\nDone walking.\n"
    )


def test_simple_walk_by_edge(
    examples_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("micro.simple_walk_by_edge", base_path=examples_path(""))
    stdout_value = captured_output.getvalue()
    assert stdout_value == "Visited 1\nVisited 2\n"


def test_guess_game(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("guess_game", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert (
        stdout_value
        == "Too high!\nToo low!\nToo high!\nCongratulations! You guessed correctly.\n"
    )


def test_printgraph(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test the dot gen of builtin function."""
    import json

    with capture_stdout() as captured_output:
        Jac.jac_import("builtin_printgraph_json", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    data = json.loads(stdout_value)

    nodes = data["nodes"]
    edges = data["edges"]

    assert len(nodes) == 5
    assert len(edges) == 6

    for node in nodes:
        label = node["label"]
        assert label in ["root", "N(val=0)", "N(val=1)"]

    for edge in edges:
        label = edge["label"]
        assert label in [
            "E(val=1)",
            "E(val=1)",
            "E(val=1)",
            "E(val=0)",
            "E(val=0)",
            "E(val=0)",
        ]


def test_printgraph_mermaid(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test the mermaid gen of builtin function."""
    with capture_stdout() as captured_output:
        Jac.jac_import(
            "builtin_printgraph_mermaid",
            base_path=fixture_path("./"),
        )
    stdout_value = captured_output.getvalue()
    assert "flowchart LR" in stdout_value


def test_chandra_bugs(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("chandra_bugs", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert (
        stdout_value
        == "<link href='{'new_val': 3, 'where': 'from_foo'}' rel='stylesheet'>\nTrue\n"
    )


def test_chandra_bugs2(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("chandra_bugs2", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert (
        stdout_value == "{'apple': None, 'pineapple': None}\n"
        "This is a long\n"
        "        line of code.\n"
        "{'a': 'apple', 'b': 'ball', 'c': 'cat', 'd': 'dog', 'e': 'elephant'}\n"
    )


def test_ignore(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("ignore_dup", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.split("\n")[0].count("here") == 10
    assert stdout_value.split("\n")[1].count("here") == 5


def test_dataclass_hasability(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("hashcheck_dup", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.count("check") == 2


def test_arith_precedence(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic precedence test."""
    prog = JacProgram().compile(
        use_str="with entry {print(4-5-4);}", file_path="test.jac"
    )
    with capture_stdout() as captured_output:
        exec(compile(prog.gen.py_ast[0], "test.jac", "exec"))  # type: ignore[call-overload]
    stdout_value = captured_output.getvalue()
    assert stdout_value == "-5\n"


def test_assignment_list_no_infinite_loop():
    """Test that assignment list parsing doesn't cause infinite loop."""
    # This syntax previously caused an infinite loop in two places:
    # 1. Grammar: assignment_list: (assignment_list COMMA)? (assignment | named_ref)
    #    Fixed by: assignment_list: (assignment | named_ref) (COMMA (assignment | named_ref))* COMMA?
    # 2. Error recovery: feed_current_token() had unbounded while loop
    #    Fixed by: adding max_attempts limit in parser.py
    code = "with entry { p1, p2 = (10, 20); }"
    # Compilation should complete quickly (even though syntax is invalid)
    jac_prog = JacProgram()
    result = jac_prog.compile(use_str=code, file_path="test.jac")
    # Should have errors (invalid syntax) but not hang
    assert result is not None  # Returns a Module object
    assert len(jac_prog.errors_had) > 0  # Check errors on program


def test_need_import(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing python."""
    with capture_stdout() as captured_output:
        Jac.jac_import("needs_import", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "<module 'pyfunc' from" in stdout_value


def test_gen_dot_bubble(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test the dot gen of nodes and edges of bubblesort."""
    with capture_stdout() as captured_output:
        Jac.jac_import("gendot_bubble_sort", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert '[label="inner_node(main=5, sub=2)"fillcolor="#FFDEAD"];' in stdout_value


def test_assign_operation(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test assign_compr."""
    with capture_stdout() as captured_output:
        Jac.jac_import("assign_compr_dup", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value == "[MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]\n"


def test_raw_bytestr(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test raw string and byte string."""
    with capture_stdout() as captured_output:
        Jac.jac_import("raw_byte_string", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.count(r"\\\\") == 2
    assert stdout_value.count("<class 'bytes'>") == 3


def test_fstring_multiple_quotation(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test fstring with multiple quotation."""
    with capture_stdout() as captured_output:
        Jac.jac_import(
            "compiler/passes/main/fixtures/fstrings",
            base_path=fixture_path("../../"),
        )
    stdout_value = captured_output.getvalue()
    assert stdout_value.split("\n")[0] == "11 13 12 12 11 12 12"
    assert stdout_value.split("\n")[1] == '12 12 """hello"""  18 18'
    assert stdout_value.split("\n")[2] == "11 12 11 12 11 18 23"
    assert stdout_value.split("\n")[3] == 'hello klkl"""'


def test_fstring_escape_sequences(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that escape sequences in f-strings are properly decoded."""
    with capture_stdout() as captured_output:
        Jac.jac_import(
            "compiler/passes/main/fixtures/fstring_escape_sequences",
            base_path=fixture_path("../../"),
        )
    stdout_value = captured_output.getvalue()
    lines = stdout_value.strip().split("\n")
    # Verify escape sequences are actual newlines/tabs, not literal \n or \t
    assert lines[0] == "'hello\\nworld'"  # repr shows \n as \\n
    assert lines[1] == "'tab\\there'"  # repr shows \t as \\t
    assert lines[2] == "'line1\\nline2\\nline3'"
    assert lines[3] == "'world\\tworld\\tworld'"


def test_deep_imports(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("deep_import", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.split("\n")[0] == "one level deeperslHello World!"


def test_deep_imports_interp_mode(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    Jac.set_base_path(fixture_path("./"))
    Jac.attach_program(
        JacProgram(),
    )
    # Clear any cached module from previous test runs
    for mod_name in list(sys.modules.keys()):
        if "deep_import_interp" in mod_name:
            del sys.modules[mod_name]
    # Delete bytecode cache files to force recompilation
    cache_dir = Path.cwd() / ".jac" / "cache"
    if cache_dir.exists():
        for cache_file in cache_dir.glob("deep_import_interp*.jbc"):
            cache_file.unlink()

    with capture_stdout() as captured_output:
        Jac.jac_import("deep_import_interp", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert len(Jac.get_program().mod.hub.keys()) == 1
    assert "one level deeperslHello World!" in stdout_value

    Jac.set_base_path(fixture_path("./"))
    Jac.attach_program(
        (prog := JacProgram()),
    )
    prog.compile(fixture_path("./deep_import_interp.jac"))
    # as we use jac_import, only main module should be in the hub
    assert len(Jac.get_program().mod.hub.keys()) == 1


def test_deep_imports_mods(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    targets = [
        "deep",
        "deep.deeper",
        "deep.mycode",
        "deep.deeper.snd_lev",
        "deep.one_lev",
    ]
    for i in targets:
        if i in sys.modules:
            del sys.modules[i]
    with capture_stdout() as captured_output:
        Jac.jac_import("deep_import_mods", base_path=fixture_path("./"))
    stdout_value = eval(captured_output.getvalue())
    for i in targets:
        assert i in stdout_value


def test_deep_outer_imports_one(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import(
            "deep.deeper.deep_outer_import",
            base_path=fixture_path("./"),
        )
    stdout_value = captured_output.getvalue()
    assert "one level deeperslHello World!" in stdout_value
    assert (
        "module 'pyfunc' from " in stdout_value
        or "module 'jaclang.tests.fixtures.pyfunc' from " in stdout_value
    )


def test_deep_outer_imports_from_loc(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        os.chdir(fixture_path("./deep/deeper/"))
        execution.run("deep_outer_import.jac")
    stdout_value = captured_output.getvalue()
    assert "one level deeperslHello World!" in stdout_value
    assert (
        "module 'jaclang.tests.fixtures.pyfunc' from " in stdout_value
        or "module 'pyfunc' from " in stdout_value
    )


def test_has_lambda_goodness(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test has lambda_goodness."""
    with capture_stdout() as captured_output:
        Jac.jac_import("has_goodness", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.split("\n")[0] == "mylist:  [1, 2, 3]"
    assert stdout_value.split("\n")[1] == "mydict:  {'a': 2, 'b': 4}"


def test_conn_assign_on_edges(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test conn assign on edges."""
    with capture_stdout() as captured_output:
        Jac.jac_import("edge_ops", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "[(3, 5), (14, 1), (5, 1)]" in stdout_value
    assert "10\n" in stdout_value
    assert "12\n" in stdout_value


def test_disconnect(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test conn assign on edges."""
    with capture_stdout() as captured_output:
        Jac.jac_import("disconn", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "c(cc=0)" in stdout_value[0]
    assert "c(cc=1)" in stdout_value[0]
    assert "c(cc=2)" in stdout_value[0]
    assert "True" in stdout_value[2]
    assert "[]" in stdout_value[3]
    assert "['GenericEdge', 'GenericEdge', 'GenericEdge']" in stdout_value[5]


def test_simple_archs(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test conn assign on edges."""
    with capture_stdout() as captured_output:
        Jac.jac_import("simple_archs", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.split("\n")[0] == "1 2 0"
    assert stdout_value.split("\n")[1] == "0"


def test_edge_walk(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test walking through edges."""
    with capture_stdout() as captured_output:
        Jac.jac_import("edges_walk", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "creator()\n" in stdout_value
    assert "[node_a(val=12)]\n" in stdout_value
    assert "node_a(val=1)" in stdout_value
    assert "node_a(val=2)" in stdout_value
    assert "[node_a(val=42), node_a(val=42)]\n" in stdout_value


def test_tuple_of_tuple_assign(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test walking through edges."""
    with capture_stdout() as captured_output:
        Jac.jac_import("tuplytuples", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert (
        "a apple b banana a apple b banana a apple b banana a apple b banana"
        in stdout_value
    )


def test_deferred_field(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test walking through edges."""
    with capture_stdout() as captured_output:
        Jac.jac_import("deferred_field", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "5 15" in stdout_value


def test_gen_dot_builtin(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test the dot gen of nodes and edges as a builtin."""
    with capture_stdout() as captured_output:
        Jac.jac_import("builtin_printgraph", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.count("True") == 16


def test_with_contexts(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test walking through edges."""
    with capture_stdout() as captured_output:
        Jac.jac_import("with_context", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "im in" in stdout_value
    assert "in the middle" in stdout_value
    assert "im out" in stdout_value
    assert (
        "{'apple': [1, 2, 3], 'banana': [1, 2, 3], 'cherry': [1, 2, 3]}" in stdout_value
    )


def test_typed_filter_compr(
    examples_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("micro.typed_filter_compr", base_path=examples_path(""))
    stdout_value = captured_output.getvalue()
    assert (
        "[MyObj(a=0), MyObj2(a=2), MyObj(a=1), MyObj2(a=3), MyObj(a=2), MyObj(a=3)]\n"
        in stdout_value
    )
    assert "[MyObj(a=0), MyObj(a=1), MyObj(a=2)]\n" in stdout_value


def test_edge_node_walk(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test walking through edges and nodes."""
    with capture_stdout() as captured_output:
        Jac.jac_import("edge_node_walk", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "creator()\n" in stdout_value
    assert "[node_a(val=12)]\n" in stdout_value
    assert "node_a(val=1)" in stdout_value
    assert "node_a(val=2)" in stdout_value
    assert "[node_b(val=42), node_b(val=42)]\n" in stdout_value


def test_annotation_tuple_issue(fixture_path: Callable[[str], str]) -> None:
    """Test conn assign on edges."""
    mypass = JacProgram().compile(fixture_path("./slice_vals.jac"))
    assert "Annotated[Str, INT, BLAH]" in mypass.gen.py
    assert "tuple[int, Optional[type], Optional[tuple]]" in mypass.gen.py


def test_enum_inside_arch(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test Enum as member stmt."""
    with capture_stdout() as captured_output:
        Jac.jac_import("enum_inside_archtype", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "2 Accessing privileged Data" in stdout_value


def test_pyfunc_1(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.pycore.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "pyfunc_1.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "def greet2(**kwargs: Any) -> None {" in output
    assert output.count("with entry {") == 14
    assert "assert (x == 5) , 'x should be equal to 5';" in output
    assert "if not (x == y) {" in output
    assert "squares_dict = {x: (x ** 2) for x in numbers};" in output
    assert '\n"""Say hello"""\n@my_decorator\n\n def say_hello() -> object {' in output


def test_pyfunc_2(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.pycore.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "pyfunc_2.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "class X {\n    with entry {\n        a_b = 67;" in output
    assert "br = b'Hello\\\\\\\\nWorld'" in output
    assert "class Circle {\n    def init(self: Circle, radius: float" in output
    assert "<>node = 90;\n    print(<>node);\n" in output


def test_pyfunc_3(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.pycore.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "pyfunc_3.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "if (0 <= x <= 5) {" in output
    assert "  case _:\n" in output
    assert " case Point(x = int(a), y = 0):\n" in output
    assert "class Sample {\n    def init" in output


def test_py2jac(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.pycore.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "match Container(inner=Inner(x=a, y=b)) {\n" in output
    assert "case Container(inner = Inner(x = a, y = 0)):\n" in output
    assert "case Container(inner = Inner(x = a, y = b)):\n" in output
    assert "case _:\n" in output


def test_py2jac_params(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.pycore.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac_params.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert (
        "def isinstance(<>obj: object, class_or_tuple: _ClassInfo, /) -> bool {"
        in output
    )
    assert (
        "def len(<>obj: Sized, astt: object, /, z: int, j: str, a: int = 90) -> int {"
        in output
    )


def test_py2jac_empty_file(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.pycore.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac_empty.py")
    with open(py_out_path) as f:
        file_source = f.read()
        converted_ast = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out
    assert isinstance(converted_ast, ast.Module)


def test_py2jac_augassign_and_doc(fixture_path: Callable[[str], str]) -> None:
    """Ensure augmented assigns avoid redecl and nested docstrings terminate."""
    import ast as py_ast

    import jaclang.pycore.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac_augassign_doc.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "x += 2;" in output  # augmented assign should not emit `let`
    assert '"""inner doc"""; def inner()' in output  # docstring should end before def


def test_py2jac_reassign_semantics(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that py2jac preserves variable reassignment semantics.

    This test catches the bug where py2jac incorrectly uses 'let' for
    variable reassignments inside loops/conditionals, which creates
    shadowed variables instead of modifying the outer scope variable.
    """
    import ast as py_ast

    import jaclang.pycore.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac_reassign.py")
    with open(py_out_path) as f:
        file_source = f.read()
        jac_code = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()

    # Key check: reassignments should NOT use 'let'
    # Wrong: "let found = True;" inside the if block
    # Right: "found = True;" inside the if block
    assert "let found = True" not in jac_code, (
        "py2jac bug: 'let' used for reassignment in loop - "
        "this creates a shadowed variable instead of reassigning"
    )
    assert (
        "let status = " not in jac_code.split("let status = ")[2]
        if jac_code.count("let status = ") > 1
        else True
    ), "py2jac bug: 'let' used for reassignment in conditional"

    # Execute the converted code and verify it produces correct results
    with capture_stdout() as captured_output:
        Jac.jac_import(
            target="py2jac_reassign",
            base_path=fixture_path("./"),
        )
    stdout_value = captured_output.getvalue()
    assert "All tests passed!" in stdout_value, (
        f"Converted Jac code produced wrong output. "
        f"This likely means py2jac created shadowed variables. Output: {stdout_value}"
    )


def test_refs_target(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test py ast to Jac ast conversion output."""
    with capture_stdout() as captured_output:
        Jac.jac_import("refs_target", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "[c(val=0), c(val=1), c(val=2)]" in stdout_value
    assert "[c(val=0)]" in stdout_value


def test_double_format_issue():
    """Basic precedence test."""
    prog = JacProgram().compile("with entry {print(hello);}", "test.jac")
    prog.unparse()
    before = prog.format()
    prog.format()
    prog.format()
    after = prog.format()
    assert before == after


def test_inherit_check(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test py ast to Jac ast conversion output."""
    with capture_stdout() as captured_output:
        Jac.jac_import("inherit_check", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value == "I am in b\nI am in b\nwww is also in b\n"


def test_tuple_unpack(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test tuple unpack."""
    with capture_stdout() as captured_output:
        Jac.jac_import("tupleunpack", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "1" in stdout_value[0]
    assert "[2, 3, 4]" in stdout_value[1]


def test_trailing_comma(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test trailing comma."""
    with capture_stdout() as captured_output:
        Jac.jac_import("trailing_comma", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "Code compiled and ran successfully!" in stdout_value


def test_try_finally(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test try finally."""
    with capture_stdout() as captured_output:
        Jac.jac_import("try_finally", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "try block" in stdout_value[0]
    assert "finally block" in stdout_value[1]
    assert "try block" in stdout_value[2]
    assert "else block" in stdout_value[3]
    assert "finally block" in stdout_value[4]


def test_arithmetic_bug(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test arithmetic bug."""
    with capture_stdout() as captured_output:
        Jac.jac_import("arithmetic_bug", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert stdout_value[0] == "0.0625"
    assert stdout_value[1] == "1e-06"
    assert stdout_value[2] == "1000.000001"
    assert stdout_value[3] == "78"
    assert stdout_value[4] == "12"


def test_lambda_expr(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test lambda expr."""
    with capture_stdout() as captured_output:
        Jac.jac_import("lambda", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert stdout_value[0] == "9"
    assert stdout_value[1] == "567"


def test_override_walker_inherit(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test py ast to Jac ast conversion output."""
    with capture_stdout() as captured_output:
        Jac.jac_import("walker_override", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value == "baz\nbar\n"


def test_self_with_no_sig(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:  # we can get rid of this, isn't?
    """Test py ast to Jac ast conversion output."""
    with capture_stdout() as captured_output:
        Jac.jac_import("nosigself", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.count("5") == 2


def test_hash_init_check(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:  # we can get rid of this, isn't?
    """Test py ast to Jac ast conversion output."""
    with capture_stdout() as captured_output:
        Jac.jac_import("hash_init_check", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "Test Passed" in stdout_value


def test_multiline_single_tok(fixture_path: Callable[[str], str]) -> None:
    """Test conn assign on edges."""
    mypass = JacProgram().compile(fixture_path("byllmissue.jac"))
    assert "2:5 - 4:8" in mypass.pp()


@pytest.mark.xfail(reason="TODO: Support symtable for inheritance")
def test_inherit_baseclass_sym(examples_path: Callable[[str], str]) -> None:
    """Basic test for symtable support for inheritance."""
    mypass = JacProgram().compile(examples_path("guess_game/guess_game3.jac"))
    table = None
    for i in mypass.sym_tab.kid_scope:
        if i.scope_name == "GuessTheNumberGame":
            for j in i.kid_scope:
                if j.scope_name == "play":
                    table = j
                    break
            break
    assert table is not None
    assert table.lookup("attempts") is not None


def test_edge_expr_not_type(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing python."""
    with capture_stdout() as captured_output:
        Jac.jac_import("edgetypeissue", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "[x()]" in stdout_value


def test_blank_with_entry(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing python."""
    with capture_stdout() as captured_output:
        Jac.jac_import("blankwithentry", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "i work" in stdout_value


def test_kwonly_params(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing python."""
    with capture_stdout() as captured_output:
        Jac.jac_import("test_kwonly_params", base_path=fixture_path("./params"))
    stdout_value = captured_output.getvalue().split("\n")
    assert stdout_value[0] == "KW_SIMPLE: 42"
    assert stdout_value[1] == "KW_DEF: 10-def 20-def"
    assert stdout_value[2] == "REG_KW: 10|test"
    assert stdout_value[3] == "MIXED_KW: 1-def-2.5-True 2-custom-3.5-False"
    assert stdout_value[4] == "ALL_KW: 100:test:1.0 200:hi:9.9"


def test_complex_params(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing python."""
    with capture_stdout() as captured_output:
        Jac.jac_import("test_complex_params", base_path=fixture_path("./params"))
    stdout_value = captured_output.getvalue().split("\n")
    assert stdout_value[0] == "ULTIMATE_MIN: 1|def|2.5|0|test|100|0"
    assert stdout_value[1] == "ULTIMATE_FULL: 1|custom|3.14|3|req|200|1"
    assert stdout_value[2] == "SEPARATORS: 42"
    assert stdout_value[3] == "EDGE_MIX: 1-test-2-True-1"
    assert stdout_value[4] == "RECURSIVE: 7 11"
    assert stdout_value[5] == "VALIDATION: x:1,y:2.5,z:10,args:1,w:True,kwargs:1"


def test_param_failing(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing python."""
    with capture_stdout() as captured_output:
        for i in [
            "test_failing_posonly",
            "test_failing_kwonly",
            "test_failing_varargs",
        ]:
            Jac.jac_import(i, base_path=fixture_path("./params"))
    stdout_value = captured_output.getvalue()
    assert "FAILED" not in stdout_value


def test_double_import_exec(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing python."""
    with capture_stdout() as captured_output:
        Jac.jac_import("dblhello", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value.count("Hello World!") == 1
    assert "im still here" in stdout_value


def test_cls_method(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test class method output."""
    with capture_stdout() as captured_output:
        Jac.jac_import("cls_method", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert stdout_value[0] == "MyClass"
    assert stdout_value[1] == "Hello, World1! Hello, World2!"
    assert stdout_value[2] == "Hello, World! Hello, World22!"


def test_list_methods(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test list_modules, list_walkers, list_nodes, and list_edges."""
    Jac.set_base_path(fixture_path("."))
    sys.modules.pop("foo", None)
    sys.modules.pop("bar", None)
    with capture_stdout() as captured_output:
        Jac.jac_import("foo", base_path=fixture_path("."))

    stdout_value = captured_output.getvalue()

    assert "Module: foo" in stdout_value
    assert "Module: bar" in stdout_value
    assert "Walkers in bar:\n  - Walker: bar_walk" in stdout_value
    assert "Nodes in bar:\n  - Node: Item" in stdout_value
    assert "Edges in bar:\n  - Edge: Link" in stdout_value
    assert "Item value: 0" in stdout_value
    assert "Created 5 items." in stdout_value


def test_walker_dynamic_update(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
    fresh_jac_context: Path,
) -> None:
    """Test dynamic update of a walker during runtime."""
    sys.modules.pop("bar", None)
    bar_file_path = fixture_path("bar.jac")
    update_file_path = fixture_path("walker_update.jac")
    with capture_stdout() as captured_output:
        execution.enter(
            filename=bar_file_path,
            entrypoint="bar_walk",
            args=[],
        )
    stdout_value = captured_output.getvalue()
    expected_output = "Created 5 items."
    assert expected_output in stdout_value.split("\n")
    # Define the new behavior to be added (using entry since exits are deferred
    # and won't run when disengage is called during child traversal)
    new_behavior = """
    # New behavior added during runtime
    can announce with `root entry {
        "bar_walk has been updated with new behavior!" |> print;
        }
    }
    """

    # Backup the original file content
    with open(bar_file_path) as bar_file:
        original_content = bar_file.read()

    # Update the bar.jac file with new behavior
    with open(bar_file_path, "r+") as bar_file:
        content = bar_file.read()
        last_brace_index = content.rfind("}")
        if last_brace_index != -1:
            updated_content = content[:last_brace_index] + new_behavior
            bar_file.seek(0)
            bar_file.write(updated_content)
            bar_file.truncate()

    with capture_stdout() as captured_output:
        try:
            # Reset state for dynamic update test
            Jac.loaded_modules.clear()
            Jac.attach_program(JacProgram())
            execution.run(
                filename=update_file_path,
            )
            stdout_value = captured_output.getvalue()
            expected_output = "bar_walk has been updated with new behavior!"
            assert expected_output in stdout_value.split("\n")
        finally:
            # Restore the original content of bar.jac
            with open(bar_file_path, "w") as bar_file:
                bar_file.write(original_content)


def test_dynamic_spawn_archetype(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that the walker and node can be spawned and behaves as expected."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("dynamic_archetype.jac"))

    output = captured_output.getvalue().strip()
    output_lines = output.split("\n")

    # Expected outputs for spawned entities
    expected_spawned_node = "Spawned Node:"
    expected_spawned_walker = "Spawned Walker:"
    expected_spawned_external_node = "Spawned External node:"

    # Check for the spawned messages
    assert any(expected_spawned_node in line for line in output_lines), (
        f"Expected '{expected_spawned_node}' in output."
    )
    assert any(expected_spawned_walker in line for line in output_lines), (
        f"Expected '{expected_spawned_walker}' in output."
    )
    assert any(expected_spawned_external_node in line for line in output_lines), (
        f"Expected '{expected_spawned_external_node}' in output."
    )

    # Expected values from the walker traversal
    expected_values = ["Value: 0", "Value: 1", "Value: 2", "Value: 3"]

    # Each expected value should appear twice (once for test_node, once for Item)
    for val in expected_values:
        occurrences = [line for line in output_lines if line.strip() == val]
        assert len(occurrences) == 2, (
            f"Expected '{val}' to appear 2 times, but found {len(occurrences)}."
        )


def test_dynamic_archetype_creation(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that the walker and node can be created dynamically."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("create_dynamic_archetype.jac"))

    output = captured_output.getvalue().strip()
    # Expected outputs for spawned entities
    expected_spawned_walker = "Dynamic Node Value: 99"

    # Check for the spawned messages
    assert expected_spawned_walker in output, (
        f"Expected '{expected_spawned_walker}' in output."
    )


def test_dynamic_archetype_creation_rel_import(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that the walker and node can be created dynamically, with relative import."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("arch_rel_import_creation.jac"))

    output = captured_output.getvalue().strip().splitlines()
    # Expected outputs for spawned entities
    expected_values = ["DynamicWalker Started", "UtilityNode Data: 42"]
    for val in expected_values:
        # Check for the spawned messages
        assert val in output, f"Expected '{val}' in output."


def test_object_ref_interface(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test class method output."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("objref.jac"))
    stdout_value = captured_output.getvalue().split("\n")
    assert len(stdout_value[0]) == 32
    assert stdout_value[1] == "MyNode(value=0)"
    assert stdout_value[2] == "valid: True"


def test_match_multi_ex(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test match case with multiple expressions."""
    with capture_stdout() as captured_output:
        Jac.jac_import("match_multi_ex", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert stdout_value[0] == "Ten"
    assert stdout_value[1] == "ten"


def test_entry_exit(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test entry and exit behavior of walker."""
    with capture_stdout() as captured_output:
        Jac.jac_import("entry_exit", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Entering at the beginning of walker:  Root()" in stdout_value[0]
    assert "entry_count=1, exit_count=1" in str(stdout_value[12])
    assert "Exiting at the end of walker:  test_node(value=" in stdout_value[11]


def test_visit_order(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test entry and exit behavior of walker."""
    with capture_stdout() as captured_output:
        Jac.jac_import("visit_order", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value == "[MyNode(Name='End'), MyNode(Name='Middle')]\n"


def test_global_multivar(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test supporting multiple global variable in a statement."""
    with capture_stdout() as captured_output:
        Jac.jac_import("glob_multivar_statement", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Hello World !" in stdout_value[0]
    assert "Welcome to Jaseci!" in stdout_value[1]


def test_archetype_def(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test archetype definition bug."""
    with capture_stdout() as captured_output:
        Jac.jac_import("archetype_def_bug", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "MyWalker" in stdout_value[0]
    assert "MyNode" in stdout_value[1]


def test_visit_sequence(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test conn assign on edges.

    With DFS post-order semantics:
    - Entries execute depth-first: a, b, c
    - Exits execute in reverse (LIFO): c, b, a
    """
    with capture_stdout() as captured_output:
        Jac.jac_import("visit_sequence", base_path=fixture_path("./"))
    assert (
        captured_output.getvalue() == "walker entry\nwalker enter to root\n"
        "a-1\na-2\na-3\n"
        "b-1\nb-2\nb-3\n"
        "c-1\nc-2\nc-3\nc-4\nc-5\nc-6\n"
        "b-4\nb-5\nb-6\n"
        "a-4\na-5\na-6\n"
        "walker exit\n"
    )


def test_connect_traverse_syntax(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test connect traverse syntax."""
    with capture_stdout() as captured_output:
        Jac.jac_import("connect_traverse_syntax", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "A(val=5), A(val=10)" in stdout_value[0]
    assert "[Root(), A(val=20)]" in stdout_value[1]
    assert (
        "A(val=5), A(val=10)" in stdout_value[2]
    )  # Remove after dropping deprecated syntax support
    assert (
        "[Root(), A(val=20)]" in stdout_value[3]
    )  # Remove after dropping deprecated syntax support


def test_node_del(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test complex nested impls."""
    with capture_stdout() as captured_output:
        Jac.jac_import("node_del", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "0 : [2, 3, 4, 5, 6, 7, 8, 9, 10]" in stdout_value[0]
    assert "7, 8 : [2, 3, 4, 5, 6, 7, 9]" in stdout_value[1]
    assert "before delete : Inner(c=[1, 2, 3], d=4)" in stdout_value[2]
    assert "after delete : Inner(c=[1, 3], d=4)" in stdout_value[3]


# Helper method to create files within tests
def create_temp_jac_file(
    content: str, dir_path: str, filename: str = "test_mod.jac"
) -> str:
    """Create a temporary Jac file in a specific directory."""
    full_path = os.path.join(dir_path, filename)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w") as f:
        f.write(content)
    return full_path


def test_import_from_site_packages(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing a Jac module from simulated site-packages."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Simulate site-packages directory structure
        mock_site_dir = os.path.join(tmpdir, "site-packages")
        os.makedirs(mock_site_dir)

        # Create a module within the simulated site-packages
        site_mod_content = 'with entry { "Site package module loaded!" |> print; }'
        create_temp_jac_file(site_mod_content, mock_site_dir, "site_pkg_mod.jac")

        # Create the importing script in the main temp directory
        importer_content = "import site_pkg_mod;"
        _ = create_temp_jac_file(importer_content, tmpdir, "importer_site.jac")
        with patch("site.getsitepackages", return_value=[mock_site_dir]):
            with capture_stdout() as captured_output:
                original_cwd = os.getcwd()
                try:
                    Jac.jac_import("importer_site", base_path=tmpdir)
                finally:
                    os.chdir(original_cwd)

            stdout_value = captured_output.getvalue()
            assert "Site package module loaded!" in stdout_value


def test_import_from_jacpath(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing a Jac module from JACPATH."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Simulate JACPATH directory
        jacpath_dir = os.path.join(tmpdir, "jaclibs")
        os.makedirs(jacpath_dir)

        # Create a module in the JACPATH directory
        jacpath_mod_content = 'with entry { "JACPATH module loaded!" |> print; }'
        create_temp_jac_file(jacpath_mod_content, jacpath_dir, "jacpath_mod.jac")

        # Create the importing script in a different location
        script_dir = os.path.join(tmpdir, "scripts")
        os.makedirs(script_dir)
        importer_content = "import jacpath_mod;"
        _ = create_temp_jac_file(importer_content, script_dir, "importer.jac")

        # Set JACPATH environment variable and run
        original_jacpath = os.environ.get("JACPATH")
        os.environ["JACPATH"] = jacpath_dir
        with capture_stdout() as captured_output:
            original_cwd = os.getcwd()
            os.chdir(script_dir)
            try:
                execution.run("importer.jac")
            finally:
                os.chdir(original_cwd)
                # Clean up environment variable
                if original_jacpath is None:
                    if "JACPATH" in os.environ:
                        del os.environ["JACPATH"]
                else:
                    os.environ["JACPATH"] = original_jacpath

        stdout_value = captured_output.getvalue()
        assert "JACPATH module loaded!" in stdout_value


def test_obj_hasvar_initialization(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (out := JacProgram()).compile(fixture_path("uninitialized_hasvars.jac"))
    assert out.errors_had

    expected_stdout_values = (
        "Non default attribute 'var3' follows default attribute",
        "    3 |     has var1: int;",
        "    4 |     has var2: int = 42;",
        "    5 |     has var3: int;  # <-- This should be syntax error.",
        "      |         ^^^^",
        "    6 | }",
        'Missing "postinit" method required by un initialized attribute(s).',
        "    9 | obj Test2 {",
        "   10 |     has var1: str;",
        "   11 |     has var2: int by postinit;",
        "      |         ^^^^",
        "   12 | }",
        "Non default attribute 'var4' follows default attribute",
        "   17 |     has var2: int = 42;",
        "   18 |     has var3: int by postinit;  # <-- This is fine.",
        "   19 |     has var4: int;  # <-- This should be syntax error.",
        "      |         ^^^^",
        "   20 |",
        "   21 |     def postinit() {",
    )

    errors_output = ""
    for error in out.errors_had:
        errors_output += error.pretty_print() + "\n"

    for exp in expected_stdout_values:
        assert exp in errors_output


def test_async_walker(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test async walker."""
    with capture_stdout() as captured_output:
        Jac.jac_import("async_walker", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Let's start the task" in stdout_value[0]
    assert "It is Coroutine task True" in stdout_value[1]
    assert "Coroutine task is completed" in stdout_value[6]


def test_async_function(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test async ability."""
    with capture_stdout() as captured_output:
        Jac.jac_import("async_function", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Hello" in stdout_value[0]
    assert "Hello" in stdout_value[1]
    assert "World!" in stdout_value[2]


def test_concurrency(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test concurrency in jaclang."""
    with capture_stdout() as captured_output:
        Jac.jac_import("concurrency", base_path=fixture_path("./"))
    # Check output contains expected values (order may vary due to concurrency)
    full_output = captured_output.getvalue()
    assert "Started" in full_output
    assert "B(name='Hi')" in full_output
    assert "All are started" in full_output
    assert "All are done" in full_output
    assert "11" in full_output
    assert "13" in full_output


def test_import_jac_from_py(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        from .fixtures import jac_from_py

        jac_from_py.main()

    stdout_value = captured_output.getvalue()
    assert (
        stdout_value == "Value: -1\nValue: 0\nValue: 1\nValue: 2\nValue: 3\nValue: 4"
        "\nValue: 5\nValue: 6\nValue: 7\nFinal Value: 8\nDone walking.\n"
    )


def test_py_namedexpr(fixture_path: Callable[[str], str]) -> None:
    """Ensure NamedExpr nodes are converted to AtomUnit."""
    import ast as py_ast

    import jaclang.pycore.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py_namedexpr.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "(x := 10)" in output


def test_py_bool_parentheses(fixture_path: Callable[[str], str]) -> None:
    """Ensure boolean expressions preserve parentheses during conversion."""
    import ast as py_ast

    import jaclang.pycore.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py_bool_expr.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "(prev_token_index is None)" in output
    assert "(next_token_index is None)" in output
    assert "(tok[0] > change_end_line)" in output
    assert "(tok[0] == change_end_line)" in output
    assert "(tok[1] > change_end_char)" in output


def test_here_visitor_usage(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test visitor, here keyword usage in jaclang."""
    with capture_stdout() as captured_output:
        Jac.jac_import("here_visitor_usage", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Here value is  10" in stdout_value[0]
    assert "Visitor name is  Walker 1" in stdout_value[1]


def test_here_visitor_error(fixture_path: Callable[[str], str]) -> None:
    """Test visitor, here keyword usage in jaclang."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output
    try:
        result = execution.run(fixture_path("here_usage_error.jac"))
    finally:
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
    assert result == 1
    stdout_value = captured_output.getvalue()
    assert "'here' is not defined" in stdout_value


def test_edge_ability(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test visitor, here keyword usage in jaclang.

    With DFS post-order semantics, entries happen depth-first and exits in reverse.
    """
    with capture_stdout() as captured_output:
        execution.run(fixture_path("edge_ability.jac"))
    stdout_value = captured_output.getvalue().split("\n")
    # Walker entry on edge (path=1)
    assert "MyEdge from walker MyEdge(path=1)" in stdout_value[0]
    # Edge entry with walker trigger
    assert "MyWalker from edge MyWalker()" in stdout_value[1]
    # Node entry with walker trigger (first node val=10)
    assert "MyWalker from node MyWalker()" in stdout_value[3]
    # Walker entry on edge (path=2) - happens during DFS into second node
    assert "MyEdge from walker MyEdge(path=2)" in stdout_value[4]


def test_backward_edge_visit(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test backward edge visit in jaclang."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("backward_edge_visit.jac"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "MyWalker() from node MyNode(val=0)" in stdout_value[0]
    assert "MyWalker() from edge MyEdge(path=0)" in stdout_value[1]
    assert "MyWalker() from edge MyEdge(path=3)" in stdout_value[6]
    assert "MyWalker() from node MyNode(val=40)" in stdout_value[9]


def test_visit_traversal(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test visit traversal semantic in jaclang."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("visit_traversal.jac"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "MyWalker() from node MyNode(val=0)" in stdout_value[0]
    assert "MyWalker() from node MyNode(val=20)" in stdout_value[2]
    assert "MyWalker() from node MyNode(val=60)" in stdout_value[4]
    assert "MyWalker() from node MyNode(val=40)" in stdout_value[6]
    assert "MyWalker() from node MyNode(val=90)" in stdout_value[7]
    assert "MyWalker() from node MyNode(val=70)" in stdout_value[9]


def test_async_ability(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test async ability."""
    with capture_stdout() as captured_output:
        Jac.jac_import("async_ability", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Let's start the task" in stdout_value[0]
    assert "It is Coroutine task True" in stdout_value[1]
    assert "I am here man MyNode(val=5)" in stdout_value[2]
    assert "Async function" in stdout_value[3]
    assert "foo3" in stdout_value[4]
    assert "foo1" in stdout_value[5]
    assert "foo2" in stdout_value[6]
    assert "Coroutine task is completed" in stdout_value[17]


def test_iter_for_continue(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test iter for continue."""
    with capture_stdout() as captured_output:
        Jac.jac_import("iter_for_continue", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "0" in stdout_value[0]
    assert "1" in stdout_value[1]
    assert "2" in stdout_value[2]
    assert "Skipping 3" in stdout_value[3]
    assert "4" in stdout_value[4]


def test_unicode_string_literals(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test unicode characters in string literals are preserved correctly."""
    with capture_stdout() as captured_output:
        Jac.jac_import("unicode_strings", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "1. ✓ 1st (due: True)" in stdout_value[0]
    assert "🌟 Star" in stdout_value[2]
    assert "Multi-line with ✓ unicode and ○ symbols" in stdout_value[3]
    assert "Raw string with ✓ and ○" in stdout_value[4]
    assert "Tab ✓" in stdout_value[5]
    assert "Newline ○" in stdout_value[6]


def test_sitecustomize_meta_importer():
    """Verify Jac modules importable without importing jaclang."""
    with tempfile.TemporaryDirectory() as tmpdir:
        Path(tmpdir, "mymod.jac").write_text('with entry {print("via meta");}')
        env = os.environ.copy()
        project_root = Path(__file__).resolve().parents[2]
        env["PYTHONPATH"] = os.pathsep.join([str(project_root), tmpdir])
        proc = subprocess.run(
            [sys.executable, "-c", "import mymod"],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env,
        )
        assert proc.returncode == 0, proc.stderr
        assert proc.stdout.strip() == "via meta"


def test_spawn_loc_list(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test spawning a walker on list of nodes.

    With DFS post-order semantics, the traversal order changes.
    """
    with capture_stdout() as captured_output:
        Jac.jac_import("spawn_loc_list", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "I am here MyNode(val=5)" in stdout_value[0]
    assert "I am here MyNode(val=15)" in stdout_value[2]
    assert "I am here MyNode(val=30)" in stdout_value[3]
    assert "I am here MyEdge(val=100)" in stdout_value[4]
    assert "I am here MyNode(val=20)" in stdout_value[6]


def test_while_else(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test else part in while loop."""
    with capture_stdout() as captured_output:
        Jac.jac_import("while_else", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Num:  4" in stdout_value[0]
    assert "Num:  3" in stdout_value[1]
    assert "Completed" in stdout_value[2]


def test_read_file_with_encoding_utf8():
    """Test reading UTF-8 encoded file."""
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as f:
        test_content = "Hello, 世界! 🌍 Testing UTF-8 encoding."
        f.write(test_content)
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)
        assert result == test_content
    finally:
        os.unlink(temp_path)


def test_read_file_with_encoding_utf16():
    """Test reading UTF-16 encoded file when UTF-8 fails."""
    with tempfile.NamedTemporaryFile(delete=False, mode="w", encoding="utf-16") as f:
        test_content = "Hello, 世界! UTF-16 encoding test."
        f.write(test_content)
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)
        assert result == test_content
    finally:
        os.unlink(temp_path)


def test_read_file_with_encoding_utf8_bom():
    """Test reading UTF-8 with BOM encoded file."""
    with tempfile.NamedTemporaryFile(delete=False, mode="w", encoding="utf-8-sig") as f:
        test_content = "Hello, UTF-8 BOM test! 🚀"
        f.write(test_content)
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)
        assert result == test_content
    finally:
        os.unlink(temp_path)


# TODO: Support reading files with Latin-1 encoding
# def test_read_file_with_encoding_latin1():
#     """Test reading Latin-1 encoded file as fallback."""
#     with tempfile.NamedTemporaryFile(mode='w', encoding='latin-1', delete=False) as f:
#         test_content = "Hello, café! Latin-1 test."
#         f.write(test_content)
#         f.flush()
#         temp_path = f.name
#
#     try:
#         result = read_file_with_encoding(temp_path)
#         assert result == test_content
#     finally:
#         os.unlink(temp_path)


def test_read_file_with_encoding_binary_file_fallback():
    """Test reading binary file falls back to latin-1."""
    with tempfile.NamedTemporaryFile(delete=False) as f:
        binary_data = bytes([0xFF, 0xFE, 0x00, 0x48, 0x65, 0x6C, 0x6C, 0x6F])
        f.write(binary_data)
        f.flush()
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)
        assert isinstance(result, str)
        assert len(result) > 0
    finally:
        os.unlink(temp_path)


def test_read_file_with_encoding_special_characters():
    """Test reading file with various special characters."""
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as f:
        test_content = "Special chars: åäö ñ ü ç é\nSymbols: ©®™ §¶†‡•\nMath: ∑∏∫√±≤≥≠\nArrows: ←→↑↓↔\nEmoji: 😀😍🎉🔥💯\n"
        f.write(test_content)
        f.flush()
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)

        assert result == test_content
        assert "åäö" in result
        assert "©®™" in result
        assert "∑∏∫" in result
        assert "😀😍" in result
    finally:
        os.unlink(temp_path)


def test_funccall_genexpr(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test function call with generator expression in both Jac and py2jac."""
    # Test language support
    with capture_stdout() as captured_output:
        Jac.jac_import("funccall_genexpr", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")[0]
    assert "Result: 30" in stdout_value

    # Test py2jac conversion
    py_file_path = f"{fixture_path('funccall_genexpr.py')}"
    with capture_stdout() as captured_output:
        transform.py2jac(py_file_path)
    stdout_value = captured_output.getvalue()
    assert "result = total((x * x) for x in range(5));" in stdout_value


def test_attr_pattern_case(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test attribute pattern matching."""
    with capture_stdout() as captured_output:
        Jac.jac_import("attr_pattern_case", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Matched a.b.c Hello Jaseci!" in stdout_value[0]


def test_switch_case(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test switch-case."""
    with capture_stdout() as captured_output:
        Jac.jac_import("switch_case", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Matched case for value: apple" in stdout_value[0]
    assert "Matched case for value: banana, orange" in stdout_value[1]
    assert "Matched case for value: grape" in stdout_value[2]
    assert "Matched case for value: kiwi" in stdout_value[3]
    assert "Matched case for value: Berry or Cherry" in stdout_value[4]
    assert "No match found for value: banana" in stdout_value[5]
    assert "No match found for value: mango" in stdout_value[6]


def test_safe_call_operator(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test safe call operator."""
    with capture_stdout() as captured_output:
        Jac.jac_import("safe_call_operator", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "None" in stdout_value[0]
    assert "Alice" in stdout_value[1]
    assert "None" in stdout_value[2]
    assert "None" in stdout_value[3]
    assert "3" in stdout_value[4]
    assert "None" in stdout_value[5]
    assert "3" in stdout_value[6]
    assert "None" in stdout_value[7]
    assert "[2, 3]" in stdout_value[8]
    assert "[]" in stdout_value[9]
    assert "None" in stdout_value[10]
    assert "None" in stdout_value[11]


def test_anonymous_ability_execution(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that anonymous abilities execute correctly with synthetic names."""
    with capture_stdout() as captured_output:
        Jac.jac_import("anonymous_ability_test", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()

    # Verify all expected outputs from the anonymous abilities
    assert "Walker root entry executed" in stdout_value
    assert "Walker root exit executed" in stdout_value
    assert "Node entry executed: TestNode" in stdout_value
    assert "Walker visiting node" in stdout_value


def test_escaped_quote_strings(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test strings with escaped quotes are handled correctly."""
    with capture_stdout() as captured_output:
        Jac.jac_import("escaped_quote_strings", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()

    assert 'He said "Hello World"' in stdout_value
    assert 'It\'s a "great" day' in stdout_value
    assert 'She said "Don\'t forget the \\backslash\\"' in stdout_value
    assert "Line 1\nLine 2\tTabbed" in stdout_value
    assert "Path: C:\\Users\\Documents\\file.txt" in stdout_value


def test_by_operator(fixture_path: Callable[[str], str]) -> None:
    """Test 'by' operator raises NotImplementedError."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output
    try:
        result = execution.run(fixture_path("by_operator.jac"))
    finally:
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
    assert result == 1
    stdout_value = captured_output.getvalue()
    assert "by" in stdout_value.lower()
    assert "not" in stdout_value.lower()
    assert "implemented" in stdout_value.lower()
