"""Tests for Jac Language Server."""

import contextlib;
import os;
import sys;
import from pathlib { Path }

import lsprotocol.types as lspt;

import jaclang;
import from jaclang.langserve.engine { JacLangServer }
import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.workspace { Workspace }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures"),
     EXAMPLES_DIR = os.path.join(JAC_ROOT, "examples"),
     PASSES_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     _active_servers: list = [];

def _clear_jac_modules {
    """Clear jac-compiled modules from sys.modules."""
    jac_modules_to_clear = [
        k
        for k in list(sys.modules.keys())
        if not k.startswith(("jaclang", "test", "_"))
        and hasattr(sys.modules.get(k), "__jac_mod__")
    ];
    for mod_name in jac_modules_to_clear {
        sys.modules.pop(mod_name, None);
    }
}

def setup_test {
    """Set up test environment.

    Note: _fresh_jac_state() runs automatically before each Jac test via the
    pytest plugin, which resets JacRuntime. We only need to handle server-
    specific setup here.
    """
    _clear_jac_modules();
    _active_servers.clear();
}

def teardown_test {
    """Tear down test environment."""
    for server in _active_servers {
        with contextlib.suppress(Exception) as _s {
            server.shutdown();
        }
        server.clear_type_system(clear_hub=True);
    }
    _active_servers.clear();
    _clear_jac_modules();
}

def fixture_path(name: str) -> str {
    """Get absolute path to fixture file."""
    return os.path.join(FIXTURE_DIR, name);
}

def examples_abs_path(name: str) -> str {
    """Get absolute path of an example from examples directory."""
    return os.path.join(EXAMPLES_DIR, name);
}

def passes_main_fixture_abs_path(name: str) -> str {
    """Get absolute path of a fixture from compiler passes main fixtures directory."""
    return os.path.join(PASSES_FIXTURES, name);
}

def create_server(workspace_path: str | None = None) -> JacLangServer {
    """Create a JacLangServer wired to the given workspace."""
    lsp = JacLangServer();
    workspace_root = workspace_path if workspace_path is not None else FIXTURE_DIR;
    workspace_val = Workspace(workspace_root, lsp);
    lsp.lsp._workspace = workspace_val;
    _active_servers.append(lsp);
    return lsp;
}

obj Case {
    has pos: lspt.Position,
        expected: list[str],
        trigger: str = ".";
}

test "test_impl_stay_connected" {
    setup_test();
    try {
        lsp = create_server();
        circle_file = uris.from_fs_path(fixture_path("circle_pure.jac"));
        circle_impl_file = uris.from_fs_path(fixture_path("circle_pure.impl.jac"));
        lsp.type_check_file(circle_file);
        pos = lspt.Position(20, 8);
        assert (
            "Circle class inherits from Shape." in lsp.get_hover_info(circle_file, pos).contents.value
        );
        lsp.type_check_file(circle_impl_file);
        pos = lspt.Position(8, 11);
        assert (
            "ability) calculate_area\n( radius : float ) -> float" in lsp.get_hover_info(
                circle_impl_file, pos
            ).contents.value.replace(
                "'", ""
            )
        );
    } finally {
        teardown_test();
    }
}

test "test_impl_auto_discover" {
    setup_test();
    try {
        lsp = create_server();
        circle_impl_file = uris.from_fs_path(fixture_path("circle_pure.impl.jac"));
        lsp.type_check_file(circle_impl_file);
        pos = lspt.Position(8, 11);
        assert (
            "(public ability) calculate_area\n( radius : float ) -> float" in lsp.get_hover_info(
                circle_impl_file, pos
            ).contents.value.replace(
                "'", ""
            )
        );
    } finally {
        teardown_test();
    }
}

test "test_outline_symbols" {
    setup_test();
    try {
        lsp = create_server();
        circle_file = uris.from_fs_path(fixture_path("circle_pure.jac"));
        lsp.type_check_file(circle_file);
        assert len(lsp.get_outline(circle_file)) == 8;
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition" {
    setup_test();
    try {
        lsp = create_server();
        circle_file = uris.from_fs_path(fixture_path("circle_pure.jac"));
        lsp.type_check_file(circle_file);
        assert "fixtures/circle_pure.impl.jac:8:5-8:19" in str(
            lsp.get_definition(circle_file, lspt.Position(9, 16))
        );
        assert "fixtures/circle_pure.jac:13:11-13:16" in str(
            lsp.get_definition(circle_file, lspt.Position(20, 16))
        );

        goto_defs_file = uris.from_fs_path(fixture_path("goto_def_tests.jac"));
        lsp.type_check_file(goto_defs_file);

        # Test if the visitor keyword goes to the walker definition
        assert "fixtures/goto_def_tests.jac:8:7-8:17" in str(
            lsp.get_definition(goto_defs_file, lspt.Position(4, 14))
        );
        # Test if the here keyword goes to the node definition
        assert "fixtures/goto_def_tests.jac:0:5-0:13" in str(
            lsp.get_definition(goto_defs_file, lspt.Position(10, 14))
        );
        # Test the SomeNode node inside the visit statement goes to its definition
        assert "fixtures/goto_def_tests.jac:0:5-0:13" in str(
            lsp.get_definition(goto_defs_file, lspt.Position(11, 21))
        );

        # Test when the left of assignment is a list.
        assert "fixtures/goto_def_tests.jac:16:5-16:8" in str(
            lsp.get_definition(goto_defs_file, lspt.Position(17, 10))
        );
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_method_manual_impl" {
    setup_test();
    try {
        lsp = create_server("");
        decldef_file = uris.from_fs_path(
            examples_abs_path("micro/decl_defs_main.impl.jac")
        );
        lsp.type_check_file(decldef_file);
        decldef_main_file = uris.from_fs_path(
            examples_abs_path("micro/decl_defs_main.jac")
        );
        lsp.type_check_file(decldef_main_file);
        lsp.type_check_file(decldef_file);
        assert "decl_defs_main.jac:7:8-7:17" in str(
            lsp.get_definition(decldef_file, lspt.Position(2, 20))
        );
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_md_path" {
    setup_test();
    try {
        lsp = create_server();
        import_file = uris.from_fs_path(fixture_path("md_path.jac"));
        lsp.type_check_file(import_file);
        positions = [
            (3, 11, "asyncio/__init__.py:0:0-0:0"),
            (6, 17, "concurrent/__init__.py:0:0-0:0"),
            (6, 28, "concurrent/futures/__init__.py:0:0-0:0"),
            (7, 17, "typing.py:0:0-0:0"),
            (9, 18, "jaclang/jac0core/__init__.py:0:0-0:0"),
            (9, 25, "jaclang/jac0core/unitree.jac:0:0-0:0"),
            (10, 34, "jac/jaclang/__init__.py:19:3-19:22"),
            (11, 35, "jaclang/jac0core/constant.jac:0:0-0:0"),
            (11, 47, "jaclang/jac0core/constant.jac:4:5-4:15"),
            (13, 47, "jaclang/compiler/type_system/type_utils.jac:0:0-0:0"),
            (14, 34, "jaclang/compiler/type_system/__init__.py:0:0-0:0"),
            (18, 5, "compiler/type_system/types.jac:66:4-66:12"),
            (20, 34, "jaclang/jac0core/unitree.jac:0:0-0:0"),
            (22, 22, "tests/langserve/fixtures/circle.jac:7:5-7:8"),
            (23, 38, "jaclang/vendor/pygls/uris.py:0:0-0:0"),
            (24, 52, "jaclang/vendor/pygls/server.py:351:0-615:13"),
            (26, 31, "jaclang/vendor/lsprotocol/types.py:0:0-0:0"),

        ];

        for (line, char, expected) in positions {
            result = str(
                lsp.get_definition(import_file, lspt.Position(line - 1, char - 1))
            );
            assert expected in result , f"Line {line}, char {char}: expected '{expected}' in '{result}'";
        }
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_connect_filter" {
    setup_test();
    try {
        lsp = create_server("");
        import_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_connect_filter.jac")
        );
        lsp.type_check_file(import_file);
        positions = [
            (25, 5, "connect_filter.jac:19:4-19:10"),
            (25, 16, "connect_filter.jac:22:4-22:13"),
            (25, 32, "connect_filter.jac:20:4-20:10"),
            (26, 16, "connect_filter.jac:4:5-4:10"),
            (27, 5, "connect_filter.jac:4:5-4:10"),
            (27, 15, "connect_filter.jac:0:5-0:11"),
            (28, 27, "connect_filter.jac:8:5-8:10"),
            (31, 16, "connect_filter.jac:0:5-0:11"),
            (31, 25, "connect_filter.jac:1:8-1:10"),
            (35, 12, "connect_filter.jac:13:8-13:13"),
            (36, 5, "connect_filter.jac:33:4-33:7"),
            (39, 9, "connect_filter.jac:0:5-0:11"),

        ];

        for (line, char, expected) in positions {
            assert expected in str(
                lsp.get_definition(import_file, lspt.Position(line - 1, char - 1))
            );
        }
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_atom_trailer" {
    setup_test();
    try {
        lsp = create_server();
        import_file = uris.from_fs_path(fixture_path("user.jac"));
        lsp.type_check_file(import_file);
        positions = [
            (12, 7, "fixtures/greet.py:6:3-7:15"),
            (12, 22, "fixtures/greet.py:1:3-2:15"),

        ];

        for (line, char, expected) in positions {
            assert expected in str(
                lsp.get_definition(import_file, lspt.Position(line - 1, char - 1))
            );
        }
    } finally {
        teardown_test();
    }
}

test "test_missing_mod_warning" {
    setup_test();
    try {
        lsp = create_server();
        import_file = uris.from_fs_path(fixture_path("md_path.jac"));
        lsp.type_check_file(import_file);

        expected_warnings = [
            "fixtures/md_path.jac, line 21, col 13: Module not found",
            "fixtures/md_path.jac, line 27, col 8: Module not found",

        ];
        warnings_str = [str(w) for w in lsp.warnings_had];
        for expected in expected_warnings {
            assert any(expected in w for w in warnings_str) , f"Expected warning '{expected}' not found in {warnings_str}";
        }
    } finally {
        teardown_test();
    }
}

test "test_completion" {
    import asyncio;

    setup_test();
    try {
        lsp = create_server();
        base_module_file = uris.from_fs_path(fixture_path("completion_test_err.jac"));
        lsp.type_check_file(base_module_file);

        test_cases: list[Case] = [
            Case(pos=lspt.Position(8, 8), expected=["bar", "baz"]),

        ];
        for case in test_cases {
            results = asyncio.run(
                lsp.get_completion(
                    base_module_file, case.pos, completion_trigger=case.trigger
                )
            );
            completions = results.items;
            for completion in case.expected {
                assert completion in str(completions);
            }
        }
    } finally {
        teardown_test();
    }
}

test "test_go_to_reference" {
    setup_test();
    try {
        lsp = create_server();
        circle_file = uris.from_fs_path(fixture_path("circle.jac"));
        lsp.type_check_file(circle_file);
        test_cases = [
            (45, 4, ["circle.jac:45:4-45:5", "51:23-51:24", "51:75-51:76"]),

        ];
        for (line, char, expected_refs) in test_cases {
            references = str(
                lsp.get_references(circle_file, lspt.Position(line, char))
            );
            for expected in expected_refs {
                assert expected in references;
            }
        }
    } finally {
        teardown_test();
    }
}

test "test_go_to_def_import_star" {
    setup_test();
    try {
        lsp = create_server("");
        import_star_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_import_star/main.jac")
        );

        lsp.type_check_file(import_star_file);
        positions = [
            (5, 16, "import_star_mod_py.py:0:0-2:2"),
            (5, 21, "import_star_mod_py.py:1:3-2:6"),
            (6, 16, "import_star_mod_jac.jac:0:4-0:7"),
            (6, 22, "import_star_mod_jac.jac:1:8-1:11"),
            (8, 25, "_pydatetime.py:"),

        ];

        for (line, char, expected) in positions {
            assert expected in str(
                lsp.get_definition(import_star_file, lspt.Position(line - 1, char - 1))
            );
        }
    } finally {
        teardown_test();
    }
}

test "test_stub_impl_hover_and_goto_def" {
    setup_test();
    try {
        lsp = create_server();
        test_file = uris.from_fs_path(fixture_path("stub_hover.jac"));
        impl_file_path = fixture_path("stub_hover.impl.jac");
        impl_file = uris.from_fs_path(impl_file_path);
        lsp.type_check_file(test_file);

        # Test hover on type annotations in stub file

        # Hover on MyServer in: def process(self: MyServer, data: str) -> str;
        hover = lsp.get_hover_info(test_file, lspt.Position(12, 24));
        assert hover is not None , "Hover should return info for self type annotation";
        assert "MyServer" in hover.contents.value , f"Hover should show MyServer info, got: {hover.contents.value}";

        # Hover on MyServer in: def handle(self: MyServer, request: int) -> None;
        hover2 = lsp.get_hover_info(test_file, lspt.Position(13, 23));
        assert hover2 is not None , "Hover should return info for self type annotation";
        assert "MyServer" in hover2.contents.value , f"Hover should show MyServer info, got: {hover2.contents.value}";

        # Test hover on type annotations in impl file
        lsp.type_check_file(impl_file);
        hover3 = lsp.get_hover_info(impl_file, lspt.Position(14, 29));
        assert hover3 is not None , "Hover should return info for self type in impl file";
        assert "MyServer" in hover3.contents.value , f"Hover should show MyServer info in impl, got: {hover3.contents.value}";

        # Test go-to-definition from stub to impl
        defn = lsp.get_definition(test_file, lspt.Position(11, 10));
        assert defn is not None , "Definition should be found for init stub";
        assert impl_file_path in defn.uri , f"Definition should point to impl file, got: {defn.uri}";
        assert defn.range.start.line == 4 , f"Definition should be at line 5 (0-indexed: 4), got: {defn.range.start.line}";

        defn2 = lsp.get_definition(test_file, lspt.Position(12, 10));
        assert defn2 is not None , "Definition should be found for process stub";
        assert impl_file_path in defn2.uri , f"Definition should point to impl file, got: {defn2.uri}";
        assert defn2.range.start.line == 10 , f"Definition should be at line 11 (0-indexed: 10), got: {defn2.range.start.line}";

        # Test go-to-definition for static field access (MyServer._counter)
        defn3 = lsp.get_definition(impl_file, lspt.Position(6, 33));
        assert defn3 is not None , "Definition should be found for static field _counter";
        assert "stub_hover.jac" in defn3.uri , f"Definition should point to declaration file, got: {defn3.uri}";
        assert defn3.range.start.line == 9 , f"Definition should be at line 10 (0-indexed: 9), got: {defn3.range.start.line}";

        # Hover on 'start' in 'self.worker.start()'
        hover_start = lsp.get_hover_info(impl_file, lspt.Position(22, 17));
        assert hover_start is not None , "Hover should return info for Thread.start method in impl body";

        # Hover on 'worker' in 'self.worker.start()'
        hover_worker = lsp.get_hover_info(impl_file, lspt.Position(22, 10));
        assert hover_worker is not None , "Hover should return info for worker field in impl body";
        assert "Thread" in hover_worker.contents.value , f"Hover should show Thread type, got: {hover_worker.contents.value}";

        # Go-to-definition on 'start' should go to Python threading module
        defn_start = lsp.get_definition(impl_file, lspt.Position(22, 17));
        assert defn_start is not None , "Definition should be found for Thread.start method";
        assert "threading" in defn_start.uri , f"Definition should point to threading module, got: {defn_start.uri}";
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_impl_body_self_attr" {
    setup_test();
    try {
        lsp = create_server("");
        impl_file = uris.from_fs_path(
            passes_main_fixture_abs_path("impl_symbol_resolution.impl.jac")
        );
        lsp.type_check_file(impl_file);

        positions = [
            (5, 17, "impl_symbol_resolution.jac:3:8-3:13", ),
            (9, 21, "impl_symbol_resolution.jac:4:8-4:12"),
            (9, 34, "impl_symbol_resolution.jac:3:8-3:13"),

        ];

        for (line, char, expected) in positions {
            result = lsp.get_definition(impl_file, lspt.Position(line - 1, char - 1));
            assert result is not None , f"Expected definition at line {line}, char {char}, got None";
            assert expected in str(result) , f"Expected '{expected}' in definition for line {line}, char {char}, "
            f"got: {result}";
        }
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_directory_import" {
    setup_test();
    try {
        lsp = create_server();
        import_file = uris.from_fs_path(fixture_path("local_imports/main.jac"));
        lsp.type_check_file(import_file);

        positions = [
            (2, 18, "local_imports/mypkg_reg/__init__.jac:0:0-0:0"),
            (2, 28, "local_imports/mypkg_reg/my_mod.jac:0:0-0:0"),
            (1, 28, "local_imports/mypkg_ns/my_mod.jac:0:0-0:0"),

        ];

        for (line, char, expected) in positions {
            def_loc = lsp.get_definition(
                import_file, lspt.Position(line - 1, char - 1)
            );
            assert def_loc is not None , f"Definition at line {line}, col {char} not found";
            assert expected in str(def_loc) , f"Expected '{expected}' in definition for line {line}, char {char}, "
            f"got: {def_loc}";
        }
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_nested_impl_symbols" {
    setup_test();
    try {
        lsp = create_server();
        impl_file = uris.from_fs_path(fixture_path("nested_impl_resolution.impl.jac"));
        lsp.type_check_file(impl_file);

        positions = [
            (2, 5, "unitree.jac"),
            (3, 8, "unitree.jac"),
            (4, 18, "unitree.jac"),
            (6, 11, "unitree.jac"),
            (7, 15, "unitree.jac"),
            (9, 22, "unitree.jac"),
            (10, 15, "unitree.jac"),

        ];

        for (line, char, expected) in positions {
            result = lsp.get_definition(impl_file, lspt.Position(line - 1, char - 1));
            assert result is not None , f"Expected definition at line {line}, char {char}, got None";
            assert expected in str(result) , f"Expected '{expected}' in definition for line {line}, char {char}, "
            f"got: {result}";
        }
    } finally {
        teardown_test();
    }
}

test "test_hover_narrowing_in_loop" {
    setup_test();
    try {
        lsp = create_server();
        # Use the dedicated LSP fixture
        narrowing_file = uris.from_fs_path(fixture_path("hover_loop.jac"));
        lsp.type_check_file(narrowing_file);

        # Line 13 is: for s in expr.strings {
        # 'expr' starts at column 17 and ends at 21 (0-indexed coords: 12, 17)
        pos = lspt.Position(12, 18);
        hover = lsp.get_hover_info(narrowing_file, pos);

        assert hover is not None , "Hover should return info for expr inside loop";
        # Verify it shows the narrowed type MyString
        assert "MyString" in hover.contents.value , f"Hover should show MyString, got: {hover.contents.value}";
        # Verify it does NOT show the union type MyInt or None
        assert "MyInt" not in hover.contents.value , "Hover should NOT show MyInt (it should be narrowed)";
    } finally {
        teardown_test();
    }
}
