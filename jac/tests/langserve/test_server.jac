"""Tests for Jac Language Server."""

import contextlib;
import os;
import sys;
import from pathlib { Path }

import jaclang.lsp.types as lspt;

import jaclang;
import from jaclang.langserve.engine { JacLangServer }
import from jaclang.lsp { uris }
import from jaclang.lsp.server { Workspace }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures"),
     EXAMPLES_DIR = os.path.join(JAC_ROOT, "examples"),
     PASSES_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     _active_servers: list = [];

"""Clear jac-compiled modules from sys.modules."""
def _clear_jac_modules {
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

"""Set up test environment.

Note: _fresh_jac_state() runs automatically before each Jac test via the
pytest plugin, which resets JacRuntime. We only need to handle server-
specific setup here.
"""
def setup_test {
    _clear_jac_modules();
    _active_servers.clear();
}

"""Tear down test environment."""
def teardown_test {
    for server in _active_servers {
        with contextlib.suppress(Exception) as _s {
            server.shutdown();
        }
        server.clear_type_system(clear_hub=True);
    }
    _active_servers.clear();
    _clear_jac_modules();
}

"""Get absolute path to fixture file."""
def fixture_path(name: str) -> str {
    return os.path.join(FIXTURE_DIR, name);
}

"""Get absolute path of an example from examples directory."""
def examples_abs_path(name: str) -> str {
    return os.path.join(EXAMPLES_DIR, name);
}

"""Get absolute path of a fixture from compiler passes main fixtures directory."""
def passes_main_fixture_abs_path(name: str) -> str {
    return os.path.join(PASSES_FIXTURES, name);
}

"""Create a JacLangServer wired to the given workspace."""
def create_server(workspace_path: str | None = None) -> JacLangServer {
    lsp = JacLangServer();
    workspace_root = workspace_path if workspace_path is not None else FIXTURE_DIR;
    workspace_val = Workspace(root_uri=uris.from_fs_path(workspace_root));
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
            "Circle class inherits from Shape." in lsp.get_hover_info(
                circle_file, pos
            ).contents.value
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
        assert "fixtures/circle_pure.jac:13:9-13:14" in str(
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

        # Test go-to-definition for self-member assigned in impl file.
        # t2.program (line 25) should go to 'has program' declaration (line 12).
        self_member_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_impl/checker_impl_self_member.jac")
        );
        lsp.type_check_file(self_member_file);
        go_def_result = str(
            lsp.get_definition(self_member_file, lspt.Position(24, 14))
        );
        # program field is declared via 'has' -- go-to-def points to the declaration
        # (line 12, 1-indexed = line 11 in 0-indexed LSP format)
        assert "checker_impl_self_member.jac:11" in go_def_result , f"Unexpected go-to-def result: {go_def_result}";
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_any_keyword" {
    setup_test();
    try {
        lsp = create_server();
        f = uris.from_fs_path(fixture_path("any_goto_def_tests.jac"));
        lsp.type_check_file(f);

        # Backtick-escaped `` `any `` (function form) → typeshed builtins.pyi
        bt_any = str(lsp.get_definition(f, lspt.Position(1, 13)));
        assert "builtins.pyi" in bt_any , f"Unexpected: {bt_any}";

        # Bare `any` keyword in type annotation → typeshed typing.pyi (Any)
        bare_any = str(lsp.get_definition(f, lspt.Position(4, 8)));
        assert "typing.pyi" in bare_any , f"Unexpected: {bare_any}";

        # Bare `Any` without import → unresolved (not in jac_builtins.pyi __all__)
        bare_Any = lsp.get_definition(f, lspt.Position(5, 8));
        assert bare_Any is None , f"Expected None, got: {bare_Any}";

        # Bare `final` without import → same — guards __all__ discipline.
        bare_final = lsp.get_definition(f, lspt.Position(6, 8));
        assert bare_final is None , f"Expected None, got: {bare_final}";
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_method_manual_impl" {
    setup_test();
    try {
        lsp = create_server("");
        decldef_file = uris.from_fs_path(
            os.path.join(
                JAC_ROOT,
                "tests",
                "compiler",
                "fixtures",
                "micro",
                "decl_defs_main.impl.jac"
            )
        );
        lsp.type_check_file(decldef_file);
        decldef_main_file = uris.from_fs_path(
            os.path.join(
                JAC_ROOT, "tests", "compiler", "fixtures", "micro", "decl_defs_main.jac"
            )
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
            (3, 11, "asyncio/__init__.pyi:0:0-0:0"),
            (6, 17, "concurrent/__init__.pyi:0:0-0:0"),
            (6, 28, "concurrent/futures/__init__.pyi:0:0-0:0"),
            (7, 17, "typing.pyi:0:0-0:0"),
            (9, 18, "jaclang/jac0core/__init__.py:0:0-0:0"),
            (9, 25, "jaclang/jac0core/unitree.jac:0:0-0:0"),
            (10, 34, "jac/jaclang/__init__.py:22:"),
            (11, 35, "jaclang/jac0core/constant.jac:0:0-0:0"),
            (11, 47, "jaclang/jac0core/constant.jac:4:5-4:15"),
            (13, 47, "jaclang/compiler/type_system/type_utils.jac:0:0-0:0"),
            (14, 34, "jaclang/compiler/type_system/__init__.py:0:0-0:0"),
            (18, 5, "compiler/type_system/types.jac:61:4-61:12"),
            (20, 34, "jaclang/jac0core/unitree.jac:0:0-0:0"),
            (22, 22, "tests/langserve/fixtures/circle.jac:7:5-7:8"),
            (23, 28, "jaclang/lsp/uris.jac:0:0-0:0"),
            (24, 40, "jaclang/lsp/server.jac:117:4-117:18"),
            (26, 31, "jaclang/lsp/types.jac:0:0-0:0"),

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

test "test_go_to_definition_jsx_component" {
    setup_test();
    try {
        lsp = create_server();
        jsx_file = uris.from_fs_path(fixture_path("jsx_goto_def.cl.jac"));
        lsp.type_check_file(jsx_file);
        # Cursor inside the <MyButton ...> tag name on line 11 (0-indexed 10).
        # `        <MyButton ...` -- 'M' is at column 9, so col 12 lands on 'u'.
        result = str(lsp.get_definition(jsx_file, lspt.Position(10, 12)));
        # Expect to land on the MyButton function declaration on line 3
        # (0-indexed 2): `def MyButton(...` -- 'MyButton' spans cols 4-12.
        assert "jsx_goto_def.cl.jac:2:4-2:12" in result , f"Unexpected go-to-def result for JSX tag: {result}";
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_connect_filter" {
    setup_test();
    try {
        lsp = create_server("");
        import_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker/checker_connect_filter.jac")
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
            (8, 25, "datetime.pyi:"),

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

test "test_go_to_definition_by_postinit" {
    setup_test();
    try {
        lsp = create_server("");
        file_uri = uris.from_fs_path(
            passes_main_fixture_abs_path("static_analysis/by_postinit_sym.jac")
        );
        lsp.type_check_file(file_uri);
        # Foo: inline
        result = lsp.get_definition(file_uri, lspt.Position(1, 20));
        assert result is not None , "Foo: expected go-to-def for 'postinit', got None";
        assert "by_postinit_sym.jac:2:" in str(result) , f"Foo: expected line 3 (0-indexed 2), got: {result}";
        # Bar: stub+impl file
        result = lsp.get_definition(file_uri, lspt.Position(8, 20));
        assert result is not None , "Bar: expected go-to-def for 'postinit', got None";
        assert "by_postinit_sym.jac:9:" in str(result) , f"Bar: expected line 10 (0-indexed 9), got: {result}";
        # Baz: impl block
        result = lsp.get_definition(file_uri, lspt.Position(15, 20));
        assert result is not None , "Baz: expected go-to-def for 'postinit', got None";
        assert "by_postinit_sym.jac:16:" in str(result) , f"Baz: expected line 17 (0-indexed 16), got: {result}";
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

test "test_go_to_definition_stub_param_compound_types" {
    setup_test();
    try {
        lsp = create_server();
        stub_file = uris.from_fs_path(fixture_path("stub_param_goto_def.jac"));
        lsp.type_check_file(stub_file);

        # (line, col, description) — 1-indexed; col points to `Module` in `uni.Module`
        positions = [
            (8, 47, "simple param: uni.Module"),
            (10, 40, "list param: list[uni.Module]"),
            (12, 38, "union param: uni.Module | None"),
            (14, 45, "dict param: dict[str, uni.Module]"),
            (16, 43, "Optional param: Optional[uni.Module]"),

        ];

        for (line, col, desc) in positions {
            result = lsp.get_definition(stub_file, lspt.Position(line - 1, col - 1));
            assert result is not None , f"go-to-def returned None for {desc}";
            assert "unitree.jac" in str(result) , f"Expected unitree.jac for {desc}, got: {result}";
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

test "test_hover_types" {
    setup_test();
    try {
        lsp = create_server("");
        narrowing_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker/checker_and_narrowing.jac")
        );
        lsp.type_check_file(narrowing_file);

        hover_cases: list[tuple] = [
            (4, 9, "str", None),
            (8, 9, "list", None),
            (12, 9, "bool", None),
            (15, 28, "Animal", None),
            (17, 11, "offspring", None),
            (93, 27, "Mammal", "None"),
            (105, 29, "Mammal", "None"),
            (113, 9, "Mammal", None),

        ];

        for case in hover_cases {
            (line, col, expected, should_not_contain) = case;
            hover = lsp.get_hover_info(
                narrowing_file, lspt.Position(line - 1, col - 1)
            );
            assert hover is not None , f"Hover should exist at line {line}, col {col}";
            assert expected in hover.contents.value , f"Line {line}: expected '{expected}' in hover, got: {hover.contents.value}";
            if should_not_contain {
                assert should_not_contain not in hover.contents.value , f"Line {line}: should NOT contain '{should_not_contain}', got: {hover.contents.value}";
            }
        }

        # Match-case narrowing: expr should be AtomTrailer, not JsxElement | AtomTrailer
        match_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_match_case_narrowing.jac")
        );
        lsp.type_check_file(match_file);
        hover = lsp.get_hover_info(match_file, lspt.Position(27, 19));
        assert hover is not None , "Match-case hover should exist";
        assert "AtomTrailer" in hover.contents.value , f"Match-case: expected AtomTrailer, got: {hover.contents.value}";
        assert "JsxElement" not in hover.contents.value , f"Match-case: should NOT contain JsxElement, got: {hover.contents.value}";

        # Walrus narrowing: greeting should be str, not str | None
        walrus_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_walrus_narrowing.jac")
        );
        lsp.type_check_file(walrus_file);
        hover = lsp.get_hover_info(walrus_file, lspt.Position(13, 15));
        assert hover is not None , "Walrus hover should exist";
        assert "str" in hover.contents.value , f"Walrus: expected str, got: {hover.contents.value}";
        assert "None" not in hover.contents.value , f"Walrus: should NOT contain None (narrowed!), got: {hover.contents.value}";

        # Comprehension types: iteration variables should have inferred types
        compr_file = uris.from_fs_path(fixture_path("hover_comprehension.jac"));
        lsp.type_check_file(compr_file);
        compr_cases = [
            (4, 41, "int"),
            (5, 27, "int"),
            (6, 22, "int"),
            (7, 30, "int"),

        ];
        for (line, col, expected) in compr_cases {
            hover = lsp.get_hover_info(compr_file, lspt.Position(line - 1, col - 1));
            assert hover is not None , f"Compr hover should exist at line {line}, col {col}";
            assert expected in hover.contents.value , f"Compr line {line}: expected '{expected}', got: {hover.contents.value}";
        }

        # __getattr__ dynamic attributes: hover should show "(dynamic attribute) name: type"
        getattr_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker_getattr_support.jac")
        );
        lsp.type_check_file(getattr_file);
        hover = lsp.get_hover_info(getattr_file, lspt.Position(23, 16));
        assert hover is not None , "__getattr__ hover should exist for p.foo";
        assert "dynamic attribute" in hover.contents.value , f"p.foo: expected 'dynamic attribute', got: {hover.contents.value}";
        assert "str" in hover.contents.value , f"p.foo: expected 'str' type, got: {hover.contents.value}";
        hover = lsp.get_hover_info(getattr_file, lspt.Position(31, 16));
        assert hover is not None , "Hover should exist for m.real_attr";
        assert "dynamic attribute" not in hover.contents.value , f"m.real_attr: should NOT be 'dynamic attribute', got: {hover.contents.value}";
        hover = lsp.get_hover_info(getattr_file, lspt.Position(32, 16));
        assert hover is not None , "__getattr__ hover should exist for m.dynamic_attr";
        assert "dynamic attribute" in hover.contents.value , f"m.dynamic_attr: expected 'dynamic attribute', got: {hover.contents.value}";
        hover = lsp.get_hover_info(getattr_file, lspt.Position(39, 18));
        assert hover is not None , "Hover should exist for ng.real_attr";
        assert "dynamic attribute" not in hover.contents.value , f"ng.real_attr: should NOT be 'dynamic attribute', got: {hover.contents.value}";
        hover = lsp.get_hover_info(getattr_file, lspt.Position(42, 7));
        if hover is not None {
            assert "dynamic attribute" not in hover.contents.value , f"ng.nonexistent: should NOT be 'dynamic attribute', got: {hover.contents.value}";
        }

        # Overload resolution: str.split() -> list[str], list[str][0] -> str
        overload_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker/checker_overload_resolution.jac")
        );
        lsp.type_check_file(overload_file);
        overload_cases = [
            (4, 6, ["list"]),  # parts: list[str] or list[LiteralString]
            (5, 6, ["str", "String"]),  # first: str or LiteralString
            (6, 6, ["str", "String"]),  # result: str or LiteralString
            (8, 6, ["list"]),  # parts2: list[str] or list[LiteralString]
            (9, 6, ["str", "String"]),  # first3: str or LiteralString
            (10, 6, ["str", "String"]),  # result3: str or LiteralString

        ];
        for (line, col, expected_list) in overload_cases {
            hover = lsp.get_hover_info(overload_file, lspt.Position(line - 1, col - 1));
            assert hover is not None , f"Overload hover at line {line} should exist";
            found = False;
            for exp in expected_list {
                if exp in hover.contents.value {
                    found = True;
                    break;
                }
            }
            assert found , f"Overload line {line}: expected one of {expected_list}, got: {hover.contents.value}";
        }

        # Stdlib overload via wildcard import: os.path.dirname (from posixpath/ntpath import *)
        stdlib_file = uris.from_fs_path(fixture_path("stdlib_overload.jac"));
        lsp.type_check_file(stdlib_file);
        hover = lsp.get_hover_info(stdlib_file, lspt.Position(5, 22));
        assert hover is not None , "Hover should return info for os.path.dirname";
        assert "dirname" in hover.contents.value , f"os.path.dirname: expected 'dirname', got: {hover.contents.value}";
        defn = lsp.get_definition(stdlib_file, lspt.Position(5, 22));
        assert defn is not None , "Definition should be found for os.path.dirname";
        assert "posixpath.pyi" in defn.uri or "ntpath.pyi" in defn.uri , f"os.path.dirname go-to-def: expected posixpath/ntpath.pyi, got: {defn.uri}";

        # isinstance narrowing in ternary: true branch should show narrowed type
        ternary_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker/checker_isinstance_ternary.jac")
        );
        lsp.type_check_file(ternary_file);
        # Line 8: result = [left] if isinstance(left, Node) else left;
        # True branch: left should be narrowed to Node (column 15, 0-indexed: 14)
        hover = lsp.get_hover_info(ternary_file, lspt.Position(7, 14));
        assert hover is not None , "Ternary true branch hover should exist";
        assert "Node" in hover.contents.value , f"Ternary true branch: expected Node, got: {hover.contents.value}";
        assert "list[Node]" not in hover.contents.value , f"Ternary true branch: should NOT contain list[Node], got: {hover.contents.value}";
        # Else branch: left should be narrowed to list[Node] (column 53, 0-indexed: 52)
        hover = lsp.get_hover_info(ternary_file, lspt.Position(7, 52));
        assert hover is not None , "Ternary else branch hover should exist";
        assert "list[Node]" in hover.contents.value , f"Ternary else branch: expected list[Node], got: {hover.contents.value}";

        # Generic function TypeVar resolution: resolved return types should appear in hover
        typevar_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker/checker_gap_func_typevar.jac")
        );
        lsp.type_check_file(typevar_file);

        typevar_cases: list[tuple[int, int, str, str]] = [
            (37, 4, "ok1", "int"),
            (42, 4, "result1", "Animal"),
            (43, 4, "result2", "Dog"),
            (47, 4, "result1", "Dog"),
            (48, 4, "result2", "Cat"),
            (51, 4, "ok_swap", "tuple"),

        ];
        for (line, col, var_name, expected_type) in typevar_cases {
            hover = lsp.get_hover_info(typevar_file, lspt.Position(line, col));
            assert hover is not None , f"Hover should exist for {var_name}";
            assert expected_type in hover.contents.value , f"{var_name} should contain {expected_type}, got: {hover.contents.value}";
        }
    } finally {
        teardown_test();
    }
}

"""Hover on an LHS assignment target shows the post-write effective type."""
test "test_hover_lhs_assignment" {
    setup_test();
    try {
        lsp = create_server("");
        lhs_file = uris.from_fs_path(fixture_path("hover_lhs_assignment.jac"));
        lsp.type_check_file(lhs_file);

        # (line, col, desc, expected, should_not_contain)
        cases: list[tuple] = [
            (13, 5, "flat_narrow LHS x", "int", "None"),
            (14, 12, "flat_narrow read x", "int", "None"),
            (19, 5, "flat_to_none LHS x", "None", "int"),
            (20, 12, "flat_to_none read x", "None", "int"),
            (25, 5, "flat_to_union LHS x", "int | NoneType", None),
            (26, 12, "flat_to_union read x", "int | NoneType", None),
            (31, 6, "destructure_narrow LHS x", "int", "None"),
            (32, 12, "destructure_narrow read x", "int", "None"),
            (37, 10, "destructure_nested LHS b", "int", "None"),
            (38, 12, "destructure_nested read b", "int", "None"),
            # aug_op: `x += 1` must not leak the bare RHS type.
            (44, 9, "aug_op LHS x", "int | NoneType", None),
            # NamedTuple destructure: LHS x narrows to `int` via shared helper.
            (51, 6, "destructure_named_tuple LHS x", "int", "None"),
            (52, 12, "destructure_named_tuple read x", "int", "None"),

        ];
        for case in cases {
            (line, col, desc, expected, should_not_contain) = case;
            hover = lsp.get_hover_info(lhs_file, lspt.Position(line - 1, col - 1));
            assert hover is not None , f"Hover should exist for {desc} at line {line}";
            assert expected in hover.contents.value , f"{desc}: expected '{expected}' in hover, got: {hover.contents.value}";
            if should_not_contain {
                assert should_not_contain not in hover.contents.value , f"{desc}: should NOT contain '{should_not_contain}', got: {hover.contents.value}";
            }
        }
    } finally {
        teardown_test();
    }
}

"""Test NamedTuple hover information - comprehensive tests for all features."""
test "test_namedtuple_hover" {
    setup_test();
    try {
        lsp = create_server("");
        namedtuple_file = uris.from_fs_path(
            passes_main_fixture_abs_path("checker/checker_namedtuple.jac")
        );
        lsp.type_check_file(namedtuple_file);

        # Comprehensive list of all variables and their expected hover types
        # Format: (line_0indexed, col, name, expected_type_substring)
        hover_tests: list[tuple[int, int, str, str]] = [
            # Class definitions
            (3, 7, "ProcessedImports", "ProcessedImports"),
            (8, 7, "Point", "Point"),
            (13, 7, "Person", "Person"),
            # Field definitions (has vars)
            (4, 9, "import_pieces", "list"),
            (5, 9, "bundled_module_names", "set"),
            (9, 9, "x", "int"),
            (10, 9, "y", "int"),
            (14, 9, "name", "str"),
            (15, 9, "age", "int"),
            (16, 9, "city", "str"),
            # Function definitions
            (20, 5, "process_point", "process_point"),
            (25, 5, "process_tuple", "process_tuple"),
            # Constructor variables - TEST 1
            (33, 5, "import_pieces", "list"),
            (34, 5, "bundled_module_names", "set"),
            (35, 5, "result", "ProcessedImports"),
            (38, 5, "result2", "ProcessedImports"),
            (41, 4, "p", "Point"),
            (44, 5, "person1", "Person"),
            (46, 5, "person2", "Person"),
            # Field access - TEST 2
            (51, 5, "x_val", "int"),
            (52, 5, "y_val", "int"),
            (53, 5, "name_val", "str"),
            (54, 5, "age_val", "int"),
            (55, 5, "pieces", "list"),
            # Tuple unpacking - TEST 3
            (60, 5, "px", "int"),
            (60, 9, "py", "int"),
            (61, 5, "pname", "str"),
            (61, 12, "page", "int"),
            (61, 18, "pcity", "str"),
            # For loop iteration - TEST 5
            (72, 9, "coord", "int"),
            # Function call result - TEST 6
            (79, 5, "total", "int"),
            # Comparison - TEST 9
            (97, 5, "p1", "Point"),
            (98, 5, "p2", "Point"),
            (99, 5, "p3", "Point"),
            (100, 5, "is_equal", "bool"),
            (101, 5, "is_less", "bool"),

        ];

        # Run all hover tests
        for (line, col, name, expected_type) in hover_tests {
            hover = lsp.get_hover_info(namedtuple_file, lspt.Position(line, col));
            assert hover is not None , f"Hover for '{name}' at line {line + 1} should exist";
            assert expected_type in hover.contents.value , f"'{name}' at line {line + 1}: expected '{expected_type}', got: {hover.contents.value}";
        }
    } finally {
        teardown_test();
    }
}

test "test_go_to_definition_import_module_path_and_item" {
    setup_test();
    try {
        lsp = create_server();
        import_file = uris.from_fs_path(fixture_path("local_imports/main.jac"));
        lsp.type_check_file(import_file);

        # Line 3: import from mypkg_deep.utils.helpers { greet, greeting }
        # Test module path segments (each should navigate to the module/directory)
        positions = [
            # "mypkg_deep" in module path → namespace package dir
            (3, 15, "local_imports/mypkg_deep"),
            # "utils" in module path → namespace package dir
            (3, 25, "local_imports/mypkg_deep/utils"),
            # "helpers" in module path → module file at 0:0
            (3, 31, "local_imports/mypkg_deep/utils/helpers.jac"),
            # "greet" in { greet, greeting } → definition in helpers.jac
            (3, 41, "local_imports/mypkg_deep/utils/helpers.jac"),
            # "greeting" in { greet, greeting } → definition in helpers.jac
            (3, 48, "local_imports/mypkg_deep/utils/helpers.jac"),

        ];

        for (line, char, expected) in positions {
            def_loc = lsp.get_definition(
                import_file, lspt.Position(line - 1, char - 1)
            );
            assert def_loc is not None , f"Definition at line {line}, col {char} not found";
            assert expected in str(def_loc) , f"Expected '{expected}' in definition for "
            f"line {line}, char {char}, got: {def_loc}";
        }
    } finally {
        teardown_test();
    }
}

test "test_cross_module_imported_func_no_false_errors" {
    setup_test();
    try {
        lsp = create_server();
        caller_file = uris.from_fs_path(fixture_path("cross_module_func_caller.jac"));
        lsp.type_check_file(caller_file);

        # There should be no diagnostics on line 5 (the call site).
        # Previously, JIR cache corruption caused FunctionType to have 0 params,
        # which produced false "wrong number of arguments" errors.
        diags = lsp.diagnostics.get(caller_file, []);
        call_line_diags = [
            d
            for d in diags
            if d.range.start.line == 4
        ];
        assert len(call_line_diags) == 0 , f"Expected no errors on call line, got: "
        f"{[d.message for d in call_line_diags]}";
    } finally {
        teardown_test();
    }
}

"""Stale JIR caches from older compiler versions must be rejected.

Regression test: a cache written by a buggy compiler (before #5195)
would lose FuncSignature.params, causing false E1052 errors on every
call site.  is_module_cache_valid must reject caches whose
jaclang_version_hash doesn't match the running compiler.
"""
test "test_jir_cache_invalidated_on_version_mismatch" {
    import struct;
    import tempfile;
    import shutil;
    import from jaclang.jac0core.jir {
        get_module_cache_path,
        is_module_cache_valid,
        HEADER_FMT,
        HEADER_SIZE
    }

    setup_test();
    try {
        lsp = create_server();
        # Type-check the caller to force JIR cache creation for the dependency.
        caller_file = uris.from_fs_path(fixture_path("cross_module_func_caller.jac"));
        lsp.type_check_file(caller_file);

        # Locate the JIR cache for the dependency module.
        dep_src = fixture_path("cross_module_func.jac");
        cache_path = get_module_cache_path(dep_src);

        # Sanity: cache should exist and be valid right now.
        assert cache_path.exists() , "JIR cache was not written";
        assert is_module_cache_valid(dep_src, cache_path) , "Fresh cache should be valid";

        # Tamper: overwrite jaclang_version_hash with a fake value.
        data = bytearray(cache_path.read_bytes());
        # Header layout <4sHHIIIIII>: jaclang_version_hash is at offset 8.
        struct.pack_into("<I", data, 8, 0xDEADBEEF);
        cache_path.write_bytes(bytes(data));

        # The cache should now be rejected.
        assert not is_module_cache_valid(dep_src, cache_path) , (
            "Cache with mismatched jaclang_version_hash should be invalid"
        );
    } finally {
        teardown_test();
    }
}

test "test_cross_module_imported_func_sem_token" {
    import from jaclang.jac0core.constant { JacSemTokenType }
    setup_test();
    try {
        lsp = create_server();
        caller_file = uris.from_fs_path(fixture_path("cross_module_func_caller.jac"));
        lsp.type_check_file(caller_file);

        # "greet_user" on line 3 (import) should have FUNCTION sem token, not PROPERTY.
        import_tok = lsp.get_token_at_position(caller_file, lspt.Position(2, 35));
        assert import_tok is not None , "Expected token at import line";
        sem = import_tok.sem_token;
        assert sem is not None , "Expected sem_token for imported function";
        assert sem[0] == JacSemTokenType.FUNCTION , (
            f"Expected FUNCTION sem token for imported function, got: {sem[0]}"
        );

        # "greet_user" on line 5 (call site) should also have FUNCTION sem token.
        call_tok = lsp.get_token_at_position(caller_file, lspt.Position(4, 14));
        assert call_tok is not None , "Expected token at call site";
        call_sem = call_tok.sem_token;
        assert call_sem is not None , "Expected sem_token for function call";
        assert call_sem[0] == JacSemTokenType.FUNCTION , (
            f"Expected FUNCTION sem token at call site, got: {call_sem[0]}"
        );
    } finally {
        teardown_test();
    }
}

test "test_format_document_lintfix" {
    # Verifies lintfix output exactly matches the expected file.
    setup_test();
    try {
        lsp = create_server(FIXTURE_DIR);
        file_uri = uris.from_fs_path(fixture_path("format_lintfix.jac"));
        lsp.type_check_file(file_uri);
        edits = lsp.format_document(file_uri, auto_lint=True);
        assert edits is not None and len(edits) > 0 , "Expected text edits from lintfix format_document";
        lintfixed = edits[0].new_text;
        expected = open(fixture_path("format_lintfix_expected.jac")).read();
        assert lintfixed == expected , (
            f"Lintfix output does not match expected.\nGOT:\n{lintfixed}\nEXPECTED:\n{expected}"
        );
    } finally {
        teardown_test();
    }
}
