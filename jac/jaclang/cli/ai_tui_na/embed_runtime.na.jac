"""EmbedRuntime — sole native owner of CPython C-API refs and GIL transitions.

PLAN.md §5.4 / Phase 4. No other ai_tui_na module may import jacpyembed.
"""

import from .embed_models {
    EmbedResult,
    BindResult,
    EmbedCallResult,
    FinalizeResult
}

import from jacpyembed {
    def jac_engine_boot -> i32;
    def jpy_Py_Finalize -> None;
    def jpy_PyRun_SimpleString(cmd: str) -> i32;
    def jpy_PyImport_AddModule(name: str) -> int;
    def jpy_PyModule_GetDict(module: int) -> int;
    def jpy_PyRun_String(s: str, start: i32, g: int, l: int) -> int;
    def jpy_PyEval_SaveThread -> int;
    def jpy_PyEval_RestoreThread(s: int) -> None;
    def jpy_PyObject_CallNoArgs(fn: int) -> int;
    def jpy_PyObject_CallOneArg(fn: int, arg: int) -> int;
    def jpy_PyUnicode_FromString(s: str) -> int;
    def jpy_PyUnicode_AsUTF8(pyobj: int) -> str;
    def jpy_Py_DecRef(pyobj: int) -> None;
}

glob PY_EVAL: i32 = 258,
     _BOOTSTRAP_TYPED: str = (
         "from jaclang.cli.ai_tui.embed_agent import "
         "start as _agent_start, submit as _agent_submit, "
         "poll as _agent_poll, snapshot as _agent_snapshot, "
         "dispose as _agent_dispose\n"
     );


obj EmbedRuntime {
    has booted: bool = False,
        bound: bool = False,
        released: bool = False,
        finalized: bool = False,
        gil_released: bool = False,
        workers_safe: bool = False,
        _main_dict: int = 0,
        _ts: int = 0,
        _fn_start: int = 0,
        _fn_submit: int = 0,
        _fn_poll: int = 0,
        _fn_snapshot: int = 0,
        _fn_dispose: int = 0;

    def boot -> EmbedResult {
        if self.finalized {
            return EmbedResult(ok=False, error="already finalized");
        }
        if self.booted {
            return EmbedResult(ok=True);
        }
        engine_rc: i32 = jac_engine_boot();
        if engine_rc != 0 {
            return EmbedResult(ok=False, error="jac_engine_boot failed");
        }
        bootstrap_rc: i32 = jpy_PyRun_SimpleString(_BOOTSTRAP_TYPED);
        if bootstrap_rc != 0 {
            return EmbedResult(ok=False, error="bootstrap import failed");
        }
        main_mod: int = jpy_PyImport_AddModule("__main__");
        if main_mod == 0 {
            return EmbedResult(ok=False, error="PyImport_AddModule(__main__) failed");
        }
        self._main_dict = jpy_PyModule_GetDict(main_mod);
        if self._main_dict == 0 {
            return EmbedResult(ok=False, error="PyModule_GetDict failed");
        }
        self.booted = True;
        return EmbedResult(ok=True);
    }

    def bind -> BindResult {
        if self.released or self.finalized {
            return BindResult(ok=False, error="runtime released/finalized");
        }
        if not self.booted {
            return BindResult(ok=False, error="not booted");
        }
        if self.bound {
            return BindResult(ok=True);
        }
        self._fn_start = self._eval_name("_agent_start");
        self._fn_submit = self._eval_name("_agent_submit");
        self._fn_poll = self._eval_name("_agent_poll");
        self._fn_snapshot = self._eval_name("_agent_snapshot");
        self._fn_dispose = self._eval_name("_agent_dispose");
        if (
            self._fn_start == 0
            or self._fn_submit == 0
            or self._fn_poll == 0
            or self._fn_snapshot == 0
            or self._fn_dispose == 0
        ) {
            self.release();
            return BindResult(ok=False, error="bind callable lookup failed");
        }
        self.bound = True;
        # After bind, release the GIL for the native loop; each call_* reacquires.
        self._release_gil();
        return BindResult(ok=True);
    }

    def call_start(request: str) -> EmbedCallResult {
        return self._call_one(self._fn_start, request);
    }

    def call_submit(command: str) -> EmbedCallResult {
        return self._call_one(self._fn_submit, command);
    }

    def call_poll(cap: int) -> EmbedCallResult {
        return self._call_one(self._fn_poll, str(cap));
    }

    def call_snapshot -> EmbedCallResult {
        return self._call_zero(self._fn_snapshot);
    }

    def call_dispose(spec: str) -> EmbedCallResult {
        # Managed dispose accepts one JSON dispose_spec string (no multi-arg C-API).
        return self._call_one(self._fn_dispose, spec);
    }

    def run_without_gil {
        # Loop tty waits run with GIL already released after bind.
        # No-op placeholder so callers document intent.
        return;
    }

    def mark_workers_safe(ok: bool) {
        self.workers_safe = ok;
    }

    def release {
        if self.released {
            return;
        }
        self._acquire_gil();
        self._fn_start = self._decref(self._fn_start);
        self._fn_submit = self._decref(self._fn_submit);
        self._fn_poll = self._decref(self._fn_poll);
        self._fn_snapshot = self._decref(self._fn_snapshot);
        self._fn_dispose = self._decref(self._fn_dispose);
        self._main_dict = 0;
        self.bound = False;
        self.released = True;
        self._release_gil();
    }

    def finalize_if_safe -> FinalizeResult {
        if self.finalized {
            return FinalizeResult(finalized=False, skipped=True, reason="already finalized");
        }
        if not self.workers_safe {
            return FinalizeResult(
                finalized=False, skipped=True, reason="workers not quiesced"
            );
        }
        self._acquire_gil();
        if not self.released {
            self._fn_start = self._decref(self._fn_start);
            self._fn_submit = self._decref(self._fn_submit);
            self._fn_poll = self._decref(self._fn_poll);
            self._fn_snapshot = self._decref(self._fn_snapshot);
            self._fn_dispose = self._decref(self._fn_dispose);
            self.released = True;
            self.bound = False;
        }
        jpy_Py_Finalize();
        self.finalized = True;
        self.gil_released = False;
        self._ts = 0;
        return FinalizeResult(finalized=True, skipped=False, reason="ok");
    }

    def force_finalize_unsafe {
        # Partial-startup / fatal paths only.
        if self.finalized {
            return;
        }
        self._acquire_gil();
        jpy_Py_Finalize();
        self.finalized = True;
        self.gil_released = False;
        self._ts = 0;
    }

    def _eval_name(name: str) -> int {
        if self._main_dict == 0 {
            return 0;
        }
        return jpy_PyRun_String(name, PY_EVAL, self._main_dict, self._main_dict);
    }

    def _call_zero(fn: int) -> EmbedCallResult {
        if fn == 0 or self.finalized {
            return EmbedCallResult(ok=False, error="callable unbound");
        }
        self._acquire_gil();
        pyobj: int = 0;
        try {
            pyobj = jpy_PyObject_CallNoArgs(fn);
            if pyobj == 0 {
                return EmbedCallResult(ok=False, error="python_exc");
            }
            out: str = jpy_PyUnicode_AsUTF8(pyobj);
            return EmbedCallResult(ok=True, value=out);
        } finally {
            if pyobj != 0 {
                jpy_Py_DecRef(pyobj);
            }
            self._release_gil();
        }
    }

    def _call_one(fn: int, arg_s: str) -> EmbedCallResult {
        if fn == 0 or self.finalized {
            return EmbedCallResult(ok=False, error="callable unbound");
        }
        self._acquire_gil();
        arg: int = 0;
        pyobj: int = 0;
        try {
            arg = jpy_PyUnicode_FromString(arg_s);
            if arg == 0 {
                return EmbedCallResult(ok=False, error="unicode_from_string failed");
            }
            pyobj = jpy_PyObject_CallOneArg(fn, arg);
            if pyobj == 0 {
                return EmbedCallResult(ok=False, error="python_exc");
            }
            out: str = jpy_PyUnicode_AsUTF8(pyobj);
            return EmbedCallResult(ok=True, value=out);
        } finally {
            if pyobj != 0 {
                jpy_Py_DecRef(pyobj);
            }
            if arg != 0 {
                jpy_Py_DecRef(arg);
            }
            self._release_gil();
        }
    }

    def _decref(handle: int) -> int {
        if handle != 0 {
            jpy_Py_DecRef(handle);
        }
        return 0;
    }

    def _release_gil {
        if not self.gil_released and self.booted and not self.finalized {
            self._ts = jpy_PyEval_SaveThread();
            self.gil_released = True;
        }
    }

    def _acquire_gil {
        if self.gil_released {
            jpy_PyEval_RestoreThread(self._ts);
            self.gil_released = False;
            self._ts = 0;
        }
    }
}
