"""JSON scanner and encoder bindings, with native-owned Python settings."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyObject,
    PyObject_GetAttrString,
    PyObject_IsTrue,
    Py_NewRef,
    jacpy_is_dict,
    jacpy_is_none,
    jacpy_is_unicode,
    jacpy_release
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
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_allocate
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
    index_value
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
        "TypeError", f"first argument must be a string, not {type_name(value)[:80]}"
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

glob:priv scanstring_signature = CallSignature(
         "scanstring", ["string", "end", "strict"], 2, 3, 3
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
    object_error("SystemError", "native JSON scanner state is unavailable");
    return None;
}

def:priv encoder_state(instance: ptr[PyObject]) -> (JsonEncoderState | None) {
    if jacpy_binding_native_present(instance, encoder_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, encoder_type.handle);
        if isinstance(state, JsonEncoderState) {
            return state;
        }
    }
    object_error("SystemError", "native JSON encoder state is unavailable");
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
                "TypeError",
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
    if jacpy_is_none(args.values[0]) == 0 and jacpy_is_dict(args.values[0]) == 0 {
        object_error(
            "TypeError",
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

def:priv scanner_property(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = scanner_state(instance);
    if state is None {
        return NULL;
    }
    if context == 0 {
        return PyBool_FromLong(state.strict);
    }
    value = state.references[int(context) - 1];
    if value == 0 {
        object_error("AttributeError", scanner_names[int(context) - 1]);
        return NULL;
    }
    return Py_NewRef(value);
}

def:priv encoder_property(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = encoder_state(instance);
    if state is None {
        return NULL;
    }
    if context >= 6 {
        return PyBool_FromLong((state.flags >> i64(context - u64(6))) & i64(1));
    }
    value = state.references[int(context)];
    if value == 0 {
        object_error("AttributeError", encoder_names[int(context)]);
        return NULL;
    }
    return Py_NewRef(value);
}

def:priv scanner_deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, scanner_type.handle);
}

def:priv scanner_clear(instance: ptr[PyObject]) -> i32 {
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
    return clear_payload(instance, encoder_type.handle);
}

def:priv encoder_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, encoder_type.handle, visitor, context);
}

glob:priv scanner_type = TypeDefinition(
         "_json.Scanner",
         "JSON scanner object",
         [],
         u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=scanner_create,
             call=scanner_call,
             dealloc=scanner_deallocate,
             clear=scanner_clear,
             traverse=scanner_traverse
         ),
         [
             PropertyDefinition(
                 "strict", PropertyCallbacks(read=scanner_property), 0, doc="strict"
             )
         ]
             + [
                 PropertyDefinition(
                     scanner_names[i],
                     PropertyCallbacks(read=scanner_property),
                     u64(i + 1),
                     doc=scanner_names[i]
                 ) for i in range(5)
             ]
     ),
     encoder_type = TypeDefinition(
         "_json.Encoder",
         "_iterencode(obj, _current_indent_level) -> iterable",
         [],
         u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=encoder_create,
             call=encoder_call,
             dealloc=encoder_deallocate,
             clear=encoder_clear,
             traverse=encoder_traverse
         ),
         [
             PropertyDefinition(
                 encoder_names[i],
                 PropertyCallbacks(read=encoder_property),
                 u64(i),
                 doc=encoder_names[i]
             ) for i in range(6)
         ]
             + [
                 PropertyDefinition(
                     "sort_keys",
                     PropertyCallbacks(read=encoder_property),
                     6,
                     doc="sort_keys"
                 ),
                 PropertyDefinition(
                     "skipkeys",
                     PropertyCallbacks(read=encoder_property),
                     7,
                     doc="skipkeys"
                 )
             ]
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

glob:priv definition = ModuleDefinition(
         "_json",
         "JSON algorithms implemented in native Jac.",
         [
             MethodDefinition(
                 "encode_basestring",
                 MethodCallbacks(positional=escape_call),
                 "Return a JSON string representation.",
                 flags=8
             ),
             MethodDefinition(
                 "encode_basestring_ascii",
                 MethodCallbacks(positional=escape_ascii_call),
                 "Return an ASCII-only JSON string representation.",
                 flags=8
             ),
             MethodDefinition(
                 "scanstring",
                 MethodCallbacks(positional=scanstring_call),
                 "Scan and unescape a JSON string.",
                 flags=1
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__json -> ptr[PyObject] {
    return definition.initialize();
}
