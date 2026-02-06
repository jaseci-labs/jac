"""End-to-end tests for native LLVM IR compilation (na {} / .na.jac).

Tests verify that .na.jac fixtures compile to LLVM IR, JIT-compile to
native machine code, and produce correct results when executed via ctypes.
"""

from __future__ import annotations

import ctypes
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures"


def compile_native(fixture: str) -> tuple[object, object]:
    """Compile a .na.jac fixture and return the JIT engine."""
    from jaclang.pycore.program import JacProgram

    prog = JacProgram()
    ir = prog.compile(file_path=str(FIXTURES / fixture))
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else []
    assert not prog.errors_had, f"Compilation errors in {fixture}: {errors}"
    engine = ir.gen.native_engine
    assert engine is not None, f"No native engine produced for {fixture}"
    return engine, ir


def get_func(engine: object, name: str, restype: type, *argtypes: type) -> object:
    """Get a ctypes-callable function from the JIT engine."""
    addr = engine.get_function_address(name)  # type: ignore[attr-defined]
    assert addr != 0, f"Function '{name}' not found in JIT engine"
    functype = ctypes.CFUNCTYPE(restype, *argtypes)
    return functype(addr)


class TestNativeArithmeticExecution:
    """Verify native arithmetic produces correct results."""

    def test_add(self):
        engine, _ = compile_native("arithmetic.na.jac")
        add = get_func(engine, "add", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64)
        assert add(3, 4) == 7
        assert add(-1, 1) == 0
        assert add(0, 0) == 0
        assert add(100, 200) == 300

    def test_multiply(self):
        engine, _ = compile_native("arithmetic.na.jac")
        mul = get_func(
            engine, "multiply", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
        )
        assert mul(5, 6) == 30
        assert mul(-3, 7) == -21
        assert mul(0, 999) == 0

    def test_negate(self):
        engine, _ = compile_native("arithmetic.na.jac")
        neg = get_func(engine, "negate", ctypes.c_int64, ctypes.c_int64)
        assert neg(5) == -5
        assert neg(-3) == 3
        assert neg(0) == 0

    def test_float_add(self):
        engine, _ = compile_native("arithmetic.na.jac")
        fadd = get_func(
            engine, "float_add", ctypes.c_double, ctypes.c_double, ctypes.c_double
        )
        assert abs(fadd(1.5, 2.5) - 4.0) < 1e-10
        assert abs(fadd(-1.0, 1.0)) < 1e-10


class TestNativeControlFlowExecution:
    """Verify control flow (if/else, while) works correctly."""

    def test_abs_val(self):
        engine, _ = compile_native("control_flow.na.jac")
        f = get_func(engine, "abs_val", ctypes.c_int64, ctypes.c_int64)
        assert f(-5) == 5
        assert f(5) == 5
        assert f(0) == 0
        assert f(-100) == 100

    def test_max_val(self):
        engine, _ = compile_native("control_flow.na.jac")
        f = get_func(engine, "max_val", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64)
        assert f(3, 7) == 7
        assert f(10, 2) == 10
        assert f(5, 5) == 5

    def test_factorial(self):
        engine, _ = compile_native("control_flow.na.jac")
        f = get_func(engine, "factorial", ctypes.c_int64, ctypes.c_int64)
        assert f(0) == 1
        assert f(1) == 1
        assert f(5) == 120
        assert f(10) == 3628800

    def test_sum_to_n(self):
        engine, _ = compile_native("control_flow.na.jac")
        f = get_func(engine, "sum_to_n", ctypes.c_int64, ctypes.c_int64)
        assert f(10) == 55
        assert f(100) == 5050
        assert f(0) == 0


class TestNativeRecursionExecution:
    """Verify recursive function calls work."""

    def test_fibonacci(self):
        engine, _ = compile_native("fibonacci.na.jac")
        fib = get_func(engine, "fib", ctypes.c_int64, ctypes.c_int64)
        assert fib(0) == 0
        assert fib(1) == 1
        assert fib(10) == 55
        assert fib(15) == 610


class TestNativeContextIsolation:
    """Verify na code is excluded from Python/JS codegen and vice versa."""

    def test_native_excluded_from_python(self):
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "mixed_contexts.jac"))
        # Python source should NOT contain native_add
        py_src = ir.gen.py
        assert "native_add" not in py_src
        # Python source should contain server_hello
        assert "server_hello" in py_src

    def test_native_ir_contains_function(self):
        engine, ir = compile_native("arithmetic.na.jac")
        # If we can get the function address, the IR was generated correctly
        addr = engine.get_function_address("add")
        assert addr != 0


class TestNativeEnumsAndLoops:
    """Verify enums, for loops, break/continue, bool expr, ternary."""

    def test_opposite_color(self):
        engine, _ = compile_native("enums_loops.na.jac")
        f = get_func(engine, "opposite_color", ctypes.c_int64, ctypes.c_int64)
        assert f(0) == 1  # WHITE -> BLACK
        assert f(1) == 0  # BLACK -> WHITE

    def test_enum_kind(self):
        engine, _ = compile_native("enums_loops.na.jac")
        f = get_func(engine, "enum_kind_test", ctypes.c_int64, ctypes.c_int64)
        assert f(0) == 100  # PAWN
        assert f(1) == 200  # KNIGHT
        assert f(2) == 300  # BISHOP
        assert f(99) == 0  # unknown

    def test_sum_range(self):
        engine, _ = compile_native("enums_loops.na.jac")
        f = get_func(engine, "sum_range", ctypes.c_int64, ctypes.c_int64)
        assert f(0) == 0
        assert f(1) == 0
        assert f(5) == 10  # 0+1+2+3+4
        assert f(10) == 45  # 0+1+...+9

    def test_first_break(self):
        engine, _ = compile_native("enums_loops.na.jac")
        f = get_func(engine, "first_break", ctypes.c_int64, ctypes.c_int64)
        assert f(3) == 3  # no break triggered
        assert f(10) == 5  # breaks at i==5
        assert f(100) == 5  # breaks at i==5

    def test_skip_even(self):
        engine, _ = compile_native("enums_loops.na.jac")
        f = get_func(engine, "skip_even", ctypes.c_int64, ctypes.c_int64)
        assert f(10) == 25  # 1+3+5+7+9
        assert f(6) == 9  # 1+3+5

    def test_bool_and(self):
        engine, _ = compile_native("enums_loops.na.jac")
        f = get_func(engine, "bool_and", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64)
        assert f(1, 1) == 1
        assert f(1, 0) == 0
        assert f(0, 1) == 0
        assert f(0, 0) == 0

    def test_bool_or(self):
        engine, _ = compile_native("enums_loops.na.jac")
        f = get_func(engine, "bool_or", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64)
        assert f(1, 1) == 1
        assert f(1, 0) == 1
        assert f(0, 1) == 1
        assert f(0, 0) == 0

    def test_ternary(self):
        engine, _ = compile_native("enums_loops.na.jac")
        f = get_func(engine, "ternary_test", ctypes.c_int64, ctypes.c_int64)
        assert f(5) == 10
        assert f(-5) == -10
        assert f(0) == -10


class TestNativeStrings:
    """Verify string literals, f-strings, concatenation, comparison."""

    def test_greet(self):
        engine, _ = compile_native("strings.na.jac")
        f = get_func(engine, "greet", ctypes.c_char_p)
        assert f() == b"hello"

    def test_str_equal(self):
        engine, _ = compile_native("strings.na.jac")
        f = get_func(
            engine, "str_equal", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
        )
        assert f(b"hello", b"hello") == 1
        assert f(b"hello", b"world") == 0

    def test_str_not_equal(self):
        engine, _ = compile_native("strings.na.jac")
        f = get_func(
            engine, "str_not_equal", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
        )
        assert f(b"hello", b"world") == 1
        assert f(b"hello", b"hello") == 0

    def test_concat(self):
        engine, _ = compile_native("strings.na.jac")
        f = get_func(
            engine, "concat_strings", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p
        )
        assert f(b"hello ", b"world") == b"hello world"

    def test_fstring_int(self):
        engine, _ = compile_native("strings.na.jac")
        f = get_func(engine, "format_int", ctypes.c_char_p, ctypes.c_int64)
        assert f(42) == b"val=42"
        assert f(0) == b"val=0"
        assert f(-7) == b"val=-7"

    def test_fstring_two(self):
        engine, _ = compile_native("strings.na.jac")
        f = get_func(
            engine, "format_two", ctypes.c_char_p, ctypes.c_int64, ctypes.c_int64
        )
        assert f(3, 4) == b"3+4"
        assert f(10, 20) == b"10+20"

    def test_fstring_mixed(self):
        engine, _ = compile_native("strings.na.jac")
        f = get_func(
            engine,
            "format_mixed",
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.c_int64,
        )
        assert f(b"Alice", 30) == b"name=Alice, age=30"


class TestNativeObjects:
    """Verify object creation, field access, methods, None comparison."""

    def test_make_point(self):
        engine, _ = compile_native("objects.na.jac")
        # make_point returns a Point* (opaque pointer)
        addr = engine.get_function_address("make_point")
        assert addr != 0, "make_point function not found"

    def test_point_sum(self):
        engine, _ = compile_native("objects.na.jac")
        f = get_func(
            engine, "point_sum", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
        )
        assert f(3, 4) == 7
        assert f(10, 20) == 30
        assert f(0, 0) == 0
        assert f(-5, 5) == 0

    def test_counter(self):
        engine, _ = compile_native("objects.na.jac")
        f = get_func(engine, "test_counter", ctypes.c_int64)
        assert f() == 3

    def test_none_check(self):
        engine, _ = compile_native("objects.na.jac")
        f = get_func(engine, "test_none", ctypes.c_int64)
        assert f() == 1


class TestNativeInheritance:
    """Verify inheritance, vtable dispatch, polymorphism."""

    def test_dog_speak(self):
        engine, _ = compile_native("inheritance.na.jac")
        f = get_func(engine, "test_dog_speak", ctypes.c_int64)
        assert f() == 1

    def test_cat_speak(self):
        engine, _ = compile_native("inheritance.na.jac")
        f = get_func(engine, "test_cat_speak", ctypes.c_int64)
        assert f() == 2

    def test_inherited_method(self):
        engine, _ = compile_native("inheritance.na.jac")
        f = get_func(engine, "test_inherited_method", ctypes.c_int64)
        assert f() == 4

    def test_polymorphic(self):
        engine, _ = compile_native("inheritance.na.jac")
        f = get_func(engine, "test_polymorphic", ctypes.c_int64, ctypes.c_int64)
        assert f(1) == 1  # Dog.speak
        assert f(0) == 2  # Cat.speak


class TestNativeLists:
    """Verify list creation, access, append, len, set."""

    def test_list_len(self):
        engine, _ = compile_native("lists.na.jac")
        f = get_func(engine, "list_len_test", ctypes.c_int64)
        assert f() == 3

    def test_list_get(self):
        engine, _ = compile_native("lists.na.jac")
        f = get_func(engine, "list_get_test", ctypes.c_int64)
        assert f() == 20

    def test_list_append(self):
        engine, _ = compile_native("lists.na.jac")
        f = get_func(engine, "list_append_test", ctypes.c_int64)
        assert f() == 4

    def test_list_sum(self):
        engine, _ = compile_native("lists.na.jac")
        f = get_func(engine, "list_sum", ctypes.c_int64)
        assert f() == 100

    def test_list_set(self):
        engine, _ = compile_native("lists.na.jac")
        f = get_func(engine, "list_set_test", ctypes.c_int64)
        assert f() == 99


class TestNativeComplexObjects:
    """Verify chained field access, chained method calls, indexed fields."""

    def test_chained_field(self):
        engine, _ = compile_native("complex_objects.na.jac")
        f = get_func(engine, "test_chained_field", ctypes.c_int64)
        assert f() == 42

    def test_chained_method(self):
        engine, _ = compile_native("complex_objects.na.jac")
        f = get_func(engine, "test_chained_method", ctypes.c_int64)
        assert f() == 99

    def test_chained_method_args(self):
        engine, _ = compile_native("complex_objects.na.jac")
        f = get_func(engine, "test_chained_method_args", ctypes.c_int64)
        assert f() == 15

    def test_deep_chain(self):
        engine, _ = compile_native("complex_objects.na.jac")
        f = get_func(engine, "test_deep_chain", ctypes.c_int64)
        assert f() == 14

    def test_indexed_field(self):
        engine, _ = compile_native("complex_objects.na.jac")
        f = get_func(engine, "test_indexed_field", ctypes.c_int64)
        assert f() == 20

    def test_indexed_field_set(self):
        engine, _ = compile_native("complex_objects.na.jac")
        f = get_func(engine, "test_indexed_field_set", ctypes.c_int64)
        assert f() == 99

    def test_field_len(self):
        engine, _ = compile_native("complex_objects.na.jac")
        f = get_func(engine, "test_field_len", ctypes.c_int64)
        assert f() == 4

    def test_field_append(self):
        engine, _ = compile_native("complex_objects.na.jac")
        f = get_func(engine, "test_field_append", ctypes.c_int64)
        assert f() == 3


class TestNativeBuiltins:
    """Verify string methods and builtins: ord, int, s[i], strip, split."""

    def test_char_at(self):
        engine, _ = compile_native("builtins.na.jac")
        f = get_func(engine, "test_char_at", ctypes.c_int64)
        assert f() == 101  # ord('e')

    def test_ord(self):
        engine, _ = compile_native("builtins.na.jac")
        f = get_func(engine, "test_ord", ctypes.c_int64)
        assert f() == 97  # ord('a')

    def test_int_parse(self):
        engine, _ = compile_native("builtins.na.jac")
        f = get_func(engine, "test_int_parse", ctypes.c_int64)
        assert f() == 42

    def test_strip(self):
        engine, _ = compile_native("builtins.na.jac")
        f = get_func(engine, "test_strip", ctypes.c_char_p)
        assert f() == b"hi"

    def test_split_len(self):
        engine, _ = compile_native("builtins.na.jac")
        f = get_func(engine, "test_split_len", ctypes.c_int64)
        assert f() == 3

    def test_split_get(self):
        engine, _ = compile_native("builtins.na.jac")
        f = get_func(engine, "test_split_get", ctypes.c_char_p)
        assert f() == b"world"

    def test_strip_split(self):
        engine, _ = compile_native("builtins.na.jac")
        f = get_func(engine, "test_strip_split", ctypes.c_int64)
        assert f() == 2


class TestNativeRuntime:
    """Runtime validation tests — exercises patterns needed for chess."""

    def test_for_list_literal(self):
        engine, _ = compile_native("runtime_validate.na.jac")
        f = get_func(engine, "test_for_list_literal", ctypes.c_int64)
        assert f() == 60

    def test_for_list_var(self):
        engine, _ = compile_native("runtime_validate.na.jac")
        f = get_func(engine, "test_for_list_var", ctypes.c_int64)
        assert f() == 15

    def test_nested_list(self):
        engine, _ = compile_native("runtime_validate.na.jac")
        f = get_func(engine, "test_nested_list", ctypes.c_int64)
        assert f() == 5

    def test_nested_set(self):
        engine, _ = compile_native("runtime_validate.na.jac")
        f = get_func(engine, "test_nested_set", ctypes.c_int64)
        assert f() == 99

    def test_for_nested(self):
        engine, _ = compile_native("runtime_validate.na.jac")
        f = get_func(engine, "test_for_nested", ctypes.c_int64)
        assert f() == 0

    def test_grid_init(self):
        engine, _ = compile_native("runtime_validate.na.jac")
        f = get_func(engine, "test_grid_init", ctypes.c_int64)
        assert f() == 9

    def test_grid_set_get(self):
        engine, _ = compile_native("runtime_validate.na.jac")
        f = get_func(engine, "test_grid_set_get", ctypes.c_int64)
        assert f() == 42


class TestNativeAugAssign:
    """Verify augmented assignment operators: +=, -=, *=, //=, %=."""

    def test_add_assign(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_add_assign", ctypes.c_int64)
        assert f() == 15

    def test_sub_assign(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_sub_assign", ctypes.c_int64)
        assert f() == 63

    def test_mul_assign(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_mul_assign", ctypes.c_int64)
        assert f() == 42

    def test_div_assign(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_div_assign", ctypes.c_int64)
        assert f() == 9

    def test_mod_assign(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_mod_assign", ctypes.c_int64)
        assert f() == 2

    def test_chained_aug(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_chained_aug", ctypes.c_int64)
        assert f() == 8  # (1+2)*3 - 1

    def test_aug_in_while(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_aug_in_while", ctypes.c_int64)
        assert f() == 45  # 0+1+2+...+9

    def test_aug_in_for(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_aug_in_for", ctypes.c_int64)
        assert f() == 45  # 0+1+2+...+9

    def test_aug_conditional(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_aug_conditional", ctypes.c_int64)
        assert f() == 2025  # even=20, odd=25 -> 20*100+25

    def test_aug_nested_loops(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_aug_nested_loops", ctypes.c_int64)
        assert f() == 25  # 5*5

    def test_aug_float_add(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_aug_float_add", ctypes.c_double)
        assert abs(f() - 4.0) < 1e-10

    def test_aug_float_mul(self):
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_aug_float_mul", ctypes.c_double)
        assert abs(f() - 7.5) < 1e-10

    def test_count_primes(self):
        """Count first 10 primes using += in nested while loops."""
        engine, _ = compile_native("aug_assign.na.jac")
        f = get_func(engine, "test_count_primes", ctypes.c_int64)
        assert f() == 29  # 10th prime


class TestNativeChess:
    """Full chess.na.jac integration tests."""

    def test_chess_compiles(self):
        engine, ir = compile_native("chess.na.jac")
        assert ir.gen.llvm_ir is not None

    def test_chess_opposite_color(self):
        engine, _ = compile_native("chess.na.jac")
        opp = get_func(engine, "opposite_color", ctypes.c_int64, ctypes.c_int64)
        assert opp(0) == 1  # WHITE -> BLACK
        assert opp(1) == 0  # BLACK -> WHITE

    def test_chess_create_piece(self):
        engine, _ = compile_native("chess.na.jac")
        addr = engine.get_function_address("create_piece")
        assert addr != 0

    def test_chess_has_entry(self):
        engine, _ = compile_native("chess.na.jac")
        addr = engine.get_function_address("jac_entry")
        assert addr != 0

    def test_chess_all_piece_types(self):
        """Verify all piece class methods are callable."""
        engine, _ = compile_native("chess.na.jac")
        for piece_type in ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]:
            addr = engine.get_function_address(f"{piece_type}.get_symbol")
            assert addr != 0, f"{piece_type}.get_symbol not found"

    def test_chess_board_methods(self):
        """Verify Board methods are callable."""
        engine, _ = compile_native("chess.na.jac")
        for method in [
            "Board.is_valid_pos",
            "Board.get_piece",
            "Board.set_piece",
            "Board.make_move",
            "Board.undo_move",
            "Board.display",
        ]:
            addr = engine.get_function_address(method)
            assert addr != 0, f"{method} not found"

    def test_chess_game_methods(self):
        """Verify Game methods are callable."""
        engine, _ = compile_native("chess.na.jac")
        for method in [
            "Game.find_king",
            "Game.is_in_check",
            "Game.get_legal_moves",
            "Game.is_checkmate",
            "Game.is_stalemate",
            "Game.parse_input",
        ]:
            addr = engine.get_function_address(method)
            assert addr != 0, f"{method} not found"


class TestNativeDicts:
    """Verify native dictionary operations produce correct results."""

    def test_dict_new_empty(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_new_empty", ctypes.c_int64)
        assert f() == 0

    def test_dict_literal_len(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_literal_len", ctypes.c_int64)
        assert f() == 3

    def test_dict_get_value(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_get_value", ctypes.c_int64)
        assert f() == 200

    def test_dict_set_value(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_set_value", ctypes.c_int64)
        assert f() == 20

    def test_dict_update_value(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_update_value", ctypes.c_int64)
        assert f() == 99

    def test_dict_len_after_set(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_len_after_set", ctypes.c_int64)
        assert f() == 3

    def test_dict_contains_true(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_contains_true", ctypes.c_int64)
        assert f() == 1

    def test_dict_contains_false(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_contains_false", ctypes.c_int64)
        assert f() == 0

    def test_dict_string_keys(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_string_keys", ctypes.c_int64)
        assert f() == 2

    def test_dict_string_values(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_string_values", ctypes.c_char_p)
        result = f()
        assert result == b"two"

    def test_dict_sum_values(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_sum_values", ctypes.c_int64)
        assert f() == 100

    def test_dict_overwrite(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_overwrite", ctypes.c_int64)
        assert f() == 30

    def test_dict_multiple_types(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_multiple_types", ctypes.c_int64)
        assert f() == 300

    def test_dict_get_first(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_get_first", ctypes.c_int64)
        assert f() == 100

    def test_dict_get_third(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_get_third", ctypes.c_int64)
        assert f() == 300

    def test_dict_set_then_get(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "dict_set_then_get", ctypes.c_int64)
        assert f() == 1500

    def test_global_dict_get(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        # Need to call jac_entry first to initialize globals
        entry = get_func(engine, "jac_entry", None)
        entry()
        f = get_func(engine, "global_dict_get", ctypes.c_int64)
        assert f() == 200

    def test_global_dict_len(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        entry = get_func(engine, "jac_entry", None)
        entry()
        f = get_func(engine, "global_dict_len", ctypes.c_int64)
        assert f() == 3


class TestNativeSets:
    """Verify native set operations produce correct results."""

    def test_set_new_empty(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "set_new_empty", ctypes.c_int64)
        assert f() == 0

    def test_set_literal_len(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "set_literal_len", ctypes.c_int64)
        assert f() == 5

    def test_set_add_element(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "set_add_element", ctypes.c_int64)
        assert f() == 4

    def test_set_add_duplicate(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "set_add_duplicate", ctypes.c_int64)
        assert f() == 3  # Duplicates shouldn't increase length

    def test_set_contains_true(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "set_contains_true", ctypes.c_int64)
        assert f() == 1

    def test_set_contains_false(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "set_contains_false", ctypes.c_int64)
        assert f() == 0

    def test_set_string_elements(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "set_string_elements", ctypes.c_int64)
        assert f() == 1

    def test_set_multiple_adds(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        f = get_func(engine, "set_multiple_adds", ctypes.c_int64)
        assert f() == 3  # 1, 2, 3 (duplicates ignored)

    def test_global_set_contains(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        entry = get_func(engine, "jac_entry", None)
        entry()
        f = get_func(engine, "global_set_contains", ctypes.c_int64)
        assert f() == 1

    def test_global_set_len(self):
        engine, _ = compile_native("dicts_sets.na.jac")
        entry = get_func(engine, "jac_entry", None)
        entry()
        f = get_func(engine, "global_set_len", ctypes.c_int64)
        assert f() == 5


class TestNativeExceptions:
    """Verify exception handling: try/except/else/finally, raise, nested."""

    def test_basic_try_except(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_basic_try_except", ctypes.c_int64)
        assert f() == 2

    def test_try_no_exception(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_try_no_exception", ctypes.c_int64)
        assert f() == 42

    def test_except_as_binding(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_except_as_binding", ctypes.c_char_p)
        assert f() == b"caught me"

    def test_try_else_no_exception(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_try_else_no_exception", ctypes.c_int64)
        assert f() == 11

    def test_try_else_with_exception(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_try_else_with_exception", ctypes.c_int64)
        assert f() == 5

    def test_try_finally(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_try_finally", ctypes.c_int64)
        assert f() == 111

    def test_try_finally_no_exception(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_try_finally_no_exception", ctypes.c_int64)
        assert f() == 105

    def test_multiple_except(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_multiple_except", ctypes.c_int64)
        assert f() == 2

    def test_catch_all(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_catch_all", ctypes.c_int64)
        assert f() == 42

    def test_nested_try(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_nested_try", ctypes.c_int64)
        assert f() == 111

    def test_raise_func_form(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_raise_func_form", ctypes.c_int64)
        assert f() == 77

    def test_full_combo_no_exc(self):
        engine, _ = compile_native("exceptions.na.jac")
        f = get_func(engine, "test_full_combo_no_exc", ctypes.c_int64)
        assert f() == 321


class TestNativeFileIO:
    """Verify file I/O: open, read, write, readline, close."""

    def test_open_write(self):
        engine, _ = compile_native("file_io.na.jac")
        f = get_func(engine, "test_open_write", ctypes.c_int64)
        assert f() == 1

    def test_write_file(self):
        engine, _ = compile_native("file_io.na.jac")
        f = get_func(engine, "test_write_file", ctypes.c_int64)
        assert f() == 11

    def test_write_read(self):
        engine, _ = compile_native("file_io.na.jac")
        f = get_func(engine, "test_write_read", ctypes.c_char_p)
        assert f() == b"NativeIO"

    def test_readline(self):
        engine, _ = compile_native("file_io.na.jac")
        f = get_func(engine, "test_readline", ctypes.c_char_p)
        assert f() == b"line1\n"

    def test_close_idempotent(self):
        engine, _ = compile_native("file_io.na.jac")
        f = get_func(engine, "test_close_idempotent", ctypes.c_int64)
        assert f() == 1

    def test_open_nonexistent(self):
        engine, _ = compile_native("file_io.na.jac")
        f = get_func(engine, "test_open_nonexistent", ctypes.c_int64)
        assert f() == 1

    def test_file_methods_exist(self):
        engine, _ = compile_native("file_io.na.jac")
        f = get_func(engine, "test_file_methods_exist", ctypes.c_int64)
        assert f() == 1


class TestNativeContextManagers:
    """Verify context managers: with statement, __enter__/__exit__, as binding."""

    def test_with_enter(self):
        engine, _ = compile_native("context_mgr.na.jac")
        f = get_func(engine, "test_with_enter", ctypes.c_int64)
        assert f() == 1

    def test_with_exit(self):
        engine, _ = compile_native("context_mgr.na.jac")
        f = get_func(engine, "test_with_exit", ctypes.c_int64)
        assert f() == 1

    def test_with_body(self):
        engine, _ = compile_native("context_mgr.na.jac")
        f = get_func(engine, "test_with_body", ctypes.c_int64)
        assert f() == 99

    def test_with_as_binding(self):
        engine, _ = compile_native("context_mgr.na.jac")
        f = get_func(engine, "test_with_as_binding", ctypes.c_int64)
        assert f() == 77

    def test_file_context_manager(self):
        engine, _ = compile_native("context_mgr.na.jac")
        f = get_func(engine, "test_file_context_manager", ctypes.c_int64)
        assert f() == 1

    def test_with_enter_exit_once(self):
        engine, _ = compile_native("context_mgr.na.jac")
        f = get_func(engine, "test_with_enter_exit_once", ctypes.c_int64)
        assert f() == 101


class TestNativeRuntimeErrors:
    """Verify runtime error checks: div-by-zero, index OOB, key missing, overflow, null deref."""

    # -- ZeroDivisionError --

    def test_int_div_by_zero(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_div_by_zero", ctypes.c_int64)
        assert f() == 1

    def test_int_mod_by_zero(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_mod_by_zero", ctypes.c_int64)
        assert f() == 1

    def test_div_by_zero_var(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_div_by_zero_var", ctypes.c_int64)
        assert f() == 1

    def test_float_div_by_zero(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_float_div_by_zero", ctypes.c_int64)
        assert f() == 1

    def test_div_no_error(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_div_no_error", ctypes.c_int64)
        assert f() == 5

    # -- IndexError --

    def test_list_index_oob(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_list_index_oob", ctypes.c_int64)
        assert f() == 1

    def test_list_negative_index(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_list_negative_index", ctypes.c_int64)
        assert f() == 1

    def test_list_index_at_len(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_list_index_at_len", ctypes.c_int64)
        assert f() == 1

    def test_list_valid_index(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_list_valid_index", ctypes.c_int64)
        assert f() == 20

    def test_list_set_oob(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_list_set_oob", ctypes.c_int64)
        assert f() == 1

    def test_empty_list_access(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_empty_list_access", ctypes.c_int64)
        assert f() == 1

    # -- KeyError --

    def test_dict_missing_key(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_dict_missing_key", ctypes.c_int64)
        assert f() == 1

    def test_dict_valid_key(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_dict_valid_key", ctypes.c_int64)
        assert f() == 2

    def test_dict_int_missing_key(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_dict_int_missing_key", ctypes.c_int64)
        assert f() == 1

    # -- OverflowError --

    def test_int_add_overflow(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_add_overflow", ctypes.c_int64)
        assert f() == 1

    def test_int_sub_underflow(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_sub_underflow", ctypes.c_int64)
        assert f() == 1

    def test_int_mul_overflow(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_mul_overflow", ctypes.c_int64)
        assert f() == 1

    def test_int_no_overflow(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_no_overflow", ctypes.c_int64)
        assert f() == 1

    # -- AttributeError (None dereference) --

    def test_none_field_access(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_none_field_access", ctypes.c_int64)
        assert f() == 1

    def test_none_method_call(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_none_method_call", ctypes.c_int64)
        assert f() == 1

    def test_valid_obj_access(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_valid_obj_access", ctypes.c_int64)
        assert f() == 42

    # -- ValueError --

    def test_int_parse_invalid(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_parse_invalid", ctypes.c_int64)
        assert f() == 1

    def test_int_parse_valid(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_parse_valid", ctypes.c_int64)
        assert f() == 123

    def test_int_parse_empty(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_int_parse_empty", ctypes.c_int64)
        assert f() == 1

    # -- AssertionError --

    def test_assert_false(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_assert_false", ctypes.c_int64)
        assert f() == 1

    def test_assert_true(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_assert_true", ctypes.c_int64)
        assert f() == 1

    # -- MemoryError --

    def test_alloc_ok(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_alloc_ok", ctypes.c_int64)
        assert f() == 1

    # -- Combined / edge cases --

    def test_catch_base_exception(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_catch_base_exception", ctypes.c_int64)
        assert f() == 1

    def test_sequential_errors(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_sequential_errors", ctypes.c_int64)
        assert f() == 11

    def test_error_in_loop(self):
        engine, _ = compile_native("runtime_errors.na.jac")
        f = get_func(engine, "test_error_in_loop", ctypes.c_int64)
        assert f() == 1


class TestNativePyInterop:
    """Verify cross-boundary calls between native (na) and Python code.

    Fixture call chain:
      with entry {}  (Python)
        → call_native(x)          (Python — calls into na block)
          → native_add_one_to_doubled(x)  (native — calls back to Python)
            → py_double(x)         (Python — returns x * 2)
          returns py_double(x) + 1
        returns the native result
      prints result
    """

    def test_interop_module_compiles(self):
        """Module with na block, Python functions, and entry compiles."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        prog.compile(str(FIXTURES / "na_py_interop.jac"))
        errors = [str(e) for e in prog.errors_had] if prog.errors_had else []
        assert not prog.errors_had, f"Compilation errors: {errors}"

    def test_native_function_exists_in_engine(self):
        """Native function from na block is available in the JIT engine."""
        engine, _ = compile_native("na_py_interop.jac")
        addr = engine.get_function_address("native_add_one_to_doubled")
        assert addr != 0, "native_add_one_to_doubled not found in JIT engine"

    def test_py_function_not_defined_in_native_ir(self):
        """py_double should be declared (external) but NOT defined in LLVM IR."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop.jac"))
        assert ir.gen.llvm_ir is not None, "No LLVM IR generated"
        llvm_ir_str = str(ir.gen.llvm_ir)
        # Must not have a define (body) for py_double — it lives in Python
        assert 'define i64 @"py_double"' not in llvm_ir_str
        # Should have an external declare so the native code can call it
        assert 'declare i64 @"py_double"' in llvm_ir_str

    def test_py_functions_in_python_codegen(self):
        """py_double and call_native should appear in Python codegen output."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop.jac"))
        py_src = ir.gen.py
        assert "py_double" in py_src
        assert "call_native" in py_src

    def test_native_function_has_stub_in_python(self):
        """Native function should have a ctypes stub in Python codegen output.

        The native function body (py_double(x) + 1) should NOT appear,
        but a ctypes bridge stub should be generated for Python → native calls.
        """
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop.jac"))
        py_src = ir.gen.py
        # Stub for the native function should exist
        assert "native_add_one_to_doubled" in py_src
        # The native function body should NOT appear as executable code in Python
        # (it may appear in the module docstring, but not as a return statement)
        assert "return py_double(x) + 1" not in py_src
        # Should reference ctypes for the bridge
        assert "CFUNCTYPE" in py_src
        assert "get_function_address" in py_src

    def test_interop_manifest_built(self):
        """InteropAnalysisPass should detect cross-boundary calls."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop.jac"))
        manifest = ir.gen.interop_manifest
        assert manifest is not None
        # py_double: defined in SERVER, called from NATIVE
        assert "py_double" in manifest.bindings
        b = manifest.bindings["py_double"]
        assert b.source_context.value == "server"
        # native_add_one_to_doubled: defined in NATIVE, called from SERVER
        assert "native_add_one_to_doubled" in manifest.bindings
        b2 = manifest.bindings["native_add_one_to_doubled"]
        assert b2.source_context.value == "native"

    def test_native_calls_python_function(self):
        """Native→Python: native_add_one_to_doubled calls py_double.

        native_add_one_to_doubled(x) calls py_double(x) then adds 1.
        py_double(5) = 10, so native_add_one_to_doubled(5) = 11.
        """
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop.jac"))
        engine = ir.gen.native_engine
        assert engine is not None
        # Register the Python function in the interop callback table
        py_func_table = ir.gen.interop_py_funcs
        py_func_table["py_double"] = lambda x: x * 2
        # Now call the native function
        f = get_func(
            engine,
            "native_add_one_to_doubled",
            ctypes.c_int64,
            ctypes.c_int64,
        )
        assert f(5) == 11  # py_double(5) = 10, + 1 = 11
        assert f(0) == 1  # py_double(0) = 0,  + 1 = 1
        assert f(-3) == -5  # py_double(-3) = -6, + 1 = -5

    def test_full_entry_chain(self):
        """Full chain: entry (Py) → call_native (Py) → native (na) → py_double (Py).

        Runs the module and verifies the printed output is 11.
        call_native(5) → native_add_one_to_doubled(5) → py_double(5)=10 → +1 → 11.
        """
        import contextlib
        import io

        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop.jac"))
        assert not prog.errors_had
        # Execute the compiled module with interop context injected
        py_code = compile(ir.gen.py, str(FIXTURES / "na_py_interop.jac"), "exec")
        namespace = {
            "__jac_native_engine__": ir.gen.native_engine,
            "__jac_interop_py_funcs__": ir.gen.interop_py_funcs,
        }
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            exec(py_code, namespace)  # noqa: S102
        output = buf.getvalue().strip()
        assert output == "11"


class TestNativeMultiModuleInterop:
    """Test NATIVE↔NATIVE cross-module imports and linking.

    These tests verify that .na.jac modules can import and call functions
    from other .na.jac modules, requiring LLVM module linking.

    NOTE: Some of these tests may fail until full NATIVE↔NATIVE
    linking is implemented.
    """

    def test_na_module_compiles(self):
        """A standalone .na.jac module compiles to LLVM IR."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_math_utils.na.jac"))
        assert not prog.errors_had, f"Errors: {prog.errors_had}"
        assert ir.gen.llvm_ir is not None, "No LLVM IR generated"
        llvm_ir_str = str(ir.gen.llvm_ir)
        assert "triple" in llvm_ir_str
        assert "square" in llvm_ir_str

    def test_module_level_na_import(self):
        """Module-level import of .na.jac file is recognized."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop_multi.jac"))
        # Should compile without errors
        assert ir is not None
        assert not prog.errors_had, f"Errors: {prog.errors_had}"
        # triple should be in manifest as a cross-module import
        manifest = ir.gen.interop_manifest
        assert "triple" in manifest.bindings
        assert manifest.bindings["triple"].source_module == "na_math_utils.na"

    def test_na_scoped_import(self):
        """Import inside na {} block is recognized."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop_multi.jac"))
        assert not prog.errors_had, f"Errors: {prog.errors_had}"
        # The na-scoped import should be tracked in manifest
        manifest = ir.gen.interop_manifest
        # add_ten should be recognized as a NATIVE→NATIVE binding
        assert "add_ten" in manifest.bindings
        assert manifest.bindings["add_ten"].source_module == "na_transformers.na"

    def test_native_module_linking(self):
        """Functions from imported .na.jac modules are callable."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop_multi.jac"))
        assert not prog.errors_had, f"Errors: {prog.errors_had}"
        engine = ir.gen.native_engine
        assert engine is not None, "No native engine created"
        # Imported native functions should be resolvable
        triple_addr = engine.get_function_address("triple")
        assert triple_addr != 0, "triple not linked into engine"

    def test_full_multi_module_chain(self):
        """Full call chain with multi-module native imports works.

        call_native(5) = triple(5) + native_compute(5)
                       = 15 + add_ten(py_double(5))
                       = 15 + add_ten(10)
                       = 15 + 20
                       = 35
        """
        import contextlib
        import io

        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "na_py_interop_multi.jac"))
        assert not prog.errors_had, f"Errors: {prog.errors_had}"
        assert ir.gen.native_engine is not None, "No native engine created"

        py_code = compile(ir.gen.py, str(FIXTURES / "na_py_interop_multi.jac"), "exec")
        namespace = {
            "__jac_native_engine__": ir.gen.native_engine,
            "__jac_interop_py_funcs__": getattr(ir.gen, "interop_py_funcs", {}),
        }
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            exec(py_code, namespace)  # noqa: S102
        output = buf.getvalue().strip()
        assert output == "35"


class TestNativeLLVMIR:
    """Verify LLVM IR output structure."""

    def test_ir_has_function_definitions(self):
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "arithmetic.na.jac"))
        assert ir.gen.llvm_ir is not None, "No LLVM IR generated"
        llvm_ir_str = str(ir.gen.llvm_ir)
        assert 'define i64 @"add"' in llvm_ir_str
        assert 'define i64 @"multiply"' in llvm_ir_str
        assert 'define i64 @"negate"' in llvm_ir_str
        assert 'define double @"float_add"' in llvm_ir_str
