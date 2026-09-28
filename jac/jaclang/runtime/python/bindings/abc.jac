"""The _abc module: the _abc_data type and module state over the generated clinic table."""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    PyObject,
    PyUnicode_InternFromString
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    jacpy_binding_module_native_set,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeFlags,
    TypeHooks
}
import from jaclang.runtime.python.bindings.payload {
    clear_payload,
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.abc { module_methods }
import from jaclang.runtime.python.modules.abc {
    AbcModuleState,
    DATA_TYPE,
    STATE_NAMES,
    abc_data_new,
    abc_data_token
}

def:priv data_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, abc_data_token.handle);
}

def:priv data_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, abc_data_token.handle, visitor, context);
}

def:priv data_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, abc_data_token.handle);
}

glob:priv data_type = TypeDefinition(
         "_abc._abc_data",
         "Internal state held by ABC machinery.",
         [],
         u64(TypeFlags.GC.value),
         TypeHooks(
             create=abc_data_new,
             dealloc=data_dealloc,
             traverse=data_traverse,
             clear=data_clear
         )
     );

"""The type is module state only, as in C: _abc does not publish it."""
def:priv execute(module: ptr[PyObject]) -> i32 {
    abc_data_token.handle = data_type.handle;
    jacpy_binding_module_native_set(module, AbcModuleState());
    type = data_type.create(module);
    if not type {
        return i32(-1);
    }
    jacpy_binding_state_set(module, i64(DATA_TYPE), type);
    jacpy_release(type);
    for index in range(len(STATE_NAMES)) {
        name = PyUnicode_InternFromString(STATE_NAMES[index]);
        if not name {
            return i32(-1);
        }
        jacpy_binding_state_set(module, i64(index + 1), name);
        jacpy_release(name);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_abc",
         "Module contains faster C implementation of abc.ABCMeta",
         module_methods,
         ModuleHooks(execute=execute),
         len(STATE_NAMES) + 1
     );

def:pub PyInit__abc -> ptr[PyObject] {
    return definition.initialize();
}
