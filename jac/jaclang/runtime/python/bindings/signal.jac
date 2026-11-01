glob:priv SIGNAL_MODULE_STATE_SIZE: Final[i64] = 32,
     INTERNAL: list[str] = [
         "SA_RESTART",
         "SA_NODEFER",
         "SA_ONSTACK",
         "EINTR",
         "EAGAIN",
         "EWOULDBLOCK",
         "RLIMIT_CORE"
     ],
     METHOD_ORDER: list[str] = [
         "default_int_handler",
         "alarm",
         "setitimer",
         "getitimer",
         "signal",
         "raise_signal",
         "strsignal",
         "getsignal",
         "set_wakeup_fd",
         "siginterrupt",
         "pause",
         "pidfd_send_signal",
         "pthread_kill",
         "pthread_sigmask",
         "sigpending",
         "sigwait",
         "sigwaitinfo",
         "sigtimedwait",
         "valid_signals"
     ];

def:priv signal_module_exec(m: ptr[PyObject]) -> i32;

import from c {
    glob:priv struct_siginfo_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("si_signo"), doc=ptr[u8]("signal number")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("si_code"), doc=ptr[u8]("signal code")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("si_errno"),
                 doc=ptr[u8]("errno associated with this signal")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("si_pid"), doc=ptr[u8]("sending process ID")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("si_uid"), doc=ptr[u8]("real user ID of sending process")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("si_status"), doc=ptr[u8]("exit value or signal")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("si_band"), doc=ptr[u8]("band event for SIGPOLL")
             ),
             PyStructSequence_Field(name=ptr[u8](), doc=ptr[u8]())
         ],
         struct_siginfo_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("signal.struct_siginfo"),
             doc=ptr[u8](
                 "struct_siginfo: Result from sigwaitinfo or sigtimedwait.\n\nThis object may be accessed either as a tuple of\n(si_signo, si_code, si_errno, si_pid, si_uid, si_status, si_band),\nor via the attributes si_signo, si_code, and so on."
             ),
             fields=addressof(struct_siginfo_fields),
             n_in_sequence=7
         ),
         signal_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(signal_module_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         signal_module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_signal"),
             m_doc=ptr[u8](
                 "This module provides mechanisms to use signal handlers in Python.\n\nFunctions:\n\nalarm() -- cause SIGALRM after a specified time [Unix only]\nsetitimer() -- cause a signal (described below) after a specified\n               float time and the timer may restart then [Unix only]\ngetitimer() -- get current value of timer [Unix only]\nsignal() -- set the action for a given signal\ngetsignal() -- get the signal action for a given signal\npause() -- wait until a signal arrives [Unix only]\ndefault_int_handler() -- default SIGINT handler\n\nsignal constants:\nSIG_DFL -- used to refer to the system default handler\nSIG_IGN -- used to ignore the signal\nNSIG -- number of defined signals\nSIGINT, SIGTERM, etc. -- signal numbers\n\nitimer constants:\nITIMER_REAL -- decrements in real time, and delivers SIGALRM upon\n               expiration\nITIMER_VIRTUAL -- decrements only when the process is executing,\n               and delivers SIGVTALRM upon expiration\nITIMER_PROF -- decrements both when the process is executing and\n               when the system is executing on behalf of the process.\n               Coupled with ITIMER_VIRTUAL, this timer is usually\n               used to profile the time spent by the application\n               in user and kernel space. SIGPROF is delivered upon\n               expiration.\n\n\n*** IMPORTANT NOTICE ***\nA signal handler function is called with two arguments:\nthe first is the signal number, the second is the interrupted stack frame."
             ),
             m_size=SIGNAL_MODULE_STATE_SIZE,
             m_methods=ptr[PyMethodDef](),
             m_slots=addressof(signal_slots)
         );
}

def:priv methods -> list[MethodDefinition];

def:priv signal_add_constants(module: ptr[PyObject]) -> i32;

def:priv signal_get_set_handlers(mod_dict: ptr[PyObject]) -> i32;

impl signal_module_exec(m: ptr[PyObject]) -> i32 {
    modstate = get_signal_state(m).view(1);

    modstate[0].default_handler = default_handler();
    modstate[0].ignore_handler = ignore_handler();

    itimer_error = PyErr_NewException(
        ptr[u8]("signal.ItimerError"), PyExc_OSError, NULL
    );
    modstate[0].itimer_error = itimer_error;
    if not itimer_error {
        return i32(-1);
    }

    if signal_add_constants(m) < 0 {
        return i32(-1);
    }

    d = PyModule_GetDict(m);
    if PyDict_SetItemString(d, ptr[u8]("SIG_DFL"), default_handler()) < 0 {
        return i32(-1);
    }
    if PyDict_SetItemString(d, ptr[u8]("SIG_IGN"), ignore_handler()) < 0 {
        return i32(-1);
    }
    if PyDict_SetItemString(d, ptr[u8]("ItimerError"), itimer_error) < 0 {
        return i32(-1);
    }

    if HAS_SIGWAITINFO or HAS_SIGTIMEDWAIT {
        siginfo_type = PyStructSequence_NewType(addressof(struct_siginfo_desc));
        modstate[0].siginfo_type = ptr[PyTypeObject](siginfo_type);
        if not siginfo_type {
            return i32(-1);
        }
        if PyModule_AddType(m, siginfo_type) < 0 {
            return i32(-1);
        }
    }

    if is_main_interpreter(tstate_interp(current_tstate())) {
        if signal_get_set_handlers(d) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

def:priv signal_module_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def:priv signal_module_clear(module: ptr[PyObject]) -> i32;

def:priv signal_module_free(module: ptr);

def:pub PyInit__signal -> ptr[PyObject];

impl methods -> list[MethodDefinition] {
    selected: list[MethodDefinition] = [];
    for name in METHOD_ORDER {
        if (name == "sigwaitinfo" and not HAS_SIGWAITINFO)
            or (name == "sigtimedwait" and not HAS_SIGTIMEDWAIT)
            or (name == "pidfd_send_signal" and not HAS_PIDFD_SEND_SIGNAL) {
            continue;
        }
        for method in module_methods {
            if method.name == name {
                selected.append(method);
            }
        }
    }
    return selected;
}

impl signal_add_constants(module: ptr[PyObject]) -> i32 {
    if PyModule_AddIntConstant(module, ptr[u8]("NSIG"), Py_NSIG) < 0 {
        return i32(-1);
    }
    for (name, value) in CONSTANTS {
        if name in INTERNAL {
            continue;
        }
        if jacpy_module_add_int_text(module, name, value) < 0 {
            return i32(-1);
        }

        if name == "SIGXFSZ" and HAS_RT_SIGNALS {
            if PyModule_AddIntConstant(module, ptr[u8]("SIGRTMIN"), sigrtmin()) < 0
                or PyModule_AddIntConstant(module, ptr[u8]("SIGRTMAX"), sigrtmax())
                    < 0 {
                return i32(-1);
            }
        }
    }
    return i32(0);
}

impl signal_get_set_handlers(mod_dict: ptr[PyObject]) -> i32 {
    signum = i32(1);
    while i64(signum) < Py_NSIG {
        c_handler = int(PyOS_getsig(signum));
        func = Py_None;
        if c_handler == 0 {
            func = default_handler();
        } elif c_handler == 1 {
            func = ignore_handler();
        }

        old_func = get_handler(signum);
        set_handler(signum, object_new_ref(func));
        object_xdecref(old_func);
        signum += 1;
    }

    sigint_func = get_handler(i32(SIGINT));
    if sigint_func == default_handler() {
        int_handler = PyMapping_GetItemString(mod_dict, ptr[u8]("default_int_handler"));
        if not int_handler {
            return i32(-1);
        }
        set_handler(i32(SIGINT), int_handler);
        object_decref(sigint_func);
        PyOS_setsig(i32(SIGINT), ptr(signal_handler));
    }
    return i32(0);
}

impl signal_module_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    state = get_signal_state(module).view(1);
    status = visit_reference(state[0].itimer_error, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(ptr[PyObject](state[0].siginfo_type), visitor, arg);
}

impl signal_module_clear(module: ptr[PyObject]) -> i32 {
    state = get_signal_state(module).view(1);
    itimer_error = state[0].itimer_error;
    state[0].itimer_error = NULL;
    object_xdecref(itimer_error);
    siginfo_type = ptr[PyObject](state[0].siginfo_type);
    state[0].siginfo_type = ptr[PyTypeObject]();
    object_xdecref(siginfo_type);
    return i32(0);
}

impl signal_module_free(module: ptr) {
    signal_module_clear(ptr[PyObject](module));
}

impl PyInit__signal -> ptr[PyObject] {
    definition = addressof(signal_module).view(1);
    if not definition[0].m_methods {
        table = method_table(methods());
        if not table {
            return NULL;
        }
        definition[0].m_traverse = int(ptr(signal_module_traverse));
        definition[0].m_clear = int(ptr(signal_module_clear));
        definition[0].m_free = int(ptr(signal_module_free));
        definition[0].m_methods = table;
    }
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(signal_module)));
}
