from jaclang.utils.test import TestCase
from jaclang.vendor.pygls import uris
from jaclang.vendor.pygls.workspace import Workspace

import lsprotocol.types as lspt
from jaclang.langserve.engine import JacLangServer


class TestJacLangServer(TestCase):

    def test_type_annotation_assignment_server(self) -> None:
        """Test that the server doesn't run if there is a syntax error."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        circle_file = uris.from_fs_path(
            self.fixture_abs_path(
                "../../../../jaclang/compiler/passes/main/tests/fixtures/type_annotation_assignment.jac"
            )
        )
        lsp.deep_check(circle_file)
        self.assertIn(
            "(public variable) should_fail1: int",
            lsp.get_hover_info(circle_file, lspt.Position(1, 15)).contents.value,
        )
        self.assertIn(
            "(public variable) should_pass2: str",
            lsp.get_hover_info(circle_file, lspt.Position(2, 15)).contents.value,
        )
        self.assertIn(
            "(public variable) should_fail2: str",
            lsp.get_hover_info(circle_file, lspt.Position(3, 15)).contents.value,
        )
        diagnostics_list = list(lsp.diagnostics.values())[0]
        self.assertEqual(len(diagnostics_list), 2)
        self.assertIn(
            "Cannot assign",
            diagnostics_list[0].message,
        )
        self.assertEqual(
            "1:5-1:30",
            str(diagnostics_list[0].range),
        )
        self.assertEqual(
            "3:5-3:27",
            str(diagnostics_list[1].range),
        )


    def test_member_access_type_inferred_server(self) -> None:
        """Test that the server doesn't run if there is a syntax error."""
        lsp = JacLangServer()
        workspace_path = self.fixture_abs_path("")
        workspace = Workspace(workspace_path, lsp)
        lsp.lsp._workspace = workspace
        circle_file = uris.from_fs_path(
            self.fixture_abs_path(
                "../../../../jaclang/compiler/passes/main/tests/fixtures/member_access_type_inferred.jac"
            )
        )
        lsp.deep_check(circle_file)
        self.assertIn(
            "(public variable) i: int",
            lsp.get_hover_info(circle_file, lspt.Position(10, 2)).contents.value,
        )
        self.assertIn(
            "(public variable) s: str",
            lsp.get_hover_info(circle_file, lspt.Position(11, 2)).contents.value,
        )
        diagnostics_list = list(lsp.diagnostics.values())[0]
        self.assertEqual(len(diagnostics_list), 1)
        self.assertIn(
            "Cannot assign",
            diagnostics_list[0].message,
        )
        self.assertEqual(
            "11:2-11:12",
            str(diagnostics_list[0].range),
        )