import contextlib
import inspect
import os
import sys
from collections.abc import Callable, Generator
from dataclasses import dataclass
from pathlib import Path

import lsprotocol.types as lspt
import pytest

from jaclang.langserve.engine import JacLangServer
from jaclang.vendor.pygls import uris
from jaclang.vendor.pygls.workspace import Workspace


def _clear_jac_modules() -> None:
    """Clear jac-compiled modules from sys.modules."""
    jac_modules_to_clear = [
        k
        for k in list(sys.modules.keys())
        if not k.startswith(("jaclang", "test", "_"))
        and hasattr(sys.modules.get(k), "__jac_mod__")
    ]
    for mod in jac_modules_to_clear:
        sys.modules.pop(mod, None)


# Track all servers created during a test for cleanup
_active_servers: list[JacLangServer] = []


@pytest.fixture(autouse=True)
def reset_jac_machine(fresh_jac_context: Path) -> Generator[None, None, None]:
    """Reset Jac machine before each test to avoid state pollution."""
    _clear_jac_modules()
    _active_servers.clear()
    yield
    # Clear type system state from all servers created during the test
    for server in _active_servers:
        # Ensure worker thread is stopped to avoid cross-test interference.
        with contextlib.suppress(Exception):
            server.shutdown()
        server.clear_type_system(clear_hub=True)
    _active_servers.clear()
    _clear_jac_modules()


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
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
def examples_abs_path() -> Callable[[str], str]:
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
def passes_main_fixture_abs_path() -> Callable[[str], str]:
    """Get absolute path of a fixture from compiler passes main fixtures directory."""
    from pathlib import Path

    def _passes_main_fixture_abs_path(file: str) -> str:
        # tests/langserve/test_server.py -> tests/compiler/passes/main/fixtures/
        tests_dir = Path(__file__).parent.parent
        file_path = tests_dir / "compiler" / "passes" / "main" / "fixtures" / file
        return str(file_path.resolve())

    return _passes_main_fixture_abs_path


def create_server(
    workspace_path: str | None, fixture_path_func: Callable[[str], str]
) -> JacLangServer:
    """Create a JacLangServer wired to the given workspace."""
    lsp = JacLangServer()
    workspace_root = workspace_path or fixture_path_func("")
    workspace = Workspace(workspace_root, lsp)
    lsp.lsp._workspace = workspace
    # Track server for cleanup in reset_jac_machine fixture
    _active_servers.append(lsp)
    return lsp


def test_impl_stay_connected(fixture_path: Callable[[str], str]) -> None:
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
            "ability) calculate_area\n( radius : float ) -> float"
            in lsp.get_hover_info(circle_impl_file, pos).contents.value.replace("'", "")
        )
    finally:
        lsp.shutdown()


def test_impl_auto_discover(fixture_path: Callable[[str], str]) -> None:
    """Test that the server doesn't run if there is a syntax error."""
    lsp = create_server(None, fixture_path)
    try:
        circle_impl_file = uris.from_fs_path(fixture_path("circle_pure.impl.jac"))
        lsp.type_check_file(circle_impl_file)
        pos = lspt.Position(8, 11)
        assert (
            "(public ability) calculate_area\n( radius : float ) -> float"
            in lsp.get_hover_info(circle_impl_file, pos).contents.value.replace("'", "")
        )
    finally:
        lsp.shutdown()


def test_outline_symbols(fixture_path: Callable[[str], str]) -> None:
    """Test that the outline symbols are correct."""
    lsp = create_server(None, fixture_path)
    try:
        circle_file = uris.from_fs_path(fixture_path("circle_pure.jac"))
        lsp.type_check_file(circle_file)
        assert len(lsp.get_outline(circle_file)) == 8
    finally:
        lsp.shutdown()


def test_go_to_definition(fixture_path: Callable[[str], str]) -> None:
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

        # Test when the left of assignment is a list.
        assert "fixtures/goto_def_tests.jac:16:5-16:8" in str(
            lsp.get_definition(goto_defs_file, lspt.Position(17, 10))
        )

    finally:
        lsp.shutdown()


def test_go_to_definition_method_manual_impl(
    examples_abs_path: Callable[[str], str],
) -> None:
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


def test_go_to_definition_md_path(fixture_path: Callable[[str], str]) -> None:
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
            (9, 18, "jaclang/pycore/__init__.py:0:0-0:0"),
            (9, 25, "jaclang/pycore/unitree.py:0:0-0:0"),
            (10, 34, "jac/jaclang/__init__.py:19:3-19:22"),
            (11, 35, "jaclang/pycore/constant.py:0:0-0:0"),
            (11, 47, "jaclang/pycore/constant.py:5:0-34:9"),
            (13, 47, "jaclang/compiler/type_system/type_utils.jac:0:0-0:0"),
            (14, 34, "jaclang/compiler/type_system/__init__.py:0:0-0:0"),
            (18, 5, "compiler/type_system/types.jac:67:4-67:12"),  # TypeBase now on line 18
            (20, 34, "jaclang/pycore/unitree.py:0:0-0:0"),              # UniScopeNode now on line 20
            # (20, 48, "compiler/unitree.py:335:0-566:11"),
            (22, 22, "tests/langserve/fixtures/circle.jac:7:5-7:8"),  # RAD now on line 22, fixture line changed too
            (23, 38, "jaclang/vendor/pygls/uris.py:0:0-0:0"),             # uris now on line 23
            (24, 52, "jaclang/vendor/pygls/server.py:351:0-615:13"),      # LanguageServer on line 24
            (26, 31, "jaclang/vendor/lsprotocol/types.py:0:0-0:0"),       # lspt now on line 26
        ]
        # fmt: on

        for line, char, expected in positions:
            assert expected in str(
                lsp.get_definition(import_file, lspt.Position(line - 1, char - 1))
            )
    finally:
        lsp.shutdown()


def test_go_to_definition_connect_filter(
    passes_main_fixture_abs_path: Callable[[str], str],
) -> None:
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


def test_go_to_definition_atom_trailer(fixture_path: Callable[[str], str]) -> None:
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


def test_missing_mod_warning(fixture_path: Callable[[str], str]) -> None:
    """Test that the missing module warning is correct."""
    lsp = create_server(None, fixture_path)
    try:
        import_file = uris.from_fs_path(fixture_path("md_path.jac"))
        lsp.type_check_file(import_file)

        expected_warnings = [
            "fixtures/md_path.jac, line 21, col 13: Module not found",  # missing_mod
            "fixtures/md_path.jac, line 27, col 8: Module not found",  # nonexistent_module
        ]
        warnings_str = [str(w) for w in lsp.warnings_had]
        for expected in expected_warnings:
            assert any(expected in w for w in warnings_str), (
                f"Expected warning '{expected}' not found in {warnings_str}"
            )
    finally:
        lsp.shutdown()


def test_completion(fixture_path: Callable[[str], str]) -> None:
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


def test_go_to_reference(fixture_path: Callable[[str], str]) -> None:
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


def test_go_to_def_import_star(
    passes_main_fixture_abs_path: Callable[[str], str],
) -> None:
    """Test that the go to reference is correct."""
    lsp = create_server(None, lambda x: "")
    try:
        import_star_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_import_star/main.jac")
        )

        lsp.type_check_file(import_star_file)
        # fmt: off
        positions = [
            (5, 16, "import_star_mod_py.py:0:0-2:2"),
            (5, 21, "import_star_mod_py.py:1:3-2:6"),
            (6, 16, "import_star_mod_jac.jac:0:4-0:7"),
            (6, 22, "import_star_mod_jac.jac:1:8-1:11"),
            (8, 25, "_pydatetime.py:"),
        ]
        # fmt: on

        for line, char, expected in positions:
            assert expected in str(
                lsp.get_definition(import_star_file, lspt.Position(line - 1, char - 1))
            )
    finally:
        lsp.shutdown()


def test_stub_impl_hover_and_goto_def(fixture_path: Callable[[str], str]) -> None:
    """Test hover and go-to-definition on method stubs and impl files.

    This tests:
    1. Hover on type annotations (self: MyServer) in method stubs works
    2. Hover on type annotations in impl files works
    3. Go-to-definition on method stubs (init, process) navigates to impl file
    """
    lsp = create_server(None, fixture_path)
    try:
        test_file = uris.from_fs_path(fixture_path("stub_hover.jac"))
        impl_file_path = fixture_path("stub_hover.impl.jac")
        impl_file = uris.from_fs_path(impl_file_path)
        lsp.type_check_file(test_file)

        # ================================================================
        # Test hover on type annotations in stub file
        # ================================================================

        # Hover on MyServer in: def process(self: MyServer, data: str) -> str;
        # Line 13 (0-indexed: 12), MyServer starts at column 22
        hover = lsp.get_hover_info(test_file, lspt.Position(12, 24))
        assert hover is not None, "Hover should return info for self type annotation"
        assert "MyServer" in hover.contents.value, (
            f"Hover should show MyServer info, got: {hover.contents.value}"
        )

        # Hover on MyServer in: def handle(self: MyServer, request: int) -> None;
        # Line 14 (0-indexed: 13), MyServer starts at column 21
        hover2 = lsp.get_hover_info(test_file, lspt.Position(13, 23))
        assert hover2 is not None, "Hover should return info for self type annotation"
        assert "MyServer" in hover2.contents.value, (
            f"Hover should show MyServer info, got: {hover2.contents.value}"
        )

        # ================================================================
        # Test hover on type annotations in impl file
        # ================================================================

        # Hover on MyServer in impl file: impl MyServer.handle(self: MyServer, ...)
        # Line 15 (0-indexed: 14), MyServer in self type annotation starts at column 27
        lsp.type_check_file(impl_file)
        hover3 = lsp.get_hover_info(impl_file, lspt.Position(14, 29))
        assert hover3 is not None, "Hover should return info for self type in impl file"
        assert "MyServer" in hover3.contents.value, (
            f"Hover should show MyServer info in impl, got: {hover3.contents.value}"
        )

        # ================================================================
        # Test go-to-definition from stub to impl
        # ================================================================

        # Goto def on 'init' stub (line 12, col 10) -> should go to impl line 5
        # def init(self: MyServer, name: str) -> None;
        defn = lsp.get_definition(test_file, lspt.Position(11, 10))
        assert defn is not None, "Definition should be found for init stub"
        assert impl_file_path in defn.uri, (
            f"Definition should point to impl file, got: {defn.uri}"
        )
        assert defn.range.start.line == 4, (
            f"Definition should be at line 5 (0-indexed: 4), got: {defn.range.start.line}"
        )

        # Goto def on 'process' stub (line 13, col 10) -> should go to impl line 11
        # def process(self: MyServer, data: str) -> str;
        defn2 = lsp.get_definition(test_file, lspt.Position(12, 10))
        assert defn2 is not None, "Definition should be found for process stub"
        assert impl_file_path in defn2.uri, (
            f"Definition should point to impl file, got: {defn2.uri}"
        )
        assert defn2.range.start.line == 10, (
            f"Definition should be at line 11 (0-indexed: 10), got: {defn2.range.start.line}"
        )

        # ================================================================
        # Test go-to-definition for static field access (MyServer._counter)
        # ================================================================

        # Goto def on '_counter' in 'MyServer._counter' (line 7, col 31)
        # Should go to static has declaration in stub file (line 10)
        defn3 = lsp.get_definition(impl_file, lspt.Position(6, 33))
        assert defn3 is not None, "Definition should be found for static field _counter"
        assert "stub_hover.jac" in defn3.uri, (
            f"Definition should point to declaration file, got: {defn3.uri}"
        )
        assert defn3.range.start.line == 9, (
            f"Definition should be at line 10 (0-indexed: 9), got: {defn3.range.start.line}"
        )

        # ================================================================
        # Test hover and go-to-definition for Python type methods in impl bodies
        # This tests the fix for type resolution in impl bodies where
        # Python type methods (like Thread.start) should be properly resolved.
        # ================================================================

        # Hover on 'start' in 'self.worker.start()' (line 23, col 17)
        # Line 23 (0-indexed: 22): `    self.worker.start();`
        # 'start' starts at column 17 (0-indexed: 16)
        hover_start = lsp.get_hover_info(impl_file, lspt.Position(22, 17))
        assert hover_start is not None, (
            "Hover should return info for Thread.start method in impl body"
        )

        # Hover on 'worker' in 'self.worker.start()' (line 23, col 10)
        hover_worker = lsp.get_hover_info(impl_file, lspt.Position(22, 10))
        assert hover_worker is not None, (
            "Hover should return info for worker field in impl body"
        )
        assert "Thread" in hover_worker.contents.value, (
            f"Hover should show Thread type, got: {hover_worker.contents.value}"
        )

        # Go-to-definition on 'start' should go to Python threading module
        defn_start = lsp.get_definition(impl_file, lspt.Position(22, 17))
        assert defn_start is not None, (
            "Definition should be found for Thread.start method"
        )
        assert "threading" in defn_start.uri, (
            f"Definition should point to threading module, got: {defn_start.uri}"
        )

    finally:
        lsp.shutdown()


def test_go_to_definition_impl_body_self_attr(
    passes_main_fixture_abs_path: Callable[[str], str],
) -> None:
    """Test go-to-definition for self.attr in impl bodies navigates to has declaration.

    This tests the fix for symbol resolution in .impl.jac files, where clicking on
    'self.count' in an impl body should navigate to the 'has count' declaration
    in the base .jac file.
    """
    lsp = create_server(None, lambda x: "")
    try:
        impl_file = uris.from_fs_path(
            passes_main_fixture_abs_path("impl_symbol_resolution.impl.jac")
        )
        lsp.type_check_file(impl_file)

        # fmt: off
        # Test positions in impl_symbol_resolution.impl.jac (1-indexed for test input):
        # Line 5: `    return self.count;`
        #         - 'count' starts at column 17
        # Line 9: `    return f"{self.name}: {self.count}";`
        #         - 'name' is at column 21, 'count' is at column 34
        #
        # Expected targets in impl_symbol_resolution.jac (0-indexed in LSP output):
        # Line 3 (0-indexed): `    has count: int = 0,` -> count at 3:8-3:13
        # Line 4 (0-indexed): `        name: str = "default";` -> name at 4:8-4:12
        positions = [
            # (impl_line, impl_char, expected_target)
            (5, 17, "impl_symbol_resolution.jac:3:8-3:13"),   # count in `return self.count`
            (9, 21, "impl_symbol_resolution.jac:4:8-4:12"),   # name in f-string
            (9, 34, "impl_symbol_resolution.jac:3:8-3:13"),   # count in f-string
        ]
        # fmt: on

        for line, char, expected in positions:
            result = lsp.get_definition(impl_file, lspt.Position(line - 1, char - 1))
            assert result is not None, (
                f"Expected definition at line {line}, char {char}, got None"
            )
            assert expected in str(result), (
                f"Expected '{expected}' in definition for line {line}, char {char}, "
                f"got: {result}"
            )
    finally:
        lsp.shutdown()


def test_go_to_definition_directory_import(
    fixture_path: Callable[[str], str],
) -> None:
    """Test go-to-definition for directory imports (namespace and regular packages)."""
    lsp = create_server(None, fixture_path)
    try:
        import_file = uris.from_fs_path(fixture_path("local_imports/main.jac"))
        lsp.type_check_file(import_file)

        # fmt: off
        # Line 1: import from mypkg_ns.my_mod { add }
        # Line 2: import from mypkg_reg.my_mod { sub }
        positions = [
            # Regular package: clicking 'mypkg_reg' -> points to __init__.jac
            (2, 18, "local_imports/mypkg_reg/__init__.jac:0:0-0:0"),
             # Regular package: clicking 'my_mod' -> points to my_mod.jac
            (2, 28, "local_imports/mypkg_reg/my_mod.jac:0:0-0:0"),

            # Namespace package: clicking 'mypkg_ns'
            # This should not resolve to anything as it is a directory

            # resolution inside the namespace package 'my_mod' -> should point to the my_mod.jac
            (1, 28, "local_imports/mypkg_ns/my_mod.jac:0:0-0:0"),
        ]
        # fmt: on

        for line, char, expected in positions:
            # We use try-except to detect if get_definition crashes (though it shouldn't usually raise)
            def_loc = lsp.get_definition(import_file, lspt.Position(line - 1, char - 1))
            assert def_loc is not None, (
                f"Definition at line {line}, col {char} not found"
            )
            assert expected in str(def_loc), (
                f"Expected '{expected}' in definition for line {line}, char {char}, "
                f"got: {def_loc}"
            )
    finally:
        lsp.shutdown()
