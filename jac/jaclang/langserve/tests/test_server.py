from dataclasses import dataclass
from jaclang.utils.test import TestCase
from jaclang.vendor.pygls import uris
from jaclang.vendor.pygls.workspace import Workspace

import lsprotocol.types as lspt
from jaclang.langserve.engine import JacLangServer


class TestJacLangServer(TestCase):

    def create_server(self, workspace_path: str | None = None) -> JacLangServer:
        """Create a JacLangServer wired to the given workspace and auto-cleanup."""
        lsp = JacLangServer()
        self.addCleanup(lsp.shutdown)
        workspace_root = workspace_path or self.fixture_abs_path("")
        workspace = Workspace(workspace_root, lsp)
        lsp.lsp._workspace = workspace
        return lsp

    def test_impl_stay_connected(self) -> None:
        """Test that the server doesn't run if there is a syntax error."""
        lsp = self.create_server()
        circle_file = uris.from_fs_path(self.fixture_abs_path("circle_pure.jac"))
        circle_impl_file = uris.from_fs_path(
            self.fixture_abs_path("circle_pure.impl.jac")
        )
        lsp.type_check_file(circle_file)
        pos = lspt.Position(20, 8)
        self.assertIn(
            "Circle class inherits from Shape.",
            lsp.get_hover_info(circle_file, pos).contents.value,
        )
        lsp.type_check_file(circle_impl_file)
        pos = lspt.Position(8, 11)
        self.assertIn(
            # "ability) calculate_area: float",
            "ability) calculate_area\\n( radius : float ) -> float",
            lsp.get_hover_info(circle_impl_file, pos).contents.value.replace("'", ""),
        )

    def test_impl_auto_discover(self) -> None:
        """Test that the server doesn't run if there is a syntax error."""
        lsp = self.create_server()
        circle_impl_file = uris.from_fs_path(
            self.fixture_abs_path("circle_pure.impl.jac")
        )
        lsp.type_check_file(circle_impl_file)
        pos = lspt.Position(8, 11)
        self.assertIn(
            # "ability) calculate_area: float",
            "(public ability) calculate_area\\n( radius : float ) -> float",
            lsp.get_hover_info(circle_impl_file, pos).contents.value.replace("'", ""),
        )

    def test_outline_symbols(self) -> None:
        """Test that the outline symbols are correct."""
        lsp = self.create_server()
        circle_file = uris.from_fs_path(self.fixture_abs_path("circle_pure.jac"))
        lsp.type_check_file(circle_file)
        self.assertEqual(8, len(lsp.get_outline(circle_file)))

    def test_go_to_definition(self) -> None:
        """Test that the go to definition is correct."""
        lsp = self.create_server()
        circle_file = uris.from_fs_path(self.fixture_abs_path("circle_pure.jac"))
        lsp.type_check_file(circle_file)
        self.assertIn(
            "fixtures/circle_pure.impl.jac:8:5-8:19",
            str(lsp.get_definition(circle_file, lspt.Position(9, 16))),
        )
        self.assertIn(
            "fixtures/circle_pure.jac:13:11-13:16",
            str(lsp.get_definition(circle_file, lspt.Position(20, 16))),
        )

        goto_defs_file = uris.from_fs_path(self.fixture_abs_path("goto_def_tests.jac"))
        lsp.type_check_file(goto_defs_file)

        # Test if the visistor keyword goes to the walker definition
        self.assertIn(
            "fixtures/goto_def_tests.jac:8:7-8:17",
            str(lsp.get_definition(goto_defs_file, lspt.Position(4, 14))),
        )
        # Test if the here keywrod goes to the node definition
        self.assertIn(
            "fixtures/goto_def_tests.jac:0:5-0:13",
            str(lsp.get_definition(goto_defs_file, lspt.Position(10, 14))),
        )
        # Test the SomeNode node inside the visit statement goes to its definition
        self.assertIn(
            "fixtures/goto_def_tests.jac:0:5-0:13",
            str(lsp.get_definition(goto_defs_file, lspt.Position(11, 21))),
        )

    def test_go_to_definition_method_manual_impl(self) -> None:
        """Test that the go to definition is correct."""
        lsp = self.create_server()
        decldef_file = uris.from_fs_path(
            self.examples_abs_path("micro/decl_defs_main.impl.jac")
        )
        lsp.type_check_file(decldef_file)
        decldef_main_file = uris.from_fs_path(
            self.examples_abs_path("micro/decl_defs_main.jac")
        )
        lsp.type_check_file(decldef_main_file)
        lsp.type_check_file(decldef_file)
        self.assertIn(
            "decl_defs_main.jac:7:8-7:17",
            str(lsp.get_definition(decldef_file, lspt.Position(2, 20))),
        )

    def test_go_to_definition_md_path(self) -> None:
        """Test that the go to definition is correct."""
        lsp = self.create_server()
        import_file = uris.from_fs_path(self.fixture_abs_path("md_path.jac"))
        lsp.type_check_file(import_file)
        # fmt: off
        positions = [
            (3, 11, "asyncio/__init__.py:0:0-0:0"),
            (6, 17, "concurrent/__init__.py:0:0-0:0"),
            (6, 28, "concurrent/futures/__init__.py:0:0-0:0"),
            (7, 17, "typing.py:0:0-0:0"),
            # not a good one since there may be different typing.py versions
            # (7, 27, "typing.py:2636:0-2636:7"),
            (9, 18, "compiler/__init__.py:0:0-0:0"),
            (9, 38, "compiler/unitree.py:0:0-0:0"),
            (10, 34, "jac/jaclang/__init__.py:7:3-7:22"),
            (11, 35, "compiler/constant.py:0:0-0:0"),
            (11, 47, "compiler/constant.py:5:0-34:9"),
            (13, 47, "compiler/type_system/type_utils.py:0:0-0:0"),
            (14, 34, "compiler/type_system/__init__.py:0:0-0:0"),
            (14, 55, "compiler/type_system/types.py:154:0-291:8"),
            (15, 34, "compiler/unitree.py:0:0-0:0"),
            (15, 48, "compiler/unitree.py:304:0-529:11"),
            (17, 22, "langserve/tests/fixtures/circle.jac:8:5-8:8"),
            (18, 38, "vendor/pygls/uris.py:0:0-0:0"),
            (19, 52, "vendor/pygls/server.py:351:0-615:13"),
            (21, 31, "vendor/lsprotocol/types.py:0:0-0:0"),
        ]
        # fmt: on

        for line, char, expected in positions:
            with self.subTest(line=line, char=char):
                self.assertIn(
                    expected,
                    str(
                        lsp.get_definition(
                            import_file, lspt.Position(line - 1, char - 1)
                        )
                    ),
                )

    def test_go_to_definition_connect_filter(self: JacLangServer) -> None:
        """Test that the go to definition is correct."""
        lsp = self.create_server()
        import_file = uris.from_fs_path(
            self.passes_main_fixture_abs_path("checker_connect_filter.jac")
        )
        lsp.type_check_file(import_file)
        # fmt: off
        positions = [
            (23, 7, "connect_filter.jac:20:4-20:10"),
            (23, 17, "connect_filter.jac:0:5-0:11"),
            (23, 28, "connect_filter.jac:21:4-21:10"),
            (26, 20, "connect_filter.jac:23:4-23:13"),
            (27, 18, "connect_filter.jac:4:5-4:10"),
            (28, 8, "connect_filter.jac:4:5-4:10"),
            (28, 18, "connect_filter.jac:0:5-0:11"),
            (32, 18, "connect_filter.jac:0:5-0:11"),
            (32, 23, "connect_filter.jac:1:6-1:8"),
            (35, 17, "connect_filter.jac:12:4-12:8"),
            (36, 6, "connect_filter.jac:34:4-34:7"),
            (40, 17, "connect_filter.jac:1:6-1:8"),
        ]
        # fmt: on

        for line, char, expected in positions:
            with self.subTest(line=line, char=char):
                self.assertIn(
                    expected,
                    str(
                        lsp.get_definition(
                            import_file, lspt.Position(line - 1, char - 1)
                        )
                    ),
                )

    def test_go_to_definition_atom_trailer(self: JacLangServer) -> None:
        """Test that the go to definition is correct."""
        lsp = self.create_server()
        import_file = uris.from_fs_path(self.fixture_abs_path("user.jac"))
        lsp.type_check_file(import_file)
        # fmt: off
        positions = [
            (14, 16, "fixtures/greet.py:8:3-9:15"),
            (14, 28, "fixtures/greet.py:2:3-3:15"),
        ]
        # fmt: on

        for line, char, expected in positions:
            with self.subTest(line=line, char=char):
                self.assertIn(
                    expected,
                    str(
                        lsp.get_definition(
                            import_file, lspt.Position(line - 1, char - 1)
                        )
                    ),
                )

    def test_missing_mod_warning(self: JacLangServer) -> None:
        """Test that the missing module warning is correct."""
        lsp = self.create_server()
        import_file = uris.from_fs_path(self.fixture_abs_path("md_path.jac"))
        lsp.type_check_file(import_file)

        positions = [
            "fixtures/md_path.jac, line 16, col 13: Module not found",
            "fixtures/md_path.jac, line 22, col 8: Module not found",
        ]
        for idx, expected in enumerate(positions):
            self.assertIn(
                expected,
                str(lsp.warnings_had[idx]),
            )

    def test_completion(self) -> None:
        """Test that the completions are correct."""
        import asyncio

        lsp = self.create_server()
        base_module_file = uris.from_fs_path(
            self.fixture_abs_path("completion_test_err.jac")
        )
        lsp.type_check_file(base_module_file)

        @dataclass
        class Case:
            pos: lspt.Position
            expected: list[str]
            trigger: str = "."

        test_cases: list[Case] = [
            Case(
                lspt.Position(8, 8),
                ["bar", "baz"],
            ),
        ]
        for case in test_cases:
            results = asyncio.run(
                lsp.get_completion(
                    base_module_file, case.pos, completion_trigger=case.trigger
                )
            )
            completions = results.items
            for completion in case.expected:
                self.assertIn(completion, str(completions))

    def test_go_to_reference(self) -> None:
        """Test that the go to reference is correct."""
        lsp = self.create_server()

        circle_file = uris.from_fs_path(self.fixture_abs_path("circle.jac"))
        lsp.type_check_file(circle_file)
        test_cases = [
            (47, 12, ["circle.jac:47:8-47:14", "69:8-69:14", "74:8-74:14"]),
            (54, 66, ["54:62-54:76", "65:23-65:37"]),
            # TODO: Even if we cannot find the function decl,
            # we should connect the function args to their decls
            # (62, 14, ["65:44-65:57", "70:33-70:46"]),
        ]
        for line, char, expected_refs in test_cases:
            references = str(lsp.get_references(circle_file, lspt.Position(line, char)))
            for expected in expected_refs:
                self.assertIn(expected, references)
