import from c {
    def _PySysRemoteDebug_SendExec(pid: i32, tid: i32, path: ptr[u8]) -> i32 {
        PyErr_SetString(
            PyExc_RuntimeError,
            ptr[u8]("Remote debugging support has not been compiled in")
        );
        return i32(-1);
    }
}
