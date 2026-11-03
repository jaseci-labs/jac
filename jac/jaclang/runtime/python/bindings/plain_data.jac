"""Plain data across a native binding.

Plain data is None, bools, ints, floats, str, bytes, lists and str-keyed
dicts, nested to any depth. `native_value` reads a Python object of that shape
into native values (a tuple reads as a list), and `python_value` builds the
Python object for a native value of that shape. Anything else is a TypeError
on the Python side: a binding that takes richer objects converts them itself.
"""

def native_value(value: ptr[PyObject]) -> any;

def python_value(value: any) -> ptr[PyObject];

def:priv native_items(value: ptr[PyObject]) -> list[any];

def:priv native_entries(value: ptr[PyObject]) -> dict[str, any];

def:priv native_int(value: ptr[PyObject]) -> int;

def:priv python_list(items: list[any]) -> ptr[PyObject];

def:priv python_dict(entries: dict[str, any]) -> ptr[PyObject];

impl native_value(value: ptr[PyObject]) -> any {
    kind = builtin_kind_of(value);
    if kind == builtin_kind.NONE.value {
        return None;
    }
    if kind == builtin_kind.BOOL.value {
        return PyObject_IsTrue(value) == 1;
    }
    if kind == builtin_kind.INT.value {
        return native_int(value);
    }
    if kind == builtin_kind.FLOAT.value {
        number: float = PyFloat_AsDouble(value);
        return number;
    }
    if kind == builtin_kind.STR.value {
        return text_value(value);
    }
    if kind == builtin_kind.BYTES.value {
        return read_buffer(value);
    }
    if kind == builtin_kind.LIST.value or kind == builtin_kind.TUPLE.value {
        return native_items(value);
    }
    if kind == builtin_kind.DICT.value {
        return native_entries(value);
    }
    object_error(PyExc_TypeError, "not plain data: " + type_name(value));
    raise boundary_failure();
}

impl native_items(value: ptr[PyObject]) -> list[any] {
    items: list[any] = [];
    for index in range(int(jacpy_sequence_size(value))) {
        item = required(jacpy_sequence_item(value, i64(index)));
        try {
            items.append(native_value(item));
        } finally {
            jacpy_release(item);
        }
    }
    return items;
}

impl native_entries(value: ptr[PyObject]) -> dict[str, any] {
    entries: dict[str, any] = {};
    position: i64 = 0;
    key: ptr[PyObject] = NULL;
    item: ptr[PyObject] = NULL;
    while PyDict_Next(value, &mut position, &mut key, &mut item) != 0 {
        if builtin_kind_of(key) != builtin_kind.STR.value {
            object_error(
                PyExc_TypeError,
                "plain data dict keys must be str, not " + type_name(key)
            );
            raise boundary_failure();
        }
        entries[text_value(key)] = native_value(item);
    }
    return entries;
}

impl native_int(value: ptr[PyObject]) -> int {
    overflow: i32 = 0;
    number = PyLong_AsLongLongAndOverflow(value, &mut overflow);
    if overflow != 0 {
        object_error(PyExc_OverflowError, "plain data ints must fit in 64 bits");
        raise boundary_failure();
    }
    if number == -1 and PyErr_Occurred() {
        raise boundary_failure();
    }
    return int(number);
}

impl python_value(value: any) -> ptr[PyObject] {
    if value is None {
        return Py_NewRef(Py_None);
    }
    if isinstance(value, bool) {
        flag: bool = value;
        return required(PyBool_FromLong(1 if flag else 0));
    }
    if isinstance(value, int) {
        number: int = value;
        return required(PyLong_FromLongLong(i64(number)));
    }
    if isinstance(value, float) {
        real: float = value;
        return required(PyFloat_FromDouble(real));
    }
    if isinstance(value, str) {
        text: str = value;
        return text_object(text);
    }
    if isinstance(value, bytes) {
        data: bytes = value;
        return required(write_buffer(data));
    }
    if isinstance(value, list) {
        items: list[any] = value;
        return python_list(items);
    }
    if isinstance(value, dict) {
        entries: dict[str, any] = value;
        return python_dict(entries);
    }
    object_error(PyExc_TypeError, "a native value is not plain data");
    raise boundary_failure();
}

impl python_list(items: list[any]) -> ptr[PyObject] {
    result = required(PyList_New(0));
    try {
        for item in items {
            element = python_value(item);
            status = PyList_Append(result, element);
            jacpy_release(element);
            if status < 0 {
                raise boundary_failure();
            }
        }
    } except boundary_failure {
        jacpy_release(result);
        raise boundary_failure();
    }
    return result;
}

impl python_dict(entries: dict[str, any]) -> ptr[PyObject] {
    result = required(PyDict_New());
    try {
        for (name, item) in entries.items() {
            element = python_value(item);
            status = dict_set_text(result, name, element);
            jacpy_release(element);
            if status < 0 {
                raise boundary_failure();
            }
        }
    } except boundary_failure {
        jacpy_release(result);
        raise boundary_failure();
    }
    return result;
}
