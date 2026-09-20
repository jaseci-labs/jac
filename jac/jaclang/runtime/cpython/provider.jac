import from jaclang.runtime.cpython.references { ObjectRef, object_result }
import from jaclang.runtime.cpython.capi {
    PyThreadState_Get,
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
    jacpy_setitem,
    jacpy_getitem,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_retain,
    jacpy_truth,
    jacpy_integer_value,
    jacpy_float_value,
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

def __jac_python_dict -> __JacPythonValue {
    return __jac_python_result(jacpy_dict_new());
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


def __jac_python_matches(error: __JacPythonError, kind: __JacPythonValue) -> bool {
    return PyErr_GivenExceptionMatches(error.reference.value, kind.value) != 0;
}
