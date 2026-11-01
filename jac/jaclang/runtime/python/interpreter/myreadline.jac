import from c {
    def fgets(buf: ptr[u8], size: i32, stream: ptr) -> ptr[u8];  def feof(
        stream: ptr
    ) -> i32;  def clearerr(stream: ptr);  def fflush(stream: ptr) -> i32;  def fputs(
        text: ptr[u8], stream: ptr
    ) -> i32;  def fileno(stream: ptr) -> i32;  def isatty(fd: i32) -> i32;  def strlen(
        text: ptr[u8]
    ) -> u64;  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def jacpy_stdio_stream(
        stream: i32
    ) -> ptr;  def _PyOS_InterruptOccurred(tstate: ptr[PyThreadState]) -> i32;  obj InputHook {
        has hook: Callable[[], i32] = 0;
    }  obj ReadlineFunction {
        has call: Callable[[ptr, ptr, ptr[u8]], ptr[u8]] = 0;
    }  obj ReadlineLock {
        has bits: u8 = 0;
    }  glob _PyOS_ReadlineTState: ptr[PyThreadState] = ptr[PyThreadState](),
         PyOS_InputHook: InputHook = InputHook(),
         PyOS_ReadlineFunctionPointer: ReadlineFunction = ReadlineFunction(); glob:priv _PyOS_ReadlineLock:
             ReadlineLock = ReadlineLock();
}

glob:priv READLINE_INT_MAX: i64 = 2147483647;

def:priv readline_tstate_address -> int;

def:priv is_main_interpreter(tstate: ptr[PyThreadState]) -> bool;

def:priv my_fgets(tstate: ptr[PyThreadState], buf: ptr[u8], size: i32, fp: ptr) -> i32;

import from c {
    def PyOS_StdioReadline(
        sys_stdin: ptr, sys_stdout: ptr, prompt: ptr[u8]
    ) -> ptr[u8] {
        tstate = _PyOS_ReadlineTState;

        fflush(sys_stdout);
        if prompt {
            fputs(prompt, jacpy_stdio_stream(2));
        }
        fflush(jacpy_stdio_stream(2));

        n: i64 = 0;
        p = ptr[u8]();
        while True {
            incr: i64 = 100;
            if n > 0 {
                incr = n + 2;
            }
            if incr > READLINE_INT_MAX {
                PyMem_RawFree(ptr(p));
                PyEval_RestoreThread(tstate);
                PyErr_SetString(PyExc_OverflowError, ptr[u8]("input line too long"));
                PyEval_SaveThread();
                return ptr[u8]();
            }
            pr = ptr[u8](PyMem_RawRealloc(ptr(p), u64(n + incr)));
            if not pr {
                PyMem_RawFree(ptr(p));
                PyEval_RestoreThread(tstate);
                PyErr_NoMemory();
                PyEval_SaveThread();
                return ptr[u8]();
            }
            p = pr;
            err = my_fgets(tstate, p + n, i32(incr), sys_stdin);
            if err == 1 {
                PyMem_RawFree(ptr(p));
                return ptr[u8]();
            } elif err != 0 {
                (p + n).view(1)[0] = u8(0);
                break;
            }
            n += i64(strlen(p + n));
            if n != 0 and (p + (n - 1)).view(1)[0] == u8(10) {
                break;
            }
        }

        pr = ptr[u8](PyMem_RawRealloc(ptr(p), u64(n + 1)));
        if not pr {
            PyMem_RawFree(ptr(p));
            PyEval_RestoreThread(tstate);
            PyErr_NoMemory();
            PyEval_SaveThread();
            return ptr[u8]();
        }
        return pr;
    }  def PyOS_Readline(sys_stdin: ptr, sys_stdout: ptr, prompt: ptr[u8]) -> ptr[u8] {
        tstate = current_tstate();
        if __atomic_load_i64(readline_tstate_address(), 0) == i64(int(tstate)) {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("can't re-enter readline"));
            return ptr[u8]();
        }

        save = PyEval_SaveThread();
        lock = ptr[PyMutex](addressof(_PyOS_ReadlineLock));
        PyMutex_Lock(lock);
        __atomic_store_i64(readline_tstate_address(), i64(int(tstate)), 0);
        function = addressof(PyOS_ReadlineFunctionPointer);
        if int(function.view(1)[0].call) == 0 {
            function.view(1)[0].call = PyOS_StdioReadline;
        }

        rv = ptr[u8]();
        if isatty(fileno(sys_stdin)) == 0
            or isatty(fileno(sys_stdout)) == 0
            or not is_main_interpreter(tstate) {
            rv = PyOS_StdioReadline(sys_stdin, sys_stdout, prompt);
        } else {
            rv = function.view(1)[0].call(sys_stdin, sys_stdout, prompt);
        }

        __atomic_store_i64(readline_tstate_address(), i64(0), 0);
        PyMutex_Unlock(lock);
        PyEval_RestoreThread(save);

        if not rv {
            return ptr[u8]();
        }

        length = strlen(rv) + 1;
        res = ptr[u8](PyMem_Malloc(length));
        if res {
            memcpy(ptr(res), ptr(rv), length);
        } else {
            PyErr_NoMemory();
        }
        PyMem_RawFree(ptr(rv));

        return res;
    }
}

impl readline_tstate_address -> int {
    return int(addressof(_PyOS_ReadlineTState));
}

impl is_main_interpreter(tstate: ptr[PyThreadState]) -> bool {
    interp = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
    return int(interp) == int(_PyInterpreterState_Main());
}

impl my_fgets(tstate: ptr[PyThreadState], buf: ptr[u8], size: i32, fp: ptr) -> i32 {
    while True {
        hook = addressof(PyOS_InputHook);

        if int(hook.view(1)[0].hook) != 0 and is_main_interpreter(tstate) {
            hook.view(1)[0].hook();
        }

        jacpy_set_errno(0);
        clearerr(fp);
        p = fgets(buf, size, fp);
        if p {
            return 0;
        }
        err = jacpy_errno();

        if feof(fp) != 0 {
            clearerr(fp);
            return -1;
        }

        if err == i64(EINTR) {
            PyEval_RestoreThread(tstate);
            s = PyErr_CheckSignals();
            PyEval_SaveThread();

            if s < 0 {
                return 1;
            }

            continue;
        }

        if _PyOS_InterruptOccurred(tstate) != 0 {
            return 1;
        }
        return -2;
    }
    return -2;
}
