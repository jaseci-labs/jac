impl set_host_callback(callback: int) {
    _ASK.callback = callback;
}

impl take_host_answer(text: str) {
    _ASK.answer = text;
}

impl ask_host(method: str, key: str) -> str {
    callback = _ASK.callback;
    if callback == 0 {
        return "";
    }
    _ASK.answer = "";
    args = PyTuple_New(2);
    PyTuple_SetItem(args, 0, PyUnicode_FromString(id(method)));
    PyTuple_SetItem(args, 1, PyUnicode_FromString(id(key)));
    result = PyObject_CallObject(callback, args);
    Py_DecRef(args);
    if result == 0 {
        PyErr_Clear();
        return "";
    }
    Py_DecRef(result);
    answer = _ASK.answer;
    _ASK.answer = "";
    return answer;
}
