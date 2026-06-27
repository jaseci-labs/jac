import from webview { Webview, respond }

import from "<libpy>" {
    def PyGILState_Ensure -> int;  def PyGILState_Release(state: int) -> None;  def PyObject_CallOneArg(
        fn: int, arg: int
    ) -> int;  def PyUnicode_FromString(s: str) -> int;  def PyUnicode_AsUTF8(
        pyobj: int
    ) -> str;  def Py_DecRef(pyobj: int) -> None;
}

glob _PH_DISPATCH: int = 0;

def _jac_invoke_handler(id: int, req: int, wv_handle: int) {
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

def _stash_wv_in_python(h: int) {
    PyRun_SimpleString(f"_wv_handle = {h}");
    PyRun_SimpleString("_host.setup(_wv_handle)");
}
