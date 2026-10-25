glob:priv marshal_dump_signature = CallSignature(
         "dump",
         ["value", "file", "version", "allow_code"],
         2,
         3,
         3,
         parser=PARSE_KEYWORDS
     );

def:priv marshal_dump_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv marshal_dump_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv marshal_load_signature = CallSignature(
         "load", ["file", "allow_code"], 1, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv marshal_load_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv marshal_load_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv marshal_dumps_signature = CallSignature(
         "dumps", ["value", "version", "allow_code"], 1, 2, 2, parser=PARSE_KEYWORDS
     );

def:priv marshal_dumps_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv marshal_dumps_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv marshal_loads_signature = CallSignature(
         "loads", ["bytes", "allow_code"], 1, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv marshal_loads_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv marshal_loads_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob module_doc: str = "This module contains functions that can read and write Python values in\na binary format. The format is specific to Python, but independent of\nmachine architecture issues.\n\nNot all Python object types are supported; in general, only objects\nwhose value is independent from a particular invocation of Python can be\nwritten and read by this module. The following types are supported:\nNone, integers, floating-point numbers, strings, bytes, bytearrays,\ntuples, lists, sets, dictionaries, and code objects, where it\nshould be understood that tuples, lists and dictionaries are only\nsupported as long as the values contained therein are themselves\nsupported; and recursive lists and dictionaries should not be written\n(they will cause infinite loops).\n\nVariables:\n\nversion -- indicates the format that the module uses. Version 0 is the\n    historical format, version 1 shares interned strings and version 2\n    uses a binary format for floating-point numbers.\n    Version 3 shares common object references (New in version 3.4).\n\nFunctions:\n\ndump() -- write value to a file\nload() -- read value from a file\ndumps() -- marshal value as a bytes object\nloads() -- read value from a bytes-like object",
     module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "dump",
             MethodCallbacks(fast_keywords=marshal_dump_call),
             "dump($module, value, file, version=version, /, *, allow_code=True)\n--\n\nWrite the value on the open file.\n\n  value\n    Must be a supported type.\n  file\n    Must be a writeable binary file.\n  version\n    Indicates the data format that dump should use.\n  allow_code\n    Allow to write code objects.\n\nIf the value has (or contains an object that has) an unsupported type, a\nValueError exception is raised - but garbage data will also be written\nto the file. The object will not be properly read back by load().",
             130
         ),
         MethodDefinition(
             "load",
             MethodCallbacks(fast_keywords=marshal_load_call),
             "load($module, file, /, *, allow_code=True)\n--\n\nRead one value from the open file and return it.\n\n  file\n    Must be readable binary file.\n  allow_code\n    Allow to load code objects.\n\nIf no valid value is read (e.g. because the data has a different Python\nversion's incompatible marshal format), raise EOFError, ValueError or\nTypeError.\n\nNote: If an object containing an unsupported type was marshalled with\ndump(), load() will substitute None for the unmarshallable type.",
             130
         ),
         MethodDefinition(
             "dumps",
             MethodCallbacks(fast_keywords=marshal_dumps_call),
             "dumps($module, value, version=version, /, *, allow_code=True)\n--\n\nReturn the bytes object that would be written to a file by dump(value, file).\n\n  value\n    Must be a supported type.\n  version\n    Indicates the data format that dumps should use.\n  allow_code\n    Allow to write code objects.\n\nRaise a ValueError exception if value has (or contains an object that\nhas) an unsupported type.",
             130
         ),
         MethodDefinition(
             "loads",
             MethodCallbacks(fast_keywords=marshal_loads_call),
             "loads($module, bytes, /, *, allow_code=True)\n--\n\nConvert the bytes-like object to a value.\n\n  allow_code\n    Allow to load code objects.\n\nIf no valid value is found, raise EOFError, ValueError or TypeError.\nExtra bytes in the input are ignored.",
             130
         ),

     ];

impl marshal_dump_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        value_: ptr[PyObject] = value;
        value = clinic_args[1];
        file: ptr[PyObject] = value;
        version: i32 = Py_MARSHAL_VERSION;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            version = convert_int(value);
        }
        allow_code: bool = True;
        if count > 3 and clinic_args[3] != NULL {
            value = clinic_args[3];
            allow_code = convert_bool(value);
        }
        return marshal_dump_impl(receiver, value_, file, version, allow_code);
    } except boundary_failure {
        return NULL;
    }
}

impl marshal_dump_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 2 and nargs <= 3 {
        return marshal_dump_bound(receiver, args, nargs);
    }
    values = unpack_stack(marshal_dump_signature, args, nargs, kwnames);
    if values {
        unpacked = marshal_dump_bound(receiver, values, 4);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        marshal_dump_signature, args, nargs, kwnames, marshal_dump_bound, receiver
    );
}

impl marshal_load_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        file: ptr[PyObject] = value;
        allow_code: bool = True;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            allow_code = convert_bool(value);
        }
        return marshal_load_impl(receiver, file, allow_code);
    } except boundary_failure {
        return NULL;
    }
}

impl marshal_load_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return marshal_load_bound(receiver, args, nargs);
    }
    values = unpack_stack(marshal_load_signature, args, nargs, kwnames);
    if values {
        unpacked = marshal_load_bound(receiver, values, 2);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        marshal_load_signature, args, nargs, kwnames, marshal_load_bound, receiver
    );
}

impl marshal_dumps_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        value_: ptr[PyObject] = value;
        version: i32 = Py_MARSHAL_VERSION;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            version = convert_int(value);
        }
        allow_code: bool = True;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            allow_code = convert_bool(value);
        }
        return marshal_dumps_impl(receiver, value_, version, allow_code);
    } except boundary_failure {
        return NULL;
    }
}

impl marshal_dumps_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 2 {
        return marshal_dumps_bound(receiver, args, nargs);
    }
    values = unpack_stack(marshal_dumps_signature, args, nargs, kwnames);
    if values {
        unpacked = marshal_dumps_bound(receiver, values, 3);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        marshal_dumps_signature, args, nargs, kwnames, marshal_dumps_bound, receiver
    );
}

impl marshal_loads_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        bytes_: BufferArgument = convert_buffer(value, "loads", argument_label("", 1));
        try {
            allow_code: bool = True;
            if count > 1 and clinic_args[1] != NULL {
                value = clinic_args[1];
                allow_code = convert_bool(value);
            }
            return marshal_loads_impl(receiver, bytes_, allow_code);
        } finally {
            bytes_.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl marshal_loads_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return marshal_loads_bound(receiver, args, nargs);
    }
    values = unpack_stack(marshal_loads_signature, args, nargs, kwnames);
    if values {
        unpacked = marshal_loads_bound(receiver, values, 2);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        marshal_loads_signature, args, nargs, kwnames, marshal_loads_bound, receiver
    );
}
