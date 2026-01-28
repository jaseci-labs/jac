import contextlib
import inspect
import os
import sys
from collections.abc import Callable, Generator
from pathlib import Path

import pytest

from jaclang.langserve.worker import WorkerConfig, WorkerManager


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


# Track all clients created during a test for cleanup
_active_clients: list["LspTestClient"] = []


class LspTestClient:
    """Test client that communicates with a real worker process.

    Simulates the real LSP two-process architecture:
    main process sends requests via queues, worker process handles
    compilation and LSP queries, sends responses back.
    """

    def __init__(self) -> None:
        config = WorkerConfig.default()
        self._wm = WorkerManager(_config=config)
        self._wm.start()
        self._last_compile_response: dict | None = None

    def compile_file(self, file_path: str) -> dict:
        """Compile a file and block until the worker finishes.

        Args:
            file_path: Absolute filesystem path to the .jac file.

        Returns:
            The compilation response dict from the worker.
        """
        self._wm.compile_file(file_path)
        # Block until worker sends back compilation result
        response = self._wm._response_queue.get(timeout=60)
        self._wm._handle_response(response)
        self._last_compile_response = response
        return response

    def hover(self, file_path: str, line: int, character: int) -> dict | None:
        """Request hover info at a position. Returns response dict or None."""
        return self._wm.request_hover(file_path, line, character)

    def definition(self, file_path: str, line: int, character: int) -> dict | None:
        """Request go-to-definition at a position. Returns response dict or None."""
        return self._wm.request_definition(file_path, line, character)

    def references(self, file_path: str, line: int, character: int) -> dict | None:
        """Request find-references at a position. Returns response dict or None."""
        return self._wm.request_references(file_path, line, character)

    def outline(self, file_path: str) -> dict | None:
        """Request document outline. Returns response dict or None."""
        return self._wm.request_outline(file_path)

    def completion(
        self, file_path: str, line: int, character: int, trigger: str = "."
    ) -> dict | None:
        """Request completions at a position. Returns response dict or None."""
        return self._wm.request_completion(
            file_path, line, character, trigger=trigger
        )

    def shutdown(self) -> None:
        """Stop the worker process."""
        self._wm.stop()


def fmt_location(resp: dict | None) -> str:
    """Format a definition response as 'uri:line:char-endline:endchar'.

    Matches the format used in test assertions like:
        "fixtures/circle_pure.impl.jac:8:5-8:19"
    """
    if resp is None:
        return ""
    loc = resp.get("location")
    if loc is None:
        return ""
    return (
        f"{loc['uri']}:{loc['line']}:{loc['character']}"
        f"-{loc['end_line']}:{loc['end_character']}"
    )


def fmt_locations(resp: dict | None) -> str:
    """Format a references response (list of locations) as a string."""
    if resp is None:
        return "[]"
    locs = resp.get("locations", [])
    parts = []
    for loc in locs:
        parts.append(
            f"{loc['uri']}:{loc['line']}:{loc['character']}"
            f"-{loc['end_line']}:{loc['end_character']}"
        )
    return str(parts)


def fmt_warning(w: dict) -> str:
    """Format a diagnostics warning dict as a readable string."""
    return f"{w.get('mod_path', '')}, line {w.get('line', 0)}, col {w.get('col', 0)}: {w.get('message', '')}"


def create_client() -> LspTestClient:
    """Create an LspTestClient and track it for cleanup."""
    client = LspTestClient()
    _active_clients.append(client)
    return client


@pytest.fixture(autouse=True)
def reset_jac_machine(fresh_jac_context: Path) -> Generator[None, None, None]:
    """Reset Jac machine before each test to avoid state pollution."""
    _clear_jac_modules()
    _active_clients.clear()
    yield
    for client in _active_clients:
        with contextlib.suppress(Exception):
            client.shutdown()
    _active_clients.clear()
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


def test_impl_stay_connected(fixture_path: Callable[[str], str]) -> None:
    """Test that hover works across stub and impl files."""
    client = create_client()
    try:
        circle_path = fixture_path("circle_pure.jac")
        circle_impl_path = fixture_path("circle_pure.impl.jac")

        client.compile_file(circle_path)
        resp = client.hover(circle_path, 20, 8)
        assert resp is not None and resp.get("hover_text"), (
            f"Expected hover text, got: {resp}"
        )
        assert "Circle class inherits from Shape." in resp["hover_text"]

        client.compile_file(circle_impl_path)
        resp = client.hover(circle_impl_path, 8, 11)
        assert resp is not None and resp.get("hover_text"), (
            f"Expected hover text, got: {resp}"
        )
        assert (
            "ability) calculate_area\n( radius : float ) -> float"
            in resp["hover_text"].replace("'", "")
        )
    finally:
        client.shutdown()


def test_impl_auto_discover(fixture_path: Callable[[str], str]) -> None:
    """Test that impl files auto-discover their parent module."""
    client = create_client()
    try:
        circle_impl_path = fixture_path("circle_pure.impl.jac")
        client.compile_file(circle_impl_path)

        resp = client.hover(circle_impl_path, 8, 11)
        assert resp is not None and resp.get("hover_text"), (
            f"Expected hover text, got: {resp}"
        )
        assert (
            "(public ability) calculate_area\n( radius : float ) -> float"
            in resp["hover_text"].replace("'", "")
        )
    finally:
        client.shutdown()


def test_outline_symbols(fixture_path: Callable[[str], str]) -> None:
    """Test that the outline symbols are correct."""
    client = create_client()
    try:
        circle_path = fixture_path("circle_pure.jac")
        client.compile_file(circle_path)

        resp = client.outline(circle_path)
        assert resp is not None
        symbols = resp.get("symbols", [])
        assert len(symbols) == 8, f"Expected 8 symbols, got {len(symbols)}: {symbols}"
    finally:
        client.shutdown()


def test_go_to_definition(fixture_path: Callable[[str], str]) -> None:
    """Test that the go to definition is correct."""
    client = create_client()
    try:
        circle_path = fixture_path("circle_pure.jac")
        client.compile_file(circle_path)

        assert "fixtures/circle_pure.impl.jac:8:5-8:19" in fmt_location(
            client.definition(circle_path, 9, 16)
        )
        assert "fixtures/circle_pure.jac:13:11-13:16" in fmt_location(
            client.definition(circle_path, 20, 16)
        )

        goto_defs_path = fixture_path("goto_def_tests.jac")
        client.compile_file(goto_defs_path)

        # Test if the visitor keyword goes to the walker definition
        assert "fixtures/goto_def_tests.jac:8:7-8:17" in fmt_location(
            client.definition(goto_defs_path, 4, 14)
        )
        # Test if the here keyword goes to the node definition
        assert "fixtures/goto_def_tests.jac:0:5-0:13" in fmt_location(
            client.definition(goto_defs_path, 10, 14)
        )
        # Test the SomeNode node inside the visit statement goes to its definition
        assert "fixtures/goto_def_tests.jac:0:5-0:13" in fmt_location(
            client.definition(goto_defs_path, 11, 21)
        )
        # Test when the left of assignment is a list
        assert "fixtures/goto_def_tests.jac:16:5-16:8" in fmt_location(
            client.definition(goto_defs_path, 17, 10)
        )
    finally:
        client.shutdown()


def test_go_to_definition_method_manual_impl(
    examples_abs_path: Callable[[str], str],
) -> None:
    """Test that the go to definition is correct."""
    client = create_client()
    try:
        decldef_impl_path = examples_abs_path("micro/decl_defs_main.impl.jac")
        decldef_main_path = examples_abs_path("micro/decl_defs_main.jac")

        client.compile_file(decldef_impl_path)
        client.compile_file(decldef_main_path)
        client.compile_file(decldef_impl_path)

        assert "decl_defs_main.jac:7:8-7:17" in fmt_location(
            client.definition(decldef_impl_path, 2, 20)
        )
    finally:
        client.shutdown()


def test_go_to_definition_md_path(fixture_path: Callable[[str], str]) -> None:
    """Test that the go to definition is correct."""
    client = create_client()
    try:
        import_path = fixture_path("md_path.jac")
        client.compile_file(import_path)

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
            result = fmt_location(
                client.definition(import_path, line - 1, char - 1)
            )
            assert expected in result, (
                f"Expected '{expected}' at ({line},{char}), got: {result}"
            )
    finally:
        client.shutdown()


def test_go_to_definition_connect_filter(
    passes_main_fixture_abs_path: Callable[[str], str],
) -> None:
    """Test that the go to definition is correct."""
    client = create_client()
    try:
        import_path = passes_main_fixture_abs_path("checker_connect_filter.jac")
        client.compile_file(import_path)

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
            result = fmt_location(
                client.definition(import_path, line - 1, char - 1)
            )
            assert expected in result, (
                f"Expected '{expected}' at ({line},{char}), got: {result}"
            )
    finally:
        client.shutdown()


def test_go_to_definition_atom_trailer(fixture_path: Callable[[str], str]) -> None:
    """Test that the go to definition is correct."""
    client = create_client()
    try:
        import_path = fixture_path("user.jac")
        client.compile_file(import_path)

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
            result = fmt_location(
                client.definition(import_path, line - 1, char - 1)
            )
            assert expected in result, (
                f"Expected '{expected}' at ({line},{char}), got: {result}"
            )
    finally:
        client.shutdown()


def test_missing_mod_warning(fixture_path: Callable[[str], str]) -> None:
    """Test that the missing module warning is correct."""
    client = create_client()
    try:
        import_path = fixture_path("md_path.jac")
        response = client.compile_file(import_path)

        warnings = response.get("diagnostics", {}).get("warnings", [])
        warnings_str = [fmt_warning(w) for w in warnings]

        expected_warnings = [
            "fixtures/md_path.jac, line 21, col 13: Module not found",  # missing_mod
            "fixtures/md_path.jac, line 27, col 8: Module not found",  # nonexistent_module
        ]
        for expected in expected_warnings:
            assert any(expected in w for w in warnings_str), (
                f"Expected warning '{expected}' not found in {warnings_str}"
            )
    finally:
        client.shutdown()


def test_completion(fixture_path: Callable[[str], str]) -> None:
    """Test that the completions are correct."""
    client = create_client()
    try:
        base_module_path = fixture_path("completion_test_err.jac")
        client.compile_file(base_module_path)

        test_cases = [
            # (line, char, trigger, expected_labels)
            (8, 8, ".", ["bar", "baz"]),
        ]
        for line, char, trigger, expected in test_cases:
            resp = client.completion(base_module_path, line, char, trigger=trigger)
            assert resp is not None, f"Expected completion response at ({line},{char})"
            items = resp.get("items", [])
            for label in expected:
                assert label in str(items), (
                    f"Expected '{label}' in completions, got: {items}"
                )
    finally:
        client.shutdown()


def test_go_to_reference(fixture_path: Callable[[str], str]) -> None:
    """Test that the go to reference is correct."""
    client = create_client()
    try:
        circle_path = fixture_path("circle.jac")
        client.compile_file(circle_path)

        # Using 0-indexed line/char
        # Line 45 = `    c = Circle(RAD);`, char 4 = start of `c`
        # References to `c` found at: 45:4-45:5, 51:23-51:24, 51:75-51:76
        test_cases = [
            (45, 4, ["circle.jac:45:4-45:5", "51:23-51:24", "51:75-51:76"]),
        ]
        for line, char, expected_refs in test_cases:
            result = fmt_locations(client.references(circle_path, line, char))
            for expected in expected_refs:
                assert expected in result, (
                    f"Expected '{expected}' in references, got: {result}"
                )
    finally:
        client.shutdown()


def test_go_to_def_import_star(
    passes_main_fixture_abs_path: Callable[[str], str],
) -> None:
    """Test that go to definition works with import star."""
    client = create_client()
    try:
        import_star_path = passes_main_fixture_abs_path(
            "checker_import_star/main.jac"
        )
        client.compile_file(import_star_path)

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
            result = fmt_location(
                client.definition(import_star_path, line - 1, char - 1)
            )
            assert expected in result, (
                f"Expected '{expected}' at ({line},{char}), got: {result}"
            )
    finally:
        client.shutdown()


def test_stub_impl_hover_and_goto_def(fixture_path: Callable[[str], str]) -> None:
    """Test hover and go-to-definition on method stubs and impl files.

    This tests:
    1. Hover on type annotations (self: MyServer) in method stubs works
    2. Hover on type annotations in impl files works
    3. Go-to-definition on method stubs (init, process) navigates to impl file
    """
    client = create_client()
    try:
        test_path = fixture_path("stub_hover.jac")
        impl_file_path = fixture_path("stub_hover.impl.jac")
        client.compile_file(test_path)

        # ================================================================
        # Test hover on type annotations in stub file
        # ================================================================

        # Hover on MyServer in: def process(self: MyServer, data: str) -> str;
        # Line 13 (0-indexed: 12), MyServer starts at column 22
        resp = client.hover(test_path, 12, 24)
        assert resp is not None and resp.get("hover_text"), (
            "Hover should return info for self type annotation"
        )
        assert "MyServer" in resp["hover_text"], (
            f"Hover should show MyServer info, got: {resp['hover_text']}"
        )

        # Hover on MyServer in: def handle(self: MyServer, request: int) -> None;
        # Line 14 (0-indexed: 13), MyServer starts at column 21
        resp2 = client.hover(test_path, 13, 23)
        assert resp2 is not None and resp2.get("hover_text"), (
            "Hover should return info for self type annotation"
        )
        assert "MyServer" in resp2["hover_text"], (
            f"Hover should show MyServer info, got: {resp2['hover_text']}"
        )

        # ================================================================
        # Test hover on type annotations in impl file
        # ================================================================

        # Hover on MyServer in impl file: impl MyServer.handle(self: MyServer, ...)
        # Line 15 (0-indexed: 14), MyServer in self type annotation starts at column 27
        client.compile_file(impl_file_path)
        resp3 = client.hover(impl_file_path, 14, 29)
        assert resp3 is not None and resp3.get("hover_text"), (
            "Hover should return info for self type in impl file"
        )
        assert "MyServer" in resp3["hover_text"], (
            f"Hover should show MyServer info in impl, got: {resp3['hover_text']}"
        )

        # ================================================================
        # Test go-to-definition from stub to impl
        # ================================================================

        # Goto def on 'init' stub (line 12, col 10) -> should go to impl line 5
        defn = client.definition(test_path, 11, 10)
        assert defn is not None, "Definition should be found for init stub"
        loc = defn.get("location")
        assert loc is not None, "Definition location should not be None"
        assert impl_file_path in loc["uri"], (
            f"Definition should point to impl file, got: {loc['uri']}"
        )
        assert loc["line"] == 4, (
            f"Definition should be at line 5 (0-indexed: 4), got: {loc['line']}"
        )

        # Goto def on 'process' stub (line 13, col 10) -> should go to impl line 11
        defn2 = client.definition(test_path, 12, 10)
        assert defn2 is not None, "Definition should be found for process stub"
        loc2 = defn2.get("location")
        assert loc2 is not None, "Definition location should not be None"
        assert impl_file_path in loc2["uri"], (
            f"Definition should point to impl file, got: {loc2['uri']}"
        )
        assert loc2["line"] == 10, (
            f"Definition should be at line 11 (0-indexed: 10), got: {loc2['line']}"
        )

        # ================================================================
        # Test go-to-definition for static field access (MyServer._counter)
        # ================================================================

        # Goto def on '_counter' in 'MyServer._counter' (line 7, col 31)
        # Should go to static has declaration in stub file (line 10)
        defn3 = client.definition(impl_file_path, 6, 33)
        assert defn3 is not None, "Definition should be found for static field _counter"
        loc3 = defn3.get("location")
        assert loc3 is not None, "Definition location should not be None"
        assert "stub_hover.jac" in loc3["uri"], (
            f"Definition should point to declaration file, got: {loc3['uri']}"
        )
        assert loc3["line"] == 9, (
            f"Definition should be at line 10 (0-indexed: 9), got: {loc3['line']}"
        )

        # ================================================================
        # Test hover and go-to-definition for Python type methods in impl bodies
        # ================================================================

        # Hover on 'start' in 'self.worker.start()' (line 23, col 17)
        hover_start = client.hover(impl_file_path, 22, 17)
        assert hover_start is not None and hover_start.get("hover_text"), (
            "Hover should return info for Thread.start method in impl body"
        )

        # Hover on 'worker' in 'self.worker.start()' (line 23, col 10)
        hover_worker = client.hover(impl_file_path, 22, 10)
        assert hover_worker is not None and hover_worker.get("hover_text"), (
            "Hover should return info for worker field in impl body"
        )
        assert "Thread" in hover_worker["hover_text"], (
            f"Hover should show Thread type, got: {hover_worker['hover_text']}"
        )

        # Go-to-definition on 'start' should go to Python threading module
        defn_start = client.definition(impl_file_path, 22, 17)
        assert defn_start is not None, (
            "Definition should be found for Thread.start method"
        )
        loc_start = defn_start.get("location")
        assert loc_start is not None, "Definition location should not be None"
        assert "threading" in loc_start["uri"], (
            f"Definition should point to threading module, got: {loc_start['uri']}"
        )
    finally:
        client.shutdown()


def test_go_to_definition_impl_body_self_attr(
    passes_main_fixture_abs_path: Callable[[str], str],
) -> None:
    """Test go-to-definition for self.attr in impl bodies navigates to has declaration.

    This tests the fix for symbol resolution in .impl.jac files, where clicking on
    'self.count' in an impl body should navigate to the 'has count' declaration
    in the base .jac file.
    """
    client = create_client()
    try:
        impl_path = passes_main_fixture_abs_path(
            "impl_symbol_resolution.impl.jac"
        )
        client.compile_file(impl_path)

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
            result = fmt_location(
                client.definition(impl_path, line - 1, char - 1)
            )
            assert result is not None and result != "", (
                f"Expected definition at line {line}, char {char}, got None"
            )
            assert expected in result, (
                f"Expected '{expected}' in definition for line {line}, char {char}, "
                f"got: {result}"
            )
    finally:
        client.shutdown()
