impl arguments(
    args: ptr[ptr[PyObject]], count: i64, function: str, wanted: int
) -> list[any] {
    if int(count) != wanted {
        object_error(
            PyExc_TypeError, f"{function}() takes {wanted} arguments, got {count}"
        );
        raise boundary_failure();
    }
    items = args.view(wanted);
    values: list[any] = [];
    for index in range(wanted) {
        values.append(native_value(items[index]));
    }
    return values;
}

impl record_of(value: any, function: str) -> dict[str, any] {
    if not isinstance(value, dict) {
        object_error(PyExc_TypeError, f"{function}() request must be a dict");
        raise boundary_failure();
    }
    record: dict[str, any] = value;
    return record;
}

impl answer(value: any) -> ptr[PyObject] {
    try {
        return python_value(value);
    } except boundary_failure {
        return NULL;
    }
}

impl compile_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        raw = record_of(arguments(args, count, "compile", 1)[0], "compile");
        return answer(compile_request(CompileRequest.from_dict(raw)).to_dict());
    } except boundary_failure {
        return NULL;
    } except KernelError as refused {
        object_error(PyExc_RuntimeError, str(refused));
        return NULL;
    }
}

impl check_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        raw = record_of(arguments(args, count, "check", 1)[0], "check");
        return answer(check_request(CheckRequest.from_dict(raw)).to_dict());
    } except boundary_failure {
        return NULL;
    } except KernelError as refused {
        object_error(PyExc_RuntimeError, str(refused));
        return NULL;
    }
}

impl open_session_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        values = arguments(args, count, "open_session", 3);
        session = open_session(
            str(values[0]), [str(path) for path in values[1]], str(values[2])
        );
        handle = _NEXT_SESSION[0];
        _NEXT_SESSION[0] = handle + 1;
        _SESSIONS[handle] = session;
        return answer(handle);
    } except boundary_failure {
        return NULL;
    } except KernelError as refused {
        object_error(PyExc_RuntimeError, str(refused));
        return NULL;
    }
}

impl session_of(handle: any) -> KernelSession {
    if not isinstance(handle, int) or handle not in _SESSIONS {
        object_error(PyExc_ValueError, f"no open kernel session {handle!r}");
        raise boundary_failure();
    }
    return _SESSIONS[handle];
}

impl session_query_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        values = arguments(args, count, "session_query", 3);
        session = session_of(values[0]);
        if not isinstance(values[2], list) {
            object_error(PyExc_TypeError, "session_query() args must be a list");
            raise boundary_failure();
        }
        query_args: list[any] = values[2];
        return answer(session_query(session, str(values[1]), query_args));
    } except boundary_failure {
        return NULL;
    } except KernelError as refused {
        object_error(PyExc_RuntimeError, str(refused));
        return NULL;
    }
}

impl close_session_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        values = arguments(args, count, "close_session", 1);
        session_of(values[0]);
        handle: int = values[0];
        del _SESSIONS[handle];
        return answer(None);
    } except boundary_failure {
        return NULL;
    }
}

impl execute(module: ptr[PyObject]) -> i32 {
    install_engine(KernelPython());
    return jacpy_module_add_int_text(module, "API_VERSION", i64(KERNEL_API_VERSION));
}

impl PyInit_jac_kernel -> ptr[PyObject] {
    return definition.initialize();
}
