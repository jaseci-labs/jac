"""Test cross-boundary calls between native (na) and Python code.

Call chain:
  with entry {}  (Python)
    → call_native(x)  (Python — calls into na block)
      → native_add_one_to_doubled(x)  (native — calls back to Python)
        → py_double(x)  (Python — returns x * 2)
      returns py_double(x) + 1
    returns the native result
  prints result
"""

# Python function in the main codespace — compiled to Python bytecode.
def py_double(x: int) -> int {
    return x * 2;
}

na {
    # Native function — compiled to LLVM IR / machine code.
    # Calls py_double which lives in the Python (non-na) codespace.
    def native_add_one_to_doubled(x: int) -> int {
        return py_double(x) + 1;
    }
}

# Python function that calls into the na block.
def call_native(x: int) -> int {
    return native_add_one_to_doubled(x);
}

# Entry point: kicks off the full Python → native → Python chain.
with entry {
    result = call_native(5);
    print(result);
}
