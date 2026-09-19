"""Reproduce the outstanding managed-native longjmp cleanup leak.

Compile with tests.support.compile_native in a runtime with the shared object API.
Calling unwind with a borrowed PyObject must leave its reference count unchanged.
The current longjmp path skips the intermediate frame's ObjectRef destructor.
"""
import from jaclang.runtime.cpython.references { ObjectResult, borrowed_result }

def fail {
    raise ValueError("native failure");
}

def inner(value: u64) -> ObjectResult {
    held = borrowed_result(value);
    fail();
    return held;
}

def:pub unwind(value: u64) {
    try {
        result = inner(value);
    } except ValueError {}
}
