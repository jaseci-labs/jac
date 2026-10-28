import from "<libpy>" {
    def PyGILState_Ensure -> int;  def PyGILState_Release(state: int) -> None;  def PyObject_CallOneArg(
        fn: int, arg: int
    ) -> int;  def PyUnicode_FromString(s: str) -> int;  def PyUnicode_AsUTF8(
        pyobj: int
    ) -> str;  def Py_DecRef(pyobj: int) -> None;  def PyRun_SimpleString(
        cmd: str
    ) -> i32;
}

glob _PH_DISPATCH: int = 0;

def _jac_invoke_handler(id: int, req: int, wv_handle: int);

def _stash_wv_in_python(h: int);
