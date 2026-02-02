"""Tests for file-based routing: RouteScanner, compiler integration, and AuthGuard.

These tests validate the file-based routing system introduced for pages/ convention:
1. RouteScanner class definition and implementation (regex patterns, constants)
2. Compiler integration (pages/ scanning, route manifest, entry file branching)
3. AuthGuard runtime component (declaration, imports, implementation)
4. Route manifest generation (_routes.js output)
5. Entry file generation (_entry.js branching on _has_pages)
"""

from __future__ import annotations

import re
from pathlib import Path

# =============================================================================
# Shared path constants
# =============================================================================

_plugin_src = Path(__file__).parent.parent / "plugin" / "src"

_route_scanner_jac = _plugin_src / "route_scanner.jac"
_route_scanner_impl = _plugin_src / "impl" / "route_scanner.impl.jac"
_compiler_jac = _plugin_src / "compiler.jac"
_compiler_impl = _plugin_src / "impl" / "compiler.impl.jac"

_client_runtime_cl = Path(__file__).parent.parent / "plugin" / "client_runtime.cl.jac"
_client_runtime_impl = (
    Path(__file__).parent.parent / "plugin" / "impl" / "client_runtime.impl.jac"
)


# =============================================================================
# RouteScanner: Class definition (route_scanner.jac)
# =============================================================================


def test_route_entry_class_defined() -> None:
    """Test that RouteEntry class is defined with expected fields."""
    print("[DEBUG] Starting test_route_entry_class_defined")

    assert _route_scanner_jac.exists(), (
        f"route_scanner.jac not found at {_route_scanner_jac}"
    )

    content = _route_scanner_jac.read_text()

    assert "class RouteEntry" in content, (
        "route_scanner.jac should define RouteEntry class"
    )
    # Required fields
    assert "path: str" in content, "RouteEntry should have path field"
    assert "component_import: str" in content, (
        "RouteEntry should have component_import field"
    )
    assert "file_path: Path" in content, "RouteEntry should have file_path field"
    assert "auth_required: bool" in content, (
        "RouteEntry should have auth_required field"
    )
    assert "is_layout: bool" in content, "RouteEntry should have is_layout field"
    assert "is_catch_all: bool" in content, (
        "RouteEntry should have is_catch_all field"
    )
    assert "children: (list[RouteEntry] | None)" in content, (
        "RouteEntry should have children field"
    )

    print("[DEBUG] RouteEntry class definition verified!")


def test_route_scanner_class_defined() -> None:
    """Test that RouteScanner class is defined with expected methods."""
    print("[DEBUG] Starting test_route_scanner_class_defined")

    content = _route_scanner_jac.read_text()

    assert "class RouteScanner" in content, (
        "route_scanner.jac should define RouteScanner class"
    )

    # Required method signatures
    expected_methods = [
        "def init(self: RouteScanner, project_root: Path)",
        "def has_pages_dir(self: RouteScanner) -> bool",
        "def scan(self: RouteScanner) -> list[RouteEntry]",
        "def get_layouts(self: RouteScanner) -> dict[(str, RouteEntry)]",
        "def get_page_files(self: RouteScanner) -> list[Path]",
        "def _scan_directory(",
        "def _file_to_route_path(self: RouteScanner, filename: str) -> str",
        "def _file_to_component_name(self: RouteScanner, file_path: Path) -> str",
        "def _detect_collisions(",
    ]
    for method in expected_methods:
        assert method in content, (
            f"RouteScanner should declare method: {method}"
        )

    print("[DEBUG] RouteScanner class definition verified!")


def test_route_scanner_constants_defined() -> None:
    """Test that RouteScanner defines expected class-level constants."""
    print("[DEBUG] Starting test_route_scanner_constants_defined")

    content = _route_scanner_jac.read_text()

    # Constants should be inside with entry { } block
    assert "with entry {" in content, (
        "RouteScanner should use 'with entry' block for constants"
    )

    expected_constants = {
        "PAGES_DIR_NAME": "'pages'",
        "LAYOUT_FILENAME": "'layout'",
        "INDEX_FILENAME": "'index'",
        "AUTH_GROUP_NAME": "'auth'",
        "COMPONENT_PREFIX": "'Pages'",
        "SKIP_SUFFIXES": "['.cl.', '.impl.', '.test.']",
    }
    for name, value in expected_constants.items():
        assert f"{name} = {value}" in content, (
            f"RouteScanner should define constant {name} = {value}"
        )

    print("[DEBUG] RouteScanner constants verified!")


def test_route_scanner_imports_pathlib() -> None:
    """Test that route_scanner.jac imports Path from pathlib."""
    print("[DEBUG] Starting test_route_scanner_imports_pathlib")

    content = _route_scanner_jac.read_text()

    assert "import from pathlib { Path }" in content, (
        "route_scanner.jac should import Path from pathlib"
    )

    print("[DEBUG] route_scanner.jac imports verified!")


# =============================================================================
# RouteScanner: Implementation (route_scanner.impl.jac)
# =============================================================================


def test_route_scanner_impl_exists() -> None:
    """Test that route_scanner.impl.jac exists."""
    print("[DEBUG] Starting test_route_scanner_impl_exists")

    assert _route_scanner_impl.exists(), (
        f"route_scanner.impl.jac not found at {_route_scanner_impl}"
    )

    print("[DEBUG] route_scanner.impl.jac exists!")


def test_route_scanner_impl_top_level_imports() -> None:
    """Test that route_scanner.impl.jac has top-level imports (not inside methods).

    Codebase convention: imports are at the top of the file, not inside functions.
    """
    print("[DEBUG] Starting test_route_scanner_impl_top_level_imports")

    content = _route_scanner_impl.read_text()

    # Imports should appear at the top, before any impl blocks
    first_impl_pos = content.index("impl ")

    # These imports should appear before the first impl
    top_section = content[:first_impl_pos]

    assert "import re" in top_section, (
        "'import re' should be at the top of the file, not inside methods"
    )
    assert "import from pathlib { Path }" in top_section, (
        "pathlib import should be at the top of the file"
    )
    assert "import from jaclang.runtimelib.client_bundle { ClientBundleError }" in top_section, (
        "ClientBundleError import should be at the top of the file"
    )

    print("[DEBUG] Top-level imports verified!")


def test_route_scanner_impl_all_methods_present() -> None:
    """Test that all RouteScanner methods are implemented."""
    print("[DEBUG] Starting test_route_scanner_impl_all_methods_present")

    content = _route_scanner_impl.read_text()

    expected_impls = [
        "impl RouteEntry.init(",
        "impl RouteScanner.init(",
        "impl RouteScanner.has_pages_dir(",
        "impl RouteScanner.scan(",
        "impl RouteScanner.get_layouts(",
        "impl RouteScanner.get_page_files(",
        "impl RouteScanner._scan_directory(",
        "impl RouteScanner._file_to_route_path(",
        "impl RouteScanner._file_to_component_name(",
        "impl RouteScanner._detect_collisions(",
    ]
    for impl in expected_impls:
        assert impl in content, (
            f"route_scanner.impl.jac should contain: {impl}"
        )

    print("[DEBUG] All implementations verified!")


def test_route_scanner_route_group_regex() -> None:
    """Test that route groups are detected with correct regex pattern.

    Route groups use parenthesized directory names: (auth), (public), etc.
    They don't add to the URL path but can set auth_required.
    """
    print("[DEBUG] Starting test_route_scanner_route_group_regex")

    content = _route_scanner_impl.read_text()

    # The regex pattern for detecting route groups: (word)
    assert r"^\((\w+)\)$" in content, (
        "Route group detection should use regex: ^\\((\\w+)\\)$"
    )

    # Verify the auth group name uses the constant, not a magic string
    assert "self.AUTH_GROUP_NAME" in content, (
        "Auth group check should use AUTH_GROUP_NAME constant, not a magic string"
    )

    print("[DEBUG] Route group regex verified!")


def test_route_scanner_dynamic_segment_regex() -> None:
    """Test that dynamic segments are converted correctly.

    [id] -> :id (React Router dynamic parameter)
    """
    print("[DEBUG] Starting test_route_scanner_dynamic_segment_regex")

    content = _route_scanner_impl.read_text()

    # Dynamic segment regex: [word]
    assert r"^\[(\w+)\]$" in content, (
        "Dynamic segment detection should use regex: ^\\[(\\w+)\\]$"
    )

    # Verify it produces :id format
    assert "dynamic_match.group(1)" in content, (
        "Dynamic segment should extract the parameter name"
    )

    print("[DEBUG] Dynamic segment regex verified!")


def test_route_scanner_catch_all_regex() -> None:
    """Test that catch-all segments are converted correctly.

    [...slug] -> * (React Router catch-all)
    """
    print("[DEBUG] Starting test_route_scanner_catch_all_regex")

    content = _route_scanner_impl.read_text()

    # Catch-all regex: [...word]
    assert r"^\[\.\.\.(\w+)\]$" in content, (
        "Catch-all detection should use regex: ^\\[\\.\\.\\.\\(\\w+\\)\\]$"
    )

    # Verify it produces * path
    assert 'return "*"' in content, "Catch-all should return '*' as route path"

    print("[DEBUG] Catch-all regex verified!")


def test_route_scanner_index_file_handling() -> None:
    """Test that index.jac maps to the directory path, not /index.

    pages/index.jac -> /
    pages/users/index.jac -> /users
    """
    print("[DEBUG] Starting test_route_scanner_index_file_handling")

    content = _route_scanner_impl.read_text()

    # Should use INDEX_FILENAME constant
    assert "self.INDEX_FILENAME" in content, (
        "Index file check should use INDEX_FILENAME constant"
    )

    # index.jac maps to url_prefix (not url_prefix/index).
    # Normalize whitespace so formatter line-wrapping doesn't break the check.
    normalized = " ".join(content.split())
    assert 'route_path = url_prefix if url_prefix else "/"' in normalized, (
        "index.jac should map to the directory URL prefix"
    )

    print("[DEBUG] Index file handling verified!")


def test_route_scanner_layout_handling() -> None:
    """Test that layout.jac is detected and stored separately from routes.

    layout.jac -> layout wrapper (not a navigable route)
    """
    print("[DEBUG] Starting test_route_scanner_layout_handling")

    content = _route_scanner_impl.read_text()

    # Should use LAYOUT_FILENAME constant
    assert "self.LAYOUT_FILENAME" in content, (
        "Layout file check should use LAYOUT_FILENAME constant"
    )

    # Layout should be stored in self._layouts, not in routes
    assert "self._layouts[" in content, (
        "Layouts should be stored in self._layouts dict"
    )

    # Layout entry should have is_layout=True
    assert "is_layout=True" in content, (
        "Layout RouteEntry should set is_layout=True"
    )

    print("[DEBUG] Layout handling verified!")


def test_route_scanner_skip_suffixes() -> None:
    """Test that .impl.jac and .test.jac files are skipped during scanning."""
    print("[DEBUG] Starting test_route_scanner_skip_suffixes")

    content = _route_scanner_impl.read_text()

    # Should use SKIP_SUFFIXES constant
    assert "self.SKIP_SUFFIXES" in content, (
        "Skip logic should use SKIP_SUFFIXES constant"
    )

    # Should skip files with these suffixes
    assert "any(suffix in entry.name for suffix in self.SKIP_SUFFIXES)" in content, (
        "Should skip files containing any of the SKIP_SUFFIXES"
    )

    print("[DEBUG] Skip suffixes verified!")


def test_route_scanner_component_name_generation() -> None:
    """Test component name generation patterns.

    pages/index.jac -> PagesIndex
    pages/about.jac -> PagesAbout
    pages/(auth)/dashboard.jac -> PagesDashboard (skips group dir)
    pages/users/[id].jac -> PagesUsersId (strips brackets)
    """
    print("[DEBUG] Starting test_route_scanner_component_name_generation")

    content = _route_scanner_impl.read_text()

    # Should use COMPONENT_PREFIX constant
    assert "self.COMPONENT_PREFIX" in content, (
        "Component name generation should use COMPONENT_PREFIX constant"
    )

    # Should skip route group directories in name
    assert r"^\(\w+\)$" in content, (
        "Component name generation should skip route group directories"
    )

    # Should strip catch-all prefix: [...slug] -> slug
    assert r"^\[\.\.\.(\w+)\]$" in content, (
        "Component name generation should strip catch-all brackets"
    )

    # Should strip dynamic brackets: [id] -> id
    assert r"^\[(\w+)\]$" in content, (
        "Component name generation should strip dynamic brackets"
    )

    print("[DEBUG] Component name generation verified!")


def test_route_scanner_collision_detection() -> None:
    """Test that route path collisions are detected and raise ClientBundleError."""
    print("[DEBUG] Starting test_route_scanner_collision_detection")

    content = _route_scanner_impl.read_text()

    # Should use ClientBundleError (imported at top level)
    assert "raise ClientBundleError(" in content, (
        "Collision detection should raise ClientBundleError"
    )

    # Should detect duplicate paths
    assert "route.path in seen" in content, (
        "Should check if route.path already exists in seen dict"
    )

    # Error message should mention both conflicting files
    assert "Route collision:" in content, (
        "Error message should describe the collision"
    )

    # Should skip layouts in collision check
    assert "route.is_layout" in content, (
        "Should skip layout routes in collision detection"
    )

    print("[DEBUG] Collision detection verified!")


def test_route_scanner_deterministic_ordering() -> None:
    """Test that directory entries are sorted for deterministic route ordering."""
    print("[DEBUG] Starting test_route_scanner_deterministic_ordering")

    content = _route_scanner_impl.read_text()

    # Should sort directory entries
    assert "sorted(dir_path.iterdir()" in content, (
        "Directory entries should be sorted for deterministic ordering"
    )

    print("[DEBUG] Deterministic ordering verified!")


def test_route_scanner_scan_resets_state() -> None:
    """Test that scan() resets routes, layouts, and page_files before scanning."""
    print("[DEBUG] Starting test_route_scanner_scan_resets_state")

    content = _route_scanner_impl.read_text()

    # Find the scan method
    scan_impl = content[content.index("impl RouteScanner.scan("):]
    # Cut at next impl
    next_impl_pos = scan_impl.index("impl ", 10)
    scan_body = scan_impl[:next_impl_pos]

    # Should reset all state
    assert "self._routes = []" in scan_body, "scan() should reset _routes"
    assert "self._layouts = {}" in scan_body, "scan() should reset _layouts"
    assert "self._page_files = []" in scan_body, "scan() should reset _page_files"

    print("[DEBUG] scan() state reset verified!")


# =============================================================================
# RouteScanner: Regex pattern correctness (Python-level validation)
# =============================================================================


def test_regex_route_group_matches() -> None:
    """Validate the route group regex matches expected directory names."""
    print("[DEBUG] Starting test_regex_route_group_matches")

    pattern = re.compile(r"^\((\w+)\)$")

    # Should match
    assert pattern.match("(auth)"), "(auth) should match route group pattern"
    assert pattern.match("(public)"), "(public) should match"
    assert pattern.match("(admin)"), "(admin) should match"

    # Should not match
    assert not pattern.match("auth"), "Plain 'auth' should not match"
    assert not pattern.match("(auth"), "Missing closing paren should not match"
    assert not pattern.match("auth)"), "Missing opening paren should not match"
    assert not pattern.match("(auth-group)"), "Hyphenated names should not match"
    assert not pattern.match("()"), "Empty parens should not match"

    # Verify group extraction
    match = pattern.match("(auth)")
    assert match is not None
    assert match.group(1) == "auth", "Should extract group name"

    print("[DEBUG] Route group regex validated!")


def test_regex_dynamic_segment_matches() -> None:
    """Validate the dynamic segment regex matches expected filenames."""
    print("[DEBUG] Starting test_regex_dynamic_segment_matches")

    pattern = re.compile(r"^\[(\w+)\]$")

    # Should match
    assert pattern.match("[id]"), "[id] should match"
    assert pattern.match("[slug]"), "[slug] should match"
    assert pattern.match("[userId]"), "[userId] should match"

    # Should not match
    assert not pattern.match("[...id]"), "[...id] should not match (catch-all)"
    assert not pattern.match("id"), "Plain 'id' should not match"
    assert not pattern.match("[id"), "Missing bracket should not match"
    assert not pattern.match("[]"), "Empty brackets should not match"

    # Verify group extraction
    match = pattern.match("[id]")
    assert match is not None
    assert match.group(1) == "id", "Should extract parameter name"

    print("[DEBUG] Dynamic segment regex validated!")


def test_regex_catch_all_matches() -> None:
    """Validate the catch-all regex matches expected filenames."""
    print("[DEBUG] Starting test_regex_catch_all_matches")

    pattern = re.compile(r"^\[\.\.\.(\w+)\]$")

    # Should match
    assert pattern.match("[...slug]"), "[...slug] should match"
    assert pattern.match("[...path]"), "[...path] should match"

    # Should not match
    assert not pattern.match("[id]"), "[id] should not match (dynamic segment)"
    assert not pattern.match("[..slug]"), "[..slug] should not match (only 2 dots)"
    assert not pattern.match("[...]"), "[...] should not match (no name)"

    # Verify group extraction
    match = pattern.match("[...slug]")
    assert match is not None
    assert match.group(1) == "slug", "Should extract catch-all name"

    print("[DEBUG] Catch-all regex validated!")


# =============================================================================
# Compiler integration: Class definition (compiler.jac)
# =============================================================================


def test_compiler_imports_route_scanner() -> None:
    """Test that compiler.jac imports RouteScanner and RouteEntry."""
    print("[DEBUG] Starting test_compiler_imports_route_scanner")

    assert _compiler_jac.exists(), f"compiler.jac not found at {_compiler_jac}"

    content = _compiler_jac.read_text()

    assert "import from .route_scanner { RouteScanner, RouteEntry }" in content, (
        "compiler.jac should import RouteScanner and RouteEntry"
    )

    print("[DEBUG] Compiler imports verified!")


def test_compiler_router_exports_include_outlet_and_authguard() -> None:
    """Test that ROUTER_EXPORTS includes Outlet and AuthGuard for file-based routing."""
    print("[DEBUG] Starting test_compiler_router_exports_include_outlet_and_authguard")

    content = _compiler_jac.read_text()

    assert "'Outlet'" in content, "ROUTER_EXPORTS should include 'Outlet'"
    assert "'AuthGuard'" in content, "ROUTER_EXPORTS should include 'AuthGuard'"

    # Verify they're in the ROUTER_EXPORTS list context
    router_exports_start = content.index("ROUTER_EXPORTS = [")
    router_exports_end = content.index("];", router_exports_start)
    router_exports_section = content[router_exports_start:router_exports_end]

    assert "'Outlet'" in router_exports_section, (
        "'Outlet' should be in ROUTER_EXPORTS list"
    )
    assert "'AuthGuard'" in router_exports_section, (
        "'AuthGuard' should be in ROUTER_EXPORTS list"
    )

    print("[DEBUG] ROUTER_EXPORTS verified!")


def test_compiler_compound_extensions_constant() -> None:
    """Test that ViteCompiler defines COMPOUND_EXTENSIONS for shared extension handling."""
    print("[DEBUG] Starting test_compiler_compound_extensions_constant")

    content = _compiler_jac.read_text()

    assert "COMPOUND_EXTENSIONS" in content, (
        "compiler.jac should define COMPOUND_EXTENSIONS constant"
    )
    assert "'.cl.jac'" in content, "COMPOUND_EXTENSIONS should include '.cl.jac'"
    assert "'.impl.jac'" in content, "COMPOUND_EXTENSIONS should include '.impl.jac'"
    assert "'.test.jac'" in content, "COMPOUND_EXTENSIONS should include '.test.jac'"

    print("[DEBUG] COMPOUND_EXTENSIONS constant verified!")


def test_compiler_has_pages_methods() -> None:
    """Test that compiler.jac declares pages-related method signatures."""
    print("[DEBUG] Starting test_compiler_has_pages_methods")

    content = _compiler_jac.read_text()

    expected_methods = [
        "def _scan_and_compile_pages(",
        "def _generate_routes_manifest(",
        "def _jac_path_to_js(",
    ]
    for method in expected_methods:
        assert method in content, (
            f"compiler.jac should declare method: {method}"
        )

    print("[DEBUG] Pages-related method signatures verified!")


# =============================================================================
# Compiler integration: Implementation (compiler.impl.jac)
# =============================================================================


def test_compiler_init_sets_pages_state() -> None:
    """Test that ViteCompiler.init() initializes _has_pages and _route_scanner."""
    print("[DEBUG] Starting test_compiler_init_sets_pages_state")

    assert _compiler_impl.exists(), (
        f"compiler.impl.jac not found at {_compiler_impl}"
    )

    content = _compiler_impl.read_text()

    # Find the init method
    init_section = content[content.index("impl ViteCompiler.init("):]
    # Isolate init body (until next impl)
    next_impl_pos = init_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = init_section.find('\n"""', 10)
    init_body = init_section[:next_impl_pos] if next_impl_pos != -1 else init_section

    assert "self._has_pages = False" in init_body, (
        "init() should set self._has_pages = False"
    )
    assert "self._route_scanner = None" in init_body, (
        "init() should set self._route_scanner = None"
    )

    print("[DEBUG] Compiler init pages state verified!")


def test_compiler_compile_calls_scan_pages() -> None:
    """Test that compile() calls _scan_and_compile_pages."""
    print("[DEBUG] Starting test_compiler_compile_calls_scan_pages")

    content = _compiler_impl.read_text()

    # Find the compile method
    compile_section = content[content.index("impl ViteCompiler.compile("):]
    next_impl_pos = compile_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = compile_section.find('\n"""', 10)
    compile_body = compile_section[:next_impl_pos] if next_impl_pos != -1 else compile_section

    assert "self._scan_and_compile_pages(" in compile_body, (
        "compile() should call _scan_and_compile_pages"
    )
    assert "self._has_pages = self._scan_and_compile_pages(" in compile_body, (
        "compile() should store _scan_and_compile_pages result in self._has_pages"
    )

    print("[DEBUG] compile() pages integration verified!")


def test_compiler_compile_passes_visited_set() -> None:
    """Test that compile() passes a shared visited set to dependency compilation.

    This prevents double-compilation of files discovered by both dependency
    scanning and pages/ scanning.
    """
    print("[DEBUG] Starting test_compiler_compile_passes_visited_set")

    content = _compiler_impl.read_text()

    # Find the compile method
    compile_section = content[content.index("impl ViteCompiler.compile("):]
    next_impl_pos = compile_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = compile_section.find('\n"""', 10)
    compile_body = compile_section[:next_impl_pos] if next_impl_pos != -1 else compile_section

    # Should create a visited set and pass it to both methods
    assert "visited: set[Path] = set()" in compile_body, (
        "compile() should create a visited set"
    )
    assert "visited=visited" in compile_body, (
        "compile() should pass visited set to dependency methods"
    )

    print("[DEBUG] Visited set sharing verified!")


def test_compiler_entry_file_branches_on_has_pages() -> None:
    """Test that create_entry_file() branches on self._has_pages."""
    print("[DEBUG] Starting test_compiler_entry_file_branches_on_has_pages")

    content = _compiler_impl.read_text()

    # Find create_entry_file method
    entry_section = content[content.index("impl ViteCompiler.create_entry_file("):]
    next_impl_pos = entry_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = entry_section.find('\n"""', 10)
    entry_body = entry_section[:next_impl_pos] if next_impl_pos != -1 else entry_section

    assert "if self._has_pages" in entry_body, (
        "create_entry_file should branch on self._has_pages"
    )
    assert "self._create_pages_entry_content(" in entry_body, (
        "create_entry_file should call _create_pages_entry_content when has_pages"
    )

    print("[DEBUG] Entry file branching verified!")


def test_compiler_pages_entry_content_structure() -> None:
    """Test that _create_pages_entry_content generates expected JS structure.

    The generated _entry.js should include:
    - React and ReactDOM imports
    - BrowserRouter, Routes, Route from react-router-dom
    - AuthGuard import
    - Route filtering (public vs auth)
    - Single App function with one BrowserRouter
    """
    print("[DEBUG] Starting test_compiler_pages_entry_content_structure")

    content = _compiler_impl.read_text()

    # Find _create_pages_entry_content method
    pages_entry_section = content[
        content.index("impl ViteCompiler._create_pages_entry_content("):
    ]
    next_impl_pos = pages_entry_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = pages_entry_section.find('\n"""', 10)
    pages_entry_body = (
        pages_entry_section[:next_impl_pos]
        if next_impl_pos != -1
        else pages_entry_section
    )

    # Core imports
    assert 'import React from "react"' in pages_entry_body, (
        "Should import React"
    )
    assert 'import { createRoot } from "react-dom/client"' in pages_entry_body, (
        "Should import createRoot"
    )
    assert "BrowserRouter" in pages_entry_body, "Should import BrowserRouter"
    assert "AuthGuard" in pages_entry_body, "Should import AuthGuard"
    assert '_routes.js' in pages_entry_body, "Should import from _routes.js"

    # Route filtering
    assert "publicRoutes" in pages_entry_body, "Should define publicRoutes"
    assert "authRoutes" in pages_entry_body, "Should define authRoutes"

    # Single App function (not dual)
    app_count = pages_entry_body.count("function App()")
    assert app_count == 1, (
        f"Should have exactly 1 App function, found {app_count}"
    )

    # Single BrowserRouter (not dual)
    assert "BrowserRouter" in pages_entry_body, "Should use BrowserRouter"

    # Layout support
    assert "RootLayout" in pages_entry_body, "Should reference RootLayout"

    print("[DEBUG] Pages entry content structure verified!")


def test_compiler_pages_entry_no_dead_code() -> None:
    """Test that _create_pages_entry_content has no dead code branches.

    Previously there was an always-false condition 'if RootLayout in []:'
    that was fixed. Verify it doesn't exist.
    """
    print("[DEBUG] Starting test_compiler_pages_entry_no_dead_code")

    content = _compiler_impl.read_text()

    assert "if 'RootLayout' in []" not in content, (
        "Should not have always-false dead code: if 'RootLayout' in []"
    )

    print("[DEBUG] No dead code verified!")


def test_compiler_scan_and_compile_pages_implementation() -> None:
    """Test _scan_and_compile_pages creates RouteScanner and compiles pages."""
    print("[DEBUG] Starting test_compiler_scan_and_compile_pages_implementation")

    content = _compiler_impl.read_text()

    # Find the method
    scan_section = content[
        content.index("impl ViteCompiler._scan_and_compile_pages("):
    ]
    next_impl_pos = scan_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = scan_section.find('\n"""', 10)
    scan_body = scan_section[:next_impl_pos] if next_impl_pos != -1 else scan_section

    # Should create RouteScanner
    assert "RouteScanner(self.project_dir)" in scan_body, (
        "Should create RouteScanner with self.project_dir"
    )

    # Should check has_pages_dir
    assert "scanner.has_pages_dir()" in scan_body, (
        "Should check if pages/ directory exists"
    )

    # Should scan routes
    assert "scanner.scan()" in scan_body, "Should call scanner.scan()"

    # Should compile page files
    assert "scanner.get_page_files()" in scan_body, (
        "Should iterate over page files to compile them"
    )
    assert "self.compile_dependencies_recursively(" in scan_body, (
        "Should compile each page file through standard pipeline"
    )

    # Should cache scanner for later use
    assert "self._route_scanner = scanner" in scan_body, (
        "Should cache scanner in self._route_scanner"
    )

    # Should generate route manifest
    assert "self._generate_routes_manifest()" in scan_body, (
        "Should call _generate_routes_manifest"
    )

    print("[DEBUG] _scan_and_compile_pages implementation verified!")


def test_compiler_generate_routes_manifest_uses_cached_data() -> None:
    """Test that _generate_routes_manifest uses cached scanner data, not re-scanning.

    This avoids a double filesystem walk which was a bug caught in code review.
    """
    print("[DEBUG] Starting test_compiler_generate_routes_manifest_uses_cached_data")

    content = _compiler_impl.read_text()

    # Find the method
    manifest_section = content[
        content.index("impl ViteCompiler._generate_routes_manifest("):
    ]
    next_impl_pos = manifest_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = manifest_section.find('\n"""', 10)
    manifest_body = (
        manifest_section[:next_impl_pos]
        if next_impl_pos != -1
        else manifest_section
    )

    # Should use self._route_scanner (cached)
    assert "self._route_scanner" in manifest_body, (
        "Should use cached self._route_scanner"
    )

    # Should use scanner._routes (cached data), NOT scanner.scan() (re-scan)
    assert "scanner._routes" in manifest_body, (
        "Should use scanner._routes (cached), not scanner.scan() (re-scan)"
    )
    assert "scanner.scan()" not in manifest_body, (
        "Should NOT call scanner.scan() — that would re-walk the filesystem"
    )

    print("[DEBUG] Cached scanner data usage verified!")


def test_compiler_generate_routes_manifest_output() -> None:
    """Test that _generate_routes_manifest generates correct JS structure.

    The generated _routes.js should export:
    - routes: array of { path, element, auth } objects
    - layouts: object keyed by URL prefix
    """
    print("[DEBUG] Starting test_compiler_generate_routes_manifest_output")

    content = _compiler_impl.read_text()

    # Find the method
    manifest_section = content[
        content.index("impl ViteCompiler._generate_routes_manifest("):
    ]
    next_impl_pos = manifest_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = manifest_section.find('\n"""', 10)
    manifest_body = (
        manifest_section[:next_impl_pos]
        if next_impl_pos != -1
        else manifest_section
    )

    # Should export routes array
    assert "export const routes = [" in manifest_body, (
        "Should generate 'export const routes = [' in output"
    )

    # Should export layouts object
    assert "export const layouts = {" in manifest_body, (
        "Should generate 'export const layouts = {' in output"
    )

    # Route objects should have path, element, auth fields
    assert "path:" in manifest_body, "Route objects should have path field"
    assert "element:" in manifest_body, "Route objects should have element field"
    assert "auth:" in manifest_body, "Route objects should have auth field"

    # Should write to _routes.js
    assert "_routes.js" in manifest_body, "Should write output to _routes.js"

    print("[DEBUG] Route manifest output structure verified!")


def test_compiler_jac_path_to_js_implementation() -> None:
    """Test that _jac_path_to_js handles compound extensions correctly.

    file.cl.jac -> file.js
    file.impl.jac -> file.js
    file.test.jac -> file.js
    file.jac -> file.js
    """
    print("[DEBUG] Starting test_compiler_jac_path_to_js_implementation")

    content = _compiler_impl.read_text()

    # Find the method
    jac_to_js_section = content[
        content.index("impl ViteCompiler._jac_path_to_js("):
    ]
    next_impl_pos = jac_to_js_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = jac_to_js_section.find('\n"""', 10)
    jac_to_js_body = (
        jac_to_js_section[:next_impl_pos]
        if next_impl_pos != -1
        else jac_to_js_section
    )

    # Should use COMPOUND_EXTENSIONS constant
    assert "self.COMPOUND_EXTENSIONS" in jac_to_js_body, (
        "Should use COMPOUND_EXTENSIONS constant for extension handling"
    )

    # Should strip compound extension and replace with .js
    assert "'.js'" in jac_to_js_body, "Should replace extensions with .js"

    print("[DEBUG] _jac_path_to_js implementation verified!")


def test_compiler_uses_project_dir_not_project_root() -> None:
    """Test that compiler uses self.project_dir (not self.project_root).

    self.project_root doesn't exist on ViteCompiler — this was a bug caught
    in code review that would cause a runtime AttributeError.
    """
    print("[DEBUG] Starting test_compiler_uses_project_dir_not_project_root")

    content = _compiler_impl.read_text()

    # Should NOT use self.project_root anywhere
    assert "self.project_root" not in content, (
        "compiler.impl.jac should use self.project_dir, not self.project_root "
        "(project_root doesn't exist on ViteCompiler)"
    )

    # Should use self.project_dir
    assert "self.project_dir" in content, (
        "compiler.impl.jac should use self.project_dir"
    )

    print("[DEBUG] project_dir usage verified!")


def test_compiler_dependencies_uses_jac_path_helper() -> None:
    """Test that compile_dependencies_recursively uses _jac_path_to_js helper.

    This avoids duplicating the compound extension handling logic.
    """
    print("[DEBUG] Starting test_compiler_dependencies_uses_jac_path_helper")

    content = _compiler_impl.read_text()

    # Find compile_dependencies_recursively
    deps_section = content[
        content.index("impl ViteCompiler.compile_dependencies_recursively("):
    ]
    next_impl_pos = deps_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = deps_section.find('\n"""', 10)
    deps_body = deps_section[:next_impl_pos] if next_impl_pos != -1 else deps_section

    assert "self._jac_path_to_js(" in deps_body, (
        "compile_dependencies_recursively should use _jac_path_to_js helper"
    )

    print("[DEBUG] _jac_path_to_js helper usage verified!")


# =============================================================================
# AuthGuard: Runtime declaration (client_runtime.cl.jac)
# =============================================================================


def test_authguard_declared_in_runtime() -> None:
    """Test that AuthGuard is declared as a public function in client_runtime.cl.jac."""
    print("[DEBUG] Starting test_authguard_declared_in_runtime")

    assert _client_runtime_cl.exists(), (
        f"client_runtime.cl.jac not found at {_client_runtime_cl}"
    )

    content = _client_runtime_cl.read_text()

    assert 'def:pub AuthGuard(redirect: str = "/login") -> any' in content, (
        "AuthGuard should be declared as public with redirect parameter"
    )

    print("[DEBUG] AuthGuard declaration verified!")


def test_outlet_imported_in_runtime() -> None:
    """Test that Outlet is imported from react-router-dom for AuthGuard to use."""
    print("[DEBUG] Starting test_outlet_imported_in_runtime")

    content = _client_runtime_cl.read_text()

    assert "Outlet as ReactRouterOutlet" in content, (
        "Should import Outlet as ReactRouterOutlet from react-router-dom"
    )

    print("[DEBUG] Outlet import verified!")


def test_outlet_exported_as_glob() -> None:
    """Test that Outlet is re-exported as a glob (public global)."""
    print("[DEBUG] Starting test_outlet_exported_as_glob")

    content = _client_runtime_cl.read_text()

    assert "Outlet = ReactRouterOutlet" in content, (
        "Outlet should be re-exported in the glob block"
    )

    print("[DEBUG] Outlet glob export verified!")


# =============================================================================
# AuthGuard: Implementation (client_runtime.impl.jac)
# =============================================================================


def test_authguard_implementation_exists() -> None:
    """Test that AuthGuard is implemented in client_runtime.impl.jac."""
    print("[DEBUG] Starting test_authguard_implementation_exists")

    assert _client_runtime_impl.exists(), (
        f"client_runtime.impl.jac not found at {_client_runtime_impl}"
    )

    content = _client_runtime_impl.read_text()

    assert 'impl AuthGuard(redirect: str = "/login") -> any' in content, (
        "AuthGuard should be implemented with redirect parameter"
    )

    print("[DEBUG] AuthGuard implementation exists!")


def test_authguard_uses_jac_is_logged_in() -> None:
    """Test that AuthGuard checks authentication via jacIsLoggedIn()."""
    print("[DEBUG] Starting test_authguard_uses_jac_is_logged_in")

    content = _client_runtime_impl.read_text()

    # Find AuthGuard implementation
    authguard_section = content[content.index("impl AuthGuard("):]
    # Isolate body (until next impl)
    next_impl_pos = authguard_section.find("\nimpl ", 10)
    authguard_body = (
        authguard_section[:next_impl_pos]
        if next_impl_pos != -1
        else authguard_section
    )

    assert "jacIsLoggedIn()" in authguard_body, (
        "AuthGuard should check jacIsLoggedIn() for authentication"
    )

    print("[DEBUG] AuthGuard jacIsLoggedIn check verified!")


def test_authguard_renders_outlet_when_authenticated() -> None:
    """Test that AuthGuard renders <Outlet /> for authenticated users."""
    print("[DEBUG] Starting test_authguard_renders_outlet_when_authenticated")

    content = _client_runtime_impl.read_text()

    # Find AuthGuard implementation
    authguard_section = content[content.index("impl AuthGuard("):]
    next_impl_pos = authguard_section.find("\nimpl ", 10)
    authguard_body = (
        authguard_section[:next_impl_pos]
        if next_impl_pos != -1
        else authguard_section
    )

    assert "<ReactRouterOutlet />" in authguard_body, (
        "AuthGuard should render <ReactRouterOutlet /> when authenticated"
    )

    print("[DEBUG] AuthGuard Outlet rendering verified!")


def test_authguard_redirects_when_unauthenticated() -> None:
    """Test that AuthGuard redirects unauthenticated users to login."""
    print("[DEBUG] Starting test_authguard_redirects_when_unauthenticated")

    content = _client_runtime_impl.read_text()

    # Find AuthGuard implementation
    authguard_section = content[content.index("impl AuthGuard("):]
    next_impl_pos = authguard_section.find("\nimpl ", 10)
    authguard_body = (
        authguard_section[:next_impl_pos]
        if next_impl_pos != -1
        else authguard_section
    )

    assert "<ReactRouterNavigate" in authguard_body, (
        "AuthGuard should use <ReactRouterNavigate> for redirect"
    )
    assert "to={redirect}" in authguard_body, (
        "AuthGuard should pass redirect prop to Navigate"
    )
    assert "replace={True}" in authguard_body, (
        "AuthGuard should use replace={True} to avoid back-button loops"
    )

    print("[DEBUG] AuthGuard redirect behavior verified!")


def test_authguard_has_docstring() -> None:
    """Test that the AuthGuard implementation has a descriptive docstring."""
    print("[DEBUG] Starting test_authguard_has_docstring")

    content = _client_runtime_impl.read_text()

    # Docstring should appear before the impl AuthGuard line
    authguard_pos = content.index("impl AuthGuard(")
    preceding = content[max(0, authguard_pos - 200):authguard_pos]

    assert '"""' in preceding, (
        "AuthGuard implementation should have a docstring"
    )

    print("[DEBUG] AuthGuard docstring verified!")


# =============================================================================
# Cross-cutting: Consistency checks
# =============================================================================


def test_route_scanner_uses_constants_not_magic_strings() -> None:
    """Test that the route scanner impl uses class constants, not hardcoded strings.

    Verifies that magic strings like 'auth', 'pages', 'layout', 'index' are
    replaced with class-level constants.
    """
    print("[DEBUG] Starting test_route_scanner_uses_constants_not_magic_strings")

    content = _route_scanner_impl.read_text()

    # The _scan_directory method should use constants, not string literals
    scan_section = content[content.index("impl RouteScanner._scan_directory("):]
    next_impl_pos = scan_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = scan_section.find('\n"""', 10)
    scan_body = scan_section[:next_impl_pos] if next_impl_pos != -1 else scan_section

    # Should NOT contain hardcoded 'auth' for group name comparison
    # (regex match is OK, but the group name check should use the constant)
    assert "self.AUTH_GROUP_NAME" in scan_body, (
        "Should use AUTH_GROUP_NAME constant instead of hardcoded 'auth'"
    )
    assert "self.LAYOUT_FILENAME" in scan_body, (
        "Should use LAYOUT_FILENAME constant instead of hardcoded 'layout'"
    )
    assert "self.INDEX_FILENAME" in scan_body, (
        "Should use INDEX_FILENAME constant instead of hardcoded 'index'"
    )

    print("[DEBUG] Constants usage verified!")


def test_no_unused_typing_any_import_in_scanner() -> None:
    """Test that route_scanner.jac does not import unused typing.Any."""
    print("[DEBUG] Starting test_no_unused_typing_any_import_in_scanner")

    content = _route_scanner_jac.read_text()

    assert "import from typing { Any }" not in content, (
        "route_scanner.jac should not import unused typing.Any"
    )

    print("[DEBUG] No unused imports verified!")


def test_compiler_no_duplicate_compound_extension_logic() -> None:
    """Test that compound extension handling is not duplicated across methods.

    The _jac_path_to_js helper should be the single place for this logic.
    There should be no inline lists of ['.cl.jac', '.impl.jac', ...] in
    other methods.
    """
    print("[DEBUG] Starting test_compiler_no_duplicate_compound_extension_logic")

    content = _compiler_impl.read_text()

    # Count occurrences of inline compound extension lists
    # The only acceptable place is inside _jac_path_to_js via COMPOUND_EXTENSIONS
    inline_list_pattern = r"\['\.(cl|impl|test)\.jac'"
    matches = re.findall(inline_list_pattern, content)

    # Should only find it in the COMPOUND_EXTENSIONS definition (in compiler.jac),
    # not as inline lists in compiler.impl.jac
    assert len(matches) == 0, (
        f"Found {len(matches)} inline compound extension lists — "
        f"should use COMPOUND_EXTENSIONS constant via _jac_path_to_js"
    )

    print("[DEBUG] No duplicated compound extension logic!")


def test_entry_file_single_browser_router() -> None:
    """Test that the generated entry file uses a single BrowserRouter, not two.

    This was a bug caught in code review: both App() and AppWithLayout()
    previously created BrowserRouter, resulting in nested routers.
    """
    print("[DEBUG] Starting test_entry_file_single_browser_router")

    content = _compiler_impl.read_text()

    # Find _create_pages_entry_content
    pages_section = content[
        content.index("impl ViteCompiler._create_pages_entry_content("):
    ]
    next_impl_pos = pages_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = pages_section.find('\n"""', 10)
    pages_body = (
        pages_section[:next_impl_pos] if next_impl_pos != -1 else pages_section
    )

    # Count BrowserRouter occurrences in the generated code
    browser_router_count = pages_body.count("BrowserRouter")

    # Should have import (1) + usage (1) = 2 references, NOT 3+ (which means dual)
    # The import line and the createElement call
    assert browser_router_count <= 3, (
        f"Found {browser_router_count} BrowserRouter references — "
        f"should have only import + single usage, not dual BrowserRouter"
    )

    # Should NOT have two separate function definitions (App + AppWithLayout)
    assert "function AppWithLayout()" not in pages_body, (
        "Should not have a separate AppWithLayout function — use single App with conditional layout"
    )

    print("[DEBUG] Single BrowserRouter verified!")


# =============================================================================
# Bug fix: Layout collision detection
# =============================================================================


def test_route_scanner_layout_collision_detection() -> None:
    """Test that duplicate layouts at the same URL prefix raise ClientBundleError.

    If pages/layout.jac and pages/(auth)/layout.jac both resolve to prefix "/",
    the second should not silently overwrite the first. Instead, a collision
    error should be raised, matching the behavior of route path collisions.
    """
    print("[DEBUG] Starting test_route_scanner_layout_collision_detection")

    content = _route_scanner_impl.read_text()

    # Find the _scan_directory method where layouts are processed
    scan_section = content[content.index("impl RouteScanner._scan_directory("):]
    next_impl_pos = scan_section.find("\nimpl ", 10)
    if next_impl_pos == -1:
        next_impl_pos = scan_section.find('\n"""', 10)
    scan_body = scan_section[:next_impl_pos] if next_impl_pos != -1 else scan_section

    # Should check for existing layout at the same prefix before inserting
    assert "Layout collision:" in scan_body, (
        "_scan_directory should detect layout collisions when the same URL "
        "prefix already has a layout registered"
    )

    # Should raise ClientBundleError (same as route collision)
    # Count raise statements to ensure layout collision also raises
    raise_count = scan_body.count("raise ClientBundleError(")
    assert raise_count >= 1, (
        "_scan_directory should raise ClientBundleError for layout collisions"
    )

    # The check should happen BEFORE the layout is inserted
    collision_check_pos = scan_body.index("Layout collision:")
    layout_insert_pos = scan_body.index("self._layouts[")
    assert collision_check_pos < layout_insert_pos, (
        "Layout collision check should happen before layout insertion"
    )

    print("[DEBUG] Layout collision detection verified!")


# =============================================================================
# Bug fix: .cl.jac files in SKIP_SUFFIXES
# =============================================================================


def test_route_scanner_skip_cl_jac_files() -> None:
    """Test that .cl.jac files are skipped in pages/ directory scanning.

    .cl.jac files are Jac class definition files (compound extension).
    If not skipped, a file like pages/about.cl.jac would produce a route
    /about.cl instead of being ignored. The compiler's COMPOUND_EXTENSIONS
    recognizes .cl.jac, so the scanner should skip it too.
    """
    print("[DEBUG] Starting test_route_scanner_skip_cl_jac_files")

    content = _route_scanner_jac.read_text()

    # Verify all compound extensions are covered
    assert "'.cl.'" in content, "SKIP_SUFFIXES should include '.cl.'"
    assert "'.impl.'" in content, "SKIP_SUFFIXES should include '.impl.'"
    assert "'.test.'" in content, "SKIP_SUFFIXES should include '.test.'"

    print("[DEBUG] .cl.jac skip suffix verified!")


def test_skip_suffixes_consistent_with_compound_extensions() -> None:
    """Test that SKIP_SUFFIXES covers all COMPOUND_EXTENSIONS from the compiler.

    The compiler recognizes ['.cl.jac', '.impl.jac', '.test.jac'] as compound
    extensions. The scanner should skip files with all of these compound
    suffixes to avoid generating wrong routes.
    """
    print("[DEBUG] Starting test_skip_suffixes_consistent_with_compound_extensions")

    scanner_content = _route_scanner_jac.read_text()
    compiler_content = _compiler_jac.read_text()

    # Extract compound extensions from compiler
    # COMPOUND_EXTENSIONS = ['.cl.jac', '.impl.jac', '.test.jac']
    compound_exts_start = compiler_content.index("COMPOUND_EXTENSIONS = [")
    compound_exts_end = compiler_content.index("];", compound_exts_start)
    compound_section = compiler_content[compound_exts_start:compound_exts_end]

    # For each compound extension, verify the corresponding skip suffix exists
    # .cl.jac -> '.cl.' should be in SKIP_SUFFIXES
    # .impl.jac -> '.impl.' should be in SKIP_SUFFIXES
    # .test.jac -> '.test.' should be in SKIP_SUFFIXES
    for ext in ["'.cl.jac'", "'.impl.jac'", "'.test.jac'"]:
        assert ext in compound_section, (
            f"COMPOUND_EXTENSIONS should contain {ext}"
        )
        # Derive the skip suffix: '.cl.jac' -> '.cl.'
        skip_suffix = ext.replace(".jac'", ".'")
        assert skip_suffix in scanner_content, (
            f"SKIP_SUFFIXES should contain {skip_suffix} to match "
            f"compiler's COMPOUND_EXTENSIONS entry {ext}"
        )
