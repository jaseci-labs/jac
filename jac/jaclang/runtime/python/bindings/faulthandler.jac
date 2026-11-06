import from c {
    glob:priv module_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("enable"),
                 ml_meth=ptr(faulthandler_py_enable),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "enable($module, /, file=sys.stderr, all_threads=True)\n--\n\nEnable the fault handler."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("disable"),
                 ml_meth=ptr(faulthandler_disable_py),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("disable($module, /)\n--\n\nDisable the fault handler.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_enabled"),
                 ml_meth=ptr(faulthandler_is_enabled),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_enabled($module, /)\n--\n\nCheck if the handler is enabled."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("dump_traceback"),
                 ml_meth=ptr(faulthandler_dump_traceback_py),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "dump_traceback($module, /, file=sys.stderr, all_threads=True)\n--\n\nDump the traceback of the current thread, or of all threads if all_threads is True, into file."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("dump_c_stack"),
                 ml_meth=ptr(faulthandler_dump_c_stack_py),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "dump_c_stack($module, /, file=sys.stderr)\n--\n\nDump the C stack of the current thread."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("dump_traceback_later"),
                 ml_meth=ptr(faulthandler_dump_traceback_later),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "dump_traceback_later($module, /, timeout, repeat=False, file=sys.stderr, exit=False)\n--\n\nDump the traceback of all threads in timeout seconds,\nor each timeout seconds if repeat is True. If exit is True, call _exit(1) which is not safe."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("cancel_dump_traceback_later"),
                 ml_meth=ptr(faulthandler_cancel_dump_traceback_later_py),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "cancel_dump_traceback_later($module, /)\n--\n\nCancel the previous call to dump_traceback_later()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("register"),
                 ml_meth=ptr(faulthandler_register_py),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "register($module, /, signum, file=sys.stderr, all_threads=True, chain=False)\n--\n\nRegister a handler for the signal 'signum': dump the traceback of the current thread, or of all threads if all_threads is True, into file."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("unregister"),
                 ml_meth=ptr(faulthandler_unregister_py),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "unregister($module, signum, /)\n--\n\nUnregister the handler of the signal 'signum' registered by register()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_read_null"),
                 ml_meth=ptr(faulthandler_read_null),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_read_null($module, /)\n--\n\nRead from NULL, raise a SIGSEGV or SIGBUS signal depending on the platform."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_sigsegv"),
                 ml_meth=ptr(faulthandler_sigsegv),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "_sigsegv($module, release_gil=False, /)\n--\n\nRaise a SIGSEGV signal."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_fatal_error_c_thread"),
                 ml_meth=ptr(faulthandler_fatal_error_c_thread),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_fatal_error_c_thread($module, /)\n--\n\nCall Py_FatalError() in a new C thread."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_sigabrt"),
                 ml_meth=ptr(faulthandler_sigabrt),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("_sigabrt($module, /)\n--\n\nRaise a SIGABRT signal.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_sigfpe"),
                 ml_meth=ptr(faulthandler_sigfpe),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("_sigfpe($module, /)\n--\n\nRaise a SIGFPE signal.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_stack_overflow"),
                 ml_meth=ptr(faulthandler_stack_overflow),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_stack_overflow($module, /)\n--\n\nRecursive call to raise a stack overflow."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         faulthandler_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(PyExec_faulthandler)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         module_def: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("faulthandler"),
             m_doc=ptr[u8]("faulthandler module."),
             m_size=0,
             m_methods=addressof(module_methods),
             m_slots=addressof(faulthandler_slots)
         );
}

def:pub PyInit_faulthandler -> ptr[PyObject];

impl PyInit_faulthandler -> ptr[PyObject] {
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(module_def)));
}
