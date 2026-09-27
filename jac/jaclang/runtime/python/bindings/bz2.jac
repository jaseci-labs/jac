"""The _bz2 module: BZ2Compressor and BZ2Decompressor over the generated clinic glue."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyObject,
    Py_NewRef
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
import from jaclang.runtime.python.bindings.clinic.bz2 {
    BZ2Compressor_methods,
    BZ2Decompressor_methods,
    BZ2Compressor_doc,
    BZ2Decompressor_doc,
    _bz2_BZ2Compressor_new,
    _bz2_BZ2Decompressor_new
}
import from jaclang.runtime.python.modules.bz2 {
    BZ2Compressor_token,
    BZ2Decompressor_token,
    decompressor_of
}

def:priv compressor_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, BZ2Compressor_token.handle);
}

def:priv compressor_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, BZ2Compressor_token.handle, visitor, context);
}

def:priv decompressor_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, BZ2Decompressor_token.handle);
}

def:priv decompressor_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, BZ2Decompressor_token.handle, visitor, context);
}

def:priv eof(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = decompressor_of(instance);
    return PyBool_FromLong(i64(state.eof)) if state is not None else NULL;
}

def:priv unused_data(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = decompressor_of(instance);
    return Py_NewRef(state.unused_data) if state is not None else NULL;
}

def:priv needs_input(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = decompressor_of(instance);
    return PyBool_FromLong(i64(state.needs_input)) if state is not None else NULL;
}

glob:priv compressor_type = TypeDefinition(
         "_bz2.BZ2Compressor",
         BZ2Compressor_doc,
         BZ2Compressor_methods,
         u64(TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=_bz2_BZ2Compressor_new,
             dealloc=compressor_dealloc,
             traverse=compressor_traverse
         )
     ),
     decompressor_type = TypeDefinition(
         "_bz2.BZ2Decompressor",
         BZ2Decompressor_doc,
         BZ2Decompressor_methods,
         u64(TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=_bz2_BZ2Decompressor_new,
             dealloc=decompressor_dealloc,
             traverse=decompressor_traverse
         ),
         [
             PropertyDefinition(
                 "eof",
                 PropertyCallbacks(read=eof),
                 0,
                 "True if the end-of-stream marker has been reached."
             ),
             PropertyDefinition(
                 "unused_data",
                 PropertyCallbacks(read=unused_data),
                 0,
                 "Data found after the end of the compressed stream."
             ),
             PropertyDefinition(
                 "needs_input",
                 PropertyCallbacks(read=needs_input),
                 0,
                 "True if more input is needed before more decompressed data can be produced."
             )
         ]
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    BZ2Compressor_token.bind(compressor_type.handle);
    BZ2Decompressor_token.bind(decompressor_type.handle);
    if not add_state_owned(module, 0, "BZ2Compressor", compressor_type.create(module))
        or not add_state_owned(
            module, 1, "BZ2Decompressor", decompressor_type.create(module)
        ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_bz2", "", [], ModuleHooks(execute=execute), 2
     );

def:pub PyInit__bz2 -> ptr[PyObject] {
    return definition.initialize();
}
