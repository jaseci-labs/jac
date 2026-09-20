import from jaclang.runtime.cpython.references { ObjectRef, object_result }
import from jaclang.runtime.cpython.capi {
    PyThreadState_Get,
    PySlice_New,
    PyInterpreterState_Get,
    PyInterpreterState_GetDict,
    jacpy_mapping_optional_item,
    jacpy_contains,
    jacpy_dict_clear,
    jacpy_call_one,
    jacpy_special_noargs,
    PyImport_ImportModuleLevelObject,
    _PyEval_ImportFrom,
    PyErr_GivenExceptionMatches,
    jacpy_import_object,
    jacpy_getattr_string,
    jacpy_call,
    jacpy_int,
    jacpy_float,
    jacpy_boolean,
    jacpy_none,
    jacpy_text,
    jacpy_bytes_from_data,
    jacpy_tuple_new,
    jacpy_tuple_set_owned,
    jacpy_dict_new,
    jacpy_list_new,
    jacpy_set_new,
    jacpy_setitem,
    jacpy_getitem,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_retain,
    jacpy_truth,
    jacpy_integer_value,
    jacpy_float_value,
    jacpy_is_bytes,
    read_buffer,
    text_value,
    boundary_failure,
    object_error,
    jacpy_error_pending,
    jacpy_error_restore
}

obj __JacPythonValue(ObjectRef) {}

obj __JacPythonIterator(ObjectRef) {
    def __iter__ -> __JacPythonIterator {
        return self;
    }

    def __next__ -> __JacPythonValue {
        value = jacpy_iter_next(self.value);
        if value == 0 {
            __jac_python_check();
            raise StopIteration();
        }
        return __jac_python_result(value);
    }
}

obj __JacPythonError(Exception) {
    has reference: ObjectRef;
}

def __jac_python_checked(value: u64) -> u64 {
    if value != 0 {
        return value;
    }
    result = object_result(0);
    raise __JacPythonError(reference=result.reference);
}

def __jac_python_result(value: u64) -> __JacPythonValue {
    return __JacPythonValue(value=__jac_python_checked(value));
}

def __jac_python_iter(value: __JacPythonValue) -> __JacPythonIterator {
    return __JacPythonIterator(value=__jac_python_checked(jacpy_iter(value.value)));
}

def __jac_python_check {
    if jacpy_error_pending() != 0 {
        failure = object_result(0);
        raise __JacPythonError(reference=failure.reference);
    }
}

def __jac_python_unbound(name: str) {
    object_error(
        "UnboundLocalError",
        "cannot access local variable '"
            + name
            + "' where it is not associated with a value"
    );
    __jac_python_check();
}

def __jac_python_restore(error: __JacPythonError) {
    jacpy_error_restore(jacpy_retain(error.reference.value));
}

def __jac_python_import(name: str) -> __JacPythonValue {
    module_name = __jac_python_text(name);
    return __jac_python_result(jacpy_import_object(module_name.value));
}

def __jac_python_import_from(name: str, attribute: str) -> __JacPythonValue {
    module_name = __jac_python_text(name);
    member_name = __jac_python_text(attribute);
    members = __jac_python_tuple(1);
    __jac_python_tuple_set(members, 0, member_name);
    module = __jac_python_result(
        PyImport_ImportModuleLevelObject(module_name.value, 0, 0, members.value, i32(0))
    );

    return __jac_python_result(
        _PyEval_ImportFrom(PyThreadState_Get(), module.value, member_name.value)
    );
}

def __jac_python_getattr(value: __JacPythonValue, name: str) -> __JacPythonValue {
    return __jac_python_result(jacpy_getattr_string(value.value, name));
}

def __jac_python_call(
    callable: __JacPythonValue, args: __JacPythonValue, kwargs: __JacPythonValue
) -> __JacPythonValue {
    return __jac_python_result(jacpy_call(callable.value, args.value, kwargs.value));
}

def __jac_python_int(value: int) -> __JacPythonValue {
    return __jac_python_result(jacpy_int(i64(value)));
}

def __jac_python_float(value: float) -> __JacPythonValue {
    return __jac_python_result(jacpy_float(value));
}

def __jac_python_bool(value: bool) -> __JacPythonValue {
    return __jac_python_result(jacpy_boolean(i64(value)));
}

def __jac_python_none -> __JacPythonValue {
    return __jac_python_result(jacpy_none());
}

def __jac_python_text(value: str) -> __JacPythonValue {
    return __jac_python_result(
        jacpy_text(value, i64(len(value.encode("utf-8", "surrogatepass"))))
    );
}

def __jac_python_bytes(value: bytes) -> __JacPythonValue {
    return __jac_python_result(jacpy_bytes_from_data(value, i64(len(value))));
}

def __jac_python_tuple(size: int) -> __JacPythonValue {
    return __jac_python_result(jacpy_tuple_new(i64(size)));
}

def __jac_python_tuple_set(
    target: __JacPythonValue, index: int, value: __JacPythonValue
) {
    jacpy_tuple_set_owned(target.value, i64(index), jacpy_retain(value.value));
    __jac_python_check();
}

def __jac_python_unpack(value: __JacPythonValue, count: int) -> __JacPythonValue {
    iterator = __jac_python_result(jacpy_iter(value.value));
    result = __jac_python_tuple(count);
    for index in range(count) {
        item = jacpy_iter_next(iterator.value);
        if item == 0 {
            __jac_python_check();
            object_error(
                "ValueError",
                "not enough values to unpack (expected "
                    + str(count)
                    + ", got "
                    + str(index)
                    + ")"
            );
            __jac_python_check();
        }
        __jac_python_tuple_set(result, index, __jac_python_result(item));
    }
    extra = jacpy_iter_next(iterator.value);
    if extra != 0 {
        retained = __jac_python_result(extra);
        object_error(
            "ValueError", "too many values to unpack (expected " + str(count) + ")"
        );
        __jac_python_check();
    }
    __jac_python_check();
    return result;
}


def __jac_python_dict -> __JacPythonValue {
    return __jac_python_result(jacpy_dict_new());
}

def __jac_python_list -> __JacPythonValue {
    return __jac_python_result(jacpy_list_new());
}

def __jac_python_set -> __JacPythonValue {
    return __jac_python_result(jacpy_set_new(0, i64(0)));
}

def __jac_python_slice(
    start: __JacPythonValue, stop: __JacPythonValue, step: __JacPythonValue
) -> __JacPythonValue {
    return __jac_python_result(PySlice_New(start.value, stop.value, step.value));
}

def __jac_python_setitem(
    target: __JacPythonValue, key: __JacPythonValue, value: __JacPythonValue
) {
    jacpy_setitem(target.value, key.value, value.value);
    __jac_python_check();
}

def __jac_python_getitem(
    target: __JacPythonValue, key: __JacPythonValue
) -> __JacPythonValue {
    return __jac_python_result(jacpy_getitem(target.value, key.value));
}

def __jac_python_truth(value: __JacPythonValue) -> bool {
    result = jacpy_truth(value.value);
    __jac_python_check();
    return result != 0;
}


def __jac_python_as_int(value: __JacPythonValue) -> int {
    result = jacpy_integer_value(value.value);
    __jac_python_check();
    return int(result);
}

def __jac_python_as_float(value: __JacPythonValue) -> float {
    result = jacpy_float_value(value.value);
    __jac_python_check();
    return result;
}

def __jac_python_as_text(value: __JacPythonValue) -> str {
    try {
        return text_value(value.value);
    } except boundary_failure {
        __jac_python_check();
        raise;
    }
}

def __jac_python_as_bytes(value: __JacPythonValue) -> bytes {
    if jacpy_is_bytes(value.value) == 0 {
        object_error("TypeError", "expected a bytes object");
        __jac_python_check();
    }
    return read_buffer(value.value);
}


def __jac_python_matches(error: __JacPythonError, kind: __JacPythonValue) -> bool {
    return PyErr_GivenExceptionMatches(error.reference.value, kind.value) != 0;
}

def __jac_python_module_state(identity: u64) -> __JacPythonValue {
    interpreter = __jac_python_checked(
        PyInterpreterState_GetDict(PyInterpreterState_Get())
    );
    key = __jac_python_tuple(2);
    __jac_python_tuple_set(key, 0, __jac_python_text("__jac_native_module_v1"));
    __jac_python_tuple_set(key, 1, __jac_python_int(int(identity)));
    existing = jacpy_mapping_optional_item(interpreter, key.value);
    __jac_python_check();
    if existing != 0 {
        return __jac_python_result(existing);
    }
    state = __jac_python_dict();
    jacpy_setitem(interpreter, key.value, state.value);
    __jac_python_check();
    return state;
}

def __jac_python_module_begin(state: __JacPythonValue) -> bool {
    marker = __jac_python_none();
    present = jacpy_contains(state.value, marker.value);
    __jac_python_check();
    if present != 0 {
        return False;
    }
    __jac_python_setitem(state, marker, marker);
    return True;
}

def __jac_python_initialize(
    identity: u64, initialize: Callable[[__JacPythonValue], None]
) {
    bootstrap = __jac_python_import("importlib._bootstrap");
    get_lock = __jac_python_getattr(bootstrap, "_get_module_lock");
    name = __jac_python_text("__jac_native_module_" + str(identity));
    lock = __jac_python_result(jacpy_call_one(get_lock.value, name.value));
    __jac_python_result(jacpy_special_noargs(lock.value, "acquire"));
    try {
        state = __jac_python_module_state(identity);
        if __jac_python_module_begin(state) {
            try {
                initialize(state);
            } except BaseException {
                jacpy_dict_clear(state.value);
                raise;
            }
        }
    } finally {
        __jac_python_result(jacpy_special_noargs(lock.value, "release"));
    }
}
