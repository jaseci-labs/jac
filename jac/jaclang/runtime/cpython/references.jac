import from jaclang.runtime.cpython.capi {
    jacpy_release,
    jacpy_visit,
    jacpy_retain,
    jacpy_error_take,
    jacpy_error_restore,
    object_error,
    jacpy_tuple_new,
    jacpy_tuple_set_owned
}

obj NativeState {
    def traverse_refs(visitor: u64, context: u64) -> i32 abst;
    def clear abst;
}

obj ObjectRef(NativeState) {
    has value: u64;

    def clear {
        previous = self.value;
        self.value = 0;
        jacpy_release(previous);
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
        return jacpy_visit(self.value, visitor, context);
    }

    def drop {
        self.clear();
    }

    def take -> u64 {
        previous = self.value;
        self.value = 0;
        return previous;
    }
}

obj ObjectResult {
    has reference: ObjectRef,
        failed: bool = False;

    def take -> u64 {
        value = self.reference.take();
        if value == 0 {
            object_error("SystemError", "native object result was already consumed");
            return 0;
        }
        if self.failed {
            jacpy_error_restore(value);
            return 0;
        }
        return value;
    }
}

def object_result(value: u64) -> ObjectResult {
    if value != 0 {
        return ObjectResult(reference=ObjectRef(value=value));
    }
    error = jacpy_error_take();
    if error == 0 {
        object_error(
            "SystemError", "native object operation failed without an exception"
        );
        error = jacpy_error_take();
    }
    return ObjectResult(reference=ObjectRef(value=error), failed=True);
}

def borrowed_result(value: u64) -> ObjectResult {
    if value == 0 {
        object_error("SystemError", "cannot borrow a null Python object");
        return object_result(0);
    }
    return object_result(jacpy_retain(value));
}

obj ReferenceState(NativeState) {
    has references: list[u64];

    def clear {
        previous = self.references;
        self.references = [u64(0) for _ in previous];
        for value in previous {
            jacpy_release(value);
        }
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
        for value in self.references {
            result = jacpy_visit(value, visitor, context);
            if result != 0 {
                return result;
            }
        }
        return i32(0);
    }

    def drop {
        self.clear();
    }
}

def owned_tuple(values: list[u64]) -> u64 {
    held = ReferenceState(references=values);
    for value in values {
        if value == 0 {
            return 0;
        }
    }
    result = jacpy_tuple_new(i64(len(values)));
    if result == 0 {
        return 0;
    }
    for i in range(len(values)) {
        value = held.references[i];
        held.references[i] = 0;
        if jacpy_tuple_set_owned(result, i64(i), value) < 0 {
            jacpy_release(result);
            return 0;
        }
    }
    return result;
}
