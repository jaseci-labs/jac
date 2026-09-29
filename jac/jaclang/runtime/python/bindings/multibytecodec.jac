"""The _multibytecodec module: MultibyteCodec and the incremental and stream
codec types over their generated clinic glue."""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    NULL,
    PyObject,
    PyUnicode_InternFromString
}

import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    PropertyCallbacks,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload {
    clear_payload,
    dispose_payload,
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.multibytecodec {
    MultibyteCodec_methods,
    MultibyteIncrementalDecoder_methods,
    MultibyteIncrementalEncoder_methods,
    MultibyteStreamReader_methods,
    MultibyteStreamWriter_methods,
    module_methods
}
import from jaclang.runtime.python.modules.multibytecodec {
    MultibyteCodec_token,
    MultibyteIncrementalDecoder_token,
    MultibyteIncrementalEncoder_token,
    MultibyteStreamReader_token,
    MultibyteStreamWriter_token,
    STATE_CODEC_TYPE,
    STATE_COUNT,
    STATE_DECODER_TYPE,
    STATE_ENCODER_TYPE,
    STATE_READER_TYPE,
    STATE_STR_WRITE,
    STATE_WRITER_TYPE,
    StatefulState,
    codecctx_errors_get,
    codecctx_errors_set,
    parse_new_arguments,
    stateful_new
}
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.bindings.members {
    MemberField,
    MemberType,
    record_clear,
    record_set_object
}

# The "errors" property's context: which stateful type it reads.
glob:priv ENCODER: u64 = 0,
     DECODER: u64 = 1,
     READER: u64 = 2,
     WRITER: u64 = 3;

def:priv codec_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, MultibyteCodec_token.handle);
}

def:priv codec_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, MultibyteCodec_token.handle, visitor, context);
}

def:priv codec_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, MultibyteCodec_token.handle);
}

def:priv encoder_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, MultibyteIncrementalEncoder_token.handle);
}

def:priv encoder_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, MultibyteIncrementalEncoder_token.handle, visitor, context
    );
}

def:priv decoder_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, MultibyteIncrementalDecoder_token.handle);
}

def:priv decoder_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, MultibyteIncrementalDecoder_token.handle, visitor, context
    );
}

def:priv reader_dealloc(instance: ptr[PyObject]) {
    record_clear(jacpy_binding_record(instance, MultibyteStreamReader_token.handle), 8);
    dispose_payload(instance, MultibyteStreamReader_token.handle);
}

def:priv reader_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, MultibyteStreamReader_token.handle, visitor, context
    );
}

def:priv writer_dealloc(instance: ptr[PyObject]) {
    record_clear(jacpy_binding_record(instance, MultibyteStreamWriter_token.handle), 8);
    dispose_payload(instance, MultibyteStreamWriter_token.handle);
}

def:priv writer_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, MultibyteStreamWriter_token.handle, visitor, context
    );
}

# tp_new of the four stateful types.
def:priv encoder_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    parsed = parse_new_arguments(args, kwargs, "IncrementalEncoder", False);
    if parsed is None {
        return NULL;
    }
    return stateful_new(
        type,
        MultibyteIncrementalEncoder_token,
        definition.handle,
        parsed.errors,
        NULL,
        True
    );
}

def:priv decoder_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    parsed = parse_new_arguments(args, kwargs, "IncrementalDecoder", False);
    if parsed is None {
        return NULL;
    }
    return stateful_new(
        type,
        MultibyteIncrementalDecoder_token,
        definition.handle,
        parsed.errors,
        NULL,
        False
    );
}

def:priv reader_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    parsed = parse_new_arguments(args, kwargs, "StreamReader", True);
    if parsed is None {
        return NULL;
    }
    instance = stateful_new(
        type,
        MultibyteStreamReader_token,
        definition.handle,
        parsed.errors,
        parsed.stream,
        False
    );
    if instance {
        mirror_stream(instance, MultibyteStreamReader_token);
    }
    return instance;
}

def:priv writer_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    parsed = parse_new_arguments(args, kwargs, "StreamWriter", True);
    if parsed is None {
        return NULL;
    }
    instance = stateful_new(
        type,
        MultibyteStreamWriter_token,
        definition.handle,
        parsed.errors,
        parsed.stream,
        True
    );
    if instance {
        mirror_stream(instance, MultibyteStreamWriter_token);
    }
    return instance;
}

# tp_init of the four stateful types accepts anything.
def:priv stateful_init(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    return i32(0);
}

def:priv errors_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return codecctx_errors_get(instance, context);
}

def:priv errors_set(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    return codecctx_errors_set(instance, value, context);
}

def:priv errors_property(kind: u64) -> PropertyDefinition {
    return PropertyDefinition(
        "errors",
        PropertyCallbacks(read=errors_get, write=errors_set),
        kind,
        "how to treat errors"
    );
}

# The stream types' "stream" member (_Py_T_OBJECT, Py_READONLY) reads the
# record, which holds the state's stream borrowed.
def:priv mirror_stream(instance: ptr[PyObject], token: ClassToken) {
    if jacpy_binding_native_present(instance, token.handle) != 0 {
        state = jacpy_binding_native_get(instance, token.handle);
        if isinstance(state, StatefulState) {
            record_set_object(
                jacpy_binding_record(instance, token.handle), 0, state.stream
            );
        }
    }
}

glob:priv STATEFUL_FLAGS: u64 = u64(
         TypeFlags.GC.value | TypeFlags.BASETYPE.value | TypeFlags.IMMUTABLE.value
     );

glob:priv codec_type = TypeDefinition(
         "_multibytecodec.MultibyteCodec",
         "",
         MultibyteCodec_methods,
         u64(
             TypeFlags.GC.value
                 | TypeFlags.DISALLOW_INSTANTIATION.value
                 | TypeFlags.IMMUTABLE.value
         ),
         TypeHooks(dealloc=codec_dealloc, traverse=codec_traverse, clear=codec_clear)
     ),
     encoder_type = TypeDefinition(
         "_multibytecodec.MultibyteIncrementalEncoder",
         "",
         MultibyteIncrementalEncoder_methods,
         STATEFUL_FLAGS,
         TypeHooks(
             create=encoder_new,
             initialize=stateful_init,
             dealloc=encoder_dealloc,
             traverse=encoder_traverse
         ),
         [errors_property(ENCODER)],
         generic_getattr=True
     ),
     decoder_type = TypeDefinition(
         "_multibytecodec.MultibyteIncrementalDecoder",
         "",
         MultibyteIncrementalDecoder_methods,
         STATEFUL_FLAGS,
         TypeHooks(
             create=decoder_new,
             initialize=stateful_init,
             dealloc=decoder_dealloc,
             traverse=decoder_traverse
         ),
         [errors_property(DECODER)],
         generic_getattr=True
     ),
     reader_type = TypeDefinition(
         "_multibytecodec.MultibyteStreamReader",
         "",
         MultibyteStreamReader_methods,
         STATEFUL_FLAGS,
         TypeHooks(
             create=reader_new,
             initialize=stateful_init,
             dealloc=reader_dealloc,
             traverse=reader_traverse
         ),
         [errors_property(READER)],
         members=[MemberField("stream", MemberType.OBJECT.value, 0, readonly=True)],
         record_size=8,
         generic_getattr=True
     ),
     writer_type = TypeDefinition(
         "_multibytecodec.MultibyteStreamWriter",
         "",
         MultibyteStreamWriter_methods,
         STATEFUL_FLAGS,
         TypeHooks(
             create=writer_new,
             initialize=stateful_init,
             dealloc=writer_dealloc,
             traverse=writer_traverse
         ),
         [errors_property(WRITER)],
         members=[MemberField("stream", MemberType.OBJECT.value, 0, readonly=True)],
         record_size=8,
         generic_getattr=True
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    MultibyteCodec_token.handle = codec_type.handle;
    MultibyteIncrementalEncoder_token.handle = encoder_type.handle;
    MultibyteIncrementalDecoder_token.handle = decoder_type.handle;
    MultibyteStreamReader_token.handle = reader_type.handle;
    MultibyteStreamWriter_token.handle = writer_type.handle;
    str_write = PyUnicode_InternFromString("write");
    if not str_write {
        return i32(-1);
    }
    jacpy_binding_state_set(module, i64(STATE_STR_WRITE), str_write);
    jacpy_release(str_write);
    codec = codec_type.create(module);
    if not codec {
        return i32(-1);
    }
    # MultibyteCodec is not a module attribute.
    jacpy_binding_state_set(module, i64(STATE_CODEC_TYPE), codec);
    jacpy_release(codec);
    if not add_state_owned(
        module,
        STATE_ENCODER_TYPE,
        "MultibyteIncrementalEncoder",
        encoder_type.create(module)
    )
        or not add_state_owned(
            module,
            STATE_DECODER_TYPE,
            "MultibyteIncrementalDecoder",
            decoder_type.create(module)
        )
        or not add_state_owned(
            module,
            STATE_READER_TYPE,
            "MultibyteStreamReader",
            reader_type.create(module)
        )
        or not add_state_owned(
            module,
            STATE_WRITER_TYPE,
            "MultibyteStreamWriter",
            writer_type.create(module)
        ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_multibytecodec",
         "",
         module_methods,
         ModuleHooks(execute=execute),
         STATE_COUNT
     );

def:pub PyInit__multibytecodec -> ptr[PyObject] {
    return definition.initialize();
}
