impl _jac_invoke_handler(id: int, req: int, wv_handle: int) {
    gstate = PyGILState_Ensure();
    py_req = PyUnicode_FromString(req as str);
    py_result = PyObject_CallOneArg(_PH_DISPATCH, py_req);
    if py_result == 0 {
        Py_DecRef(py_req);
        PyGILState_Release(gstate);
        respond(
            wv_handle, id, "{\"ok\":false,\"error\":{\"code\":\"DISPATCH_CRASHED\"}}"
        );
        return;
    }
    result_str = PyUnicode_AsUTF8(py_result);
    Py_DecRef(py_req);
    respond(wv_handle, id, result_str);
    Py_DecRef(py_result);
    PyGILState_Release(gstate);
}

impl _stash_wv_in_python(h: int) {
    PyRun_SimpleString(f"_ctx.setup_webview({h})");
}
