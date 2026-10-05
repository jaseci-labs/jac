"""The _md5 module: the md5 type over its generated clinic glue."""

import from jaclang.runtime.python.cpython_api {
    PyLong_FromLong,
    PyModule_AddIntConstant,
    PyObject,
    PyUnicode_FromString
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    PropertyCallbacks
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.md5 {
    MD5Type_methods,
    module_methods
}
import from jaclang.runtime.python.modules.hashlib { HASHLIB_GIL_MINSIZE }
import from jaclang.runtime.python.modules.md5 {
    MD5Type_token,
    MD5_BLOCKSIZE,
    MD5_DIGESTSIZE
}

def:priv md5_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, MD5Type_token.handle);
}

def:priv md5_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, MD5Type_token.handle, visitor, context);
}

def:priv get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(MD5_BLOCKSIZE);
}

def:priv get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyUnicode_FromString("md5");
}

def:priv get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(MD5_DIGESTSIZE);
}

glob:priv md5_type = TypeDefinition(
         "_md5.md5",
         "",
         MD5Type_methods,
         u64(
             TypeFlags.DISALLOW_INSTANTIATION.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.GC.value
         ),
         TypeHooks(dealloc=md5_dealloc, traverse=md5_traverse),
         [
             PropertyDefinition("block_size", PropertyCallbacks(read=get_block_size)),
             PropertyDefinition("name", PropertyCallbacks(read=get_name)),
             PropertyDefinition("digest_size", PropertyCallbacks(read=get_digest_size))
         ]
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    MD5Type_token.handle = md5_type.handle;
    if not add_state_owned(module, 0, "MD5Type", md5_type.create(module))
        or PyModule_AddIntConstant(module, "_GIL_MINSIZE", HASHLIB_GIL_MINSIZE) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_md5", "", module_methods, ModuleHooks(execute=execute), 1
     );

def:pub PyInit__md5 -> ptr[PyObject] {
    return definition.initialize();
}
