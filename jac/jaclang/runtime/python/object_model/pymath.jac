import from c {
    def fegetenv(envp: ptr) -> i32;  def fesetenv(envp: ptr) -> i32;  def _Py_get_387controlword -> u16 {
        if HAVE_X87_CONTROL_WORD == 0 {
            return u16(0);
        }
        env = ptr[u16](__thread_local_block("jac_object_model_pymath_fenv", 64));
        fegetenv(ptr(env));
        return env.view(1)[0];
    }  def _Py_set_387controlword(cw: u16) {
        if HAVE_X87_CONTROL_WORD == 0 {
            return;
        }
        env = ptr[u16](__thread_local_block("jac_object_model_pymath_fenv", 64));
        fegetenv(ptr(env));
        env.view(1)[0] = cw;
        fesetenv(ptr(env));
    }
}
