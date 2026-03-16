"""End-to-end tests for native LLVM IR compilation (na {} / .na.jac).

Tests verify that .na.jac fixtures compile to LLVM IR, JIT-compile to
native machine code, and produce correct results when executed via ctypes.
"""

import ctypes;
import os;
import subprocess;
import sys;
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
    fadd = get_func(eng, "float_add", ctypes.c_double, ctypes.c_double, ctypes.c_double);
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
    f = get_func(eng, "str_not_equal", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p);
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

test "strings str replace count arg respected" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(eng, "str_replace_first_only", ctypes.c_char_p, ctypes.c_char_p);
    # only the first 'a' should be replaced; remaining 'a's must be untouched
    assert f(b"aaa") == b"Xaa";
    assert f(b"banana") == b"bXnana";
}

test "strings for-in-str join" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(eng, "str_for_in_join", ctypes.c_char_p, ctypes.c_char_p);
    assert f(b"Hello") == b"Hello";
    assert f(b"") == b"";
}

test "strings for-in-str count" {
    (eng, _) = compile_native("strings.na.jac");
    f = get_func(eng, "str_for_in_count", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"Hello") == 5;
    assert f(b"") == 0;
}

# --- TestNativePrintMultiArgs ---
test "print multi args compiles" {
    (eng, _) = compile_native("print_multi_args.na.jac");
    assert eng is not None;
}

test "print multi args multiple args" {
    (eng, _) = compile_native("print_multi_args.na.jac");
    f = get_func(eng, "test_multiple_args", ctypes.c_int64);
    assert f() == 0;
}

test "print multi args mixed types" {
    (eng, _) = compile_native("print_multi_args.na.jac");
    f = get_func(eng, "test_mixed_types", ctypes.c_int64);
    assert f() == 0;
}

test "print multi args variables" {
    (eng, _) = compile_native("print_multi_args.na.jac");
    f = get_func(eng, "test_variables", ctypes.c_int64);
    assert f() == 0;
}

test "print multi args single arg" {
    (eng, _) = compile_native("print_multi_args.na.jac");
    f = get_func(eng, "test_single_arg", ctypes.c_int64);
    assert f() == 0;
}

test "print multi args many args" {
    (eng, _) = compile_native("print_multi_args.na.jac");
    f = get_func(eng, "test_many_args", ctypes.c_int64);
    assert f() == 0;
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

test "objects init called" {
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "test_init_called", ctypes.c_int64);
    assert f() == 42;
}

test "objects init executed" {
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "test_init_executed", ctypes.c_int64);
    assert f() == 20;
}

test "objects init no args" {
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "test_init_no_args", ctypes.c_int64);
    assert f() == 99;
}

test "objects init positional" {
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "test_init_positional", ctypes.c_int64);
    # KWInit(10, 20) → init adds 1 to each → x=11, y=21 → sum=32
    assert f() == 32;
}

test "objects init side effects" {
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "test_init_side_effects", ctypes.c_int64);
    assert f() == 1;
}

test "objects empty dict in struct ctor" {
    # Container(entries={}) used to store null → segfault on first dict access.
    (eng, _) = compile_native("objects.na.jac");
    f = get_func(eng, "test_empty_dict_ctor_field", ctypes.c_int64);
    assert f() == 30;
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

# --- TestMultipleInheritance ---
test "multi-inherit two parent fields" {
    (eng, _) = compile_native("multi_inherit.na.jac");
    f = get_func(eng, "test_two_parent_fields", ctypes.c_int64);
    assert f() == 151;
}

test "multi-inherit two parent methods" {
    (eng, _) = compile_native("multi_inherit.na.jac");
    f = get_func(eng, "test_two_parent_methods", ctypes.c_int64);
    assert f() == 192;
}

test "multi-inherit diamond field access" {
    (eng, _) = compile_native("multi_inherit.na.jac");
    f = get_func(eng, "test_diamond_field_access", ctypes.c_int64);
    assert f() == 130;
}

test "multi-inherit diamond single id" {
    (eng, _) = compile_native("multi_inherit.na.jac");
    f = get_func(eng, "test_diamond_single_id", ctypes.c_int64);
    assert f() == 42;
}

test "multi-inherit mro method resolution" {
    (eng, _) = compile_native("multi_inherit.na.jac");
    f = get_func(eng, "test_mro_method_resolution", ctypes.c_int64);
    assert f() == 2;
}

test "multi-inherit three mixins" {
    (eng, _) = compile_native("multi_inherit.na.jac");
    f = get_func(eng, "test_three_mixins", ctypes.c_int64);
    assert f() == 10;
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

# --- TestNativeCrossModuleMethods ---
# Regression tests for: _register_imported_archetype must forward-declare all
# archetype methods so that method_funcs["Type.method"] is populated for
# imported types.  Before the fix every cross-module method call was silently
# dropped from the IR (value stayed null/0).
test "cross-module method call once" {
    (eng, _) = compile_native("na_method_import.na.jac");
    f = get_func(eng, "test_imported_method_once", ctypes.c_int64);
    assert f() == 1;
}

test "cross-module method call five times" {
    (eng, _) = compile_native("na_method_import.na.jac");
    f = get_func(eng, "test_imported_method_five", ctypes.c_int64);
    assert f() == 5;
}

test "cross-module method call with argument" {
    (eng, _) = compile_native("na_method_import.na.jac");
    f = get_func(eng, "test_imported_method_with_arg", ctypes.c_int64);
    assert f() == 10;
}

test "cross-module chained method calls" {
    (eng, _) = compile_native("na_method_import.na.jac");
    f = get_func(eng, "test_imported_chained_methods", ctypes.c_int64);
    assert f() == 12;
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

test "chess play random moves stress" {
    # Stress test: play 20 random moves then quit.
    # Exercises global dict GC root survival, tuple-keyed dict access,
    # and repeated make_move/undo_move cycles across many game iterations.
    chess_path = os.path.join(FIXTURES, "chess.na.jac");
    # 20 blank lines (random moves) followed by "quit"
    stdin_data = "\n" * 20 + "quit\n";
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", chess_path],
        input=stdin_data,
        capture_output=True,
        text=True,
        timeout=120
    );
    assert result.returncode == 0 , (
        f"Chess crashed with exit code {result.returncode}.\n"
        f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}\n"
        f"stdout tail: {result.stdout[-500:] if result.stdout else '(empty)'}"
    );
    assert "Game ended." in result.stdout , (
        f"Expected 'Game ended.' in output.\n"
        f"stdout tail: {result.stdout[-500:] if result.stdout else '(empty)'}"
    );
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
        "__jac_interop_py_funcs__": ir.gen.interop_py_funcs
    };
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        exec(py_code, namespace);
    }
    output = buf.getvalue().strip();
    assert output == "35";
}

# --- TestCrossModuleStructTypes ---
test "cross module struct compile" {
    # Importing a struct type from another .na.jac module compiles without errors.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_struct_import.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "cross module struct function call" {
    # Imported function returning a struct and function accepting a struct work correctly.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_struct_import.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    eng = ir.gen.native_engine;
    assert eng is not None;
    # make_point and get_x should be linked
    make_point_addr = eng.get_function_address("make_point");
    assert make_point_addr != 0 , "make_point not linked into engine";
    get_x_addr = eng.get_function_address("get_x");
    assert get_x_addr != 0 , "get_x not linked into engine";
}

test "cross module struct execution" {
    # Call use_imported_point via ctypes to verify cross-module struct passing works.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_struct_import.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    eng = ir.gen.native_engine;
    assert eng is not None;
    use_imported_point = get_func(
        eng, "use_imported_point", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    result = use_imported_point(3, 4);
    assert result == 3 , f"Expected 3, got {result}";
    result2 = use_imported_point(7, 9);
    assert result2 == 7 , f"Expected 7, got {result2}";
}

# --- TestCrossModuleGlobalLinkage ---
# Regression tests for: global-internal-linkage-breaks-cross-module
# Before fix: module globals were emitted with LLVM `internal` linkage. The
# linker renamed the definition (e.g. @MAGIC -> @MAGIC.467) when another module
# declared it as `external`, leaving the external reference permanently null.
# Any read then caused a null-pointer segfault (exit 134).
# After fix: globals use default (public) linkage; the symbol resolves correctly.
test "cross module global linkage compile" {
    # Importing a module that directly reads globals from another .na.jac module
    # must compile and JIT without errors.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_glob_import.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "cross module global direct read" {
    # read_magic() directly accesses the imported MAGIC global.
    # With internal linkage this segfaulted; with public linkage it must return 42.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_glob_import.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    eng = ir.gen.native_engine;
    assert eng is not None;
    read_magic = get_func(eng, "read_magic", ctypes.c_int64);
    result = read_magic();
    assert result == 42 , f"Expected MAGIC==42, got {result}";
}

test "cross module global via function" {
    # read_magic_via_func() delegates to get_magic() from the exporting module.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_glob_import.na.jac")));
    assert not prog.errors_had;
    eng = ir.gen.native_engine;
    assert eng is not None;
    read_via_func = get_func(eng, "read_magic_via_func", ctypes.c_int64);
    result = read_via_func();
    assert result == 42 , f"Expected 42 via get_magic(), got {result}";
}

test "cross module global arithmetic" {
    # sum_globals() reads both MAGIC and BASE from the exporting module and adds
    # them; read_base_plus(n) delegates to add_base(n).
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "na_glob_import.na.jac")));
    assert not prog.errors_had;
    eng = ir.gen.native_engine;
    assert eng is not None;
    sum_g = get_func(eng, "sum_globals", ctypes.c_int64);
    result = sum_g();
    assert result == 142 , f"Expected MAGIC+BASE==142, got {result}";
    add_b = get_func(eng, "read_base_plus", ctypes.c_int64, ctypes.c_int64);
    result2 = add_b(5);
    assert result2 == 105 , f"Expected BASE+5==105, got {result2}";
}

# --- TestNativeCacheMarker ---
test "cache marker non native file has no llvmir section in jir" {
    # Compiling a file without na blocks should NOT write SEC_LLVM_IR into the JIR cache.
    import tempfile;
    import time;
    import shutil;
    import from jaclang.jac0core.jir {
        get_module_cache_path,
        read_sections,
        SECTIONS_MAGIC,
        HEADER_SIZE,
        SEC_LLVM_IR
    }

    tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False);
    tmp.write("glob x = 1;\n");
    tmp.flush();
    jac_file = tmp.name;
    tmp.close();

    # Set source mtime slightly in the past so cache files are strictly newer
    past = time.time() - 2;
    os.utime(jac_file, (past, past));

    try {
        import from jaclang.jac0core.compiler { JacCompiler }
        prog = JacProgram();
        JacCompiler().get_bytecode(jac_file, prog);

        cache_path = get_module_cache_path(jac_file);
        assert cache_path.exists() , f"JIR cache file not created at {cache_path}";

        data = cache_path.read_bytes();
        magic_bytes = SECTIONS_MAGIC;
        pos = data.find(magic_bytes, HEADER_SIZE);
        secs: dict = {};
        if pos >= 0 {
            secs = read_sections(data, pos + len(magic_bytes));
        }
        assert SEC_LLVM_IR not in secs , (
            f"Non-native file should not have SEC_LLVM_IR in JIR cache"
        );
    } except Exception as e {
        os.unlink(jac_file);
        raise;
    }
    os.unlink(jac_file);
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

# --- TestRefCounting ---
test "rc basic alloc" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_alloc_basic", ctypes.c_int64);
    assert f() == 42;
}

test "rc object lifecycle" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_object_lifecycle", ctypes.c_int64);
    assert f() == 10;
}

test "rc reassignment" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_reassign", ctypes.c_int64);
    assert f() == 2;
}

test "rc list growth" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_list_growth", ctypes.c_int64);
    assert f() == 20;
}

test "rc list of objects" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_list_of_objects", ctypes.c_int64);
    assert f() == 3;
}

test "rc nested structure" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_nested_structure", ctypes.c_int64);
    assert f() == 3;
}

test "rc string alloc" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_string_alloc", ctypes.c_int64);
    assert f() == 11;
}

test "rc return transfer" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_return_transfer", ctypes.c_int64);
    assert f() == 42;
}

test "rc dict growth" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_dict_growth", ctypes.c_int64);
    assert f() == 20;
}

test "rc loop reassign" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_loop_reassign", ctypes.c_int64);
    assert f() == 10;
}

test "rc set operations" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_set_operations", ctypes.c_int64);
    assert f() == 5;
}

test "rc string reassign" {
    (eng, _) = compile_native("refcount.na.jac");
    f = get_func(eng, "test_string_reassign", ctypes.c_int64);
    assert f() == 5;
}

# --- TestRefCountingStress ---
test "rc stress many objects" {
    (eng, _) = compile_native("rc_stress.na.jac");
    f = get_func(eng, "test_many_objects", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
}

test "rc stress rapid reassign" {
    (eng, _) = compile_native("rc_stress.na.jac");
    f = get_func(eng, "test_rapid_reassign", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 999;
}

test "rc stress large list" {
    (eng, _) = compile_native("rc_stress.na.jac");
    f = get_func(eng, "test_large_list", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
}

test "rc stress string concat" {
    (eng, _) = compile_native("rc_stress.na.jac");
    f = get_func(eng, "test_string_concat_stress", ctypes.c_int64, ctypes.c_int64);
    assert f(100) == 100;
}

test "rc stress large dict" {
    (eng, _) = compile_native("rc_stress.na.jac");
    f = get_func(eng, "test_large_dict", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
}

test "dicts items iteration sum" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_items_iter_sum", ctypes.c_int64);
    assert f() == 60;
}

# --- TestNativeEmptyGlobDict (regression: empty-dict-glob-var-init-null-ptr) ---
test "dicts empty glob dict set and get" {
    # glob x: dict[K,V] = {} previously left the global as null -> segfault on first access.
    (eng, _) = compile_native("dicts_sets.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "empty_glob_dict_set_get", ctypes.c_int64);
    assert f() == 7;
}

# --- TestNativeDictDeleteRemove (regression: dict-delete-silently-dropped) ---
test "dicts dict remove method" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_remove_method", ctypes.c_int64);
    assert f() == 1;  # key must be absent after .remove()
}

test "dicts dict delete keyword" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_delete_keyword", ctypes.c_int64);
    assert f() == 1;  # key must be absent after del d[k]
}

test "dicts dict.get found" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_get_found", ctypes.c_int64);
    assert f() == 10 , f"Expected 10, got {f()}";
}

test "dicts dict.get not found" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_get_notfound", ctypes.c_int64);
    assert f() == -99 , f"Expected -99, got {f()}";
}

test "dicts dict.get no default" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_get_no_default", ctypes.c_int64);
    assert f() == 100 , f"Expected 100, got {f()}";
}

test "dicts global dict.get method" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_dict_get_method", ctypes.c_int64);
    assert f() == 200 , f"Expected 200, got {f()}";
}

test "dicts global dict.get not found method" {
    (eng, _) = compile_native("dicts_sets.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "global_dict_get_notfound_method", ctypes.c_int64);
    assert f() == -42 , f"Expected -42, got {f()}";
}

test "dicts for-in-dict param iteration" {
    # for k in d where d is a dict parameter was always elided (body never ran).
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_param_iter_sum_fixture", ctypes.c_int64);
    assert f() == 60;
}

test "dicts for-in-dict field access iteration" {
    # for k in c.props where c is a struct with a dict field used to segfault
    # because the AtomTrailer expression had no bare name to look up in var_dict_type.
    (eng, _) = compile_native("dicts_sets.na.jac");
    f = get_func(eng, "dict_field_iter_sum_fixture", ctypes.c_int64);
    assert f() == 60;
}

test "default params omitted trailing defaults" {
    (eng, _) = compile_native("default_params.na.jac");
    method_f = get_func(eng, "test_method_default_omitted", ctypes.c_int64);
    assert method_f() == 22;  # 5 + 7 + 10 (offset default)
    free_f = get_func(eng, "test_free_fn_default_omitted", ctypes.c_int64);
    assert free_f() == 142;  # 42 + 100 (bias default)
}

# --- Auto-Promotion Tests ---
glob CHESS_JAC = str(
         Path(jaclang.__file__).parent.parent / "examples" / "chess" / "chess.jac"
     );

"""Compile a regular .jac file with auto-promotion and return the engine."""
def compile_auto_native(file_path: str) -> tuple {
    prog = JacProgram();
    prog._auto_promote_native = True;
    prog._auto_promote_target = os.path.abspath(file_path);
    ir = prog.compile(file_path=file_path);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    return (ir, prog);
}

test "auto promote chess.jac detects native compatible" {
    (ir, _) = compile_auto_native(CHESS_JAC);
    assert ir is not None;
    assert ir.gen._auto_promoted_native , (
        "chess.jac should be auto-promoted to native"
    );
    assert ir.gen.native_engine is not None , (
        "Auto-promoted chess.jac should have a native engine"
    );
}

test "auto promote chess.jac has entry and key functions" {
    (ir, _) = compile_auto_native(CHESS_JAC);
    eng = ir.gen.native_engine;
    # jac_entry must exist
    assert eng.get_function_address("jac_entry") != 0;
    # Key game functions must be present
    for func_name in [
        "opposite_color",
        "create_piece",
        "Board.display",
        "Game.is_checkmate",
        "Game.find_king",
        "Game.play"
    ] {
        assert eng.get_function_address(func_name) != 0 , (
            f"{func_name} not found in auto-promoted native engine"
        );
    }
}

test "auto promote chess.jac runs via cli" {
    # End-to-end: jac run --autonative chess.jac should execute natively.
    stdin_data = "\n" * 20 + "quit\n";
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", "--autonative", CHESS_JAC],
        input=stdin_data,
        capture_output=True,
        text=True,
        timeout=120
    );
    assert result.returncode == 0 , (
        f"Auto-promoted chess crashed with exit code {result.returncode}.\n"
        f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
    );
    assert "Game ended." in result.stdout , (
        f"Expected 'Game ended.' in output.\n"
        f"stdout tail: {result.stdout[-500:] if result.stdout else '(empty)'}"
    );
    # Verify the native execution message appears (may be line-wrapped by Rich)
    combined = " ".join((result.stdout + result.stderr).split());
    assert "executed natively" in combined , (
        f"Expected native execution message.\n" f"output tail: {combined[-500:]}"
    );
}

# --- Native sys Module Tests ---
test "sys argv via jac run autonative" {
    # Test that sys.argv works when running via `jac run --autonative`
    fixture = str(os.path.join(FIXTURES, "sys_argv.jac"));
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "run",
            "--autonative",
            fixture,
            "hello",
            "--test-flag",
            "world"
        ],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert result.returncode == 0 , (
        f"sys_argv fixture crashed: exit={result.returncode}\n"
        f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
    );
    out = result.stdout;
    # Should report correct argc (fixture path + 3 args = 4)
    assert "argc: 4" in out , (f"Expected 'argc: 4' in output.\nstdout: {out}");
    # Should find the --test-flag
    assert "FLAG_FOUND" in out , (f"Expected 'FLAG_FOUND' in output.\nstdout: {out}");
    # Should print each argument
    assert "arg: hello" in out , (f"Expected 'arg: hello' in output.\nstdout: {out}");
    assert "arg: world" in out , (f"Expected 'arg: world' in output.\nstdout: {out}");
    assert "DONE" in out , (f"Expected 'DONE' in output.\nstdout: {out}");
}

test "sys argv via nacompile" {
    # Test that sys.argv works when compiled to a standalone binary via nacompile
    import tempfile;
    fixture = str(os.path.join(FIXTURES, "sys_argv.jac"));
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "sys_argv_bin");
        # Step 1: Compile to native binary
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert comp.returncode == 0 , (
            f"nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"Binary not created at {out_bin}";
        # Step 2: Run the binary with arguments
        result = subprocess.run(
            [out_bin, "hello", "--test-flag", "world"],
            capture_output=True,
            text=True,
            timeout=10
        );
        assert result.returncode == 0 , (
            f"Native binary crashed: exit={result.returncode}\n"
            f"stderr: {result.stderr[-500:] if result.stderr else '(empty)'}"
        );
        out = result.stdout;
        # Should report correct argc (binary path + 3 args = 4)
        assert "argc: 4" in out , (f"Expected 'argc: 4' in output.\nstdout: {out}");
        # Should find the --test-flag
        assert "FLAG_FOUND" in out , (
            f"Expected 'FLAG_FOUND' in output.\nstdout: {out}"
        );
        # Should print each argument
        assert "arg: hello" in out , (
            f"Expected 'arg: hello' in output.\nstdout: {out}"
        );
        assert "arg: world" in out , (
            f"Expected 'arg: world' in output.\nstdout: {out}"
        );
        assert "DONE" in out , (f"Expected 'DONE' in output.\nstdout: {out}");
        # Step 3: Run with --exit-code flag to test sys.exit()
        exit_result = subprocess.run(
            [out_bin, "--exit-code", "1"], capture_output=True, text=True, timeout=10
        );
        assert exit_result.returncode == 1 , (
            f"Expected exit code 1, got {exit_result.returncode}"
        );
        # DONE should NOT appear (sys.exit called before it)
        assert "DONE" not in exit_result.stdout , (
            f"DONE should not appear after sys.exit()\nstdout: {exit_result.stdout}"
        );
    }
}

# --- TestNativeListBugs ---
test "list_bugs pop local removes element" {
    (eng, _) = compile_native("list_bugs.na.jac");
    f = get_func(eng, "pop_and_len", ctypes.c_int64);
    assert f() == 2;
}

test "list_bugs pop local returns last value" {
    (eng, _) = compile_native("list_bugs.na.jac");
    f = get_func(eng, "pop_value", ctypes.c_int64);
    assert f() == 30;
}

test "list_bugs pop loop drains list" {
    (eng, _) = compile_native("list_bugs.na.jac");
    f = get_func(eng, "pop_loop", ctypes.c_int64);
    assert f() == 3;
}

test "list_bugs pop global removes element" {
    (eng, _) = compile_native("list_bugs.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "pop_global_len", ctypes.c_int64);
    assert f() == 2;
}

test "list_bugs obj list field access" {
    (eng, _) = compile_native("list_bugs.na.jac");
    f = get_func(eng, "obj_list_field", ctypes.c_int64);
    assert f() == 42;
}

test "list_bugs obj list two items" {
    (eng, _) = compile_native("list_bugs.na.jac");
    f = get_func(eng, "obj_list_two_items", ctypes.c_int64);
    assert f() == 40;
}

test "list_bugs obj global list" {
    (eng, _) = compile_native("list_bugs.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "obj_global_list", ctypes.c_int64);
    assert f() == 100;
}

test "list_bugs reassign int list with empty literal" {
    (eng, _) = compile_native("list_bugs.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "reassign_int_list", ctypes.c_int64);
    assert f() == 99;
}

test "list_bugs reassign str list with empty literal" {
    (eng, _) = compile_native("list_bugs.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "reassign_str_list", ctypes.c_int64);
    assert f() == 1;
}

# --- String Enum Tests ---
test "string_enums ordinal red" {
    (eng, _) = compile_native("string_enums.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "color_ordinal_red", ctypes.c_int64);
    assert f() == 0 , f"Color.RED ordinal should be 0, got {f()}";
}

test "string_enums ordinal blue" {
    (eng, _) = compile_native("string_enums.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "color_ordinal_blue", ctypes.c_int64);
    assert f() == 2 , f"Color.BLUE ordinal should be 2, got {f()}";
}

test "string_enums comparison" {
    (eng, _) = compile_native("string_enums.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "color_cmp", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 10 , f"color_cmp(RED=0) should be 10";
    assert f(1) == 20 , f"color_cmp(GREEN=1) should be 20";
    assert f(2) == 30 , f"color_cmp(BLUE=2) should be 30";
}

test "string_enums value access" {
    (eng, _) = compile_native("string_enums.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "color_value", ctypes.c_char_p, ctypes.c_int64);
    assert f(0) == b"red" , f"Color.RED.value should be 'red', got {f(0)}";
    assert f(1) == b"green" , f"Color.GREEN.value should be 'green'";
    assert f(2) == b"blue" , f"Color.BLUE.value should be 'blue'";
}

test "string_enums name access" {
    (eng, _) = compile_native("string_enums.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "color_name", ctypes.c_char_p, ctypes.c_int64);
    assert f(0) == b"RED" , f"Color.RED.name should be 'RED', got {f(0)}";
    assert f(1) == b"GREEN" , f"Color.GREEN.name should be 'GREEN'";
    assert f(2) == b"BLUE" , f"Color.BLUE.name should be 'BLUE'";
}

test "string_enums direction value" {
    (eng, _) = compile_native("string_enums.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "direction_value", ctypes.c_char_p, ctypes.c_int64);
    assert f(0) == b"N" , f"Direction.NORTH.value should be 'N'";
    assert f(1) == b"S" , f"Direction.SOUTH.value should be 'S'";
}

test "string_enums int enum still works" {
    (eng, _) = compile_native("string_enums.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "int_enum_still_works", ctypes.c_int64);
    assert f() == 2 , f"Priority.HIGH should be 2, got {f()}";
}

# --- Cross-Module Enum Import Tests ---
test "enum_import compiles" {
    (eng, _) = compile_native("na_enum_import.na.jac");
    assert eng is not None;
}

test "enum_import enum comparison" {
    (eng, _) = compile_native("na_enum_import.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "use_imported_enum", ctypes.c_int64);
    assert f() == 1 , f"TokenKind.KW_IF == TokenKind.KW_IF should return 1";
}

test "enum_import ordinal" {
    (eng, _) = compile_native("na_enum_import.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "imported_enum_ordinals", ctypes.c_int64);
    # TokenKind.EOF is the last member (ordinal 6)
    assert f() == 6 , f"TokenKind.EOF ordinal should be 6, got {f()}";
}

test "enum_import value access" {
    (eng, _) = compile_native("na_enum_import.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "imported_enum_value", ctypes.c_char_p);
    assert f() == b"+" , f"TokenKind.PLUS.value should be '+', got {f()}";
}

test "enum_import cross module function call" {
    (eng, _) = compile_native("na_enum_import.na.jac");
    # Call both entry functions (imported module needs its globals initialized)
    renamed_entry_addr = eng.get_function_address("__jac_entry_na_enum_export_na");
    if renamed_entry_addr {
        renamed_entry = ctypes.CFUNCTYPE(None)(renamed_entry_addr);
        renamed_entry();
    }
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "check_if_keyword", ctypes.c_int64);
    r = f();
    assert r == 3 , f"Expected 3 (KW_IF ordinal), got {r}";
    f2 = get_func(eng, "check_else_keyword", ctypes.c_int64);
    r2 = f2();
    assert r2 == 4 , f"Expected 4 (KW_ELSE ordinal), got {r2}";
    f3 = get_func(eng, "check_unknown_keyword", ctypes.c_int64);
    r3 = f3();
    assert r3 == -1 , f"Expected -1 (not found), got {r3}";
}

# --- Switch statement tests ---
test "switch int match" {
    (eng, _ir) = compile_native("switch_stmt.na.jac");
    entry = get_func(eng, "jac_entry", None);
    entry();
    f = get_func(eng, "switch_int", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 10 , f"switch_int(1) should be 10, got {f(1)}";
    assert f(2) == 20 , f"switch_int(2) should be 20, got {f(2)}";
    assert f(3) == 30 , f"switch_int(3) should be 30, got {f(3)}";
    assert f(99) == -1 , f"switch_int(99) should be -1 (default), got {f(99)}";
}

test "switch enum" {
    (eng, _ir) = compile_native("switch_stmt.na.jac");
    entry = get_func(eng, "jac_entry", None);
    entry();
    f = get_func(eng, "switch_enum", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 100 , f"switch_enum(RED=0) should be 100, got {f(0)}";
    assert f(1) == 200 , f"switch_enum(GREEN=1) should be 200, got {f(1)}";
    assert f(2) == 300 , f"switch_enum(BLUE=2) should be 300, got {f(2)}";
}

test "switch string" {
    (eng, _ir) = compile_native("switch_stmt.na.jac");
    entry = get_func(eng, "jac_entry", None);
    entry();
    f = get_func(eng, "switch_str", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"(") == 1 , f"switch_str('(') should be 1, got {f(b'(')}";
    assert f(b")") == 2 , f"switch_str(')') should be 2, got {f(b')')}";
    assert f(b"{") == 3;
    assert f(b"}") == 4;
    assert f(b"x") == 0 , f"switch_str('x') should be 0 (default), got {f(b'x')}";
}

test "switch no default" {
    (eng, _ir) = compile_native("switch_stmt.na.jac");
    entry = get_func(eng, "jac_entry", None);
    entry();
    f = get_func(eng, "switch_no_default", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 100 , f"switch_no_default(10) should be 100, got {f(10)}";
    assert f(20) == 200 , f"switch_no_default(20) should be 200, got {f(20)}";
    assert f(99) == -1 , f"switch_no_default(99) should be -1 (unchanged), got {f(99)}";
}

# --- TestJIRBitcodeCaching ---
test "jir bitcode cache round-trip" {
    import struct;
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.jir {
        get_module_cache_path,
        SECTIONS_MAGIC,
        HEADER_SIZE,
        read_sections,
        SEC_NATIVE_OBJ
    }

    compiler = JacCompiler();
    fixture = str(os.path.join(FIXTURES, "arithmetic.na.jac"));

    # Step 1: Compile via get_bytecode to populate JIR cache
    prog1 = JacProgram();
    code1 = compiler.get_bytecode(fixture, prog1);
    assert code1 is not None , "get_bytecode should return code object";

    # Step 2: Verify SEC_NATIVE_OBJ section exists in the cached JIR file
    cache_path = get_module_cache_path(fixture);
    assert cache_path.exists() , f"JIR cache file should exist at {cache_path}";
    jir_data = cache_path.read_bytes();
    magic: bytes = SECTIONS_MAGIC;
    pos = jir_data.find(magic, HEADER_SIZE);
    assert pos >= 0 , "JIR file should contain SECTIONS_MAGIC";
    secs = read_sections(jir_data, pos + len(magic));
    assert SEC_NATIVE_OBJ in secs , f"JIR should contain SEC_NATIVE_OBJ, got sections: {list(
        secs.keys()
    )}";

    # Step 3: Verify platform header in SEC_NATIVE_OBJ
    sec_data = secs[SEC_NATIVE_OBJ];
    assert len(sec_data) > 2 , "SEC_NATIVE_OBJ too short";
    (triple_len, ) = struct.unpack_from('<H', sec_data, 0);
    cached_triple = sec_data[2:2 + triple_len].decode('utf-8');
    import llvmlite.binding as llvm;
    assert cached_triple == llvm.get_default_triple() , (
        f"Triple mismatch: {cached_triple} != {llvm.get_default_triple()}"
    );
    bitcode_size = len(sec_data) - 2 - triple_len;
    assert bitcode_size > 0 , "Bitcode should not be empty";

    # Step 4: Load from cache with a fresh compiler and call native function
    compiler2 = JacCompiler();
    prog2 = JacProgram();
    code2 = compiler2.get_bytecode(fixture, prog2);
    assert code2 is not None , "Cache reload should return code object";

    # Step 5: Verify native engine was restored via get_native_interop_setup
    (engine, _) = compiler2.get_native_interop_setup(fixture, prog2);
    assert engine is not None , "Native engine should be restored from bitcode cache";
    add = get_func(engine, "add", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert add(17, 25) == 42 , f"add(17,25) via cached engine should be 42, got {add(
        17, 25
    )}";
}

# --- CType struct contract: layout metadata and field types ---
test "struct layout exports correct field types" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None , "Native layout should be exported";
    assert "AllFields" in layout.structs , "AllFields struct should be in layout";
    af = layout.structs["AllFields"];
    field_map = {f.name: f for f in af.fields};
    assert field_map["x"].llvm_type == "i64";
    assert field_map["y"].llvm_type == "f64";
    assert field_map["name"].llvm_type == "i8*";
    assert field_map["flag"].llvm_type == "i1";
    assert field_map["items"].llvm_type.startswith("List.");
}

test "struct layout tracks field indices correctly" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    layout = ir.gen.native_layout;
    af = layout.structs["AllFields"];
    indices = [f.index for f in af.fields];
    # Indices should be consecutive starting from 0
    assert indices == list(range(len(af.fields)));
}

test "optional field compiles to pointer type" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    layout = ir.gen.native_layout;
    assert "MaybePoint" in layout.structs;
    mp = layout.structs["MaybePoint"];
    field_map = {f.name: f for f in mp.fields};
    assert field_map["x"].llvm_type == "i64";
    assert field_map["y"].llvm_type == "i64";
    # label is str|None → still i8* (pointers are nullable)
    assert field_map["label"].llvm_type == "i8*";
}

test "all_fields struct round-trip via ctypes" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    make = get_func(
        eng,
        "make_all_fields",
        ctypes.c_void_p,
        ctypes.c_int64,
        ctypes.c_double,
        ctypes.c_char_p
    );
    get_x = get_func(eng, "get_all_fields_x", ctypes.c_int64, ctypes.c_void_p);
    ptr = make(42, 3.14, b"hello");
    assert ptr != 0;
    assert get_x(ptr) == 42;
}

test "all_fields bool field round-trip" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    make = get_func(
        eng,
        "make_all_fields",
        ctypes.c_void_p,
        ctypes.c_int64,
        ctypes.c_double,
        ctypes.c_char_p
    );
    get_flag = get_func(eng, "get_all_fields_flag", ctypes.c_bool, ctypes.c_void_p);
    ptr = make(1, 2.0, b"test");
    assert get_flag(ptr) == True;
}

test "maybe_point struct round-trip" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    make = get_func(
        eng, "make_maybe_point", ctypes.c_void_p, ctypes.c_int64, ctypes.c_int64
    );
    get_x = get_func(eng, "get_maybe_x", ctypes.c_int64, ctypes.c_void_p);
    ptr = make(10, 20);
    assert ptr != 0;
    assert get_x(ptr) == 10;
}

test "NativeFieldInfo func_ptr defaults to False" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    layout = ir.gen.native_layout;
    af = layout.structs["AllFields"];
    for f in af.fields {
        assert f.is_func_ptr == False , f"Field {f.name} should not be func_ptr";
        assert f.func_param_types is None;
        assert f.func_ret_type is None;
    }
}

test "function layout exports param and return types" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    layout = ir.gen.native_layout;
    assert "add" in layout.functions;
    add_layout = layout.functions["add"];
    assert add_layout.param_types == ["i64", "i64"];
    assert add_layout.ret_type == "i64";
}

test "layout exports all expected functions" {
    (eng, ir) = compile_native("func_ptr_fields.na.jac");
    layout = ir.gen.native_layout;
    expected = {"add","mul","negate","identity","make_all_fields","get_all_fields_x","get_all_fields_flag","make_maybe_point","get_maybe_x"};
    assert expected == set(layout.functions.keys());
}

# --- Jac-to-Jac function pointer tests (Callable[[...], ret] type annotation) ---
test "fnptr apply2 with add" {
    (eng, _) = compile_native("fnptr_jac.na.jac");
    apply2 = get_func(
        eng, "apply2", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    add_addr = eng.get_function_address("add");
    assert apply2(add_addr, 3, 4) == 7;
    assert apply2(add_addr, 0, 0) == 0;
    assert apply2(add_addr, -1, 1) == 0;
}

test "fnptr apply2 with mul" {
    (eng, _) = compile_native("fnptr_jac.na.jac");
    apply2 = get_func(
        eng, "apply2", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    mul_addr = eng.get_function_address("mul");
    assert apply2(mul_addr, 3, 4) == 12;
    assert apply2(mul_addr, 0, 99) == 0;
    assert apply2(mul_addr, -2, 5) == -10;
}

test "fnptr apply1 with negate" {
    (eng, _) = compile_native("fnptr_jac.na.jac");
    apply1 = get_func(eng, "apply1", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    neg_addr = eng.get_function_address("negate");
    assert apply1(neg_addr, 5) == -5;
    assert apply1(neg_addr, 0) == 0;
    assert apply1(neg_addr, -3) == 3;
}

test "fnptr call_via_local stores and calls pointer" {
    (eng, _) = compile_native("fnptr_jac.na.jac");
    call_via_local = get_func(
        eng,
        "call_via_local",
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64
    );
    add_addr = eng.get_function_address("add");
    mul_addr = eng.get_function_address("mul");
    assert call_via_local(add_addr, 6, 7) == 13;
    assert call_via_local(mul_addr, 6, 7) == 42;
}

# --- TestCrossModuleGlobInit ---
test "cross module glob init compiles without errors" {
    # Importing a module with a glob list initializer must compile cleanly.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "cross_module_glob_init.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "cross module glob init: imported glob is non-null on first access" {
    # Before the fix, _TABLE in the library module stayed null after import,
    # causing table_len() to return garbage and table_push() to segfault.
    # After the fix, jac_entry calls __jac_glob_init_cross_module_glob_init_lib_na
    # so the list is properly allocated before any code touches it.
    (eng, _) = compile_native("cross_module_glob_init.na.jac");
    # Call jac_entry to trigger __jac_glob_init for both this module and the import.
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_test = get_func(eng, "run_glob_init_test", ctypes.c_int64);
    result = run_test();
    # Encoded: initial_len*10000 + after_one*100 + after_two = 0*10000 + 1*100 + 2 = 102
    assert result == 102 , f"Expected 102 (0 items, then 1, then 2), got {result}";
}

test "cross module glob init: pushed values are readable" {
    # Verify table_get(0) and table_get(1) return the values pushed by run_test.
    (eng, _) = compile_native("cross_module_glob_init.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_test = get_func(eng, "run_glob_init_test", ctypes.c_int64);
    run_test();  # populate: push(42), push(99)
    get_first = get_func(eng, "get_first", ctypes.c_int64);
    get_second = get_func(eng, "get_second", ctypes.c_int64);
    assert get_first() == 42 , f"Expected 42, got {get_first()}";
    assert get_second() == 99 , f"Expected 99, got {get_second()}";
}

# ─── FIX 1: Transitive native imports linked via DFS ─────────────────────────
# Before the fix, the linker only walked direct imports. A → B → C would
# compile B but leave C's symbols unresolved at JIT link time.
# jac-bun/issues/transitive-native-import-not-linked/
test "transitive import: compiles without errors" {
    # fix_transitive_entry imports fix_transitive_mid which imports fix_transitive_leaf.
    # All three modules must be linked for compilation to succeed.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "fix_transitive_entry.na.jac")));
    assert not prog.errors_had , f"Errors: {prog.errors_had}";
    assert ir is not None;
    assert ir.gen.native_engine is not None , "No native engine created";
}

test "transitive import: function call through two import hops returns correct value" {
    # run_transitive_test() → get_mid() → get_leaf() → 99
    # All three functions must be linked for this to work.
    (eng, _) = compile_native("fix_transitive_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_fn = get_func(eng, "run_transitive_test", ctypes.c_int64);
    assert run_fn() == 99 , f"Expected 99, got {run_fn()}";
}

test "transitive import: same result on repeated calls (no state corruption)" {
    (eng, _) = compile_native("fix_transitive_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    run_fn = get_func(eng, "run_transitive_test", ctypes.c_int64);
    assert run_fn() == 99 , f"First call: expected 99, got {run_fn()}";
    assert run_fn() == 99 , f"Second call: expected 99, got {run_fn()}";
    assert run_fn() == 99 , f"Third call: expected 99, got {run_fn()}";
}

# ─── FIX 4: del list[i] shrinks the list ─────────────────────────────────────
# Before the fix, `del container.field_list[i]` was silently dropped from
# the IR — the element was never removed and the list length never changed.
# jac-bun/issues/del-struct-field-list-no-shrink/
test "del list item: length decrements after delete" {
    # Container starts with [10, 20, 30]; after del items[2] length must be 2.
    (eng, _) = compile_native("fix_del_list.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_del_shrinks_length", ctypes.c_int64);
    result = f();
    assert result == 2 , f"Expected length 2 after del, got {result}";
}

test "del list item: remaining elements shift left after delete" {
    # After del items[0] from [10, 20, 30], items[0] must become 20.
    (eng, _) = compile_native("fix_del_list.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_del_shifts_elements", ctypes.c_int64);
    result = f();
    assert result == 20 , f"Expected items[0]=20 after del, got {result}";
}

test "del list item: deleting only element yields empty list" {
    # del items[0] from single-element list — length must become 0.
    (eng, _) = compile_native("fix_del_list.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_del_last_element", ctypes.c_int64);
    result = f();
    assert result == 0 , f"Expected length 0 after del, got {result}";
}

# ─── FIX 3a: Imported archetype methods registered in method_funcs ────────────
# Before the fix, _forward_declare_method was never called for methods on
# imported archetypes, so calls like `c.increment()` were silently dropped.
# jac-bun/issues/imported-archetype-methods-not-in-method-funcs/
test "imported archetype method: single increment returns 1" {
    # Counter.increment() on an imported struct; expect 1 after one call.
    (eng, _) = compile_native("fix_method_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_increment_once", ctypes.c_int64);
    result = f();
    assert result == 1 , f"Expected 1, got {result}";
}

test "imported archetype method: double increment returns 2" {
    # Two calls to increment() on the same Counter; expect 2.
    (eng, _) = compile_native("fix_method_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_increment_twice", ctypes.c_int64);
    result = f();
    assert result == 2 , f"Expected 2, got {result}";
}

test "imported archetype method: add_delta returns updated value" {
    # Counter starts at 5, add_delta(3); expect 8.
    (eng, _) = compile_native("fix_method_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_add_delta", ctypes.c_int64);
    result = f();
    assert result == 8 , f"Expected 8, got {result}";
}

test "imported archetype method: independent instances do not share state" {
    # Two counters accumulate independently; encoded as a*100 + b.
    # a = 2 (incremented twice), b = 15 (start 10 + delta 5) → 215.
    (eng, _) = compile_native("fix_method_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_two_counters", ctypes.c_int64);
    result = f();
    assert result == 215 , f"Expected 215 (a=2, b=15), got {result}";
}

# ─── FIX 3b: Cross-module fn arg where param type is from a third module ──────
# When calling an imported function whose parameter type is itself defined in
# a third module, the compiler emitted i64(0) instead of the correct struct*.
# jac-bun/issues/cross-module-fn-arg-third-module-struct-as-i64/
test "third module struct: compiles without type errors" {
    # fix_third_entry imports from fix_third_a and fix_third_b.
    # fix_third_b's read_value takes a DataA from fix_third_a — third-module struct.
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "fix_third_entry.na.jac")));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine";
}

test "third module struct: value field survives cross-module round-trip" {
    # make_data_a(77, 3) → pass to read_value; expect 77.
    (eng, _) = compile_native("fix_third_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_third_struct_value", ctypes.c_int64);
    result = f();
    assert result == 77 , f"Expected 77, got {result}";
}

test "third module struct: both fields correct after cross-module call" {
    # make_data_a(77, 3) → read_sum (value+tag); expect 80.
    (eng, _) = compile_native("fix_third_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_third_struct_sum", ctypes.c_int64);
    result = f();
    assert result == 80 , f"Expected 80, got {result}";
}

# ─── FIX 5: var_type_node populated for imported globals (subscript access) ───
# Before the fix, _register_imported_globals did not store the type-annotation
# AST node in var_type_node, so _resolve_ptr_elem_cast_type emitted i8* null
# when accessing elements of cross-module list globals inline (ITEMS[i].field).
# jac-bun/issues/cross-module-list-subscript-multilevel-field-access/
test "cross-module subscript: compiles without errors" {
    prog = JacProgram();
    ir = prog.compile(str(os.path.join(FIXTURES, "fix_subscript_entry.na.jac")));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert ir.gen.native_engine is not None , "No native engine";
}

test "cross-module subscript: inline ITEMS[0].value returns correct value" {
    # push_item(42, 7) then ITEMS[0].value inline (no typed local); expect 42.
    (eng, _) = compile_native("fix_subscript_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();  # initialises ITEMS glob in fix_subscript_outer
    f = get_func(eng, "test_subscript_value", ctypes.c_int64);
    result = f();
    assert result == 42 , f"Expected 42, got {result}";
}

test "cross-module subscript: inline ITEMS[0].extra returns correct value" {
    # push_item(42, 7) then ITEMS[0].extra inline; expect 7.
    (eng, _) = compile_native("fix_subscript_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_subscript_extra", ctypes.c_int64);
    result = f();
    assert result == 7 , f"Expected 7, got {result}";
}

test "cross-module subscript: inline access to second item returns correct value" {
    # push (42,7) then (99,3); ITEMS[1].value inline; expect 99.
    (eng, _) = compile_native("fix_subscript_entry.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "test_subscript_second_item", ctypes.c_int64);
    result = f();
    assert result == 99 , f"Expected 99, got {result}";
}
