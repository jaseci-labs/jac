from jaclang.utils.test import TestCase
from jaclang.vendor.pygls import uris
from jaclang.vendor.pygls.workspace import Workspace

import lsprotocol.types as lspt
import pytest
from jaclang import JacMachineInterface as _
from jaclang.langserve.engine import JacLangServer
from .session import LspSession


class TestJacLangServer(TestCase):

    def test_formatting(self) -> None:
        with LspSession() as s:
            s.initialize()
            with open(self.fixture_abs_path("hello.jac"), "w") as f:
                f.write('with entry {print("Hello, World!");}')
            with open(self.fixture_abs_path("hello.jac"), "r") as f:
                self.assertEqual(f.read(), 'with entry {print("Hello, World!");}')
            params_json = {
                "textDocument": {
                    "uri": uris.from_fs_path(self.fixture_abs_path("hello.jac")),
                    "languageId": "jac",
                    "version": 1,
                    "text": "with entry {print('Hello, World!');}",
                },
                "options": {"tabSize": 4, "insertSpaces": True},
            }
            text_edits = s.text_document_formatting(params_json)
            self.assertEqual(
                text_edits,
                [
                    {
                        "range": {
                            "start": {"line": 0, "character": 0},
                            "end": {"line": 2, "character": 0},
                        },
                        "newText": 'with entry {\n    print("Hello, World!");\n}\n',
                    }
                ],
            )

    def test_impl_stay_connected(self) -> None:
        """Test that the server doesn't run if there is a syntax error."""
        lsp = JacLangServer()
        # Set up the workspace path to "fixtures/"
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        circle_file = uris.from_fs_path(self.fixture_abs_path("circle_pure.jac"))
        circle_impl_file = uris.from_fs_path(
            self.fixture_abs_path("circle_pure.impl.jac")
        )
        lsp.deep_check(circle_file)
        pos = lspt.Position(20, 8)
        self.assertIn(
            "Circle class inherits from Shape.",
            lsp.get_hover_info(circle_file, pos).contents.value,
        )
        lsp.deep_check(circle_impl_file)
        pos = lspt.Position(8, 11)
        self.assertIn(
            # "ability) calculate_area: float",
            "ability) calculate_area\n( radius : float ) -> float",
            lsp.get_hover_info(circle_impl_file, pos).contents.value.replace("'", ""),
        )

    def test_impl_auto_discover(self) -> None:
        """Test that the server doesn't run if there is a syntax error."""
        lsp = JacLangServer()
        # Set up the workspace path to "fixtures/"
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        circle_impl_file = uris.from_fs_path(
            self.fixture_abs_path("circle_pure.impl.jac")
        )
        lsp.deep_check(circle_impl_file)
        pos = lspt.Position(8, 11)
        self.assertIn(
            # "ability) calculate_area: float",
            "(public ability) calculate_area\n( radius : float ) -> float",
            lsp.get_hover_info(circle_impl_file, pos).contents.value.replace("'", ""),
        )

    @pytest.mark.xfail(reason="TODO: Fix when we have the type checker")
    def test_show_type_impl(self) -> None:
        """Test that the server doesn't run if there is a syntax error."""
        lsp = JacLangServer()
        # Set up the workspace path to "fixtures/"
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        target = uris.from_fs_path(self.examples_abs_path("guess_game/guess_game4.jac"))
        lsp.deep_check(target)
        pos = lspt.Position(43, 18)
        self.assertIn(
            "attempts: int",
            lsp.get_hover_info(target, pos).contents.value,
        )

    def test_outline_symbols(self) -> None:
        """Test that the outline symbols are correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        circle_file = uris.from_fs_path(self.fixture_abs_path("circle_pure.jac"))
        lsp.deep_check(circle_file)
        self.assertEqual(8, len(lsp.get_outline(circle_file)))

    def test_go_to_definition(self) -> None:
        """Test that the go to definition is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        circle_file = uris.from_fs_path(self.fixture_abs_path("circle_pure.jac"))
        lsp.deep_check(circle_file)
        self.assertIn(
            "fixtures/circle_pure.impl.jac:8:5-8:19",
            str(lsp.get_definition(circle_file, lspt.Position(9, 16))),
        )
        self.assertIn(
            "fixtures/circle_pure.jac:13:11-13:16",
            str(lsp.get_definition(circle_file, lspt.Position(20, 16))),
        )

    def test_go_to_definition_method(self) -> None:
        """Test that the go to definition is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        guess_game_file = uris.from_fs_path(
            self.examples_abs_path("guess_game/guess_game3.impl.jac")
        )
        lsp.deep_check(guess_game_file)
        self.assertIn(
            "guess_game3.jac:16:8-16:21",
            str(lsp.get_definition(guess_game_file, lspt.Position(15, 17))),
        )

    def test_go_to_definition_method_manual_impl(self) -> None:
        """Test that the go to definition is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        decldef_file = uris.from_fs_path(
            self.examples_abs_path("micro/decl_defs_main.impl.jac")
        )
        lsp.deep_check(decldef_file)
        decldef_main_file = uris.from_fs_path(
            self.examples_abs_path("micro/decl_defs_main.jac")
        )
        lsp.deep_check(decldef_main_file)
        lsp.deep_check(decldef_file)
        self.assertIn(
            "decl_defs_main.jac:7:8-7:17",
            str(lsp.get_definition(decldef_file, lspt.Position(2, 20))),
        )

    @pytest.mark.xfail(
        reason="TODO: Fix the go to definition for imports[ abs_path is not set]"
    )
    def test_test_annex(self) -> None:
        """Test that the server doesn't run if there is a syntax error."""
        lsp = JacLangServer()
        # Set up the workspace path to "fixtures/"
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        circle_file = uris.from_fs_path(self.fixture_abs_path("circle_pure.test.jac"))
        lsp.deep_check(circle_file)
        pos = lspt.Position(13, 21)
        self.assertIn(
            "shape_type: circle_pure.ShapeType",
            lsp.get_hover_info(circle_file, pos).contents.value,
        )

    @pytest.mark.xfail(
        reason="TODO: Fix the go to definition for imports[ abs_path is not set]"
    )
    def test_go_to_defintion_import(self) -> None:
        """Test that the go to definition is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        import_file = uris.from_fs_path(
            self.fixture_abs_path("import_include_statements.jac")
        )
        lsp.deep_check(import_file)
        positions = [
            (0, 12, "tdlib/os/__init__.pyi:0:0-0:0"),
            (1, 18, "stdlib/math.pyi:0:0-0:0"),
            (2, 24, "datetime.pyi:0:0-0:0"),
            (3, 17, "base_module_structure.jac:0:0-0:0"),
            (3, 87, "base_module_structure.jac:23:5-23:14"),
            (5, 65, "py_import.py:0:0-0:0"),
            (5, 35, "py_import.py:0:0-0:0"),
            # (5, 65, "py_import.py:12:0-20:5"),  # TODO : Should work after 'from' import files are raised
            # (5, 35, "py_import.py:3:0-4:5"),
        ]

        for line, char, expected in positions:
            with self.subTest(line=line, char=char):
                self.assertIn(
                    expected,
                    str(lsp.get_definition(import_file, lspt.Position(line, char))),
                )

    @pytest.mark.xfail(
        reason="TODO: Fix the go to definition for imports[ abs_path is not set]"
    )
    def test_go_to_definition_foolme(self) -> None:
        """Test that the go to definition is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        import_file = uris.from_fs_path(
            self.fixture_abs_path(
                "../../../../jaclang/compiler/passes/main/tests/fixtures/py_imp_test.jac"
            )
        )
        lsp.deep_check(import_file)
        positions = [
            (6, 39, "/pygame_mock/__init__.pyi:2:0-2:0"),
            (6, 45, "/pygame_mock/constants.py:3:0-4:1"),
            (7, 31, "/pygame_mock/__init__.pyi:2:0-2:0"),
            (7, 35, "/pygame_mock/constants.py:3:0-4:1"),
            (20, 51, "/py_imp_test.jac:6:4-6:11"),
            (20, 64, "/pygame_mock/constants.py:4:3-4:15"),
            (21, 48, "/py_imp_test.jac:10:4-10:6"),
            (21, 58, "/py_imp_test.jac:11:8-11:15"),
            (21, 68, "/pygame_mock/constants.py:4:3-4:15"),
            (23, 58, "/pygame_mock/constants.py:4:3-4:15"),
        ]

        for line, char, expected in positions:
            with self.subTest(line=line, char=char):
                self.assertIn(
                    expected,
                    str(lsp.get_definition(import_file, lspt.Position(line, char))),
                )

    @pytest.mark.xfail(reason="TODO: Fix the go to definition")
    def test_go_to_definition_index_expr(self) -> None:
        """Test that the go to definition is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        import_file = uris.from_fs_path(
            self.fixture_abs_path("../../../../jaclang/tests/fixtures/index_slice.jac")
        )
        lsp.deep_check(import_file)
        positions = [
            (23, 20, "index_slice.jac:2:8-2:13"),
            (24, 24, "index_slice.jac:2:8-2:13"),
            (27, 33, "index_slice.jac:2:8-2:13"),
        ]

        for line, char, expected in positions:
            with self.subTest(line=line, char=char):
                print(str(lsp.get_definition(import_file, lspt.Position(line, char))))
                self.assertIn(
                    expected,
                    str(lsp.get_definition(import_file, lspt.Position(line, char))),
                )

    @pytest.mark.xfail(reason="TODO: Fix when we have the type checker")
    def test_sem_tokens(self) -> None:
        """Test that the Semantic Tokens are generated correctly."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        circle_file = uris.from_fs_path(self.fixture_abs_path("circle.jac"))
        lsp.deep_check(circle_file)
        sem_list = lsp.get_semantic_tokens(circle_file).data
        expected_counts = [
            ("<JacSemTokenType.VARIABLE: 8>, <JacSemTokenModifier.READONLY: 4>", 12),
            (
                "<JacSemTokenType.PROPERTY: 9>, <JacSemTokenModifier.DEFINITION: 2>,",
                21,
            ),
            (
                "<JacSemTokenType.PARAMETER: 7>, <JacSemTokenModifier.DECLARATION: 1>,",
                5,
            ),
            (
                "<JacSemTokenType.FUNCTION: 12>, <JacSemTokenModifier.DECLARATION: 1>,",
                8,
            ),
            ("<JacSemTokenType.METHOD: 13>, <JacSemTokenModifier.DECLARATION: 1>", 6),
            ("<JacSemTokenType.ENUM: 3>, <JacSemTokenModifier.DECLARATION: 1>,", 4),
            ("<JacSemTokenType.CLASS: 2>, <JacSemTokenModifier.DECLARATION: ", 12),
            (
                "<JacSemTokenType.NAMESPACE: 0>, <JacSemTokenModifier.DEFINITION: 2>,",
                3,
            ),
        ]
        for token_type, expected_count in expected_counts:
            self.assertEqual(str(sem_list).count(token_type), expected_count)

    @pytest.mark.xfail(reason="TODO: Fix when we have the type checker")
    def test_completion(self) -> None:
        """Test that the completions are correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        base_module_file = uris.from_fs_path(
            self.fixture_abs_path("base_module_structure.jac")
        )
        lsp.deep_check(base_module_file)
        test_cases = [
            (lspt.Position(38, 16), ["get_color1", "color1", "point1"], 3),
            (lspt.Position(42, 22), ["RED", "GREEN", "BLUE"], 3),
            (lspt.Position(42, 33), ["RED", "GREEN", "BLUE"], 3),
            (lspt.Position(42, 45), ["RED", "GREEN", "BLUE"], 3),
            (lspt.Position(46, 20), ["RED22", "GREEN22", "BLUE22"], 3),
            (lspt.Position(46, 30), ["RED22", "GREEN22", "BLUE22"], 3),
            (lspt.Position(46, 41), ["RED22", "GREEN22", "BLUE22"], 3),
            (
                lspt.Position(51, 32),
                ["RED22", "GREEN22", "BLUE22"],
                3,
            ),
            (
                lspt.Position(65, 13),
                [
                    "get_color1",
                    "color1",
                    "point1",
                    "base_colorred",
                    "pointred",
                    "inner_red",
                    "doubleinner",
                    "apply_red",
                ],
                11,
            ),
            (
                lspt.Position(65, 23),
                ["color22", "doublepoint22", "point22", "apply_inner_red", "enum_red"],
                5,
            ),
            (
                lspt.Position(65, 31),
                ["RED22", "GREEN22", "BLUE22"],
                3,
            ),
            (
                lspt.Position(35, 28),
                [],
                0,
            ),
            (
                lspt.Position(72, 12),
                [
                    "get_color1",
                    "color1",
                    "point1",
                    "base_colorred",
                    "pointred",
                    "inner_red",
                    "doubleinner",
                    "apply_red",
                ],
                11,
            ),
            (
                lspt.Position(73, 22),
                ["color22", "doublepoint22", "apply_inner_red", "point22", "enum_red"],
                5,
            ),
            (
                lspt.Position(37, 12),
                ["self", "add", "subtract", "x", "Colorenum", "Colour1", "red", "r"],
                153,
                None,
            ),
        ]
        default_trigger = "."
        for case in test_cases:
            position, expected_completions, expected_length = case[:3]
            completion_trigger = case[3] if len(case) > 3 else default_trigger
            completions = lsp.get_completion(
                base_module_file, position, completion_trigger=completion_trigger
            ).items
            for completion in expected_completions:
                self.assertIn(completion, str(completions))
            self.assertEqual(expected_length, len(completions))

            if position == lspt.Position(73, 12):
                self.assertEqual(
                    2, str(completions).count("kind=<CompletionItemKind.Function: 3>")
                )
                self.assertEqual(
                    4, str(completions).count("kind=<CompletionItemKind.Field: 5>")
                )

    def test_go_to_reference(self) -> None:
        """Test that the go to reference is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace

        circle_file = uris.from_fs_path(self.fixture_abs_path("circle.jac"))
        lsp.deep_check(circle_file)
        test_cases = [
            (47, 12, ["circle.jac:47:8-47:14", "69:8-69:14", "74:8-74:14"]),
            (54, 66, ["54:62-54:76", "65:22-65:36"]),
            (62, 14, ["65:43-65:56", "70:32-70:45"]),
        ]
        for line, char, expected_refs in test_cases:
            references = str(lsp.get_references(circle_file, lspt.Position(line, char)))
            for expected in expected_refs:
                self.assertIn(expected, references)

    @pytest.mark.xfail(reason="TODO: Fix when we have the type checker")
    def test_py_type__definition(self) -> None:
        """Test that the go to definition is correct for pythoon imports."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        import_file = uris.from_fs_path(
            self.fixture_abs_path(
                "../../../../jaclang/compiler/passes/main/tests/fixtures/py_imp_test.jac"
            )
        )
        lsp.deep_check(import_file)
        positions = [
            (19, 29, "pygame_mock/color.py:0:0-2:4"),
            (3, 17, "/pygame_mock/__init__.py:0:0-0:0"),
            (20, 45, "pygame_mock/color.py:0:0-2:4"),
            (19, 77, "mock/constants.py:4:3-4:15"),
            (26, 28, "mock/display.py:0:0-1:7"),
            (24, 22, "vendor/mypy/typeshed/stdlib/argparse.pyi:125:0-256:13"),
            (19, 74, "pygame_mock/constants.py:4:3-4:15"),
            # TODO: Need to properly support this
            # (27, 17, "/stdlib/os/__init__.pyi:50:0-50:3"),
        ]

        for line, char, expected in positions:
            with self.subTest(line=line, char=char):
                self.assertIn(
                    expected,
                    str(lsp.get_definition(import_file, lspt.Position(line, char))),
                    msg=positions.index((line, char, expected)) + 1,
                )

    @pytest.mark.xfail(reason="TODO: Fix when we have the type checker")
    def test_py_type__references(self) -> None:
        """Test that the go to definition is correct for pythoon imports."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace

        circle_file = uris.from_fs_path(
            self.fixture_abs_path(
                "../../../../jaclang/compiler/passes/main/tests/fixtures/py_imp_test.jac"
            )
        )
        lsp.deep_check(circle_file)
        test_cases = [
            (
                2,
                21,
                [
                    ":6:21-6:32",
                    ":7:11-7:22",
                    ":11:25-11:36",
                    ":12:15-12:26",
                    ":18:33-18:44",
                    "19:46-19:57",
                    ":19:8-19:19",
                    ":19:46-19:57",
                    ":20:8-20:19",
                    "21:8-21:19,",
                    "23:8-23:19",
                    ":26:4-26:15",
                ],
            ),
            (
                19,
                63,
                [
                    "6:33-6:42",
                    "7:23-7:32",
                    "18:45-18:54",
                    "19:58-19:67",
                    "11:37-11:46",
                    "12:27-12:36",
                ],
            ),
            (
                24,
                53,
                [
                    "24:42-24:56",
                    "24:16-24:30",
                    "argparse.pyi:358:21-358:35",
                    "argparse.pyi:164:29-164:43",
                    "argparse.pyi:32:52-32:66",
                ],
            ),
        ]
        for line, char, expected_refs in test_cases:
            references = str(lsp.get_references(circle_file, lspt.Position(line, char)))
            for expected in expected_refs:
                self.assertIn(expected, references)

    @pytest.mark.xfail(reason="TODO: Fix when we have the type checker")
    def test_rename_symbol(self) -> None:
        """Test that the rename is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace

        circle_file = uris.from_fs_path(self.fixture_abs_path("circle.jac"))
        lsp.deep_check(circle_file)
        test_cases = [
            (
                20,
                14,
                "ShapeKind",
                "27:20-27:29,",
                "36:19-36:28",
                "75:26-75:35",
                "20:5-20:14",
            ),
            (12, 34, "circleRadius", "12:21-12:27", "12:30-12:36", "11:19-11:25"),
            (62, 14, "target_area", "65:43-65:56", "70:32-70:45", "62:5-62:18"),
            (57, 33, "type_of_shape", "75:12-75:22", "27:8-27:18,", "57:23-57:33"),
        ]
        for tup in test_cases:
            line, char, new_name, *expected_refs = tup
            references = str(
                lsp.rename_symbol(circle_file, lspt.Position(line, char), new_name)
            )
            for expected in expected_refs:
                self.assertIn(expected, references)

    @pytest.mark.xfail(reason="TODO: Fix when we have the type checker")
    def test_rename_uses(self) -> None:
        """Test that the rename is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace

        circle_file = uris.from_fs_path(self.fixture_abs_path("rename.jac"))
        lsp.deep_check(circle_file)
        # fmt: off
        test_cases = [
            (0, 7, "func", "25:4-25:7", "0:4-0:7", "4:5-4:8",),
            (4, 8, "func", "25:4-25:7", "0:4-0:7", "4:5-4:8",),
            (25, 6, "func", "25:4-25:7", "0:4-0:7", "4:5-4:8",),
            (10, 10, "canBar", "27:8-27:11", "10:8-10:11"),
            (27, 9, "canBar", "27:8-27:11", "10:8-10:11"),
            (9, 6, "canBar", "26:10-26:13", "28:4-28:7", "16:5-16:8", "9:4-9:7"),
            (26, 11, "canBar", "26:10-26:13", "28:4-28:7", "16:5-16:8", "9:4-9:7"),
            (16, 8, "canBar", "26:10-26:13", "28:4-28:7", "16:5-16:8", "9:4-9:7"),
            (28, 6, "canBar", "26:10-26:13", "28:4-28:7", "16:5-16:8", "9:4-9:7"),
            (11, 10, "canBar", "11:8-11:11", "16:9-16:12", "28:11-28:14"),
            (16, 12, "canBar", "11:8-11:11", "16:9-16:12", "28:11-28:14"),
            (28, 13, "canBar", "11:8-11:11", "16:9-16:12", "28:11-28:14"),
            (12, 10, "canBaz", "12:8-12:11", "20:9-20:12"),
            (20, 12, "canBaz", "12:8-12:11", "20:9-20:12"),
            (26, 6, "count", "27:4-27:7", "26:4-26:7"),
            (27, 5, "count", "27:4-27:7", "26:4-26:7"),
        ]
        # fmt: on
        for tup in test_cases:
            line, char, new_name, *expected_refs = tup
            references = str(
                lsp.rename_symbol(circle_file, lspt.Position(line, char), new_name)
            )
            for expected in expected_refs:
                self.assertIn(expected, references)

    def test_binder_go_to_module(self) -> None:
        """Test that the go to definition is correct."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        guess_game_file = uris.from_fs_path(self.fixture_abs_path('../../../compiler/passes/main/tests/fixtures/sym_binder.jac'))
        lsp.deep_check(guess_game_file)
        self.assertIn(
            "/tests/fixtures/M1.jac:0:0-0:0",
            str(lsp.get_definition(guess_game_file, lspt.Position(29, 9))),
        )