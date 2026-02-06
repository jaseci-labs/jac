"""Test cross-boundary calls with multi-module native imports.

This extends na_py_interop.jac to also test:
1. Import inside na {} block of .na.jac files
2. NATIVE→NATIVE function calls across module boundaries

Call chain:
  with entry {}  (Python)
    → call_native(x)  (Python)
      → triple(x)  (native, from na_math_utils.na)
      → native_compute(x)  (native, local)
        → py_double(x)  (Python - sv↔na interop)
        → add_ten(...)  (native, from na_transformers.na)
      returns triple(x) + native_compute(x)
    returns the native result
  prints result

Expected: call_native(5) = triple(5) + native_compute(5)
        = 15 + add_ten(py_double(5))
        = 15 + add_ten(10)
        = 15 + 20
        = 35
"""

# Python function in the main codespace — compiled to Python bytecode.
def py_double(x: int) -> int {
    return x * 2;
}

na {
    # Import native functions from .na.jac modules
    import from na_math_utils { triple }
    import from na_transformers { add_ten }

    # Native function that uses:
    # - py_double (sv function, sv↔na interop)
    # - add_ten (na function from na_transformers.na, na↔na linking)
    def native_compute(x: int) -> int {
        doubled = py_double(x);  # sv↔na: calls Python function
        return add_ten(doubled);  # na↔na: calls imported native function
    }

    # Main native entry point that uses:
    # - triple (na function from na_math_utils.na)
    # - native_compute (local na function)
    def native_entry(x: int) -> int {
        tripled = triple(x);  # na↔na: calls imported native function
        computed = native_compute(x);  # na→na: calls local native function
        return tripled + computed;
    }
}

# Python function that calls into the na block.
def call_native(x: int) -> int {
    return native_entry(x);
}

# Entry point: kicks off the full chain.
with entry {
    result = call_native(5);
    print(result);
}
