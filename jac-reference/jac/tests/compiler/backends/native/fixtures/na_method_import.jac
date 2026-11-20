"""Test: calling methods on an imported archetype.

Before the fix, _register_imported_archetype registered the struct layout but
never called _forward_declare_method for the archetype's abilities.  As a
result method_funcs["Counter.increment"] was absent, _codegen_method_call
returned None, and _codegen_assignment silently dropped the entire statement.

After the fix every Ability in the imported archetype body is forward-declared,
so method calls on imported struct types emit correct LLVM call instructions.

Expected outputs (used by test_native_gen_pass.jac):
  test_imported_method_once()       -> 1
  test_imported_method_five()       -> 5
  test_imported_method_with_arg()   -> 10
  test_imported_chained_methods()   -> 12
"""

import from na_method_import_lib { Counter, make_counter }

# Returns 1  (start=0, increment once)
def test_imported_method_once() -> int {
    c: Counter = make_counter(0);
    return c.increment();
}

# Returns 5  (start=0, increment five times)
def test_imported_method_five() -> int {
    c: Counter = make_counter(0);
    c.increment();
    c.increment();
    c.increment();
    c.increment();
    return c.increment();
}

# Returns 10  (start=3, add 7)
def test_imported_method_with_arg() -> int {
    c: Counter = make_counter(3);
    return c.add(7);
}

# Returns 12  (start=0, increment to 2, then add 10)
def test_imported_chained_methods() -> int {
    c: Counter = make_counter(0);
    c.increment();
    c.increment();
    return c.add(10);
}
