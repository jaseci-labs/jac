"""Test Jac language generally."""

import io
import os
import sys
import unittest
import sysconfig
import tempfile
from unittest.mock import patch

from jaclang import JacMachineInterface as Jac, JacMachine
from jaclang.cli import cli
from jaclang.compiler.program import JacProgram
from jaclang.utils.lang_tools import AstTool
from jaclang.utils.test import TestCase


@unittest.skip("Skipping typecheck tests")
class JacTypeCheckTests(TestCase):
    """Test pass module."""

    def setUp(self) -> None:
        """Set up test."""
        self.mach = JacMachine(self.fixture_abs_path("./"))
        Jac.attach_program(
            self.mach,
            JacProgram(),
        )
        return super().setUp()

    def tearDown(self) -> None:
        """Tear down test."""
        return super().tearDown()

    def test_multi_dim_arr_slice(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.tool(
            "ir",
            [
                "ast",
                self.fixture_abs_path("multi_dim_array_split.jac"),
            ],
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        expected_outputs = [
            "+-- AtomTrailer - Type: builtins.list[builtins.int]",
            "    +-- Name - arr - Type: builtins.list[builtins.list[builtins.int]],  SymbolTable: list",
            "+-- IndexSlice - [IndexSlice] - Type: builtins.list[builtins.list[builtins.int]],  SymbolTable: None",
            "        +-- Token - [, ",
            "        +-- Int - 1 - Type: Literal[1]?,  SymbolTable: None",
            "        +-- Token - :, ",
            "        +-- Int - 3 - Type: Literal[3]?,  SymbolTable: None",
            "        +-- Token - ,, ",
            "        +-- Int - 1 - Type: Literal[1]?,  SymbolTable: None",
            "        +-- Token - :, ",
            "        +-- Token - :, ",
            "        +-- Int - 2 - Type: Literal[2]?,  SymbolTable: None",
            "        +-- Token - ], ",
        ]

        for expected in expected_outputs:
            self.assertIn(expected, stdout_value)

    def test_needs_import_1(self) -> None:
        """Test py ast to Jac ast conversion output."""
        file_name = self.fixture_abs_path("pyfunc_1.py")

        from jaclang.compiler.passes.main.pyast_load_pass import PyastBuildPass
        import ast as py_ast
        import jaclang.compiler.unitree as uni

        with open(file_name, "r") as f:
            file_source = f.read()
            parsed_ast = py_ast.parse(file_source)
            try:
                py_ast_build_pass = PyastBuildPass(
                    ir_in=uni.PythonModuleAst(
                        parsed_ast, orig_src=uni.Source(file_source, file_name)
                    ),
                    prog=JacProgram(),
                ).ir_out
            except Exception as e:
                return f"Error While Jac to Py AST conversion: {e}"

        (prog := JacProgram()).build(
            use_str=py_ast_build_pass.unparse(),
            file_path=file_name[:-3] + ".jac",
        )

        archetype_count = 0
        for mod in prog.mod.hub.values():
            if mod.name == "builtins":
                continue
            archetype_count += len(mod.get_all_sub_nodes(uni.Archetype))

        self.assertEqual(archetype_count, 24)
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            self.mach, "needs_import_1", base_path=self.fixture_abs_path("./")
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("pyfunc_1 imported", stdout_value)

    def test_needs_import_2(self) -> None:
        """Test py ast to Jac ast conversion output."""
        file_name = self.fixture_abs_path("pyfunc_2.py")

        from jaclang.compiler.passes.main.pyast_load_pass import PyastBuildPass
        import ast as py_ast
        import jaclang.compiler.unitree as uni

        with open(file_name, "r") as f:
            file_source = f.read()
            parsed_ast = py_ast.parse(file_source)
            try:
                py_ast_build_pass = PyastBuildPass(
                    ir_in=uni.PythonModuleAst(
                        parsed_ast,
                        orig_src=uni.Source(file_source, file_name),
                    ),
                    prog=JacProgram(),
                ).ir_out
            except Exception as e:
                return f"Error While Jac to Py AST conversion: {e}"

            (prog := JacProgram()).build(
                use_str=py_ast_build_pass.unparse(),
                file_path=file_name[:-3] + ".jac",
            )

        archetype_count = 0
        for mod in prog.mod.hub.values():
            if mod.name == "builtins":
                continue
            archetype_count += len(mod.get_all_sub_nodes(uni.Archetype))

        self.assertEqual(archetype_count, 30)  # Because of the Archetype from math
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            self.mach, "needs_import_2", base_path=self.fixture_abs_path("./")
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("pyfunc_2 imported", stdout_value)
        self.assertEqual(stdout_value.count("<class 'bytes'>"), 3)

    def test_needs_import_3(
        self,
    ) -> None:  # TODO : Pyfunc_3 has a bug in conversion in matchmapping node
        """Test py ast to Jac ast conversion output."""
        file_name = self.fixture_abs_path("pyfunc_3.py")
        import jaclang.compiler.unitree as uni

        with open(file_name, "r") as f:
            file_source = f.read()
        (prog := JacProgram()).build(use_str=file_source, file_path=file_name)

        archetype_count = sum(
            len(mod.get_all_sub_nodes(uni.Archetype))
            for mod in prog.mod.hub.values()
            if mod.name != "builtins"
        )
        self.assertEqual(
            archetype_count, 58
        )  # Fixed duplication of 'case' module (previously included 3 times, added 20 extra Archetypes; 75 → 55)
        builtin_mod = next(
            (mod for name, mod in prog.mod.hub.items() if "builtins" in name),
            None,
        )
        self.assertEqual(len(builtin_mod.get_all_sub_nodes(uni.Archetype)), 109)
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(
            self.mach, "needs_import_3", base_path=self.fixture_abs_path("./")
        )
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("pyfunc_3 imported", stdout_value)

    def test_type_fuse_expr(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.tool(
            "ir",
            [
                "ast",
                self.examples_abs_path("reference/collection_values.jac"),
            ],
        )

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn(
            "builtins.dict[builtins.int, builtins.int]",
            stdout_value,
        )
        self.assertIn(
            "typing.Generator[builtins.int, None, None]",
            stdout_value,
        )

    def test_random_check(self) -> None:
        """Test py ast to Jac ast conversion output."""
        from jaclang.settings import settings

        module_paths = ["random", "ast"]
        for module_path in module_paths:
            stdlib_dir = sysconfig.get_paths()["stdlib"]
            file_path = os.path.join(
                stdlib_dir,
                module_path + ".py",
            )
            settings.print_py_raised_ast = True
            with open(file_path) as f:
                file_source = f.read()
            ir = JacProgram().build(
                use_str=file_source,
                file_path=file_path,
            )
            gen_ast = ir.pp()
            if module_path == "random":
                self.assertIn("ModulePath - statistics -", gen_ast)
            else:
                self.assertIn("+-- Name - NodeTransformer - Type: No", gen_ast)

    def test_deep_convert(self) -> None:
        """Test py ast to Jac ast conversion output."""
        file_name = self.fixture_abs_path("pyfunc_1.py")

        import jaclang.compiler.unitree as uni
        from jaclang.settings import settings

        settings.print_py_raised_ast = True
        with open(file_name, "r") as f:
            file_source = f.read()
        ir = (prog := JacProgram()).build(use_str=file_source, file_path=file_name)
        jac_ast = ir.pp()
        self.assertIn(" |   +-- String - 'Loop completed normally{}'", jac_ast)
        sub_node_list_count = 0
        for i in prog.mod.hub.values():
            if i.name == "builtins":
                continue
            sub_node_list_count += len(i.get_all_sub_nodes(uni.SubNodeList))
        self.assertEqual(sub_node_list_count, 623)
        captured_output = io.StringIO()
        sys.stdout = captured_output
        Jac.jac_import(self.mach, "deep_convert", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Deep convo is imported", stdout_value)

    def test_ds_type_check_pass(self) -> None:
        """Test conn assign on edges."""
        (mypass := JacProgram()).build(
            self.examples_abs_path("micro/simple_walk.jac"),
        )
        self.assertEqual(len(mypass.errors_had), 0)
        self.assertEqual(len(mypass.warnings_had), 0)

    def test_ds_type_check_pass2(self) -> None:
        """Test conn assign on edges."""
        (mypass := JacProgram()).build(
            self.examples_abs_path("guess_game/guess_game5.jac"),
        )
        self.assertEqual(len(mypass.errors_had), 0)
        self.assertEqual(len(mypass.warnings_had), 0)

    def test_circle_override1_type_check_pass(self) -> None:
        """Test conn assign on edges."""
        (mypass := JacProgram()).build(
            self.examples_abs_path("manual_code/circle.jac"),
        )
        self.assertEqual(len(mypass.errors_had), 0)
        # FIXME: Figure out what to do with warning.
        # self.assertEqual(len(mypass.warnings_had), 0)

    def test_expr_types(self) -> None:
        """Testing for print AstTool."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["ast", f"{self.fixture_abs_path('expr_type.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        self.assertRegex(
            stdout_value, r"4\:9 \- 4\:14.*BinaryExpr \- Type\: builtins.int"
        )
        self.assertRegex(
            stdout_value, r"7\:9 \- 7\:17.*FuncCall \- Type\: builtins.float"
        )
        self.assertRegex(
            stdout_value, r"9\:6 \- 9\:11.*CompareExpr \- Type\: builtins.bool"
        )
        self.assertRegex(
            stdout_value, r"10\:6 - 10\:15.*BinaryExpr \- Type\: builtins.str"
        )
        self.assertRegex(
            stdout_value, r"11\:5 \- 11\:13.*AtomTrailer \- Type\: builtins.int"
        )
        self.assertRegex(
            stdout_value, r"12\:5 \- 12\:14.*UnaryExpr \- Type\: builtins.bool"
        )
        self.assertRegex(
            stdout_value, r"13\:5 \- 13\:25.*IfElseExpr \- Type\: Literal\['a']\?"
        )
        self.assertRegex(
            stdout_value,
            r"14\:5 \- 14\:27.*ListCompr - \[ListCompr] \- Type\: builtins.list\[builtins.int]",
        )

    def test_type_check(self) -> None:
        """Testing for print AstTool."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.check(f"{self.fixture_abs_path('game1.jac')}")
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Errors: 0, Warnings: 1", stdout_value)

    def test_type_errors(self) -> None:
        """Basic test for pass."""
        (type_checked := JacProgram()).build(
            file_path=self.fixture_abs_path("func.jac"),
        )

        errs = "\n".join([i.msg for i in type_checked.warnings_had])
        files = "\n".join([i.loc.mod_path for i in type_checked.warnings_had])

        for i in [
            "func2.jac",
            "func.jac",
            '(got "int", expected "str")',
            '(got "str", expected "int")',
        ]:
            self.assertIn(i, errs + files)

    def test_imported_module_typecheck(self) -> None:
        """Basic test for pass."""
        (type_checked := JacProgram()).build(
            file_path=self.fixture_abs_path("game1.jac"),
        )

        errs = "\n".join([i.msg for i in type_checked.warnings_had])
        files = "\n".join([i.loc.mod_path for i in type_checked.warnings_had])

        for i in [
            'Argument 2 to "is_pressed" of "Button" has incompatible type "int"; expected "str"',
        ]:
            self.assertIn(i, errs + files)

    def test_type_coverage(self) -> None:
        """Testing for type info coverage in sym_tab via ast."""
        out = AstTool().ir(["ast", f"{self.fixture_abs_path('type_info.jac')}"])
        lis = [
            "introduce - Type: None",
            "25:30 - 25:37\t        |   |   |           +-- Name - species - Type: None",  # AtomTrailer
        ]
        self.assertIn("HasVar - species - Type: builtins.str", out)
        self.assertIn("myDog - Type: type_info.Dog", out)
        self.assertIn("Body - Type: type_info.Dog.Body", out)
        self.assertEqual(out.count("Type: builtins.str"), 35)
        for i in lis:
            self.assertNotIn(i, out)

    def test_data_spatial_type_info(self) -> None:
        """Testing for type info for dataspatial constructs."""
        out = AstTool().ir(
            ["ast", f"{self.fixture_abs_path('data_spatial_types.jac')}"]
        )
        self.assertRegex(
            out,
            r"129:22 - 129:26.*SpecialVarRef - root \- Type\: jaclang.runtimelib.archetype.Root",
        )
        self.assertRegex(out, r"129:11 - 129:27.*FuncCall \- Type\: builtins\.str")
        self.assertRegex(
            out,
            r"129:13 - 129:21.*Name \- node_dot \- Type\: builtins.str",
        )

        self.assertRegex(
            out,
            r"128:5 - 128:25.*BinaryExpr \- Type\: "
            + r"Union\[jaclang.runtimelib.archetype.WalkerArchetype, concurrent.futures._base.Future\[Any\]\]",
        )

        self.assertRegex(
            out,
            r"48:11 - 48:28.*EdgeRefTrailer \- Type\: builtins.list\[jaclang.runtimelib.archetype.Archetype\]",
        )

        self.assertRegex(out, r"24:5 - 24:25.*BinaryExpr \- Type\: builtins.bool", out)

    def test_type_info(self) -> None:
        """Testing for type info inside the ast tool."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.tool("ir", ["ast", f"{self.fixture_abs_path('type_info.jac')}"])
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertEqual(stdout_value.count("type_info.ServerWrapper"), 5)
        self.assertEqual(stdout_value.count("builtins.int"), 3)
        self.assertEqual(stdout_value.count("builtins.str"), 10)
        self.assertIn("Literal['test_server']", stdout_value)
        self.assertIn("Literal['1']", stdout_value)

    def test_base_class_complex_expr(self) -> None:
        """Testing for print AstTool."""
        from jaclang.settings import settings

        # settings.ast_symbol_info_detailed = True
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool(
            "ir", ["ast", f"{self.fixture_abs_path('base_class_complex_expr.jac')}"]
        )

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        settings.ast_symbol_info_detailed = False

        self.assertRegex(
            stdout_value,
            r"36\:9 \- 36\:13.*Name \- Kiwi \- Type\: base_class_complex_expr.Kiwi,  SymbolTable\: Kiwi",
        )

    def test_import_all(self) -> None:
        """Testing for print AstTool."""
        from jaclang.settings import settings

        settings.ast_symbol_info_detailed = True
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["ast", f"{self.fixture_abs_path('import_all.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        settings.ast_symbol_info_detailed = False

        self.assertRegex(
            stdout_value,
            r"6\:25 - 6\:30.*Name - floor -.*SymbolPath: math.floor",
        )
        self.assertRegex(
            stdout_value,
            r"5\:25 - 5\:27.*Name - pi -.*SymbolPath: math.pi",
        )

    def test_import_mod_abs_path(self) -> None:
        """Testing for print AstTool."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["ast", f"{self.fixture_abs_path('import.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue().replace("\\", "/")
        self.assertRegex(
            stdout_value,
            r"1.*ModulePath - os - abs_path\:.*typeshed/stdlib/os/__init__.pyi",
        )
        self.assertRegex(
            stdout_value,
            r"2.*ModulePath - sys - abs_path\:.*typeshed/stdlib/sys/__init__.pyi",
        )
        self.assertRegex(
            stdout_value,
            r"3.*ModulePath - pyfunc - abs_path\:.*fixtures/pyfunc.py",
        )
        self.assertRegex(
            stdout_value,
            r"4.*ModulePath - pygame_mock - abs_path\:.*fixtures/pygame_mock/inner/__init__.py",
        )
        self.assertRegex(
            stdout_value,
            r"6.*ModulePath - math - abs_path\:.*typeshed/stdlib/math.pyi",
        )
        self.assertRegex(
            stdout_value,
            r"7.*ModulePath - argparse - abs_path\:.*typeshed/stdlib/argparse.pyi",
        )
        self.assertRegex(
            stdout_value,
            r"8.*ModulePath - pygame_mock - abs_path\:.*fixtures/pygame_mock/__init__.py",
        )
        self.assertRegex(
            stdout_value,
            r"8.*ModuleItem - color - abs_path\:.*fixtures/pygame_mock/color.py",
        )
        self.assertRegex(
            stdout_value,
            r"8.*ModuleItem - display - abs_path\:.*fixtures/pygame_mock/display.py",
        )

    def test_sub_class_symbol_table_fix_1(self) -> None:
        """Testing for print AstTool."""
        from jaclang.settings import settings

        settings.ast_symbol_info_detailed = True
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["ast", f"{self.fixture_abs_path('base_class1.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        settings.ast_symbol_info_detailed = False

        self.assertRegex(
            stdout_value,
            r"10:7 - 10:12.*Name - start - Type.*SymbolPath: base_class1.B.start",
        )

    def test_sub_class_symbol_table_fix_2(self) -> None:
        """Testing for print AstTool."""
        from jaclang.settings import settings

        settings.ast_symbol_info_detailed = True
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["ast", f"{self.fixture_abs_path('base_class2.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        settings.ast_symbol_info_detailed = False

        self.assertRegex(
            stdout_value,
            r"10:7 - 10:12.*Name - start - Type.*SymbolPath: base_class2.B.start",
        )
