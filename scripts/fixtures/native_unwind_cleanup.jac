"""Reproduce the outstanding managed-native longjmp cleanup leak.

Build as a native shared library in a runtime with the shared object API.
Calling unwind with a borrowed PyObject must leave its reference count unchanged.
The current longjmp path skips the intermediate frame's ObjectRef destructor.
"""
import from jaclang.runtime.python.references { ObjectRef }
import from jaclang.runtime.python.capi { jacpy_retain }

def fail {
    raise ValueError("native failure");
}

def inner(value: u64) -> ObjectRef {
    held = ObjectRef(value=jacpy_retain(value));
    fail();
    return held;
}

def:pub unwind(value: u64) {
    try {
        result = inner(value);
    } except ValueError {}
}
