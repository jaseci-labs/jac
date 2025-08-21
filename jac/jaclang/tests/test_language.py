"""Test Jac language generally."""

import io
import os
import sys
import sysconfig
import tempfile
import subprocess
from pathlib import Path
from unittest.mock import patch

from jaclang import JacMachine as Jac
from jaclang.cli import cli
from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase
from jaclang.runtimelib.utils import read_file_with_encoding


class JacLanguageTests(TestCase):
    """Test pass module."""

    def setUp(self) -> None:
        """Set up test."""
        Jac.reset_machine()
        Jac.set_base_path(self.fixture_abs_path("./"))
        Jac.attach_program(
            JacProgram(),
        )
        return super().setUp()

    def tearDown(self) -> None:
        """Tear down test."""
        Jac.reset_machine()
        return super().tearDown()

    def test_sub_abilities(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        # Execute the function
        cli.run(self.fixture_abs_path("sub_abil_sep.jac"))

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        # Assertions or verifications
        self.assertEqual(
            "Hello, world!\n" "I'm a ninja Myca!\n",
            stdout_value,
        )

    def test_sub_abilities_multi(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        # Execute the function
        cli.run(self.fixture_abs_path("sub_abil_sep_multilev.jac"))  # type: ignore

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        # Assertions or verifications
        self.assertEqual(
            "Hello, world!\n" "I'm a ninja Myca!\n",
            stdout_value,
        )

    def test_simple_jac_red(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            "micro.simple_walk",
            base_path=self.examples_abs_path(""),
            override_name="__main__",
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(
            stdout_value,
            "Value: -1\nValue: 0\nValue: 1\nValue: 2\nValue: 3\nValue: 4"
            "\nValue: 5\nValue: 6\nValue: 7\nFinal Value: 8\nDone walking.\n",
        )

    def test_simple_walk_by_edge(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            "micro.simple_walk_by_edge", base_path=self.examples_abs_path("")
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(
            stdout_value,
            "Visited 1\nVisited 2\n",
        )

    def test_guess_game(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("guess_game", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(
            stdout_value,
            "Too high!\nToo low!\nToo high!\nCongratulations! You guessed correctly.\n",
        )

    def test_printgraph(self) -> None:
        """Test the dot gen of builtin function."""
        import json

        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("builtin_printgraph_json", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        data = json.loads(stdout_value)

        nodes = data["nodes"]
        edges = data["edges"]

        self.assertEqual(len(nodes), 5)
        self.assertEqual(len(edges), 6)

        for node in nodes:
            label = node["label"]
            self.assertIn(label, ["root", "N(val=0)", "N(val=1)"])

        for edge in edges:
            label = edge["label"]
            self.assertIn(label, ["E(val=1)", "E(val=1)", "E(val=1)", "E(val=0)", "E(val=0)", "E(val=0)"])


    def test_printgraph_mermaid(self) -> None:
        """Test the mermaid gen of builtin function."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            "builtin_printgraph_mermaid",
            base_path=self.fixture_abs_path("./"),
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("flowchart LR", stdout_value)

    def test_chandra_bugs(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("chandra_bugs", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(
            stdout_value,
            "<link href='{'new_val': 3, 'where': 'from_foo'}' rel='stylesheet'>\nTrue\n",
        )

    def test_chandra_bugs2(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("chandra_bugs2", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(
            stdout_value,
            "{'apple': None, 'pineapple': None}\n"
            "This is a long\n"
            "        line of code.\n"
            "{'a': 'apple', 'b': 'ball', 'c': 'cat', 'd': 'dog', 'e': 'elephant'}\n",
        )

    def test_ignore(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("ignore_dup", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.split("\n")[0].count("here"), 10)
        self.assertEqual(stdout_value.split("\n")[1].count("here"), 5)

    def test_dataclass_hasability(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("hashcheck_dup", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.count("check"), 2)

    def test_arith_precedence(self) -> None:
        """Basic precedence test."""
        prog = JacProgram().compile(
            use_str="with entry {print(4-5-4);}", file_path="test.jac"
        )
        captured_output = io.StringIO()
        sys.stdout = captured_output
        exec(compile(prog.gen.py_ast[0], "test.py", "exec"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value, "-5\n")

    def test_need_import(self) -> None:
        """Test importing python."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("needs_import", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("<module 'pyfunc' from", stdout_value)

    def test_filter_compr(self) -> None:
        """Testing filter comprehension."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            "reference.special_comprehensions",
            base_path=self.examples_abs_path(""),
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("True", stdout_value)

    def test_gen_dot_bubble(self) -> None:
        """Test the dot gen of nodes and edges of bubblesort."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("gendot_bubble_sort", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn(
            '[label="inner_node(main=5, sub=2)"fillcolor="#FFDEAD"];',
            stdout_value,
        )

    def test_assign_operation(self) -> None:
        """Test assign_compr."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("assign_compr_dup", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(
            "[MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]\n",
            stdout_value,
        )

    def test_raw_bytestr(self) -> None:
        """Test raw string and byte string."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("raw_byte_string", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.count(r"\\\\"), 2)
        self.assertEqual(stdout_value.count("<class 'bytes'>"), 3)

    def test_fstring_multiple_quotation(self) -> None:
        """Test fstring with multiple quotation."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            "compiler/passes/main/tests/fixtures/fstrings",
            base_path=self.fixture_abs_path("../../"),
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.split("\n")[0], "11 13 12 12 11 12 12")
        self.assertEqual(stdout_value.split("\n")[1], '12 12 """hello"""  18 18')
        self.assertEqual(stdout_value.split("\n")[2], "11 12 11 12 11 18 23")
        self.assertEqual(stdout_value.split("\n")[3], 'hello klkl"""')

    def test_deep_imports(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        Jac.jac_import("deep_import", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.split("\n")[0], "one level deeperslHello World!")

    def test_deep_imports_interp_mode(self) -> None:
        """Parse micro jac file."""
        Jac.set_base_path(self.fixture_abs_path("./"))
        Jac.attach_program(
            JacProgram(),
        )
        Jac.jac_import("deep_import_interp", base_path=self.fixture_abs_path("./"))
        self.assertEqual(len(Jac.program.mod.hub.keys()), 1)
        Jac.set_base_path(self.fixture_abs_path("./"))
        Jac.attach_program(
            (prog := JacProgram()),
        )
        prog.build(self.fixture_abs_path("./deep_import_interp.jac"))
        Jac.jac_import("deep_import_interp", base_path=self.fixture_abs_path("./"))
        self.assertEqual(len(Jac.program.mod.hub.keys()), 5)

    def test_deep_imports_mods(self) -> None:
        """Parse micro jac file."""
        Jac.reset_machine()
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
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("deep_import_mods", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = eval(captured_output.getvalue())
        for i in targets:
            self.assertIn(i, stdout_value)

    def test_deep_outer_imports_one(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            "deep.deeper.deep_outer_import",
            base_path=self.fixture_abs_path("./"),
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("one level deeperslHello World!", stdout_value)
        self.assertIn("module 'pyfunc' from ", stdout_value)

    def test_deep_outer_imports_from_loc(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        os.chdir(self.fixture_abs_path("./deep/deeper/"))
        cli.run("deep_outer_import.jac")
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("one level deeperslHello World!", stdout_value)
        self.assertIn("module 'pyfunc' from ", stdout_value)

    def test_has_lambda_goodness(self) -> None:
        """Test has lambda_goodness."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("has_goodness", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.split("\n")[0], "mylist:  [1, 2, 3]")
        self.assertEqual(stdout_value.split("\n")[1], "mydict:  {'a': 2, 'b': 4}")

    def test_conn_assign_on_edges(self) -> None:
        """Test conn assign on edges."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("edge_ops", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("[(3, 5), (14, 1), (5, 1)]", stdout_value)
        self.assertIn("10\n", stdout_value)
        self.assertIn("12\n", stdout_value)

    def test_disconnect(self) -> None:
        """Test conn assign on edges."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("disconn", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("c(cc=0)", stdout_value[0])
        self.assertIn("c(cc=1)", stdout_value[0])
        self.assertIn("c(cc=2)", stdout_value[0])
        self.assertIn("True", stdout_value[2])
        self.assertIn("[]", stdout_value[3])
        self.assertIn(
            "['GenericEdge', 'GenericEdge', 'GenericEdge']",
            stdout_value[5],
        )

    def test_simple_archs(self) -> None:
        """Test conn assign on edges."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("simple_archs", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.split("\n")[0], "1 2 0")
        self.assertEqual(stdout_value.split("\n")[1], "0")

    def test_edge_walk(self) -> None:
        """Test walking through edges."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("edges_walk", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("creator()\n", stdout_value)
        self.assertIn("[node_a(val=12)]\n", stdout_value)
        self.assertIn("node_a(val=1)", stdout_value)
        self.assertIn("node_a(val=2)", stdout_value)
        self.assertIn("[node_a(val=42), node_a(val=42)]\n", stdout_value)

    def test_tuple_of_tuple_assign(self) -> None:
        """Test walking through edges."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("tuplytuples", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn(
            "a apple b banana a apple b banana a apple b banana a apple b banana",
            stdout_value,
        )

    def test_deferred_field(self) -> None:
        """Test walking through edges."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("deferred_field", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn(
            "5 15",
            stdout_value,
        )

    def test_gen_dot_builtin(self) -> None:
        """Test the dot gen of nodes and edges as a builtin."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("builtin_printgraph", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.count("True"), 16)

    def test_with_contexts(self) -> None:
        """Test walking through edges."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("with_context", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("im in", stdout_value)
        self.assertIn("in the middle", stdout_value)
        self.assertIn("im out", stdout_value)
        self.assertIn(
            "{'apple': [1, 2, 3], 'banana': [1, 2, 3], 'cherry': [1, 2, 3]}",
            stdout_value,
        )

    def test_typed_filter_compr(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("micro.typed_filter_compr", base_path=self.examples_abs_path(""))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn(
            "[MyObj(a=0), MyObj2(a=2), MyObj(a=1), "
            "MyObj2(a=3), MyObj(a=2), MyObj(a=3)]\n",
            stdout_value,
        )
        self.assertIn("[MyObj(a=0), MyObj(a=1), MyObj(a=2)]\n", stdout_value)

    def test_edge_node_walk(self) -> None:
        """Test walking through edges and nodes."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("edge_node_walk", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("creator()\n", stdout_value)
        self.assertIn("[node_a(val=12)]\n", stdout_value)
        self.assertIn("node_a(val=1)", stdout_value)
        self.assertIn("node_a(val=2)", stdout_value)
        self.assertIn("[node_b(val=42), node_b(val=42)]\n", stdout_value)

    def test_annotation_tuple_issue(self) -> None:
        """Test conn assign on edges."""
        mypass = JacProgram().compile(self.fixture_abs_path("./slice_vals.jac"))
        self.assertIn("Annotated[Str, INT, BLAH]", mypass.gen.py)
        self.assertIn("tuple[int, Optional[type], Optional[tuple]]", mypass.gen.py)

    def test_enum_inside_arch(self) -> None:
        """Test Enum as member stmt."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("enum_inside_archtype", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("2 Accessing privileged Data", stdout_value)

    def test_pyfunc_1(self) -> None:
        """Test py ast to Jac ast conversion."""
        from jaclang.compiler.passes.main import PyastBuildPass
        import jaclang.compiler.unitree as uni
        import ast as py_ast

        py_out_path = os.path.join(self.fixture_abs_path("./"), "pyfunc_1.py")
        with open(py_out_path) as f:
            file_source = f.read()
            output = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    py_ast.parse(file_source),
                    orig_src=uni.Source(file_source, py_out_path),
                ),
                prog=JacProgram(),
            ).ir_out.unparse()
        self.assertIn("def greet2(**kwargs: Any)", output)
        self.assertEqual(output.count("with entry {"), 14)
        self.assertIn("assert (x == 5) , 'x should be equal to 5' ;", output)
        self.assertIn("if not (x == y) {", output)
        self.assertIn("def greet2(**kwargs: Any) {", output)
        self.assertIn("squares_dict = { x : (x ** 2) for x in numbers };", output)
        self.assertIn(
            '\n\n"""Say hello"""\n@ my_decorator\n\n def say_hello() {', output
        )

    def test_pyfunc_2(self) -> None:
        """Test py ast to Jac ast conversion."""
        from jaclang.compiler.passes.main import PyastBuildPass
        import jaclang.compiler.unitree as uni
        import ast as py_ast

        py_out_path = os.path.join(self.fixture_abs_path("./"), "pyfunc_2.py")
        with open(py_out_path) as f:
            file_source = f.read()
            output = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    py_ast.parse(file_source),
                    orig_src=uni.Source(file_source, py_out_path),
                ),
                prog=JacProgram(),
            ).ir_out.unparse()
        self.assertIn("class X {\n    with entry {\n        a_b = 67;", output)
        self.assertIn("br = b'Hello\\\\\\\\nWorld'", output)
        self.assertIn(
            "class Circle {\n    def init(self: Circle, radius: float", output
        )
        self.assertIn("<>node = 90;\n    print(<>node);\n", output)

    def test_pyfunc_3(self) -> None:
        """Test py ast to Jac ast conversion."""
        from jaclang.compiler.passes.main import PyastBuildPass
        import jaclang.compiler.unitree as uni
        import ast as py_ast

        py_out_path = os.path.join(self.fixture_abs_path("./"), "pyfunc_3.py")
        with open(py_out_path) as f:
            file_source = f.read()
            output = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    py_ast.parse(file_source),
                    orig_src=uni.Source(file_source, py_out_path),
                ),
                prog=JacProgram(),
            ).ir_out.unparse()
        self.assertIn("if (0 <= x <= 5) {", output)
        self.assertIn("  case _:\n", output)
        self.assertIn(" case Point(x = int(a), y = 0):\n", output)
        self.assertIn("class Sample {\n    def init", output)

    def test_py2jac(self) -> None:
        """Test py ast to Jac ast conversion."""
        from jaclang.compiler.passes.main import PyastBuildPass
        import jaclang.compiler.unitree as ast
        import ast as py_ast

        py_out_path = os.path.join(self.fixture_abs_path("./"), "py2jac.py")
        with open(py_out_path) as f:
            file_source = f.read()
            output = PyastBuildPass(
                ir_in=ast.PythonModuleAst(
                    py_ast.parse(file_source),
                    orig_src=ast.Source(file_source, py_out_path),
                ),
                prog=None,
            ).ir_out.unparse()
        self.assertIn("match Container(inner=Inner(x=a, y=b)) {\n", output)
        self.assertIn("case Container(inner = Inner(x = a, y = 0)):\n", output)
        self.assertIn("case Container(inner = Inner(x = a, y = b)):\n", output)
        self.assertIn("case _:\n", output)

    def test_refs_target(self) -> None:
        """Test py ast to Jac ast conversion output."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("refs_target", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("[c(val=0), c(val=1), c(val=2)]", stdout_value)
        self.assertIn("[c(val=0)]", stdout_value)

    def test_py_kw_as_name_disallowed(self) -> None:
        """Basic precedence test."""
        (prog := JacProgram()).compile(
            use_str="with entry {print.is.not.True(4-5-4);}", file_path="test.jac"
        )
        self.assertIn("Python keyword is used as name", str(prog.errors_had[0].msg))

    def test_double_format_issue(self) -> None:
        """Basic precedence test."""
        prog = JacProgram().compile("with entry {print(hello);}", "test.jac")
        prog.unparse()
        before = prog.format()
        prog.format()
        prog.format()
        after = prog.format()
        self.assertEqual(before, after)

    def test_inherit_check(self) -> None:
        """Test py ast to Jac ast conversion output."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("inherit_check", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual("I am in b\nI am in b\nwww is also in b\n", stdout_value)

    def test_tuple_unpack(self) -> None:
        """Test tuple unpack."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("tupleunpack", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("1", stdout_value[0])
        self.assertIn("[2, 3, 4]", stdout_value[1])

    def test_trailing_comma(self) -> None:
        """Test trailing comma."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("trailing_comma", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Code compiled and ran successfully!", stdout_value)

    def test_try_finally(self) -> None:
        """Test try finally."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("try_finally", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("try block", stdout_value[0])
        self.assertIn("finally block", stdout_value[1])
        self.assertIn("try block", stdout_value[2])
        self.assertIn("else block", stdout_value[3])
        self.assertIn("finally block", stdout_value[4])

    def test_arithmetic_bug(self) -> None:
        """Test arithmetic bug."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("arithmetic_bug", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertEqual("0.0625", stdout_value[0])
        self.assertEqual("1e-06", stdout_value[1])
        self.assertEqual("1000.000001", stdout_value[2])
        self.assertEqual("78", stdout_value[3])
        self.assertEqual("12", stdout_value[4])

    def test_lambda_expr(self) -> None:
        """Test lambda expr."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("lambda", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertEqual("9", stdout_value[0])
        self.assertEqual("567", stdout_value[1])

    def test_override_walker_inherit(self) -> None:
        """Test py ast to Jac ast conversion output."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("walker_override", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual("baz\nbar\n", stdout_value)

    def test_self_with_no_sig(self) -> None:  # we can get rid of this, isn't?
        """Test py ast to Jac ast conversion output."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("nosigself", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.count("5"), 2)

    def test_hash_init_check(self) -> None:  # we can get rid of this, isn't?
        """Test py ast to Jac ast conversion output."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("hash_init_check", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Test Passed", stdout_value)

    def test_multiline_single_tok(self) -> None:
        """Test conn assign on edges."""
        mypass = JacProgram().compile(self.fixture_abs_path("byllmissue.jac"))
        self.assertIn("2:5 - 4:8", mypass.pp())

    def test_inherit_baseclass_sym(self) -> None:
        """Basic test for symtable support for inheritance."""
        mypass = JacProgram().compile(
            self.examples_abs_path("guess_game/guess_game3.jac")
        )
        table = None
        for i in mypass.sym_tab.kid_scope:
            if i.scope_name == "GuessTheNumberGame":
                for j in i.kid_scope:
                    if j.scope_name == "play":
                        table = j
                        break
                break
        self.assertIsNotNone(table)
        self.assertIsNotNone(table.lookup("attempts"))

    def test_edge_expr_not_type(self) -> None:
        """Test importing python."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("edgetypeissue", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("[x()]", stdout_value)

    def test_blank_with_entry(self) -> None:
        """Test importing python."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("blankwithentry", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("i work", stdout_value)

    def test_double_import_exec(self) -> None:
        """Test importing python."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("dblhello", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.count("Hello World!"), 1)
        self.assertIn("im still here", stdout_value)

    def test_cls_method(self) -> None:
        """Test class method output."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("cls_method", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertEqual("MyClass", stdout_value[0])
        self.assertEqual("Hello, World1! Hello, World2!", stdout_value[1])
        self.assertEqual("Hello, World! Hello, World22!", stdout_value[2])

    def test_list_methods(self) -> None:
        """Test list_modules, list_walkers, list_nodes, and list_edges."""
        Jac.reset_machine()
        Jac.set_base_path(self.fixture_abs_path("."))
        sys.modules.pop("foo", None)
        sys.modules.pop("bar", None)
        captured_output = io.StringIO()
        sys.stdout = captured_output

        Jac.jac_import("foo", base_path=self.fixture_abs_path("."))

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        self.assertIn(
            "Module: foo",
            stdout_value,
        )
        self.assertIn(
            "Module: bar",
            stdout_value,
        )
        self.assertIn(
            "Walkers in bar:\n  - Walker: bar_walk",
            stdout_value,
        )
        self.assertIn("Nodes in bar:\n  - Node: Item", stdout_value)
        self.assertIn("Edges in bar:\n  - Edge: Link", stdout_value)
        self.assertIn("Item value: 0", stdout_value)
        self.assertIn("Created 5 items.", stdout_value)

    def test_walker_dynamic_update(self) -> None:
        """Test dynamic update of a walker during runtime."""
        Jac.reset_machine()
        Jac.set_base_path(self.fixture_abs_path("."))
        sys.modules.pop("bar", None)
        session = self.fixture_abs_path("bar_walk.session")
        bar_file_path = self.fixture_abs_path("bar.jac")
        update_file_path = self.fixture_abs_path("walker_update.jac")
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.enter(
            filename=bar_file_path,
            session=session,
            entrypoint="bar_walk",
            args=[],
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        os.remove(session) if os.path.exists(session) else None
        expected_output = "Created 5 items."
        self.assertIn(expected_output, stdout_value.split("\n"))
        # Define the new behavior to be added
        new_behavior = """
        # New behavior added during runtime
        can end with `root exit {
            "bar_walk has been updated with new behavior!" |> print;
            disengage;
            }
        }
        """

        # Backup the original file content
        with open(bar_file_path, "r") as bar_file:
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

        captured_output = io.StringIO()
        sys.stdout = captured_output

        try:
            cli.run(
                filename=update_file_path,
            )
            sys.stdout = sys.__stdout__
            stdout_value = captured_output.getvalue()
            expected_output = "bar_walk has been updated with new behavior!"
            self.assertIn(expected_output, stdout_value.split("\n"))
        finally:
            # Restore the original content of bar.jac
            with open(bar_file_path, "w") as bar_file:
                bar_file.write(original_content)

    def test_dynamic_spawn_archetype(self) -> None:
        """Test that the walker and node can be spawned and behaves as expected."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("dynamic_archetype.jac"))

        output = captured_output.getvalue().strip()
        output_lines = output.split("\n")

        # Expected outputs for spawned entities
        expected_spawned_node = "Spawned Node:"
        expected_spawned_walker = "Spawned Walker:"
        expected_spawned_external_node = "Spawned External node:"

        # Check for the spawned messages
        self.assertTrue(
            any(expected_spawned_node in line for line in output_lines),
            f"Expected '{expected_spawned_node}' in output.",
        )
        self.assertTrue(
            any(expected_spawned_walker in line for line in output_lines),
            f"Expected '{expected_spawned_walker}' in output.",
        )
        self.assertTrue(
            any(expected_spawned_external_node in line for line in output_lines),
            f"Expected '{expected_spawned_external_node}' in output.",
        )

        # Expected values from the walker traversal
        expected_values = ["Value: 0", "Value: 1", "Value: 2", "Value: 3"]

        # Each expected value should appear twice (once for test_node, once for Item)
        for val in expected_values:
            occurrences = [line for line in output_lines if line.strip() == val]
            self.assertEqual(
                len(occurrences),
                2,
                f"Expected '{val}' to appear 2 times, but found {len(occurrences)}.",
            )

    def test_dynamic_archetype_creation(self) -> None:
        """Test that the walker and node can be created dynamically."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("create_dynamic_archetype.jac"))

        output = captured_output.getvalue().strip()
        # Expected outputs for spawned entities
        expected_spawned_walker = "Dynamic Node Value: 99"

        # Check for the spawned messages
        self.assertTrue(
            expected_spawned_walker in output,
            f"Expected '{expected_spawned_walker}' in output.",
        )

    def test_dynamic_archetype_creation_rel_import(self) -> None:
        """Test that the walker and node can be created dynamically, with relative import."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("arch_rel_import_creation.jac"))

        output = captured_output.getvalue().strip().splitlines()
        # Expected outputs for spawned entities
        expected_values = ["DynamicWalker Started", "UtilityNode Data: 42"]
        for val in expected_values:
            # Check for the spawned messages
            self.assertTrue(
                val in output,
                f"Expected '{val}' in output.",
            )

    def test_object_ref_interface(self) -> None:
        """Test class method output."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("objref.jac"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertEqual(len(stdout_value[0]), 32)
        self.assertEqual("MyNode(value=0)", stdout_value[1])
        self.assertEqual("valid: True", stdout_value[2])

    def test_match_multi_ex(self) -> None:
        """Test match case with multiple expressions."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("match_multi_ex", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertEqual("Ten", stdout_value[0])
        self.assertEqual("ten", stdout_value[1])

    def test_entry_exit(self) -> None:
        """Test entry and exit behavior of walker."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("entry_exit", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("Entering at the beginning of walker:  Root()", stdout_value[0])
        self.assertIn("entry_count=1, exit_count=1", str(stdout_value[12]))
        self.assertIn(
            "Exiting at the end of walker:  test_node(value=", stdout_value[11]
        )

    def test_visit_order(self) -> None:
        """Test entry and exit behavior of walker."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("visit_order", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual("[MyNode(Name='End'), MyNode(Name='Middle')]\n", stdout_value)

    def test_global_multivar(self) -> None:
        """Test supporting multiple global variable in a statement."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("glob_multivar_statement", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("Hello World !", stdout_value[0])
        self.assertIn("Welcome to Jaseci!", stdout_value[1])

    def test_archetype_def(self) -> None:
        """Test archetype definition bug."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("archetype_def_bug", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("MyWalker", stdout_value[0])
        self.assertIn("MyNode", stdout_value[1])

    def test_visit_sequence(self) -> None:
        """Test conn assign on edges."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("visit_sequence", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        self.assertEqual(
            "walker entry\nwalker enter to root\n"
            "a-1\na-2\na-3\na-4\na-5\na-6\n"
            "b-1\nb-2\nb-3\nb-4\nb-5\nb-6\n"
            "c-1\nc-2\nc-3\nc-4\nc-5\nc-6\n"
            "walker exit\n",
            captured_output.getvalue(),
        )

    def test_connect_traverse_syntax(self) -> None:
        """Test connect traverse syntax."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("connect_traverse_syntax", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("A(val=5), A(val=10)", stdout_value[0])
        self.assertIn("[Root(), A(val=20)]", stdout_value[1])
        self.assertIn(
            "A(val=5), A(val=10)", stdout_value[2]
        )  # Remove after dropping deprecated syntax support
        self.assertIn(
            "[Root(), A(val=20)]", stdout_value[3]
        )  # Remove after dropping deprecated syntax support

    def test_node_del(self) -> None:
        """Test complex nested impls."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("node_del", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("0 : [2, 3, 4, 5, 6, 7, 8, 9, 10]", stdout_value[0])
        self.assertIn("7, 8 : [2, 3, 4, 5, 6, 7, 9]", stdout_value[1])
        self.assertIn("before delete : Inner(c=[1, 2, 3], d=4)", stdout_value[2])
        self.assertIn("after delete : Inner(c=[1, 3], d=4)", stdout_value[3])

    # Helper method to create files within tests
    def create_temp_jac_file(
        self, content: str, dir_path: str, filename: str = "test_mod.jac"
    ) -> str:
        """Create a temporary Jac file in a specific directory."""
        full_path = os.path.join(dir_path, filename)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, "w") as f:
            f.write(content)
        return full_path

    def test_import_from_site_packages(self) -> None:
        """Test importing a Jac module from simulated site-packages."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Simulate site-packages directory structure
            mock_site_dir = os.path.join(tmpdir, "site-packages")
            os.makedirs(mock_site_dir)

            # Create a module within the simulated site-packages
            site_mod_content = 'with entry { "Site package module loaded!" |> print; }'
            self.create_temp_jac_file(
                site_mod_content, mock_site_dir, "site_pkg_mod.jac"
            )

            # Create the importing script in the main temp directory
            importer_content = "import site_pkg_mod;"
            _ = self.create_temp_jac_file(importer_content, tmpdir, "importer_site.jac")
            with patch("site.getsitepackages", return_value=[mock_site_dir]):
                captured_output = io.StringIO()
                sys.stdout = captured_output
                original_cwd = os.getcwd()
                try:
                    Jac.jac_import("importer_site", base_path=tmpdir)
                finally:
                    os.chdir(original_cwd)
                    sys.stdout = sys.__stdout__

                stdout_value = captured_output.getvalue()
                self.assertIn("Site package module loaded!", stdout_value)

    def test_import_from_jacpath(self) -> None:
        """Test importing a Jac module from JACPATH."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Simulate JACPATH directory
            jacpath_dir = os.path.join(tmpdir, "jaclibs")
            os.makedirs(jacpath_dir)

            # Create a module in the JACPATH directory
            jacpath_mod_content = 'with entry { "JACPATH module loaded!" |> print; }'
            self.create_temp_jac_file(
                jacpath_mod_content, jacpath_dir, "jacpath_mod.jac"
            )

            # Create the importing script in a different location
            script_dir = os.path.join(tmpdir, "scripts")
            os.makedirs(script_dir)
            importer_content = "import jacpath_mod;"
            _ = self.create_temp_jac_file(importer_content, script_dir, "importer.jac")

            # Set JACPATH environment variable and run
            original_jacpath = os.environ.get("JACPATH")
            os.environ["JACPATH"] = jacpath_dir
            captured_output = io.StringIO()
            sys.stdout = captured_output
            original_cwd = os.getcwd()
            os.chdir(script_dir)
            try:
                cli.run("importer.jac")
            finally:
                os.chdir(original_cwd)
                sys.stdout = sys.__stdout__
                # Clean up environment variable
                if original_jacpath is None:
                    if "JACPATH" in os.environ:
                        del os.environ["JACPATH"]
                else:
                    os.environ["JACPATH"] = original_jacpath

            stdout_value = captured_output.getvalue()
            self.assertIn("JACPATH module loaded!", stdout_value)

    def test_obj_hasvar_initialization(self) -> None:
        """Basic test for pass."""
        (out := JacProgram()).compile(
            self.fixture_abs_path("uninitialized_hasvars.jac")
        )
        self.assertTrue(out.errors_had)

        expected_stdout_values = (
            "Non default attribute 'var3' follows default attribute",
            "    4 |     has var1: int;",
            "    5 |     has var2: int = 42;",
            "    6 |     has var3: int; # <-- This should be syntax error.",
            "      |         ^^^^",
            "    7 | }",
            'Missing "postinit" method required by un initialized attribute(s).',
            "   11 | obj Test2 {",
            "   12 |     has var1: str;",
            "   13 |     has var2: int by postinit;",
            "      |         ^^^^",
            "   14 | }",
            "Non default attribute 'var4' follows default attribute",
            "   19 |     has var2: int = 42;",
            "   20 |     has var3: int by postinit;  # <-- This is fine.",
            "   21 |     has var4: int;  # <-- This should be syntax error.",
            "      |         ^^^^",
            "   22 |",
            "   23 |     def postinit() {",
        )

        errors_output = ""
        for error in out.errors_had:
            errors_output += error.pretty_print() + "\n"

        for exp in expected_stdout_values:
            self.assertIn(exp, errors_output)

    def test_async_walker(self) -> None:
        """Test async walker."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("async_walker", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("Let's start the task", stdout_value[0])
        self.assertIn("It is Coroutine task True", stdout_value[1])
        self.assertIn("Coroutine task is completed", stdout_value[6])

    def test_async_function(self) -> None:
        """Test async ability."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("async_function", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("Hello", stdout_value[0])
        self.assertIn("Hello", stdout_value[1])
        self.assertIn("World!", stdout_value[2])

    def test_concurrency(self) -> None:
        """Test concurrency in jaclang."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("concurrency", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("Started", stdout_value[0])
        self.assertIn("B(name='Hi')", stdout_value[8])
        self.assertIn("11", stdout_value[9])
        self.assertIn("13", stdout_value[10])

    def test_import_jac_from_py(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        from .fixtures import jac_from_py

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(
            stdout_value,
            "Value: -1\nValue: 0\nValue: 1\nValue: 2\nValue: 3\nValue: 4"
            "\nValue: 5\nValue: 6\nValue: 7\nFinal Value: 8\nDone walking.\n",
        )

    def test_py_namedexpr(self) -> None:
        """Ensure NamedExpr nodes are converted to AtomUnit."""
        from jaclang.compiler.passes.main import PyastBuildPass
        import jaclang.compiler.unitree as uni
        import ast as py_ast

        py_out_path = os.path.join(self.fixture_abs_path("./"), "py_namedexpr.py")
        with open(py_out_path) as f:
            file_source = f.read()
            output = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    py_ast.parse(file_source),
                    orig_src=uni.Source(file_source, py_out_path),
                ),
                prog=JacProgram(),
            ).ir_out.unparse()
        self.assertIn("(x := 10)", output)

    def test_py_bool_parentheses(self) -> None:
        """Ensure boolean expressions preserve parentheses during conversion."""
        from jaclang.compiler.passes.main import PyastBuildPass
        import jaclang.compiler.unitree as uni
        import ast as py_ast

        py_out_path = os.path.join(self.fixture_abs_path("./"), "py_bool_expr.py")
        with open(py_out_path) as f:
            file_source = f.read()
            output = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    py_ast.parse(file_source),
                    orig_src=uni.Source(file_source, py_out_path),
                ),
                prog=JacProgram(),
            ).ir_out.unparse()
        self.assertIn("(prev_token_index is None)", output)
        self.assertIn("(next_token_index is None)", output)
        self.assertIn("(tok[ 0 ] > change_end_line)", output)
        self.assertIn("(tok[ 0 ] == change_end_line)", output)
        self.assertIn("(tok[ 1 ] > change_end_char)", output)

    def test_here_visitor_usage(self) -> None:
        """Test visitor, here keyword usage in jaclang."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("here_visitor_usage", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("Here value is  10", stdout_value[0])
        self.assertIn("Visitor name is  Walker 1", stdout_value[1])

    def test_here_visitor_error(self) -> None:
        """Test visitor, here keyword usage in jaclang."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        sys.stderr = captured_output
        cli.run(self.fixture_abs_path("here_usage_error.jac"))
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
        stdout_value = captured_output.getvalue()
        self.assertIn("'here' is not defined", stdout_value)

    def test_edge_ability(self) -> None:
        """Test visitor, here keyword usage in jaclang."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("edge_ability.jac"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("MyEdge from walker MyEdge(path=1)", stdout_value[0])
        self.assertIn("MyWalker from edge MyWalker()", stdout_value[1])
        self.assertIn("MyWalker from node MyWalker()", stdout_value[6])
        self.assertIn("MyEdge from walker MyEdge(path=2)", stdout_value[16])

    def test_backward_edge_visit(self) -> None:
        """Test backward edge visit in jaclang."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("backward_edge_visit.jac"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("MyWalker() from node MyNode(val=0)", stdout_value[0])
        self.assertIn("MyWalker() from edge MyEdge(path=0)", stdout_value[1])
        self.assertIn("MyWalker() from edge MyEdge(path=3)", stdout_value[6])
        self.assertIn("MyWalker() from node MyNode(val=40)", stdout_value[9])

    def test_visit_traversal(self) -> None:
        """Test visit traversal semantic in jaclang."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("visit_traversal.jac"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("MyWalker() from node MyNode(val=0)", stdout_value[0])
        self.assertIn("MyWalker() from node MyNode(val=20)", stdout_value[2])
        self.assertIn("MyWalker() from node MyNode(val=60)", stdout_value[4])
        self.assertIn("MyWalker() from node MyNode(val=40)", stdout_value[6])
        self.assertIn("MyWalker() from node MyNode(val=90)", stdout_value[7])
        self.assertIn("MyWalker() from node MyNode(val=70)", stdout_value[9])

    def test_async_ability(self) -> None:
        """Test async ability."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("async_ability", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("Let's start the task", stdout_value[0])
        self.assertIn("It is Coroutine task True", stdout_value[1])
        self.assertIn("I am here man MyNode(val=5)", stdout_value[2])
        self.assertIn("Async function", stdout_value[3])
        self.assertIn("foo3", stdout_value[4])
        self.assertIn("foo1", stdout_value[5])
        self.assertIn("foo2", stdout_value[6])
        self.assertIn("Coroutine task is completed", stdout_value[17])

    def test_unicode_string_literals(self) -> None:
        """Test unicode characters in string literals are preserved correctly."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("unicode_strings", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("1. ✓ 1st (due: True)", stdout_value[0])
        self.assertIn("🌟 Star", stdout_value[2])
        self.assertIn("Multi-line with ✓ unicode and ○ symbols", stdout_value[3])
        self.assertIn("Raw string with ✓ and ○", stdout_value[4])
        self.assertIn("Tab ✓", stdout_value[5])
        self.assertIn("Newline ○", stdout_value[6])

    def test_sitecustomize_meta_importer(self) -> None:
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
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(proc.stdout.strip(), "via meta")

    def test_spawn_loc_list(self) -> None:
        """Test spawning a walker on list of nodes."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("spawn_loc_list", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("I am here MyNode(val=5)", stdout_value[0])
        self.assertIn("I am here MyNode(val=15)", stdout_value[2])
        self.assertIn("I am here MyNode(val=20)", stdout_value[3])
        self.assertIn("I am here MyEdge(val=100)", stdout_value[5])
        self.assertIn("I am here MyNode(val=30)", stdout_value[6])

    def test_while_else(self) -> None:
        """Test else part in while loop."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import("while_else", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().split("\n")
        self.assertIn("Num:  4", stdout_value[0])
        self.assertIn("Num:  3", stdout_value[1])
        self.assertIn("Completed", stdout_value[2])

    def test_read_file_with_encoding_utf8(self) -> None:
        """Test reading UTF-8 encoded file."""
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', delete=False) as f:
            test_content = "Hello, 世界! 🌍 Testing UTF-8 encoding."
            f.write(test_content)
            temp_path = f.name
        
        try:
            result = read_file_with_encoding(temp_path)
            self.assertEqual(result, test_content)
        finally:
            os.unlink(temp_path)

    def test_read_file_with_encoding_utf16(self) -> None:
        """Test reading UTF-16 encoded file when UTF-8 fails."""
        with tempfile.NamedTemporaryFile(delete=False, mode="w", encoding="utf-16") as f:
            test_content = "Hello, 世界! UTF-16 encoding test."
            f.write(test_content)
            temp_path = f.name
        
        try:
            result = read_file_with_encoding(temp_path)
            self.assertEqual(result, test_content)
        finally:
            os.unlink(temp_path)

    def test_read_file_with_encoding_utf8_bom(self) -> None:
        """Test reading UTF-8 with BOM encoded file."""
        with tempfile.NamedTemporaryFile(delete=False, mode='w', encoding='utf-8-sig') as f:
            test_content = "Hello, UTF-8 BOM test! 🚀"
            f.write(test_content)
            temp_path = f.name
        
        try:
            result = read_file_with_encoding(temp_path)
            self.assertEqual(result, test_content)
        finally:
            os.unlink(temp_path)

    # TODO: Support reading files with Latin-1 encoding
    # def test_read_file_with_encoding_latin1(self) -> None:
    #     """Test reading Latin-1 encoded file as fallback."""
    #     with tempfile.NamedTemporaryFile(mode='w', encoding='latin-1', delete=False) as f:
    #         test_content = "Hello, café! Latin-1 test."
    #         f.write(test_content)
    #         f.flush()
    #         temp_path = f.name

    #     try:
    #         result = read_file_with_encoding(temp_path)
    #         self.assertEqual(result, test_content)
    #     finally:
    #         os.unlink(temp_path)

    def test_read_file_with_encoding_binary_file_fallback(self) -> None:
        """Test reading binary file falls back to latin-1."""
        with tempfile.NamedTemporaryFile(delete=False) as f:
            binary_data = bytes([0xFF, 0xFE, 0x00, 0x48, 0x65, 0x6C, 0x6C, 0x6F])
            f.write(binary_data)
            f.flush()  
            temp_path = f.name
        
        try:
            result = read_file_with_encoding(temp_path)
            self.assertIsInstance(result, str)
            self.assertGreater(len(result), 0)
        finally:
            os.unlink(temp_path)

    def test_read_file_with_encoding_special_characters(self) -> None:
        """Test reading file with various special characters."""
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', delete=False) as f:
            test_content = (
                "Special chars: åäö ñ ü ç é\n"
                "Symbols: ©®™ §¶†‡•\n" 
                "Math: ∑∏∫√±≤≥≠\n"
                "Arrows: ←→↑↓↔\n"
                "Emoji: 😀😍🎉🔥💯\n"
            )
            f.write(test_content)
            f.flush()  
            temp_path = f.name
        
        try:
            result = read_file_with_encoding(temp_path)

            self.assertEqual(result, test_content)
            self.assertIn("åäö", result)
            self.assertIn("©®™", result)
            self.assertIn("∑∏∫", result)
            self.assertIn("😀😍", result)
        finally:
            os.unlink(temp_path)