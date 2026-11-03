impl CallbackAsker.ask(method: str, key: str) -> dict[str, any] {
    method_text = text_object(method);
    key_text = text_object(key);
    arguments = object_tuple([method_text, key_text]);
    jacpy_release(method_text);
    jacpy_release(key_text);
    answer = PyObject_CallObject(self.callback, arguments);
    jacpy_release(arguments);
    if not answer {
        raise RuntimeError(
            f"the host failed to answer {method} {key!r}: {take_error_text()}"
        );
    }
    try {
        record = native_value(answer);
    } except boundary_failure {
        raise RuntimeError(
            f"the host's answer to {method} {key!r} is not plain data: "
            f"{take_error_text()}"
        );
    } finally {
        jacpy_release(answer);
    }
    if not isinstance(record, dict) {
        raise RuntimeError(f"the host answered {method} {key!r} with a non-dict");
    }
    entries: dict[str, any] = record;
    return entries;
}

impl request_of(args: ptr[ptr[PyObject]], count: i64, function: str) -> KernelRequest {
    if count < 1 or count > 2 {
        object_error(
            PyExc_TypeError, f"{function}() takes a request and an optional asker"
        );
        raise boundary_failure();
    }
    raw = native_value(args.view(1)[0]);
    if not isinstance(raw, dict) {
        object_error(PyExc_TypeError, f"{function}() request must be a dict");
        raise boundary_failure();
    }
    fields: dict[str, any] = raw;
    try {
        return KernelRequest.from_dict(fields);
    } except Exception as err {
        object_error(PyExc_TypeError, f"{function}() request is malformed: {err}");
        raise boundary_failure();
    }
}

impl asker_of(args: ptr[ptr[PyObject]], count: i64) -> (HostAsker | None) {
    if count < 2 {
        return None;
    }
    callback = args.view(2)[1];
    if callback == Py_None {
        return None;
    }
    return CallbackAsker(callback=callback);
}

impl compile_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        request = request_of(args, count, "compile");
        outcome = CompileReport(analysis=AnalysisReport(entry_path=request.path));
        try {
            outcome = compile_request(request, asker_of(args, count));
        } except Exception as err {
            outcome.analysis.status = ANALYSIS_CRASHED;
            outcome.analysis.message = f"kernel compile raised: {err}";
        }
        return python_value(outcome.to_dict());
    } except boundary_failure {
        return NULL;
    }
}

impl check_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        request = request_of(args, count, "check");
        outcome = AnalysisReport(entry_path=request.path);
        try {
            outcome = check_request(request, asker_of(args, count));
        } except Exception as err {
            outcome.status = ANALYSIS_CRASHED;
            outcome.message = f"kernel analysis raised: {err}";
        }
        return python_value(outcome.to_dict());
    } except boundary_failure {
        return NULL;
    }
}

impl execute(module: ptr[PyObject]) -> i32 {
    return jacpy_module_add_int_text(module, "API_VERSION", i64(KERNEL_API_VERSION));
}

impl PyInit_jac_kernel -> ptr[PyObject] {
    return definition.initialize();
}
