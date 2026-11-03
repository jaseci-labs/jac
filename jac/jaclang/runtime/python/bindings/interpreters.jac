import from c {
    glob:priv module_functions: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("new_config"),
                 ml_meth=ptr(interp_new_config),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "new_config(name='isolated', /, **overrides) -> type.SimpleNamespace\n\nReturn a representation of a new PyInterpreterConfig.\n\nThe name determines the initial values of the config.  Supported named\nconfigs are: default, isolated, legacy, and empty.\n\nAny keyword arguments are set on the corresponding config fields,\noverriding the initial values."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("create"),
                 ml_meth=ptr(interp_create),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "create([config], *, reqrefs=False) -> ID\n\nCreate a new interpreter and return a unique generated ID.\n\nThe caller is responsible for destroying the interpreter before exiting,\ntypically by using _interpreters.destroy().  This can be managed \nautomatically by passing \"reqrefs=True\" and then using _incref() and\n_decref() appropriately.\n\n\"config\" must be a valid interpreter config or the name of a\npredefined config (\"isolated\" or \"legacy\").  The default\nis \"isolated\"."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("destroy"),
                 ml_meth=ptr(interp_destroy),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "destroy(id, *, restrict=False)\n\nDestroy the identified interpreter.\n\nAttempting to destroy the current interpreter raises InterpreterError.\nSo does an unrecognized ID."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("list_all"),
                 ml_meth=ptr(interp_list_all),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "list_all() -> [(ID, whence)]\n\nReturn a list containing the ID of every existing interpreter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_current"),
                 ml_meth=ptr(interp_get_current),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_current() -> (ID, whence)\n\nReturn the ID of current interpreter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_main"),
                 ml_meth=ptr(interp_get_main),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_main() -> (ID, whence)\n\nReturn the ID of main interpreter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_running"),
                 ml_meth=ptr(interp_is_running),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "is_running(id, *, restrict=False) -> bool\n\nReturn whether or not the identified interpreter is running."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_config"),
                 ml_meth=ptr(interp_get_config),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "get_config(id, *, restrict=False) -> types.SimpleNamespace\n\nReturn a representation of the config used to initialize the interpreter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("whence"),
                 ml_meth=ptr(interp_whence),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "whence(id) -> int\n\nReturn an identifier for where the interpreter was created."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("exec"),
                 ml_meth=ptr(interp_exec),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "exec(id, code, shared=None, *, restrict=False)\n\nExecute the provided code in the identified interpreter.\nThis is equivalent to running the builtin exec() under the target\ninterpreter, using the __dict__ of its __main__ module as both\nglobals and locals.\n\n\"code\" may be a string containing the text of a Python script.\n\nFunctions (and code objects) are also supported, with some restrictions.\nThe code/function must not take any arguments or be a closure\n(i.e. have cell vars).  Methods and other callables are not supported.\n\nIf a function is provided, its code object is used and all its state\nis ignored, including its __globals__ dict."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("call"),
                 ml_meth=ptr(interp_call),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "call(id, callable, args=None, kwargs=None, *, restrict=False)\n\nCall the provided object in the identified interpreter.\nPass the given args and kwargs, if possible."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("run_string"),
                 ml_meth=ptr(interp_run_string),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "run_string(id, script, shared=None, *, restrict=False)\n\nExecute the provided string in the identified interpreter.\n\n(See _interpreters.exec()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("run_func"),
                 ml_meth=ptr(interp_run_func),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "run_func(id, func, shared=None, *, restrict=False)\n\nExecute the body of the provided function in the identified interpreter.\nCode objects are also supported.  In both cases, closures and args\nare not supported.  Methods and other callables are not supported either.\n\n(See _interpreters.exec()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set___main___attrs"),
                 ml_meth=ptr(interp_set___main___attrs),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "set___main___attrs(id, ns, *, restrict=False)\n\nBind the given attributes in the interpreter's __main__ module."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("incref"),
                 ml_meth=ptr(interp_incref),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("decref"),
                 ml_meth=ptr(interp_decref),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_shareable"),
                 ml_meth=ptr(object_is_shareable),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "is_shareable(obj) -> bool\n\nReturn True if the object's data may be shared between interpreters and\nFalse otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("capture_exception"),
                 ml_meth=ptr(capture_exception),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "capture_exception(exc=None) -> types.SimpleNamespace\n\nReturn a snapshot of an exception.  If \"exc\" is None\nthen the current exception, if any, is used (but not cleared).\n\nThe returned snapshot is the same as what _interpreters.exec() returns."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         module_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(module_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         moduledef: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_interpreters"),
             m_doc=ptr[u8](
                 "This module provides primitive operations to manage Python interpreters.\nThe 'interpreters' module provides a more convenient interface."
             ),
             m_size=16,
             m_methods=addressof(module_functions),
             m_slots=addressof(module_slots),
             m_traverse=module_traverse,
             m_clear=module_clear,
             m_free=module_free
         );
}

def:pub PyInit__interpreters -> ptr[PyObject];

impl PyInit__interpreters -> ptr[PyObject] {
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(moduledef)));
}
