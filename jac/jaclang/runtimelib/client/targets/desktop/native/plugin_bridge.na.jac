"""Reference source for the native plugin IPC shim (not compiled directly).

This file is **not** compiled by nacompile. The bridge is inlined into the
generated host source by ``_generate_host_source()`` in
``native_desktop_target.impl.jac``, extracted between the BRIDGE START /
BRIDGE END markers. This file is the single authoritative copy.

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

# --- BRIDGE START ---
glob _PH_DISPATCH: int = 0;

def _jac_invoke_handler(id: int, req: int, wv_handle: int) {
    gstate = PyGILState_Ensure();
    py_req = PyUnicode_FromString(req as str);  # inttoptr i64 -> i8*
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

# nacompile cannot lower wv.get_handle() inside an f-string for
# PyRun_SimpleString; passing the int through a native helper works.
def _stash_wv_in_python(h: int) {
    PyRun_SimpleString(f"_wv_handle = {h}");
    PyRun_SimpleString("_host.setup(_wv_handle)");
}
# --- BRIDGE END ---
