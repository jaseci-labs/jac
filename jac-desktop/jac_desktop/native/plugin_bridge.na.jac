"""Native shim bridging webview callbacks into the CPython plugin host.

This is the only new native file. It sits in nacompile alongside webview.na.jac
and the generated host.na.jac. ~20 lines that handle:
  - inttoptr coercion (C string pointer -> Jac str)
  - GIL management (PyGILState_Ensure / Release)
  - CPython function call (PyObject_CallOneArg)
  - webview_return with the result

The free function pattern (not a bound method) is confirmed by test_binding.jac.
"""
import from webview { Webview, respond }

import from "<libpy>" {
    def PyGILState_Ensure -> int;  def PyGILState_Release(state: int) -> None;  def PyObject_CallOneArg(
        fn: int, arg: int
    ) -> int;  def PyUnicode_FromString(s: str) -> int;  def PyUnicode_AsUTF8(
        pyobj: int
    ) -> str;  def Py_DecRef(pyobj: int) -> None;
}

# PyObject* to plugin_host.dispatch, set during CPython bootstrap
glob _PH_DISPATCH: int = 0;

def _jac_invoke_handler(id: int, req: int, wv_handle: int) {
    req_str: str = req;  # inttoptr i64 -> i8*, valid for callback lifetime
    gstate = PyGILState_Ensure();
    py_req = PyUnicode_FromString(req_str);
    py_result = PyObject_CallOneArg(_PH_DISPATCH, py_req);
    result_str = PyUnicode_AsUTF8(py_result);
    Py_DecRef(py_req);
    Py_DecRef(py_result);
    PyGILState_Release(gstate);
    respond(wv_handle, id, result_str);
}
