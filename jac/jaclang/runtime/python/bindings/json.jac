"""JSON scanner and encoder bindings, with native-owned Python settings."""
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
    jacpy_release,
    jacpy_retain,
    jacpy_truth,
    jacpy_boolean,
    jacpy_is_unicode,
    jacpy_is_none,
    jacpy_is_dict,
    jacpy_getattr_string,
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

def:priv check_string(value: u64) -> bool {
    if jacpy_is_unicode(value) != 0 {
        return True;
    }
    object_error(
        "TypeError", f"first argument must be a string, not {type_name(value)[:80]}"
    );
    return False;
}

def:priv escape_value(value: u64) -> u64 {
    return jacpy_json_escape(value, 0) if check_string(value) else u64(0);
}

def:priv escape_ascii_value(value: u64) -> u64 {
    return jacpy_json_escape(value, 1) if check_string(value) else u64(0);
}

def:priv escape_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, escape_value);
}

def:priv escape_ascii_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, escape_ascii_value);
}

glob:priv scanstring_signature = CallSignature(
         "scanstring", ["string", "end", "strict"], 2, 3, 3
     );

def:priv scanstring_bound(args: BoundArguments) -> u64 {
    end = index_value(args.values[1]);
    if end is None {
        return 0;
    }
    strict: i64 = 1;
    if args.values[2] != 0 {
        strict = jacpy_truth(args.values[2]);
        if strict < 0 {
            return 0;
        }
    }
    if not check_string(args.values[0]) {
        return 0;
    }
    return jacpy_json_scanstring(args.values[0], end, strict);
}

def:priv scanstring_call(module: u64, args: u64) -> u64 {
    return invoke(scanstring_signature, args, 0, scanstring_bound);
}

def:priv scanner_state(instance: u64) -> (JsonScannerState | None) {
    if jacpy_binding_native_present(instance, scanner_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, scanner_type.handle);
        if isinstance(state, JsonScannerState) {
            return state;
        }
    }
    object_error("SystemError", "native JSON scanner state is unavailable");
    return None;
}

def:priv encoder_state(instance: u64) -> (JsonEncoderState | None) {
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

def:priv scanner_create_bound(args: BoundArguments) -> u64 {
    instance = jacpy_binding_allocate(args.context);
    if instance == 0 {
        return 0;
    }
    state = JsonScannerState(references=[u64(0) for _ in scanner_names]);
    if jacpy_binding_native_set(instance, scanner_type.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    context = args.values[0];
    strict = jacpy_getattr_string(context, "strict");
    if strict == 0 {
        jacpy_release(instance);
        return 0;
    }
    state.strict = jacpy_truth(strict);
    jacpy_release(strict);
    if state.strict < 0 {
        jacpy_release(instance);
        return 0;
    }
    for i in range(len(scanner_names)) {
        value = jacpy_getattr_string(context, scanner_names[i]);
        if value == 0 {
            jacpy_release(instance);
            return 0;
        }
        state.references[i] = value;
    }
    return instance;
}

def:priv scanner_create(type: u64, args: u64, kwargs: u64) -> u64 {
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

def:priv encoder_create_bound(args: BoundArguments) -> u64 {
    for i in [4, 5] {
        if jacpy_is_unicode(args.values[i]) == 0 {
            object_error(
                "TypeError",
                f"make_encoder() argument {i + 1} must be str, not {type_name(
                    args.values[i]
                )}"
            );
            return 0;
        }
    }
    flags: i64 = 0;
    for i in range(3) {
        flag = jacpy_truth(args.values[6 + i]);
        if flag < 0 {
            return 0;
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
        return 0;
    }
    instance = jacpy_binding_allocate(args.context);
    if instance == 0 {
        return 0;
    }
    state = JsonEncoderState(
        references=[jacpy_retain(args.values[i]) for i in range(6)], flags=flags
    );
    if jacpy_binding_native_set(instance, encoder_type.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv encoder_create(type: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(encoder_init_signature, args, kwargs, encoder_create_bound, type);
}

glob:priv scanner_call_signature = CallSignature(
         "scan_once", ["string", "idx"], 2, 2
     );

def:priv scanner_call_bound(args: BoundArguments) -> u64 {
    start = index_value(args.values[1]);
    if start is None or not check_string(args.values[0]) {
        return 0;
    }
    state = scanner_state(args.context);
    if state is None {
        return 0;
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

def:priv scanner_call(instance: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(scanner_call_signature, args, kwargs, scanner_call_bound, instance);
}

glob:priv encoder_call_signature = CallSignature(
         "_iterencode", ["obj", "_current_indent_level"], 2, 2
     );

def:priv encoder_call_bound(args: BoundArguments) -> u64 {
    level = index_value(args.values[1]);
    if level is None {
        return 0;
    }
    state = encoder_state(args.context);
    if state is None {
        return 0;
    }
    settings: u64 = 0;
    try {
        settings = object_tuple(state.references);
    } except boundary_failure {
        return 0;
    }
    result = jacpy_json_encode(args.values[0], level, settings, state.flags);
    jacpy_release(settings);
    return result;
}

def:priv encoder_call(instance: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(encoder_call_signature, args, kwargs, encoder_call_bound, instance);
}

def:priv scanner_property(instance: u64, context: u64) -> u64 {
    state = scanner_state(instance);
    if state is None {
        return 0;
    }
    if context == 0 {
        return jacpy_boolean(state.strict);
    }
    value = state.references[int(context) - 1];
    if value == 0 {
        object_error("AttributeError", scanner_names[int(context) - 1]);
        return 0;
    }
    return jacpy_retain(value);
}

def:priv encoder_property(instance: u64, context: u64) -> u64 {
    state = encoder_state(instance);
    if state is None {
        return 0;
    }
    if context >= 6 {
        return jacpy_boolean((state.flags >> i64(context - u64(6))) & i64(1));
    }
    value = state.references[int(context)];
    if value == 0 {
        object_error("AttributeError", encoder_names[int(context)]);
        return 0;
    }
    return jacpy_retain(value);
}

def:priv scanner_deallocate(instance: u64) {
    dispose_payload(instance, scanner_type.handle);
}

def:priv scanner_clear(instance: u64) -> i32 {
    return clear_payload(instance, scanner_type.handle);
}

def:priv scanner_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, scanner_type.handle, visitor, context);
}

def:priv encoder_deallocate(instance: u64) {
    dispose_payload(instance, encoder_type.handle);
}

def:priv encoder_clear(instance: u64) -> i32 {
    return clear_payload(instance, encoder_type.handle);
}

def:priv encoder_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
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
         [PropertyDefinition("strict", scanner_property, 0, doc="strict")]
             + [
                 PropertyDefinition(
                     scanner_names[i],
                     scanner_property,
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
                 encoder_names[i], encoder_property, u64(i), doc=encoder_names[i]
             ) for i in range(6)
         ]
             + [
                 PropertyDefinition("sort_keys", encoder_property, 6, doc="sort_keys"),
                 PropertyDefinition("skipkeys", encoder_property, 7, doc="skipkeys")
             ]
     );

def:priv execute(module: u64) -> i32 {
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

def:pub PyInit__json -> u64 {
    return definition.initialize();
}
