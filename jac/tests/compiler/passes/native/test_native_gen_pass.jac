"""End-to-end tests for native LLVM IR compilation (na {} / .na.jac).

Tests verify that .na.jac fixtures compile to LLVM IR, JIT-compile to
native machine code, and produce correct results when executed via ctypes.
"""

import ctypes;
import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

# --- TestNativeArithmeticExecution ---
test "arithmetic add" {
    (eng, _) = compile_native("arithmetic.na.jac");
    add = get_func(eng, "add", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert add(3, 4) == 7;
    assert add(-1, 1) == 0;
    assert add(0, 0) == 0;
    assert add(100, 200) == 300;
}

test "arithmetic multiply" {
    (eng, _) = compile_native("arithmetic.na.jac");
    mul = get_func(eng, "multiply", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert mul(5, 6) == 30;
    assert mul(-3, 7) == -21;
    assert mul(0, 999) == 0;
}

test "arithmetic negate" {
    (eng, _) = compile_native("arithmetic.na.jac");
    neg = get_func(eng, "negate", ctypes.c_int64, ctypes.c_int64);
    assert neg(5) == -5;
    assert neg(-3) == 3;
    assert neg(0) == 0;
}

test "arithmetic float add" {
    (eng, _) = compile_native("arithmetic.na.jac");
    fadd = get_func(
        eng, "float_add", ctypes.c_double, ctypes.c_double, ctypes.c_double
    );
    assert abs(fadd(1.5, 2.5) - 4.0) < 1e-10;
    assert abs(fadd(-1.0, 1.0)) < 1e-10;
}

# --- TestNativeControlFlowExecution ---
test "control flow abs val" {
    (eng, _) = compile_native("control_flow.na.jac");
    f = get_func(eng, "abs_val", ctypes.c_int64, ctypes.c_int64);
    assert f(-5) == 5;
    assert f(5) == 5;
    assert f(0) == 0;
    assert f(-100) == 100;
}

test "control flow max val" {
    (eng, _) = compile_native("control_flow.na.jac");
    f = get_func(eng, "max_val", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 7) == 7;
    assert f(10, 2) == 10;
    assert f(5, 5) == 5;
}

test "control flow factorial" {
    (eng, _) = compile_native("control_flow.na.jac");
    f = get_func(eng, "factorial", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1;
    assert f(1) == 1;
    assert f(5) == 120;
    assert f(10) == 3628800;
}

test "control flow sum to n" {
    (eng, _) = compile_native("control_flow.na.jac");
    f = get_func(eng, "sum_to_n", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 55;
    assert f(100) == 5050;
    assert f(0) == 0;
}

# --- TestNativeRecursionExecution ---
test "recursion fibonacci" {
    (eng, _) = compile_native("fibonacci.na.jac");
    fib = get_func(eng, "fib", ctypes.c_int64, ctypes.c_int64);
    assert fib(0) == 0;
    assert fib(1) == 1;
    assert fib(10) == 55;
    assert fib(15) == 610;
}

# --- TestNativeContextIsolation ---
test "context isolation native excluded from python" {
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "mixed_contexts.jac")));
    # Python source should NOT contain native_add
    py_src = ir.gen.py;
    assert "native_add" not in py_src;
    # Python source should contain server_hello
    assert "server_hello" in py_src;
}

test "context isolation native ir contains function" {
    (eng, ir) = compile_native("arithmetic.na.jac");
    # If we can get the function address, the IR was generated correctly
    addr = eng.get_function_address("add");
    assert addr != 0;
}

# --- TestNativeEnumsAndLoops ---
test "enums loops opposite color" {
    (eng, _) = compile_native("enums_loops.na.jac");
    f = get_func(eng, "opposite_color", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1;  # WHITE -> BLACK
    assert f(1) == 0;  # BLACK -> WHITE
}

test "enums loops enum kind" {
    (eng, _) = compile_native("enums_loops.na.jac");
    f = get_func(eng, "enum_kind_test", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 100;  # PAWN
    assert f(1) == 200;  # KNIGHT
    assert f(2) == 300;  # BISHOP
    assert f(99) == 0;  # unknown
}

test "enums loops sum range" {
    (eng, _) = compile_native("enums_loops.na.jac");
    f = get_func(eng, "sum_range", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 0;
    assert f(1) == 0;
    assert f(5) == 10;  # 0+1+2+3+4
    assert f(10) == 45;  # 0+1+...+9
}

test "enums loops first break" {
    (eng, _) = compile_native("enums_loops.na.jac");
    f = get_func(eng, "first_break", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 3;  # no break triggered
    assert f(10) == 5;  # breaks at i==5
    assert f(100) == 5;  # breaks at i==5
}

test "enums loops skip even" {
    (eng, _) = compile_native("enums_loops.na.jac");
    f = get_func(eng, "skip_even", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 25;  # 1+3+5+7+9
    assert f(6) == 9;  # 1+3+5
}

test "enums loops bool and" {
    (eng, _) = compile_native("enums_loops.na.jac");
    f = get_func(eng, "bool_and", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(1, 1) == 1;
    assert f(1, 0) == 0;
    assert f(0, 1) == 0;
    assert f(0, 0) == 0;
}

test "enums loops bool or" {
    (eng, _) = compile_native("enums_loops.na.jac");
    f = get_func(eng, "bool_or", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(1, 1) == 1;
    assert f(1, 0) == 1;
    assert f(0, 1) == 1;
    assert f(0, 0) == 0;
}

test "enums loops ternary" {
    (eng, _) = compile_native("enums_loops.na.jac");
    f = get_func(eng, "ternary_test", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 10;
    assert f(-5) == -10;
    assert f(0) == -10;
}

# --- TestNativeStrings ---
test "strings greet" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(eng, "greet", ctypes.c_char_p);
    assert f() == b"hello";
}

test "strings str equal" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(eng, "str_equal", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p);
    assert f(b"hello", b"hello") == 1;
    assert f(b"hello", b"world") == 0;
}

test "strings str not equal" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(
        eng, "str_not_equal", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    assert f(b"hello", b"world") == 1;
    assert f(b"hello", b"hello") == 0;
}

test "strings concat" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(
        eng, "concat_strings", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p
    );
    assert f(b"hello ", b"world") == b"hello world";
}

test "strings fstring int" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(eng, "format_int", ctypes.c_char_p, ctypes.c_int64);
    assert f(42) == b"val=42";
    assert f(0) == b"val=0";
    assert f(-7) == b"val=-7";
}

test "strings fstring two" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(eng, "format_two", ctypes.c_char_p, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 4) == b"3+4";
    assert f(10, 20) == b"10+20";
}

test "strings fstring mixed" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(eng, "format_mixed", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64);
    assert f(b"Alice", 30) == b"name=Alice, age=30";
}

# --- TestNativeObjects ---
test "objects make point" {
    (eng, _) = compile_native("objects.na.jac");
    # make_point returns a Point* (opaque pointer)
    addr = eng.get_function_address("make_point");
    assert addr != 0 , "make_point function not found";
}

test "objects point sum" {
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "point_sum", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 4) == 7;
    assert f(10, 20) == 30;
    assert f(0, 0) == 0;
    assert f(-5, 5) == 0;
}

test "objects counter" {
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "test_counter", ctypes.c_int64);
    assert f() == 3;
}

test "objects none check" {
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "test_none", ctypes.c_int64);
    assert f() == 1;
}

# --- TestNativeInheritance ---
test "inheritance dog speak" {
    (eng, _) = compile_native("inheritance.na.jac");
    f = get_func(eng, "test_dog_speak", ctypes.c_int64);
    assert f() == 1;
}

test "inheritance cat speak" {
    (eng, _) = compile_native("inheritance.na.jac");
    f = get_func(eng, "test_cat_speak", ctypes.c_int64);
    assert f() == 2;
}

test "inheritance inherited method" {
    (eng, _) = compile_native("inheritance.na.jac");
    f = get_func(eng, "test_inherited_method", ctypes.c_int64);
    assert f() == 4;
}

test "inheritance polymorphic" {
    (eng, _) = compile_native("inheritance.na.jac");
    f = get_func(eng, "test_polymorphic", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 1;  # Dog.speak
    assert f(0) == 2;  # Cat.speak
}

# --- TestNativeLists ---
test "lists list len" {
    (eng, _) = compile_native("lists.na.jac");
    f = get_func(eng, "list_len_test", ctypes.c_int64);
    assert f() == 3;
}

test "lists list get" {
    (eng, _) = compile_native("lists.na.jac");
    f = get_func(eng, "list_get_test", ctypes.c_int64);
    assert f() == 20;
}

test "lists list append" {
    (eng, _) = compile_native("lists.na.jac");
    f = get_func(eng, "list_append_test", ctypes.c_int64);
    assert f() == 4;
}

test "lists list sum" {
    (eng, _) = compile_native("lists.na.jac");
    f = get_func(eng, "list_sum", ctypes.c_int64);
    assert f() == 100;
}

test "lists list set" {
    (eng, _) = compile_native("lists.na.jac");
    f = get_func(eng, "list_set_test", ctypes.c_int64);
    assert f() == 99;
}

# --- TestNativeComplexObjects ---
test "complex objects chained field" {
    (eng, _) = compile_native("complex_objects.na.jac");
    f = get_func(eng, "test_chained_field", ctypes.c_int64);
    assert f() == 42;
}

test "complex objects chained method" {
    (eng, _) = compile_native("complex_objects.na.jac");
    f = get_func(eng, "test_chained_method", ctypes.c_int64);
    assert f() == 99;
}

test "complex objects chained method args" {
    (eng, _) = compile_native("complex_objects.na.jac");
    f = get_func(eng, "test_chained_method_args", ctypes.c_int64);
    assert f() == 15;
}

test "complex objects deep chain" {
    (eng, _) = compile_native("complex_objects.na.jac");
    f = get_func(eng, "test_deep_chain", ctypes.c_int64);
    assert f() == 14;
}

test "complex objects indexed field" {
    (eng, _) = compile_native("complex_objects.na.jac");
    f = get_func(eng, "test_indexed_field", ctypes.c_int64);
    assert f() == 20;
}

test "complex objects indexed field set" {
    (eng, _) = compile_native("complex_objects.na.jac");
    f = get_func(eng, "test_indexed_field_set", ctypes.c_int64);
    assert f() == 99;
}

test "complex objects field len" {
    (eng, _) = compile_native("complex_objects.na.jac");
    f = get_func(eng, "test_field_len", ctypes.c_int64);
    assert f() == 4;
}

test "complex objects field append" {
    (eng, _) = compile_native("complex_objects.na.jac");
    f = get_func(eng, "test_field_append", ctypes.c_int64);
    assert f() == 3;
}

# --- TestNativeBuiltins ---
test "builtins char at" {
    (eng, _) = compile_native("builtins.na.jac");
    f = get_func(eng, "test_char_at", ctypes.c_int64);
    assert f() == 101;  # ord('e')
}

test "builtins ord" {
    (eng, _) = compile_native("builtins.na.jac");
    f = get_func(eng, "test_ord", ctypes.c_int64);
    assert f() == 97;  # ord('a')
}

test "builtins int parse" {
    (eng, _) = compile_native("builtins.na.jac");
    f = get_func(eng, "test_int_parse", ctypes.c_int64);
    assert f() == 42;
}

test "builtins strip" {
    (eng, _) = compile_native("builtins.na.jac");
    f = get_func(eng, "test_strip", ctypes.c_char_p);
    assert f() == b"hi";
}

test "builtins split len" {
    (eng, _) = compile_native("builtins.na.jac");
    f = get_func(eng, "test_split_len", ctypes.c_int64);
    assert f() == 3;
}

test "builtins split get" {
    (eng, _) = compile_native("builtins.na.jac");
    f = get_func(eng, "test_split_get", ctypes.c_char_p);
    assert f() == b"world";
}

test "builtins strip split" {
    (eng, _) = compile_native("builtins.na.jac");
    f = get_func(eng, "test_strip_split", ctypes.c_int64);
    assert f() == 2;
}

# --- TestNativeRuntime ---
test "runtime for list literal" {
    (eng, _) = compile_native("runtime_validate.na.jac");
    f = get_func(eng, "test_for_list_literal", ctypes.c_int64);
    assert f() == 60;
}

test "runtime for list var" {
    (eng, _) = compile_native("runtime_validate.na.jac");
    f = get_func(eng, "test_for_list_var", ctypes.c_int64);
    assert f() == 15;
}

test "runtime nested list" {
    (eng, _) = compile_native("runtime_validate.na.jac");
    f = get_func(eng, "test_nested_list", ctypes.c_int64);
    assert f() == 5;
}

test "runtime nested set" {
    (eng, _) = compile_native("runtime_validate.na.jac");
    f = get_func(eng, "test_nested_set", ctypes.c_int64);
    assert f() == 99;
}

test "runtime for nested" {
    (eng, _) = compile_native("runtime_validate.na.jac");
    f = get_func(eng, "test_for_nested", ctypes.c_int64);
    assert f() == 0;
}

test "runtime grid init" {
    (eng, _) = compile_native("runtime_validate.na.jac");
    f = get_func(eng, "test_grid_init", ctypes.c_int64);
    assert f() == 9;
}

test "runtime grid set get" {
    (eng, _) = compile_native("runtime_validate.na.jac");
    f = get_func(eng, "test_grid_set_get", ctypes.c_int64);
    assert f() == 42;
}

# --- TestNativeAugAssign ---
test "aug assign add assign" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_add_assign", ctypes.c_int64);
    assert f() == 15;
}

test "aug assign sub assign" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_sub_assign", ctypes.c_int64);
    assert f() == 63;
}

test "aug assign mul assign" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_mul_assign", ctypes.c_int64);
    assert f() == 42;
}

test "aug assign div assign" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_div_assign", ctypes.c_int64);
    assert f() == 9;
}

test "aug assign mod assign" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_mod_assign", ctypes.c_int64);
    assert f() == 2;
}

test "aug assign chained aug" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_chained_aug", ctypes.c_int64);
    assert f() == 8;  # (1+2)*3 - 1
}

test "aug assign aug in while" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_aug_in_while", ctypes.c_int64);
    assert f() == 45;  # 0+1+2+...+9
}

test "aug assign aug in for" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_aug_in_for", ctypes.c_int64);
    assert f() == 45;  # 0+1+2+...+9
}

test "aug assign aug conditional" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_aug_conditional", ctypes.c_int64);
    assert f() == 2025;  # even=20, odd=25 -> 20*100+25
}

test "aug assign aug nested loops" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_aug_nested_loops", ctypes.c_int64);
    assert f() == 25;  # 5*5
}

test "aug assign aug float add" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_aug_float_add", ctypes.c_double);
    assert abs(f() - 4.0) < 1e-10;
}

test "aug assign aug float mul" {
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_aug_float_mul", ctypes.c_double);
    assert abs(f() - 7.5) < 1e-10;
}

test "aug assign count primes" {
    # Count first 10 primes using += in nested while loops.
    (eng, _) = compile_native("aug_assign.na.jac");
    f = get_func(eng, "test_count_primes", ctypes.c_int64);
    assert f() == 29;  # 10th prime
}

# --- TestNativeChess ---
test "chess compiles" {
    (eng, ir) = compile_native("chess.na.jac");
    assert ir.gen.llvm_ir is not None;
}

test "chess opposite color" {
    (eng, _) = compile_native("chess.na.jac");
    opp = get_func(eng, "opposite_color", ctypes.c_int64, ctypes.c_int64);
    assert opp(0) == 1;  # WHITE -> BLACK
    assert opp(1) == 0;  # BLACK -> WHITE
}

test "chess create piece" {
    (eng, _) = compile_native("chess.na.jac");
    addr = eng.get_function_address("create_piece");
    assert addr != 0;
}

test "chess has entry" {
    (eng, _) = compile_native("chess.na.jac");
    addr = eng.get_function_address("jac_entry");
    assert addr != 0;
}

test "chess all piece types" {
    # Verify all piece class methods are callable.
    (eng, _) = compile_native("chess.na.jac");
    piece_types = ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"];
    for piece_type in piece_types {
        addr = eng.get_function_address(f"{piece_type}.get_symbol");
        assert addr != 0 , f"{piece_type}.get_symbol not found";
    }
}

test "chess board methods" {
    # Verify Board methods are callable.
    (eng, _) = compile_native("chess.na.jac");
    methods = [
        "Board.is_valid_pos",
        "Board.get_piece",
        "Board.set_piece",
        "Board.make_move",
        "Board.undo_move",
        "Board.display"
    ];
    for method in methods {
        addr = eng.get_function_address(method);
        assert addr != 0 , f"{method} not found";
    }
}

test "chess game methods" {
    # Verify Game methods are callable.
    (eng, _) = compile_native("chess.na.jac");
    methods = [
        "Game.find_king",
        "Game.is_in_check",
        "Game.get_legal_moves",
        "Game.is_checkmate",
        "Game.is_stalemate",
        "Game.parse_input"
    ];
    for method in methods {
        addr = eng.get_function_address(method);
        assert addr != 0 , f"{method} not found";
    }
}

# --- TestNativeDicts ---
test "dicts dict new empty" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_new_empty", ctypes.c_int64);
    assert f() == 0;
}

test "dicts dict literal len" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_literal_len", ctypes.c_int64);
    assert f() == 3;
}

test "dicts dict get value" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_get_value", ctypes.c_int64);
    assert f() == 200;
}

test "dicts dict set value" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_set_value", ctypes.c_int64);
    assert f() == 20;
}

test "dicts dict update value" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_update_value", ctypes.c_int64);
    assert f() == 99;
}

test "dicts dict len after set" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_len_after_set", ctypes.c_int64);
    assert f() == 3;
}

test "dicts dict contains true" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_contains_true", ctypes.c_int64);
    assert f() == 1;
}

test "dicts dict contains false" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_contains_false", ctypes.c_int64);
    assert f() == 0;
}

test "dicts dict string keys" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_string_keys", ctypes.c_int64);
    assert f() == 2;
}

test "dicts dict string values" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_string_values", ctypes.c_char_p);
    result = f();
    assert result == b"two";
}

test "dicts dict sum values" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_sum_values", ctypes.c_int64);
    assert f() == 100;
}

test "dicts dict overwrite" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_overwrite", ctypes.c_int64);
    assert f() == 30;
}

test "dicts dict multiple types" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_multiple_types", ctypes.c_int64);
    assert f() == 300;
}

test "dicts dict get first" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_get_first", ctypes.c_int64);
    assert f() == 100;
}

test "dicts dict get third" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_get_third", ctypes.c_int64);
    assert f() == 300;
}

test "dicts dict set then get" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_set_then_get", ctypes.c_int64);
    assert f() == 1500;
}

test "dicts global dict get" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    # Need to call jac_entry first to initialize globals
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_dict_get", ctypes.c_int64);
    assert f() == 200;
}

test "dicts global dict len" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_dict_len", ctypes.c_int64);
    assert f() == 3;
}

# --- TestNativeSets ---
test "sets set new empty" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "set_new_empty", ctypes.c_int64);
    assert f() == 0;
}

test "sets set literal len" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "set_literal_len", ctypes.c_int64);
    assert f() == 5;
}

test "sets set add element" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "set_add_element", ctypes.c_int64);
    assert f() == 4;
}

test "sets set add duplicate" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "set_add_duplicate", ctypes.c_int64);
    assert f() == 3;  # Duplicates shouldn't increase length
}

test "sets set contains true" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "set_contains_true", ctypes.c_int64);
    assert f() == 1;
}

test "sets set contains false" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "set_contains_false", ctypes.c_int64);
    assert f() == 0;
}

test "sets set string elements" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "set_string_elements", ctypes.c_int64);
    assert f() == 1;
}

test "sets set multiple adds" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "set_multiple_adds", ctypes.c_int64);
    assert f() == 3;  # 1, 2, 3 (duplicates ignored)
}

test "sets global set contains" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_set_contains", ctypes.c_int64);
    assert f() == 1;
}

test "sets global set len" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_set_len", ctypes.c_int64);
    assert f() == 5;
}

# --- TestNativeExceptions ---
test "exceptions basic try except" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_basic_try_except", ctypes.c_int64);
    assert f() == 2;
}

test "exceptions try no exception" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_try_no_exception", ctypes.c_int64);
    assert f() == 42;
}

test "exceptions except as binding" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_except_as_binding", ctypes.c_char_p);
    assert f() == b"caught me";
}

test "exceptions try else no exception" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_try_else_no_exception", ctypes.c_int64);
    assert f() == 11;
}

test "exceptions try else with exception" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_try_else_with_exception", ctypes.c_int64);
    assert f() == 5;
}

test "exceptions try finally" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_try_finally", ctypes.c_int64);
    assert f() == 111;
}

test "exceptions try finally no exception" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_try_finally_no_exception", ctypes.c_int64);
    assert f() == 105;
}

test "exceptions multiple except" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_multiple_except", ctypes.c_int64);
    assert f() == 2;
}

test "exceptions catch all" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_catch_all", ctypes.c_int64);
    assert f() == 42;
}

test "exceptions nested try" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_nested_try", ctypes.c_int64);
    assert f() == 111;
}

test "exceptions raise func form" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_raise_func_form", ctypes.c_int64);
    assert f() == 77;
}

test "exceptions full combo no exc" {
    (eng, _) = compile_native("exceptions.na.jac");
    f = get_func(eng, "test_full_combo_no_exc", ctypes.c_int64);
    assert f() == 321;
}

# --- TestNativeFileIO ---
test "file io open write" {
    (eng, _) = compile_native("file_io.na.jac");
    f = get_func(eng, "test_open_write", ctypes.c_int64);
    assert f() == 1;
}

test "file io write file" {
    (eng, _) = compile_native("file_io.na.jac");
    f = get_func(eng, "test_write_file", ctypes.c_int64);
    assert f() == 11;
}

test "file io write read" {
    (eng, _) = compile_native("file_io.na.jac");
    f = get_func(eng, "test_write_read", ctypes.c_char_p);
    assert f() == b"NativeIO";
}

test "file io readline" {
    (eng, _) = compile_native("file_io.na.jac");
    f = get_func(eng, "test_readline", ctypes.c_char_p);
    assert f() == b"line1\n";
}

test "file io close idempotent" {
    (eng, _) = compile_native("file_io.na.jac");
    f = get_func(eng, "test_close_idempotent", ctypes.c_int64);
    assert f() == 1;
}

test "file io open nonexistent" {
    (eng, _) = compile_native("file_io.na.jac");
    f = get_func(eng, "test_open_nonexistent", ctypes.c_int64);
    assert f() == 1;
}

test "file io file methods exist" {
    (eng, _) = compile_native("file_io.na.jac");
    f = get_func(eng, "test_file_methods_exist", ctypes.c_int64);
    assert f() == 1;
}

# --- TestNativeContextManagers ---
test "context managers with enter" {
    (eng, _) = compile_native("context_mgr.na.jac");
    f = get_func(eng, "test_with_enter", ctypes.c_int64);
    assert f() == 1;
}

test "context managers with exit" {
    (eng, _) = compile_native("context_mgr.na.jac");
    f = get_func(eng, "test_with_exit", ctypes.c_int64);
    assert f() == 1;
}

test "context managers with body" {
    (eng, _) = compile_native("context_mgr.na.jac");
    f = get_func(eng, "test_with_body", ctypes.c_int64);
    assert f() == 99;
}

test "context managers with as binding" {
    (eng, _) = compile_native("context_mgr.na.jac");
    f = get_func(eng, "test_with_as_binding", ctypes.c_int64);
    assert f() == 77;
}

test "context managers file context manager" {
    (eng, _) = compile_native("context_mgr.na.jac");
    f = get_func(eng, "test_file_context_manager", ctypes.c_int64);
    assert f() == 1;
}

test "context managers with enter exit once" {
    (eng, _) = compile_native("context_mgr.na.jac");
    f = get_func(eng, "test_with_enter_exit_once", ctypes.c_int64);
    assert f() == 101;
}

# --- TestNativeRuntimeErrors ---

# -- ZeroDivisionError --
test "runtime errors int div by zero" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_div_by_zero", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors int mod by zero" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_mod_by_zero", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors div by zero var" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_div_by_zero_var", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors float div by zero" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_float_div_by_zero", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors div no error" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_div_no_error", ctypes.c_int64);
    assert f() == 5;
}

# -- IndexError --
test "runtime errors list index oob" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_list_index_oob", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors list negative index" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_list_negative_index", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors list index at len" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_list_index_at_len", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors list valid index" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_list_valid_index", ctypes.c_int64);
    assert f() == 20;
}

test "runtime errors list set oob" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_list_set_oob", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors empty list access" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_empty_list_access", ctypes.c_int64);
    assert f() == 1;
}

# -- KeyError --
test "runtime errors dict missing key" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_dict_missing_key", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors dict valid key" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_dict_valid_key", ctypes.c_int64);
    assert f() == 2;
}

test "runtime errors dict int missing key" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_dict_int_missing_key", ctypes.c_int64);
    assert f() == 1;
}

# -- OverflowError --
test "runtime errors int add overflow" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_add_overflow", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors int sub underflow" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_sub_underflow", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors int mul overflow" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_mul_overflow", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors int no overflow" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_no_overflow", ctypes.c_int64);
    assert f() == 1;
}

# -- AttributeError (None dereference) --
test "runtime errors none field access" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_none_field_access", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors none method call" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_none_method_call", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors valid obj access" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_valid_obj_access", ctypes.c_int64);
    assert f() == 42;
}

# -- ValueError --
test "runtime errors int parse invalid" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_parse_invalid", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors int parse valid" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_parse_valid", ctypes.c_int64);
    assert f() == 123;
}

test "runtime errors int parse empty" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_int_parse_empty", ctypes.c_int64);
    assert f() == 1;
}

# -- AssertionError --
test "runtime errors assert false" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_assert_false", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors assert true" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_assert_true", ctypes.c_int64);
    assert f() == 1;
}

# -- MemoryError --
test "runtime errors alloc ok" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_alloc_ok", ctypes.c_int64);
    assert f() == 1;
}

# -- Combined / edge cases --
test "runtime errors catch base exception" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_catch_base_exception", ctypes.c_int64);
    assert f() == 1;
}

test "runtime errors sequential errors" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_sequential_errors", ctypes.c_int64);
    assert f() == 11;
}

test "runtime errors error in loop" {
    (eng, _) = compile_native("runtime_errors.na.jac");
    f = get_func(eng, "test_error_in_loop", ctypes.c_int64);
    assert f() == 1;
}

# --- TestNativePyInterop ---
test "py interop interop module compiles" {
    # Module with na block, Python functions, and entry compiles.
    prog = JacProgram();
    prog.compile(str(os.path.join(FIXTURES, "na_py_interop.jac")));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
}

test "py interop native function exists in engine" {
    # Native function from na block is available in the JIT engine.
    (eng, _) = compile_native("na_py_interop.jac");
    addr = eng.get_function_address("native_add_one_to_doubled");
    assert addr != 0 , "native_add_one_to_doubled not found in JIT engine";
}

test "py interop py function not defined in native ir" {
    # py_double should be declared (external) but NOT defined in LLVM IR.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop.jac")));
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # Must not have a define (body) for py_double -- it lives in Python
    assert 'define i64 @"py_double"' not in llvm_ir_str;
    # Should have an external declare so the native code can call it
    assert 'declare i64 @"py_double"' in llvm_ir_str;
}

test "py interop py functions in python codegen" {
    # py_double and call_native should appear in Python codegen output.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop.jac")));
    py_src = ir.gen.py;
    assert "py_double" in py_src;
    assert "call_native" in py_src;
}

test "py interop native function has stub in python" {
    # Native function should have a ctypes stub in Python codegen output.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop.jac")));
    py_src = ir.gen.py;
    # Stub for the native function should exist
    assert "native_add_one_to_doubled" in py_src;
    # The native function body should NOT appear as executable code in Python
    assert "return py_double(x) + 1" not in py_src;
    # Should reference ctypes for the bridge
    assert "CFUNCTYPE" in py_src;
    assert "get_function_address" in py_src;
}

test "py interop interop manifest built" {
    # InteropAnalysisPass should detect cross-boundary calls.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop.jac")));
    manifest = ir.gen.interop_manifest;
    assert manifest is not None;
    # py_double: defined in SERVER, called from NATIVE
    assert "py_double" in manifest.bindings;
    b = manifest.bindings["py_double"];
    assert b.source_context.value == "server";
    # native_add_one_to_doubled: defined in NATIVE, called from SERVER
    assert "native_add_one_to_doubled" in manifest.bindings;
    b2 = manifest.bindings["native_add_one_to_doubled"];
    assert b2.source_context.value == "native";
}

test "py interop native calls python function" {
    # Native->Python: native_add_one_to_doubled calls py_double.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop.jac")));
    eng = ir.gen.native_engine;
    assert eng is not None;
    # Register the Python function in the interop callback table
    py_func_table = ir.gen.interop_py_funcs;
    py_func_table["py_double"] = lambda x : x * 2;
    # Now call the native function
    f = get_func(eng, "native_add_one_to_doubled", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 11;  # py_double(5) = 10, + 1 = 11
    assert f(0) == 1;  # py_double(0) = 0,  + 1 = 1
    assert f(-3) == -5;  # py_double(-3) = -6, + 1 = -5
}

test "py interop full entry chain" {
    # Full chain: entry (Py) -> call_native (Py) -> native (na) -> py_double (Py).
    import contextlib;
    import io;

    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop.jac")));
    assert not prog.errors_had;
    # Execute the compiled module with interop context injected
    py_code = compile(
        ir.gen.py, str(os.path.join(FIXTURES, "na_py_interop.jac")), "exec"
    );
    namespace = {
        "__jac_native_engine__": ir.gen.native_engine,
        "__jac_interop_py_funcs__": ir.gen.interop_py_funcs
    };
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        exec(py_code, namespace);
    }
    output = buf.getvalue().strip();
    assert output == "11";
}

# --- TestNativeMultiModuleInterop ---
test "multi module na module compiles" {
    # A standalone .na.jac module compiles to LLVM IR.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_math_utils.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    assert "triple" in llvm_ir_str;
    assert "square" in llvm_ir_str;
}

test "multi module module level na import" {
    # Module-level import of .na.jac file is recognized.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop_multi.jac")));
    # Should compile without errors
    assert ir is not None;
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    # triple should be in manifest as a cross-module import
    manifest = ir.gen.interop_manifest;
    assert "triple" in manifest.bindings;
    assert manifest.bindings["triple"].source_module == "na_math_utils.na";
}

test "multi module na scoped import" {
    # Import inside na {} block is recognized.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop_multi.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    # The na-scoped import should be tracked in manifest
    manifest = ir.gen.interop_manifest;
    # add_ten should be recognized as a NATIVE->NATIVE binding
    assert "add_ten" in manifest.bindings;
    assert manifest.bindings["add_ten"].source_module == "na_transformers.na";
}

test "multi module native module linking" {
    # Functions from imported .na.jac modules are callable.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop_multi.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    eng = ir.gen.native_engine;
    assert eng is not None , "No native engine created";
    # Imported native functions should be resolvable
    triple_addr = eng.get_function_address("triple");
    assert triple_addr != 0 , "triple not linked into engine";
}

test "multi module full multi module chain" {
    # Full call chain with multi-module native imports works.
    import contextlib;
    import io;

    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_py_interop_multi.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine created";

    py_code = compile(
        ir.gen.py, str(os.path.join(FIXTURES, "na_py_interop_multi.jac")), "exec"
    );
    namespace = {
        "__jac_native_engine__": ir.gen.native_engine,
        "__jac_interop_py_funcs__": getattr(ir.gen, "interop_py_funcs", {})
    };
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        exec(py_code, namespace);
    }
    output = buf.getvalue().strip();
    assert output == "35";
}

# --- TestNativeCacheMarker ---
test "cache marker non native file caches empty llvmir" {
    # Compiling a file without na blocks stores '' for llvm_ir in cache.
    import tempfile;
    import time;
    import shutil;
    import from jaclang.jac0core.bccache { CacheKey, DiskBytecodeCache }
    import from jaclang.jac0core.compiler { JacCompiler }

    tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False);
    tmp.write("glob x = 1;\n");
    tmp.flush();
    jac_file = tmp.name;
    tmp.close();

    # Set source mtime slightly in the past so cache files are strictly newer
    past = time.time() - 2;
    os.utime(jac_file, (past, past));

    try {
        cache = DiskBytecodeCache();
        cache._cache_dir = Path(tempfile.mkdtemp());
        jac_compiler = JacCompiler(bytecode_cache=cache);
        jac_compiler.get_bytecode(jac_file, JacProgram());

        key = CacheKey.for_source(jac_file);
        cached_ir = cache.get_llvmir(key);
        assert cached_ir == "" , (
            f"Non-native file should cache empty llvm_ir, got {cached_ir!r}"
        );
    } except Exception as e {
        os.unlink(jac_file);
        raise ;
    }
    os.unlink(jac_file);
    shutil.rmtree(str(cache._cache_dir), ignore_errors=True);
}

# --- TestNativeLLVMIR ---
test "llvmir ir has function definitions" {
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "arithmetic.na.jac")));
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    assert 'define i64 @"add"' in llvm_ir_str;
    assert 'define i64 @"multiply"' in llvm_ir_str;
    assert 'define i64 @"negate"' in llvm_ir_str;
    assert 'define double @"float_add"' in llvm_ir_str;
}

# --- TestCLibImportSyntax ---
test "clib import produces extern declares" {
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "clib_import.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # Extern C functions should be 'declare' (no body), not 'define'
    assert 'declare double @"sqrt"' in llvm_ir_str;
    assert 'declare double @"pow"' in llvm_ir_str;
    assert 'define double @"sqrt"' not in llvm_ir_str;
    assert 'define double @"pow"' not in llvm_ir_str;
    # Native Jac function should be 'define' (has body)
    assert 'define double @"hypotenuse"' in llvm_ir_str;
    # Library path should be stored for the compile pass
    assert ir.gen._clib_paths is not None;
    assert "/usr/lib/libm.so.6" in ir.gen._clib_paths;
}

test "clib import inside na block" {
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "clib_import_na_block.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # Extern C functions from na {} block should be 'declare'
    assert 'declare double @"ceil"' in llvm_ir_str;
    assert 'declare double @"floor"' in llvm_ir_str;
    # Native Jac function should be 'define'
    assert 'define double @"round_up"' in llvm_ir_str;
    # Library path should be stored
    assert ir.gen._clib_paths is not None;
    assert "/usr/lib/libm.so.6" in ir.gen._clib_paths;
}

test "clib struct value-type coercion" {
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "clib_struct_coerce.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir.gen.llvm_ir is not None , "No LLVM IR generated";
    llvm_ir_str = str(ir.gen.llvm_ir);
    # --- Large struct (Vec2: 128-bit, float fields) ---
    # Extern sqrt should use value type (f64 -> f64)
    assert 'declare double @"sqrt"' in llvm_ir_str;
    # Vec2 struct type should be defined
    assert '%"Vec2"' in llvm_ir_str , "Vec2 struct type not found in IR";
    # Jac functions should use pointer types for Vec2 (Jac semantics)
    assert '%"Vec2"* @"make_vec"' in llvm_ir_str , "make_vec should return Vec2 pointer";
    assert '%"Vec2"* %"v"' in llvm_ir_str , "vec_length should take Vec2 pointer param";
    # --- Small struct (Color: 32-bit, integer fields) ABI coercion ---
    # Color struct type should be defined
    assert '%"Color" = type {i8, i8, i8, i8}' in llvm_ir_str , "Color struct type not found";
    # Extern draw should have Color param ABI-coerced to i32
    assert 'declare void @"draw"(i32 %"x", i32 %"y", i32 %"color")' in llvm_ir_str , "draw should use i32 for Color param (ABI coercion)";
    # Jac test_draw function should use Color pointer internally
    assert 'define void @"test_draw"' in llvm_ir_str;
    # ABI coercion instructions should be present (bitcast %Color* to i32*, then load)
    assert "struct.abi.cast" in llvm_ir_str , "Missing struct-to-ABI bitcast";
    assert "struct.abi.unbox" in llvm_ir_str , "Missing struct ABI unbox load";
}
