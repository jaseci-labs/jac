"""The _uuid module: generate_time_safe() and the library capability flags."""

import from jaclang.runtime.python.cpython_api {
    PyModule_AddIntConstant,
    PyObject
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition
}
import from jaclang.runtime.python.modules.uuid { py_uuid_generate_time_safe }
import from jaclang.runtime.python.modules.uuid_library {
    HAVE_UUID_HEADER,
    HAVE_GENERATE_TIME_SAFE,
    HAVE_GENERATE_TIME_SAFE_STABLE_MAC
}

glob:priv METH_NOARGS: i64 = 4;

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PyModule_AddIntConstant(
        module, "has_uuid_generate_time_safe", i64(HAVE_GENERATE_TIME_SAFE)
    )
        < 0
        or PyModule_AddIntConstant(
            module,
            "has_stable_extractable_node",
            i64(HAVE_GENERATE_TIME_SAFE_STABLE_MAC)
        )
            < 0 {
        return i32(-1);
    }
    return i32(0);
}

def:priv methods -> list[MethodDefinition] {
    if not HAVE_UUID_HEADER {
        return [];
    }
    return [
        MethodDefinition(
            "generate_time_safe",
            MethodCallbacks(positional=py_uuid_generate_time_safe),
            "",
            METH_NOARGS
        )
    ];
}

glob:priv definition = ModuleDefinition(
         "_uuid", "", methods(), ModuleHooks(execute=execute)
     );

def:pub PyInit__uuid -> ptr[PyObject] {
    return definition.initialize();
}
