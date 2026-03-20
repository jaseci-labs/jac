"""Tests for the native lexer and auto-marshalling infrastructure.

Tests:
1. Native lexer compilation
2. NativeModuleLayout metadata export from NaIRGenPass
3. Auto-generated ctypes marshalling via native_marshal.jac
"""

import ctypes;
import os;
import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.codeinfo { NativeFunctionInfo }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.parser.tokens { Token, TokenKind, SourceLoc }
import from jaclang.jac0core.parser.lexer { Lexer }
import from llvmlite.binding { ExecutionEngine }
import jaclang.jac0core.unitree as uni;

glob NA_LEXER_PATH = str(
         Path(jaclang.__file__).parent / "jac0core" / "parser" / "lexer.na.jac"
     ),
     FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     );

def compile_fixture(fixture: str) -> tuple[ExecutionEngine | None, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    return (ir.gen.native_engine, ir);
}

# --- Compilation test ---
test "native lexer compiles" {
    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , "No native engine produced for lexer.na.jac";
}

# --- Metadata export tests ---
test "native layout exported for lexer" {
    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    layout = ir.gen.native_layout;
    assert layout is not None , "No native_layout on CodeGenTarget";
    assert len(layout.structs) > 0 , "No structs in layout";
    assert len(layout.enums) > 0 , "No enums in layout";
    assert len(layout.functions) > 0 , "No functions in layout";
}

test "native layout struct fields correct" {
    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    layout = ir.gen.native_layout;
    assert layout is not None;
    assert "SourceLoc" in layout.structs , "SourceLoc struct missing";
    loc = layout.structs["SourceLoc"];
    field_names = [f.name for f in loc.fields];
    assert "line" in field_names , "SourceLoc.line field missing";
    assert "col_start" in field_names , "SourceLoc.col_start field missing";
}

test "native layout enum members correct" {
    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    layout = ir.gen.native_layout;
    assert layout is not None;
    assert len(layout.enums) > 0 , "No enums in layout";
    for (ename, elayout) in layout.enums.items() {
        assert len(elayout.members) > 0 , f"Enum {ename} has no members";
    }
}

test "native layout functions have types" {
    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    layout = ir.gen.native_layout;
    assert layout is not None;
    for (fname, flayout) in layout.functions.items() {
        assert flayout.ret_type , f"Function {fname} has no ret_type";
    }
}

# --- Auto-marshalling tests with arithmetic fixture ---
test "auto-marshal arithmetic add" {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function
    }
    (eng, ir) = compile_fixture("arithmetic.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    func_layout = layout.functions.get("add");
    assert func_layout is not None , "add function not in layout";
    wrapper = wrap_native_function(eng, func_layout, ct_classes, enum_maps, {});
    assert wrapper is not None , "Failed to wrap add function";
    assert wrapper(3, 4) == 7;
    assert wrapper(-1, 1) == 0;
    assert wrapper(100, 200) == 300;
}

test "auto-marshal arithmetic float_add" {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function
    }
    (eng, ir) = compile_fixture("arithmetic.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    func_layout = layout.functions.get("float_add");
    assert func_layout is not None , "float_add function not in layout";
    wrapper = wrap_native_function(eng, func_layout, ct_classes, enum_maps, {});
    assert wrapper is not None;
    result = wrapper(1.5, 2.5);
    assert abs(result - 4.0) < 0.001 , f"Expected 4.0, got {result}";
}

test "auto-marshal install_native_wrappers" {
    import types;
    import from jaclang.jac0core.native_marshal { install_native_wrappers }
    (eng, ir) = compile_fixture("arithmetic.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;

    # Create a mock module with Python functions
    mock_mod = types.ModuleType("mock_arithmetic");
    mock_mod.add = lambda a: int , b: int : a + b;
    mock_mod.multiply = lambda a: int , b: int : a * b;
    mock_mod.negate = lambda x: int : -x;
    mock_mod.float_add = lambda a: float , b: float : a + b;

    count = install_native_wrappers(mock_mod, eng, layout);
    assert count >= 1 , f"Expected at least 1 wrapper installed, got {count}";

    # Verify the native wrapper works
    assert mock_mod.add(10, 20) == 30;
    assert mock_mod.multiply(5, 6) == 30;

    # Verify original Python functions are preserved
    assert hasattr(mock_mod, "_py_add") , "Original Python add not preserved";
}

# --- String enum auto-marshalling ---
test "native layout for string enums" {
    (eng, ir) = compile_fixture("string_enums.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
    assert "Color" in layout.enums , "Color enum not in layout";
    color_layout = layout.enums["Color"];
    assert color_layout.is_string_valued , "Color should be string-valued";
    member_names = [m[0] for m in color_layout.members];
    assert "RED" in member_names;
    assert "GREEN" in member_names;
    assert "BLUE" in member_names;
}

test "auto-marshal string enum functions" {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function
    }
    (eng, ir) = compile_fixture("string_enums.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    # color_ordinal_red should return 0 (ordinal of RED)
    func_layout = layout.functions.get("color_ordinal_red");
    assert func_layout is not None;
    wrapper = wrap_native_function(eng, func_layout, ct_classes, enum_maps, {});
    assert wrapper is not None;
    assert wrapper() == 0 , f"Expected 0 (RED ordinal), got {wrapper()}";
    # color_ordinal_blue should return 2 (ordinal of BLUE)
    func_layout2 = layout.functions.get("color_ordinal_blue");
    wrapper2 = wrap_native_function(eng, func_layout2, ct_classes, enum_maps, {});
    assert wrapper2() == 2 , f"Expected 2 (BLUE ordinal), got {wrapper2()}";
}

# --- Tuple metadata export ---
test "native layout tuple metadata for tokenize" {
    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    layout = ir.gen.native_layout;
    assert layout is not None;
    assert len(layout.tuples) > 0 , "No tuples in layout";
    # tokenize function should have ret_tuple_layout
    func_layout = layout.functions.get("tokenize");
    assert func_layout is not None , "tokenize function not in layout";
    assert func_layout.ret_type == "Tuple*" , f"Expected Tuple* return, got {func_layout.ret_type}";
    assert func_layout.ret_tuple_layout is not None , "tokenize has no ret_tuple_layout";
    tl = func_layout.ret_tuple_layout;
    assert len(tl.element_types) == 2 , f"Expected 2 tuple elements, got {len(
        tl.element_types
    )}";
    # First element: list of Token structs, second element: i64 (error count)
    assert tl.element_types[0] == "List.ptr*" , f"Element 0: {tl.element_types[0]}";
    assert tl.element_types[1] == "i64" , f"Element 1: {tl.element_types[1]}";
    # Struct hint for first element should identify Token
    assert tl.element_struct_hints[0] == "Token" , f"Hint 0: {tl.element_struct_hints[
        0
    ]}";
}

# --- Tuple/struct auto-marshalling proof of concept ---
test "auto-marshal tuple with struct list" {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function
    }
    (eng, ir) = compile_fixture("tuple_structs.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    # Call jac_entry to init globals
    entry_addr = eng.get_function_address("jac_entry");
    if entry_addr {
        import ctypes as ct;
        entry_fn = ct.CFUNCTYPE(None)(entry_addr);
        entry_fn();
    }
    # Test split_points: returns tuple[list[Point], list[int]]
    func_layout = layout.functions.get("split_points");
    assert func_layout is not None;
    assert func_layout.ret_type == "Tuple*";
    assert func_layout.ret_tuple_layout is not None;
    wrapper = wrap_native_function(
        eng, func_layout, ct_classes, enum_maps, {}, layout=layout
    );
    assert wrapper is not None;
    result = wrapper(3);
    assert isinstance(result, tuple) , f"Expected tuple, got {type(result)}";
    assert len(result) == 2;
    (points, sums) = result;
    assert len(points) == 3;
    assert len(sums) == 3;
    # Verify struct fields (zero-copy NativeStructView — supports ["field"])
    assert points[0]["x"] == 0 and points[0]["y"] == 0;
    assert points[1]["x"] == 1 and points[1]["y"] == 10;
    assert points[2]["x"] == 2 and points[2]["y"] == 20;
    # Verify int list
    assert sums == [0, 11, 22];
}

test "auto-marshal struct with string field" {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function
    }
    (eng, ir) = compile_fixture("tuple_structs.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
    assert eng is not None;
    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    entry_addr = eng.get_function_address("jac_entry");
    if entry_addr {
        import ctypes as ct;
        entry_fn = ct.CFUNCTYPE(None)(entry_addr);
        entry_fn();
    }
    func_layout = layout.functions.get("make_result");
    assert func_layout is not None;
    wrapper = wrap_native_function(
        eng, func_layout, ct_classes, enum_maps, {}, layout=layout
    );
    assert wrapper is not None;
    result = wrapper(42, "hello");
    assert result["value"] == 42;
    assert result["label"] == "hello";
}

# --- Native tokenize end-to-end tests ---
test "native tokenize returns correct tokens" {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function
    }
    import ctypes as ct;

    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    eng = ir.gen.native_engine;
    layout = ir.gen.native_layout;
    assert eng is not None;
    assert layout is not None;

    # Init globals: tokens module first (KEYWORDS dict), then lexer module
    tokens_glob_addr = eng.get_function_address("__jac_glob_init_tokens_na");
    if tokens_glob_addr {
        ct.CFUNCTYPE(None)(tokens_glob_addr)();
    }
    glob_init_addr = eng.get_function_address("__jac_glob_init");
    if glob_init_addr {
        ct.CFUNCTYPE(None)(glob_init_addr)();
    }

    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    func_layout = layout.functions.get("tokenize");
    assert func_layout is not None , "tokenize function not in layout";
    wrapper = wrap_native_function(
        eng, func_layout, ct_classes, enum_maps, {}, layout=layout
    );
    assert wrapper is not None;

    result = wrapper("x = 1;", "test.jac");
    assert isinstance(result, tuple) , f"Expected tuple, got {type(result)}";
    assert len(result) == 2;
    (tokens, error_count) = result;
    assert error_count == 0 , f"Unexpected errors: {error_count}";
    # Expected tokens: NAME('x'), EQ('='), INT('1'), SEMI(';'), EOF('')
    assert len(tokens) >= 5 , f"Expected >= 5 tokens, got {len(tokens)}";
    # Check token values
    values = [t["value"] if isinstance(t, dict) else t.value for t in tokens];
    assert "x" in values , f"Missing 'x' in token values: {values}";
    assert "=" in values , f"Missing '=' in token values: {values}";
    assert "1" in values , f"Missing '1' in token values: {values}";
    # Check NAME token kind is correct (not -1)
    name_tok = tokens[0];
    name_kind = name_tok["kind"] if isinstance(name_tok, dict) else name_tok.kind;
    name_ordinal = list(TokenKind).index(TokenKind.NAME);
    assert name_kind == name_ordinal , f"NAME token kind should be {name_ordinal}, got {name_kind}";
}

test "native tokenize matches python lexer" {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function
    }
    import ctypes as ct;

    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    eng = ir.gen.native_engine;
    layout = ir.gen.native_layout;
    assert eng is not None;
    assert layout is not None;
    tokens_glob_addr = eng.get_function_address("__jac_glob_init_tokens_na");
    if tokens_glob_addr {
        ct.CFUNCTYPE(None)(tokens_glob_addr)();
    }
    glob_init_addr = eng.get_function_address("__jac_glob_init");
    if glob_init_addr {
        ct.CFUNCTYPE(None)(glob_init_addr)();
    }

    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    func_layout = layout.functions.get("tokenize");
    wrapper = wrap_native_function(
        eng, func_layout, ct_classes, enum_maps, {}, layout=layout
    );
    assert wrapper is not None;

    source = "x = 1 + 2;";
    (na_tokens, na_errors) = wrapper(source, "test.jac");

    # Compare against Python lexer
    py_lexer = Lexer(source, "test.jac");
    py_tokens = py_lexer.tokenize();

    assert len(na_tokens) == len(py_tokens) , (
        f"Token count mismatch: native={len(na_tokens)}, python={len(py_tokens)}"
    );
    for i in range(len(py_tokens)) {
        na_tok = na_tokens[i];
        py_tok = py_tokens[i];
        na_val = na_tok["value"] if isinstance(na_tok, dict) else na_tok.value;
        assert na_val == py_tok.value , (
            f"Token {i} value mismatch: native='{na_val}', python='{py_tok.value}'"
        );
    }
}

# --- Performance benchmark ---
test "native tokenize performance" {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function
    }
    import ctypes as ct;
    import time;

    prog = JacProgram();
    ir = prog.compile(file_path=NA_LEXER_PATH);
    eng = ir.gen.native_engine;
    layout = ir.gen.native_layout;
    assert eng is not None;
    assert layout is not None;
    tokens_glob_addr = eng.get_function_address("__jac_glob_init_tokens_na");
    if tokens_glob_addr {
        ct.CFUNCTYPE(None)(tokens_glob_addr)();
    }
    glob_init_addr = eng.get_function_address("__jac_glob_init");
    if glob_init_addr {
        ct.CFUNCTYPE(None)(glob_init_addr)();
    }

    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    func_layout = layout.functions.get("tokenize");
    na_tokenize = wrap_native_function(
        eng, func_layout, ct_classes, enum_maps, {}, layout=layout
    );

    # Generate a non-trivial source string
    source = "x = 1 + 2;\n" * 100;
    iterations = 50;

    # Benchmark native tokenize (includes marshalling overhead)
    start = time.perf_counter();
    for _ in range(iterations) {
        (na_tokens, na_errors) = na_tokenize(source, "bench.jac");
    }
    na_time = time.perf_counter() - start;

    # Benchmark Python lexer
    start = time.perf_counter();
    for _ in range(iterations) {
        py_lexer = Lexer(source, "bench.jac");
        py_tokens = py_lexer.tokenize();
    }
    py_time = time.perf_counter() - start;

    speedup = py_time / na_time if na_time > 0 else float("inf");
    print(
        f"\nPerf: native={na_time:.3f}s, python={py_time:.3f}s, "
        f"speedup={speedup:.2f}x ({iterations} iters, {len(source)} chars)"
    );
    # Just verify it completes; speedup depends on marshalling overhead
    assert na_time > 0;
    assert py_time > 0;
}

# --- Deferred native acceleration tests ---
test "discover bootstrap na modules" {
    import from jaclang.jac0core.native_accel { discover_bootstrap_na_modules }
    modules = discover_bootstrap_na_modules();
    # lexer.na.jac should be discovered if it's loaded
    found_lexer = False;
    for (mod_name, na_file) in modules.items() {
        if "lexer" in mod_name and na_file.endswith("lexer.na.jac") {
            found_lexer = True;
        }
    }
    assert found_lexer , f"lexer.na.jac not found in discovered modules: {modules}";
}

test "accelerate module compiles lexer" {
    import from jaclang.jac0core.native_accel { accelerate_module }
    mod_name = "jaclang.jac0core.parser.lexer";
    na_file = str(
        Path(jaclang.__file__).parent / "jac0core" / "parser" / "lexer.na.jac"
    );
    # Ensure module is loaded
    assert mod_name in sys.modules , f"{mod_name} not loaded";
    lexer_mod = sys.modules[mod_name];

    # Save original functions so we can restore after test
    saved: dict = {};
    for (name, obj) in list(lexer_mod.__dict__.items()) {
        if callable(obj) and not name.startswith("_") {
            saved[name] = obj;
        }
    }

    try {
        count = accelerate_module(mod_name, na_file);
        assert count >= 0 , f"accelerate_module failed with {count}";
        # Check that the engine was stored on the module
        if count > 0 {
            assert hasattr(lexer_mod, "__jac_native_engine__") , "Native engine not stored on module";
            assert hasattr(lexer_mod, "__jac_native_layout__") , "Native layout not stored on module";
        }
    } finally {
        # Restore original Python functions to avoid corrupting other tests
        # in the same xdist worker (native wrappers return int ordinals
        # instead of TokenKind enum members)
        for (name, orig) in saved.items() {
            if hasattr(lexer_mod.__dict__.get(name), "__wrapped__") {
                lexer_mod.__dict__[name] = orig;
            }
        }
        # Clean up native engine references
        lexer_mod.__dict__.pop("__jac_native_engine__", None);
        lexer_mod.__dict__.pop("__jac_native_layout__", None);
        # Clean up _py_ prefixed backup copies
        for name in list(lexer_mod.__dict__.keys()) {
            if name.startswith("_py_") {
                del lexer_mod.__dict__[name];
            }
        }
    }
}
