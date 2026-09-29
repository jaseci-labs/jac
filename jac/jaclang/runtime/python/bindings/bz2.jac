"""The _bz2 module: BZ2Compressor and BZ2Decompressor over the generated clinic glue."""

import from jaclang.runtime.python.cpython_api { PyObject }

import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    jacpy_binding_record
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
    BZ2Decompressor_eof__doc__,
    BZ2Decompressor_needs_input_doc,
    BZ2Decompressor_unused_data__doc__,
    _bz2_BZ2Compressor_new,
    _bz2_BZ2Decompressor_new
}
import from jaclang.runtime.python.modules.bz2 {
    BZ2Compressor_token,
    BZ2Decompressor_token
}
import from jaclang.runtime.python.bindings.members {
    MemberField,
    MemberType,
    record_clear
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
    record_clear(jacpy_binding_record(instance, BZ2Decompressor_token.handle), 16);
    dispose_payload(instance, BZ2Decompressor_token.handle);
}

def:priv decompressor_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, BZ2Decompressor_token.handle, visitor, context);
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
         members=[
             MemberField(
                 "eof",
                 MemberType.BOOL.value,
                 0,
                 readonly=True,
                 doc=BZ2Decompressor_eof__doc__
             ),
             MemberField(
                 "unused_data",
                 MemberType.OBJECT_EX.value,
                 8,
                 readonly=True,
                 doc=BZ2Decompressor_unused_data__doc__
             ),
             MemberField(
                 "needs_input",
                 MemberType.BOOL.value,
                 1,
                 readonly=True,
                 doc=BZ2Decompressor_needs_input_doc
             )
         ],
         record_size=16
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    BZ2Compressor_token.handle = compressor_type.handle;
    BZ2Decompressor_token.handle = decompressor_type.handle;
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
