"""JSON scanner and encoder bindings, with native-owned Python settings."""

import from jaclang.runtime.python.cpython_api {
    jacpy_is_dict,
    jacpy_is_unicode,
    jacpy_release,
    NULL,
    Py_NewRef,
    Py_None,
    PyExc_SystemError,
    PyExc_TypeError,
    PyObject,
    PyObject_GetAttrString,
    PyObject_IsTrue
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodDefinition,
    MethodCallbacks,
    ModuleHooks,
    add_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    jacpy_binding_allocate,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.members {
    MemberField,
    MemberType,
    record_clear,
    record_set_byte,
    record_set_object
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present,
    dispose_payload,
    clear_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.references { ReferenceState }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke,
    invoke_one,
    index_value,
    PARSE_FORMAT
}
import from jaclang.runtime.python.bindings.clinic.json {
    encoder_doc,
    encoder_members_default_doc,
    encoder_members_encoder_doc,
    encoder_members_indent_doc,
    encoder_members_item_separator_doc,
    encoder_members_key_separator_doc,
    encoder_members_markers_doc,
    encoder_members_skipkeys_doc,
    encoder_members_sort_keys_doc,
    module_doc,
    pydoc_encode_basestring,
    pydoc_encode_basestring_ascii,
    pydoc_scanstring,
    scanner_doc,
    scanner_members_object_hook_doc,
    scanner_members_parse_constant_doc,
    scanner_members_parse_float_doc,
    scanner_members_parse_int_doc,
    scanner_members_strict_doc
}
import from jaclang.runtime.python.modules.json {
    jacpy_json_escape,
    jacpy_json_scanstring,
    jacpy_json_scan,
    jacpy_json_encode
}
import from jaclang.runtime.python.capi {
    object_error,
    type_name,
    object_tuple,
    boundary_failure
}

obj JsonScannerState(ReferenceState) {
    has strict: i64 = 1;
}

obj JsonEncoderState(ReferenceState) {
    has flags: i64 = 0;
}

glob:priv scanner_names = [
         "object_hook",
         "object_pairs_hook",
         "parse_float",
         "parse_int",
         "parse_constant"
     ],
     encoder_names = [
         "markers",
         "default",
         "encoder",
         "indent",
         "key_separator",
         "item_separator"
     ];

def:priv check_string(value: ptr[PyObject]) -> bool {
    if jacpy_is_unicode(value) != 0 {
        return True;
    }
    object_error(
        PyExc_TypeError, f"first argument must be a string, not {type_name(value)[:80]}"
    );
    return False;
}

def:priv escape_value(value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_json_escape(value, 0) if check_string(value) else NULL;
}

def:priv escape_ascii_value(value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_json_escape(value, 1) if check_string(value) else NULL;
}

def:priv escape_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, escape_value);
}

def:priv escape_ascii_call(
    module: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_one(value, escape_ascii_value);
}

# PyArg_ParseTuple(args, "On|p:scanstring", ...).
glob:priv scanstring_signature = CallSignature(
         "scanstring", ["string", "end", "strict"], 2, 3, 3, parser=PARSE_FORMAT
     );

def:priv scanstring_bound(args: BoundArguments) -> ptr[PyObject] {
    end = index_value(args.values[1]);
    if end is None {
        return NULL;
    }
    strict: i64 = 1;
    if args.values[2] != 0 {
        strict = PyObject_IsTrue(args.values[2]);
        if strict < 0 {
            return NULL;
        }
    }
    if not check_string(args.values[0]) {
        return NULL;
    }
    return jacpy_json_scanstring(args.values[0], end, strict);
}

def:priv scanstring_call(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(scanstring_signature, args, NULL, scanstring_bound);
}

def:priv scanner_state(instance: ptr[PyObject]) -> (JsonScannerState | None) {
    if jacpy_binding_native_present(instance, scanner_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, scanner_type.handle);
        if isinstance(state, JsonScannerState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "native JSON scanner state is unavailable");
    return None;
}

def:priv encoder_state(instance: ptr[PyObject]) -> (JsonEncoderState | None) {
    if jacpy_binding_native_present(instance, encoder_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, encoder_type.handle);
        if isinstance(state, JsonEncoderState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "native JSON encoder state is unavailable");
    return None;
}

glob:priv scanner_init_signature = CallSignature(
         "make_scanner", ["context"], 1, 1
     );

def:priv scanner_create_bound(args: BoundArguments) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(args.context);
    if instance == 0 {
        return NULL;
    }
    state = JsonScannerState(references=[NULL for _ in scanner_names]);
    if jacpy_binding_native_set(instance, scanner_type.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    context = args.values[0];
    strict = PyObject_GetAttrString(context, "strict");
    if strict == 0 {
        jacpy_release(instance);
        return NULL;
    }
    state.strict = PyObject_IsTrue(strict);
    jacpy_release(strict);
    if state.strict < 0 {
        jacpy_release(instance);
        return NULL;
    }
    for i in range(len(scanner_names)) {
        value = PyObject_GetAttrString(context, scanner_names[i]);
        if value == 0 {
            jacpy_release(instance);
            return NULL;
        }
        state.references[i] = value;
    }
    record = jacpy_binding_record(instance, scanner_type.handle);
    record_set_byte(record, 0, int(state.strict));
    for i in range(len(scanner_names)) {
        record_set_object(record, 8 * (i + 1), state.references[i]);
    }
    return instance;
}

def:priv scanner_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(scanner_init_signature, args, kwargs, scanner_create_bound, type);
}

glob:priv encoder_init_signature = CallSignature(
         "make_encoder",
         [
             "markers",
             "default",
             "encoder",
             "indent",
             "key_separator",
             "item_separator",
             "sort_keys",
             "skipkeys",
             "allow_nan"
         ],
         9,
         9
     );

def:priv encoder_create_bound(args: BoundArguments) -> ptr[PyObject] {
    for i in [4, 5] {
        if jacpy_is_unicode(args.values[i]) == 0 {
            object_error(
                PyExc_TypeError,
                f"make_encoder() argument {i + 1} must be str, not {type_name(
                    args.values[i]
                )}"
            );
            return NULL;
        }
    }
    flags: i64 = 0;
    for i in range(3) {
        flag = PyObject_IsTrue(args.values[6 + i]);
        if flag < 0 {
            return NULL;
        }
        flags |= flag << i64(i);
    }
    if args.values[0] != Py_None and jacpy_is_dict(args.values[0]) == 0 {
        object_error(
            PyExc_TypeError,
            f"make_encoder() argument 1 must be dict or None, not {type_name(
                args.values[0]
            )}"
        );
        return NULL;
    }
    instance = jacpy_binding_allocate(args.context);
    if instance == 0 {
        return NULL;
    }
    state = JsonEncoderState(
        references=[Py_NewRef(args.values[i]) for i in range(6)], flags=flags
    );
    if jacpy_binding_native_set(instance, encoder_type.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    record = jacpy_binding_record(instance, encoder_type.handle);
    for i in range(6) {
        record_set_object(record, 8 * i, state.references[i]);
    }
    record_set_byte(record, 48, int(flags & 1));
    record_set_byte(record, 49, int((flags >> 1) & 1));
    return instance;
}

def:priv encoder_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(encoder_init_signature, args, kwargs, encoder_create_bound, type);
}

glob:priv scanner_call_signature = CallSignature(
         "scan_once", ["string", "idx"], 2, 2
     );

def:priv scanner_call_bound(args: BoundArguments) -> ptr[PyObject] {
    start = index_value(args.values[1]);
    if start is None or not check_string(args.values[0]) {
        return NULL;
    }
    state = scanner_state(args.context);
    if state is None {
        return NULL;
    }
    return jacpy_json_scan(
        args.values[0],
        start,
        state.strict,
        state.references[0],
        state.references[1],
        state.references[2],
        state.references[3],
        state.references[4]
    );
}

def:priv scanner_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(scanner_call_signature, args, kwargs, scanner_call_bound, instance);
}

glob:priv encoder_call_signature = CallSignature(
         "_iterencode", ["obj", "_current_indent_level"], 2, 2
     );

def:priv encoder_call_bound(args: BoundArguments) -> ptr[PyObject] {
    level = index_value(args.values[1]);
    if level is None {
        return NULL;
    }
    state = encoder_state(args.context);
    if state is None {
        return NULL;
    }
    settings: ptr[PyObject] = NULL;
    try {
        settings = object_tuple(state.references);
    } except boundary_failure {
        return NULL;
    }
    result = jacpy_json_encode(args.values[0], level, settings, state.flags);
    jacpy_release(settings);
    return result;
}

def:priv encoder_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(encoder_call_signature, args, kwargs, encoder_call_bound, instance);
}

def:priv scanner_deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, scanner_type.handle);
}

def:priv scanner_clear(instance: ptr[PyObject]) -> i32 {
    record_clear(jacpy_binding_record(instance, scanner_type.handle), SCANNER_RECORD);
    return clear_payload(instance, scanner_type.handle);
}

def:priv scanner_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, scanner_type.handle, visitor, context);
}

def:priv encoder_deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, encoder_type.handle);
}

def:priv encoder_clear(instance: ptr[PyObject]) -> i32 {
    record_clear(jacpy_binding_record(instance, encoder_type.handle), ENCODER_RECORD);
    return clear_payload(instance, encoder_type.handle);
}

def:priv encoder_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, encoder_type.handle, visitor, context);
}

# PyScannerObject's and PyEncoderObject's read-only PyMemberDefs, over a
# field record mirroring the native state: strict (a char) then five object
# pointers; six object pointers then the sort_keys and skipkeys chars.
glob:priv SCANNER_RECORD: int = 48,
     ENCODER_RECORD: int = 56;

def:priv scanner_members -> list[MemberField] {
    docs = [
        scanner_members_object_hook_doc,
        None,
        scanner_members_parse_float_doc,
        scanner_members_parse_int_doc,
        scanner_members_parse_constant_doc
    ];
    return [
        MemberField(
            name="strict",
            kind=MemberType.BOOL.value,
            offset=0,
            readonly=True,
            doc=scanner_members_strict_doc
        )
    ]
        + [
            MemberField(
                name=scanner_names[i],
                kind=MemberType.OBJECT.value,
                offset=8 * (i + 1),
                readonly=True,
                doc=docs[i]
            ) for i in range(5)
        ];
}

def:priv encoder_members -> list[MemberField] {
    docs = [
        encoder_members_markers_doc,
        encoder_members_default_doc,
        encoder_members_encoder_doc,
        encoder_members_indent_doc,
        encoder_members_key_separator_doc,
        encoder_members_item_separator_doc
    ];
    return [
        MemberField(
            name=encoder_names[i],
            kind=MemberType.OBJECT.value,
            offset=8 * i,
            readonly=True,
            doc=docs[i]
        ) for i in range(6)
    ]
        + [
            MemberField(
                name="sort_keys",
                kind=MemberType.BOOL.value,
                offset=48,
                readonly=True,
                doc=encoder_members_sort_keys_doc
            ),
            MemberField(
                name="skipkeys",
                kind=MemberType.BOOL.value,
                offset=49,
                readonly=True,
                doc=encoder_members_skipkeys_doc
            )
        ];
}

glob:priv scanner_type = TypeDefinition(
         "_json.Scanner",
         scanner_doc,
         [],
         u64(TypeFlags.GC.value),
         TypeHooks(
             create=scanner_create,
             call=scanner_call,
             dealloc=scanner_deallocate,
             clear=scanner_clear,
             traverse=scanner_traverse
         ),
         members=scanner_members(),
         record_size=SCANNER_RECORD
     ),
     encoder_type = TypeDefinition(
         "_json.Encoder",
         encoder_doc,
         [],
         u64(TypeFlags.GC.value),
         TypeHooks(
             create=encoder_create,
             call=encoder_call,
             dealloc=encoder_deallocate,
             clear=encoder_clear,
             traverse=encoder_traverse
         ),
         members=encoder_members(),
         record_size=ENCODER_RECORD
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    if not add_owned(module, "make_scanner", scanner_type.create(module)) {
        return i32(-1);
    }
    if not add_owned(module, "make_encoder", encoder_type.create(module)) {
        return i32(-1);
    }
    return i32(0);
}

# speedups_methods[]: hand-written in _json.c, with its PyDoc_STRVAR docs.
glob:priv definition = ModuleDefinition(
         "_json",
         module_doc,
         [
             MethodDefinition(
                 "encode_basestring_ascii",
                 MethodCallbacks(positional=escape_ascii_call),
                 pydoc_encode_basestring_ascii,
                 flags=8
             ),
             MethodDefinition(
                 "encode_basestring",
                 MethodCallbacks(positional=escape_call),
                 pydoc_encode_basestring,
                 flags=8
             ),
             MethodDefinition(
                 "scanstring",
                 MethodCallbacks(positional=scanstring_call),
                 pydoc_scanstring,
                 flags=1
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__json -> ptr[PyObject] {
    return definition.initialize();
}
