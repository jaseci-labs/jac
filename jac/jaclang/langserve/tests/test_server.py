import inspect
import os
from dataclasses import dataclass

import lsprotocol.types as lspt
import pytest

from jaclang.langserve.engine import JacLangServer
from jaclang.vendor.pygls import uris
from jaclang.vendor.pygls.workspace import Workspace


@pytest.fixture
def fixture_path():
    """Get absolute path to fixture file."""

    def _fixture_path(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        file_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return os.path.abspath(file_path)

    return _fixture_path


@pytest.fixture
def examples_abs_path():
    """Get absolute path of a example from examples directory."""
    import jaclang

    def _examples_abs_path(example: str) -> str:
        fixture_src = jaclang.__file__
        file_path = os.path.join(
            os.path.dirname(os.path.dirname(fixture_src)), "examples", example
        )
        return os.path.abspath(file_path)

    return _examples_abs_path


@pytest.fixture
def passes_main_fixture_abs_path():
    """Get absolute path of a fixture from compiler passes main fixtures directory."""
    import jaclang

    def _passes_main_fixture_abs_path(file: str) -> str:
        fixture_src = jaclang.__file__
        file_path = os.path.join(
            os.path.dirname(fixture_src),
            "compiler",
            "passes",
            "main",
            "tests",
            "fixtures",
            file,
        )
        return os.path.abspath(file_path)

    return _passes_main_fixture_abs_path


def create_server(workspace_path: str | None, fixture_path_func) -> JacLangServer:
    """Create a JacLangServer wired to the given workspace."""
    lsp = JacLangServer()
    workspace_root = workspace_path or fixture_path_func("")
    workspace = Workspace(workspace_root, lsp)
    lsp.lsp._workspace = workspace
    return lsp


def test_impl_stay_connected(fixture_path) -> None:
    """Test that the server doesn't run if there is a syntax error."""
    lsp = create_server(None, fixture_path)
    try:
        circle_file = uris.from_fs_path(fixture_path("circle_pure.jac"))
        circle_impl_file = uris.from_fs_path(fixture_path("circle_pure.impl.jac"))
        lsp.type_check_file(circle_file)
        pos = lspt.Position(20, 8)
        assert (
            "Circle class inherits from Shape."
            in lsp.get_hover_info(circle_file, pos).contents.value
        )
        lsp.type_check_file(circle_impl_file)
        pos = lspt.Position(8, 11)
        assert (
            "ability) calculate_area\\n( radius : float ) -> float"
            in lsp.get_hover_info(circle_impl_file, pos).contents.value.replace("'", "")
        )
    finally:
        lsp.shutdown()


def test_impl_auto_discover(fixture_path) -> None:
    """Test that the server doesn't run if there is a syntax error."""
    lsp = create_server(None, fixture_path)
    try:
        circle_impl_file = uris.from_fs_path(fixture_path("circle_pure.impl.jac"))
        lsp.type_check_file(circle_impl_file)
        pos = lspt.Position(8, 11)
        assert (
            "(public ability) calculate_area\\n( radius : float ) -> float"
            in lsp.get_hover_info(circle_impl_file, pos).contents.value.replace("'", "")
        )
    finally:
        lsp.shutdown()


def test_outline_symbols(fixture_path) -> None:
    """Test that the outline symbols are correct."""
    lsp = create_server(None, fixture_path)
    try:
        circle_file = uris.from_fs_path(fixture_path("circle_pure.jac"))
        lsp.type_check_file(circle_file)
        assert len(lsp.get_outline(circle_file)) == 8
    finally:
        lsp.shutdown()


def test_go_to_definition(fixture_path) -> None:
    """Test that the go to definition is correct."""
    lsp = create_server(None, fixture_path)
    try:
        circle_file = uris.from_fs_path(fixture_path("circle_pure.jac"))
        lsp.type_check_file(circle_file)
        assert "fixtures/circle_pure.impl.jac:8:5-8:19" in str(
            lsp.get_definition(circle_file, lspt.Position(9, 16))
        )
        assert "fixtures/circle_pure.jac:13:11-13:16" in str(
            lsp.get_definition(circle_file, lspt.Position(20, 16))
        )

        goto_defs_file = uris.from_fs_path(fixture_path("goto_def_tests.jac"))
        lsp.type_check_file(goto_defs_file)

        # Test if the visistor keyword goes to the walker definition
        assert "fixtures/goto_def_tests.jac:8:7-8:17" in str(
            lsp.get_definition(goto_defs_file, lspt.Position(4, 14))
        )
        # Test if the here keywrod goes to the node definition
        assert "fixtures/goto_def_tests.jac:0:5-0:13" in str(
            lsp.get_definition(goto_defs_file, lspt.Position(10, 14))
        )
        # Test the SomeNode node inside the visit statement goes to its definition
        assert "fixtures/goto_def_tests.jac:0:5-0:13" in str(
            lsp.get_definition(goto_defs_file, lspt.Position(11, 21))
        )
    finally:
        lsp.shutdown()


def test_go_to_definition_method_manual_impl(examples_abs_path) -> None:
    """Test that the go to definition is correct."""
    lsp = create_server(None, lambda x: "")
    try:
        decldef_file = uris.from_fs_path(
            examples_abs_path("micro/decl_defs_main.impl.jac")
        )
        lsp.type_check_file(decldef_file)
        decldef_main_file = uris.from_fs_path(
            examples_abs_path("micro/decl_defs_main.jac")
        )
        lsp.type_check_file(decldef_main_file)
        lsp.type_check_file(decldef_file)
        assert "decl_defs_main.jac:7:8-7:17" in str(
            lsp.get_definition(decldef_file, lspt.Position(2, 20))
        )
    finally:
        lsp.shutdown()


def test_go_to_definition_md_path(fixture_path) -> None:
    """Test that the go to definition is correct."""
    lsp = create_server(None, fixture_path)
    try:
        import_file = uris.from_fs_path(fixture_path("md_path.jac"))
        lsp.type_check_file(import_file)
        # fmt: off
        # Updated line numbers after fixture reformatting
        positions = [
            (3, 11, "asyncio/__init__.py:0:0-0:0"),
            (6, 17, "concurrent/__init__.py:0:0-0:0"),
            (6, 28, "concurrent/futures/__init__.py:0:0-0:0"),
            (7, 17, "typing.py:0:0-0:0"),
            (9, 18, "compiler/__init__.py:0:0-0:0"),
            (9, 38, "compiler/unitree.py:0:0-0:0"),
            (10, 34, "jac/jaclang/__init__.py:8:3-8:22"),
            (11, 35, "compiler/constant.py:0:0-0:0"),
            (11, 47, "compiler/constant.py:5:0-34:9"),
            (13, 47, "compiler/type_system/type_utils.py:0:0-0:0"),
            (14, 34, "compiler/type_system/__init__.py:0:0-0:0"),
            (18, 5, "compiler/type_system/types.py:64:0-103:7"),  # TypeBase now on line 18
            (20, 34, "compiler/unitree.py:0:0-0:0"),              # UniScopeNode now on line 20
            (20, 48, "compiler/unitree.py:316:0-547:11"),
            (22, 22, "langserve/tests/fixtures/circle.jac:7:5-7:8"),  # RAD now on line 22, fixture line changed too
            (23, 38, "vendor/pygls/uris.py:0:0-0:0"),             # uris now on line 23
            (24, 52, "vendor/pygls/server.py:351:0-615:13"),      # LanguageServer on line 24
            (26, 31, "vendor/lsprotocol/types.py:0:0-0:0"),       # lspt now on line 26
        ]
        # fmt: on

        for line, char, expected in positions:
            assert expected in str(
                lsp.get_definition(import_file, lspt.Position(line - 1, char - 1))
            )
    finally:
        lsp.shutdown()


def test_go_to_definition_connect_filter(passes_main_fixture_abs_path) -> None:
    """Test that the go to definition is correct."""
    lsp = create_server(None, lambda x: "")
    try:
        import_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_connect_filter.jac")
        )
        lsp.type_check_file(import_file)
        # fmt: off
        # Line numbers are 1-indexed for test input, expected results are 0-indexed
        positions = [
            (25, 5, "connect_filter.jac:19:4-19:10"),   # a_inst ref -> a_inst def
            (25, 16, "connect_filter.jac:22:4-22:13"), # edge_inst ref -> edge_inst def
            (25, 32, "connect_filter.jac:20:4-20:10"), # b_inst ref -> b_inst def
            (26, 16, "connect_filter.jac:4:5-4:10"),   # NodeA ref -> NodeA def
            (27, 5, "connect_filter.jac:4:5-4:10"),    # NodeA ref -> NodeA def
            (27, 15, "connect_filter.jac:0:5-0:11"),   # MyEdge ref -> MyEdge def
            (28, 27, "connect_filter.jac:8:5-8:10"),   # NodeB ref -> NodeB def
            (31, 16, "connect_filter.jac:0:5-0:11"),   # MyEdge ref -> MyEdge def
            (31, 25, "connect_filter.jac:1:8-1:10"),   # id ref -> id def
            (35, 12, "connect_filter.jac:13:8-13:13"), # title ref -> title def
            (36, 5, "connect_filter.jac:33:4-33:7"),   # lst ref -> lst def
            (39, 9, "connect_filter.jac:0:5-0:11"),    # MyEdge ref -> MyEdge def
        ]
        # fmt: on

        for line, char, expected in positions:
            assert expected in str(
                lsp.get_definition(import_file, lspt.Position(line - 1, char - 1))
            )
    finally:
        lsp.shutdown()


def test_go_to_definition_atom_trailer(fixture_path) -> None:
    """Test that the go to definition is correct."""
    lsp = create_server(None, fixture_path)
    try:
        import_file = uris.from_fs_path(fixture_path("user.jac"))
        lsp.type_check_file(import_file)
        # fmt: off
        # Line 12: a.try_to_greet().pass_message("World");
        # try_to_greet is at char 7 (1-indexed)
        # pass_message is at char 22 (1-indexed)
        positions = [
            (12, 7, "fixtures/greet.py:6:3-7:15"),    # try_to_greet -> Greet.try_to_greet
            (12, 22, "fixtures/greet.py:1:3-2:15"),   # pass_message -> GreetMessage.pass_message
        ]
        # fmt: on

        for line, char, expected in positions:
            assert expected in str(
                lsp.get_definition(import_file, lspt.Position(line - 1, char - 1))
            )
    finally:
        lsp.shutdown()


def test_missing_mod_warning(fixture_path) -> None:
    """Test that the missing module warning is correct."""
    lsp = create_server(None, fixture_path)
    try:
        import_file = uris.from_fs_path(fixture_path("md_path.jac"))
        lsp.type_check_file(import_file)

        positions = [
            "fixtures/md_path.jac, line 21, col 13: Module not found",  # missing_mod
            "fixtures/md_path.jac, line 27, col 8: Module not found",  # nonexistent_module
        ]
        for idx, expected in enumerate(positions):
            assert expected in str(lsp.warnings_had[idx])
    finally:
        lsp.shutdown()


def test_completion(fixture_path) -> None:
    """Test that the completions are correct."""
    import asyncio

    lsp = create_server(None, fixture_path)
    try:
        base_module_file = uris.from_fs_path(fixture_path("completion_test_err.jac"))
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
                assert completion in str(completions)
    finally:
        lsp.shutdown()


def test_go_to_reference(fixture_path) -> None:
    """Test that the go to reference is correct."""
    lsp = create_server(None, fixture_path)
    try:
        circle_file = uris.from_fs_path(fixture_path("circle.jac"))
        lsp.type_check_file(circle_file)
        # Using 0-indexed line/char (passed directly to lspt.Position)
        # Line 45 = `    c = Circle(RAD);`, char 4 = start of `c`
        # References to `c` found at: 45:4-45:5, 51:23-51:24, 51:75-51:76
        test_cases = [
            (45, 4, ["circle.jac:45:4-45:5", "51:23-51:24", "51:75-51:76"]),
        ]
        for line, char, expected_refs in test_cases:
            references = str(lsp.get_references(circle_file, lspt.Position(line, char)))
            for expected in expected_refs:
                assert expected in references
    finally:
        lsp.shutdown()


def test_go_to_def_import_star(passes_main_fixture_abs_path) -> None:
    """Test that the go to reference is correct."""
    lsp = create_server(None, lambda x: "")
    try:
        import_star_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_import_star/main.jac")
        )

        lsp.type_check_file(import_star_file)
        # fmt: off
        positions = [
            (4, 16, "import_star_mod_py.py:0:0-2:2"),
            (4, 21, "import_star_mod_py.py:1:3-2:6"),
            (5, 16, "import_star_mod_jac.jac:0:4-0:7"),
            (5, 22, "import_star_mod_jac.jac:1:8-1:11"),
        ]
        # fmt: on

        for line, char, expected in positions:
            assert expected in str(
                lsp.get_definition(import_star_file, lspt.Position(line - 1, char - 1))
            )
    finally:
        lsp.shutdown()
