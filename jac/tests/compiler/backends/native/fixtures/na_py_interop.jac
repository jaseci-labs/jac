"""Test cross-boundary calls between native (na) and Python code.

Call chain:
  with entry {}  (Python)
    → call_native(x)  (Python — calls into na block)
      → native_add_one_to_doubled(x)  (native — calls back to Python)
        → py_double(x)  (Python — returns x * 2)
      returns py_double(x) + 1
    returns the native result
  prints result
  → native_note(x)  (native, no `-> T`: returns None across the bridge)
    → py_note(x)  (Python, no `-> T`: prints x, returns None)
"""

# Python function in the main codespace — compiled to Python bytecode.
def py_double(x: int) -> int {
    return x * 2;
}


# Python function with no return annotation: its native caller declares it void.
def py_note(x: int) {
    print(x);
}


# Native function — compiled to LLVM IR / machine code.
# Calls py_double which lives in the Python (non-na) codespace.
def native_add_one_to_doubled(x: int) -> int {
    return py_double(x) + 1;
}


# Native function with no return annotation: it returns None to Python.
def native_note(x: int) {
    py_note(x);
}


# Python function that calls into the na block.
def call_native(x: int) -> int {
    return native_add_one_to_doubled(x);
}

# Entry point: kicks off the full Python → native → Python chain.
with entry {
    result = call_native(5);
    print(result);
    native_note(7);
}
