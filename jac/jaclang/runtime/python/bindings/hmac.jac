"""The _hmac module: the HMAC type, UnknownHashError and the one-shot functions
over the generated clinic glue."""

import from jaclang.runtime.python.cpython_api { PyModule_AddIntConstant, PyObject }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.hmac {
    HMAC_getset,
    HMAC_methods,
    module_methods
}
import from jaclang.runtime.python.modules.hashlib { HASHLIB_GIL_MINSIZE }
import from jaclang.runtime.python.modules.hmac {
    HMAC_TYPE,
    HMAC_token,
    UNKNOWN_HASH_ERROR,
    hmac_repr
}

def:priv hmac_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, HMAC_token.handle);
}

def:priv hmac_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, HMAC_token.handle, visitor, context);
}

glob:priv hmac_type = TypeDefinition(
         "_hmac.HMAC",
         "",
         HMAC_methods,
         u64(
             TypeFlags.DISALLOW_INSTANTIATION.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.GC.value
         ),
         TypeHooks(repr=hmac_repr, dealloc=hmac_dealloc, traverse=hmac_traverse),
         HMAC_getset
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    HMAC_token.handle = hmac_type.handle;
    if not add_state_owned(
        module,
        UNKNOWN_HASH_ERROR,
        "UnknownHashError",
        jacpy_binding_exception("_hmac.UnknownHashError", "ValueError", "")
    )
        or not add_state_owned(module, HMAC_TYPE, "HMAC", hmac_type.create(module))
        or PyModule_AddIntConstant(module, "_GIL_MINSIZE", HASHLIB_GIL_MINSIZE) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_hmac", "", module_methods, ModuleHooks(execute=execute), 2
     );

def:pub PyInit__hmac -> ptr[PyObject] {
    return definition.initialize();
}
