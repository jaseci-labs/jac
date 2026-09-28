"""The atexit module: register, unregister and the private test hooks."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodDefinition,
    MethodCallbacks
}
import from jaclang.runtime.python.modules.atexit {
    atexit_clear,
    atexit_ncallbacks,
    atexit_register,
    atexit_run_exitfuncs,
    atexit_unregister
}

glob:priv METH_VARARGS_KEYWORDS: i64 = 3,
     METH_NOARGS: i64 = 4,
     METH_O: i64 = 8;

glob:priv definition = ModuleDefinition(
         "atexit",
         "allow programmer to define multiple exit functions to be executed\nupon normal program termination.\n\nTwo public functions, register and unregister, are defined.\n",
         [
             MethodDefinition(
                 "register",
                 MethodCallbacks(keywords=atexit_register),
                 "register($module, func, /, *args, **kwargs)\n--\n\nRegister a function to be executed upon normal program termination\n\n    func - function to be called at exit\n    args - optional arguments to pass to func\n    kwargs - optional keyword arguments to pass to func\n\n    func is returned to facilitate usage as a decorator.",
                 METH_VARARGS_KEYWORDS
             ),
             MethodDefinition(
                 "_clear",
                 MethodCallbacks(positional=atexit_clear),
                 "_clear($module, /)\n--\n\nClear the list of previously registered exit functions.",
                 METH_NOARGS
             ),
             MethodDefinition(
                 "unregister",
                 MethodCallbacks(positional=atexit_unregister),
                 "unregister($module, func, /)\n--\n\nUnregister an exit function which was previously registered using\natexit.register\n\n    func - function to be unregistered",
                 METH_O
             ),
             MethodDefinition(
                 "_run_exitfuncs",
                 MethodCallbacks(positional=atexit_run_exitfuncs),
                 "_run_exitfuncs($module, /)\n--\n\nRun all registered exit functions.\n\nIf a callback raises an exception, it is logged with sys.unraisablehook.",
                 METH_NOARGS
             ),
             MethodDefinition(
                 "_ncallbacks",
                 MethodCallbacks(positional=atexit_ncallbacks),
                 "_ncallbacks($module, /)\n--\n\nReturn the number of registered exit functions.",
                 METH_NOARGS
             )
         ]
     );

def:pub PyInit_atexit -> ptr[PyObject] {
    return definition.initialize();
}
