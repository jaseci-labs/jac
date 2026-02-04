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
