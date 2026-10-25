def:priv _imp_lock_held_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_acquire_lock_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_release_lock_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp__fix_co_filename_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _imp__fix_co_filename_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _imp_create_builtin_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_extension_suffixes_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_init_frozen_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _imp_find_frozen_signature = CallSignature(
         "find_frozen", ["name", "withdata"], 1, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _imp_find_frozen_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _imp_find_frozen_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_get_frozen_object_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _imp_get_frozen_object_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _imp_is_frozen_package_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_is_builtin_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_is_frozen_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp__frozen_module_names_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp__override_frozen_modules_for_tests_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp__override_multi_interp_extensions_check_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_create_dynamic_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _imp_create_dynamic_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _imp_exec_dynamic_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _imp_exec_builtin_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _imp_source_hash_signature = CallSignature(
         "source_hash", ["key", "source"], 2, 2, 0, parser=PARSE_KEYWORDS
     );

def:priv _imp_source_hash_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _imp_source_hash_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob doc_imp: str = "(Extremely) low-level import machinery bits as used by importlib.",
     module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "lock_held",
             MethodCallbacks(positional=_imp_lock_held_call),
             "lock_held($module, /)\n--\n\nReturn True if the import lock is currently held, else False.\n\nOn platforms without threads, return False.",
             4
         ),
         MethodDefinition(
             "acquire_lock",
             MethodCallbacks(positional=_imp_acquire_lock_call),
             "acquire_lock($module, /)\n--\n\nAcquires the interpreter's import lock for the current thread.\n\nThis lock should be used by import hooks to ensure thread-safety when\nimporting modules.  On platforms without threads, this function does\nnothing.",
             4
         ),
         MethodDefinition(
             "release_lock",
             MethodCallbacks(positional=_imp_release_lock_call),
             "release_lock($module, /)\n--\n\nRelease the interpreter's import lock.\n\nOn platforms without threads, this function does nothing.",
             4
         ),
         MethodDefinition(
             "_fix_co_filename",
             MethodCallbacks(fast=_imp__fix_co_filename_call),
             "_fix_co_filename($module, code, path, /)\n--\n\nChanges code.co_filename to specify the passed-in file path.\n\n  code\n    Code object to change.\n  path\n    File path to use.",
             128
         ),
         MethodDefinition(
             "create_builtin",
             MethodCallbacks(positional=_imp_create_builtin_call),
             "create_builtin($module, spec, /)\n--\n\nCreate an extension module.",
             8
         ),
         MethodDefinition(
             "extension_suffixes",
             MethodCallbacks(positional=_imp_extension_suffixes_call),
             "extension_suffixes($module, /)\n--\n\nReturns the list of file suffixes used to identify extension modules.",
             4
         ),
         MethodDefinition(
             "init_frozen",
             MethodCallbacks(positional=_imp_init_frozen_call),
             "init_frozen($module, name, /)\n--\n\nInitializes a frozen module.",
             8
         ),
         MethodDefinition(
             "find_frozen",
             MethodCallbacks(fast_keywords=_imp_find_frozen_call),
             "find_frozen($module, name, /, *, withdata=False)\n--\n\nReturn info about the corresponding frozen module (if there is one) or None.\n\nThe returned info (a 2-tuple):\n\n * data         the raw marshalled bytes\n * is_package   whether or not it is a package\n * origname     the originally frozen module's name, or None if not\n                a stdlib module (this will usually be the same as\n                the module's current name)",
             130
         ),
         MethodDefinition(
             "get_frozen_object",
             MethodCallbacks(fast=_imp_get_frozen_object_call),
             "get_frozen_object($module, name, data=None, /)\n--\n\nCreate a code object for a frozen module.",
             128
         ),
         MethodDefinition(
             "is_frozen_package",
             MethodCallbacks(positional=_imp_is_frozen_package_call),
             "is_frozen_package($module, name, /)\n--\n\nReturns True if the module name is of a frozen package.",
             8
         ),
         MethodDefinition(
             "is_builtin",
             MethodCallbacks(positional=_imp_is_builtin_call),
             "is_builtin($module, name, /)\n--\n\nReturns True if the module name corresponds to a built-in module.",
             8
         ),
         MethodDefinition(
             "is_frozen",
             MethodCallbacks(positional=_imp_is_frozen_call),
             "is_frozen($module, name, /)\n--\n\nReturns True if the module name corresponds to a frozen module.",
             8
         ),
         MethodDefinition(
             "_frozen_module_names",
             MethodCallbacks(positional=_imp__frozen_module_names_call),
             "_frozen_module_names($module, /)\n--\n\nReturns the list of available frozen modules.",
             4
         ),
         MethodDefinition(
             "_override_frozen_modules_for_tests",
             MethodCallbacks(positional=_imp__override_frozen_modules_for_tests_call),
             "_override_frozen_modules_for_tests($module, override, /)\n--\n\n(internal-only) Override PyConfig.use_frozen_modules.\n\n(-1: \"off\", 1: \"on\", 0: no override)\nSee frozen_modules() in Lib/test/support/import_helper.py.",
             8
         ),
         MethodDefinition(
             "_override_multi_interp_extensions_check",
             MethodCallbacks(
                 positional=_imp__override_multi_interp_extensions_check_call
             ),
             "_override_multi_interp_extensions_check($module, override, /)\n--\n\n(internal-only) Override PyInterpreterConfig.check_multi_interp_extensions.\n\n(-1: \"never\", 1: \"always\", 0: no override)",
             8
         ),
         MethodDefinition(
             "create_dynamic",
             MethodCallbacks(fast=_imp_create_dynamic_call),
             "create_dynamic($module, spec, file=<unrepresentable>, /)\n--\n\nCreate an extension module.",
             128
         ),
         MethodDefinition(
             "exec_dynamic",
             MethodCallbacks(positional=_imp_exec_dynamic_call),
             "exec_dynamic($module, mod, /)\n--\n\nInitialize an extension module.",
             8
         ),
         MethodDefinition(
             "exec_builtin",
             MethodCallbacks(positional=_imp_exec_builtin_call),
             "exec_builtin($module, mod, /)\n--\n\nInitialize a built-in module.",
             8
         ),
         MethodDefinition(
             "source_hash",
             MethodCallbacks(fast_keywords=_imp_source_hash_call),
             "source_hash($module, /, key, source)\n--\n\n",
             130
         ),

     ];

impl _imp_lock_held_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return _imp_lock_held_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_acquire_lock_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return _imp_acquire_lock_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_release_lock_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return _imp_release_lock_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp__fix_co_filename_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        subclass_PyCode_Type(value, "_fix_co_filename", argument_label("", 1));
        code: ptr[PyObject] = value;
        value = clinic_args[1];
        path: ptr[PyObject] = convert_unicode(
            value, "_fix_co_filename", argument_label("", 2)
        );
        return _imp__fix_co_filename_impl(receiver, code, path);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp__fix_co_filename_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2)
        and not check_positional("_fix_co_filename", int(nargs), 2, 2) {
        return NULL;
    }
    return _imp__fix_co_filename_bound(receiver, args, nargs);
}

impl _imp_create_builtin_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        spec: ptr[PyObject] = value;
        return _imp_create_builtin_impl(receiver, spec);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_extension_suffixes_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return _imp_extension_suffixes_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_init_frozen_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        name: ptr[PyObject] = convert_unicode(value, "init_frozen", "argument");
        return _imp_init_frozen_impl(receiver, name);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_find_frozen_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        name: ptr[PyObject] = convert_unicode(
            value, "find_frozen", argument_label("", 1)
        );
        withdata: bool = False;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            withdata = convert_bool(value);
        }
        return _imp_find_frozen_impl(receiver, name, withdata);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_find_frozen_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return _imp_find_frozen_bound(receiver, args, nargs);
    }
    values = unpack_stack(_imp_find_frozen_signature, args, nargs, kwnames);
    if values {
        unpacked = _imp_find_frozen_bound(receiver, values, 2);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _imp_find_frozen_signature,
        args,
        nargs,
        kwnames,
        _imp_find_frozen_bound,
        receiver
    );
}

impl _imp_get_frozen_object_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        name: ptr[PyObject] = convert_unicode(
            value, "get_frozen_object", argument_label("", 1)
        );
        data: ptr[PyObject] = borrowed_none();
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            data = value;
        }
        return _imp_get_frozen_object_impl(receiver, name, data);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_get_frozen_object_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2)
        and not check_positional("get_frozen_object", int(nargs), 1, 2) {
        return NULL;
    }
    return _imp_get_frozen_object_bound(receiver, args, nargs);
}

impl _imp_is_frozen_package_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        name: ptr[PyObject] = convert_unicode(value, "is_frozen_package", "argument");
        return _imp_is_frozen_package_impl(receiver, name);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_is_builtin_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        name: ptr[PyObject] = convert_unicode(value, "is_builtin", "argument");
        return _imp_is_builtin_impl(receiver, name);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_is_frozen_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        name: ptr[PyObject] = convert_unicode(value, "is_frozen", "argument");
        return _imp_is_frozen_impl(receiver, name);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp__frozen_module_names_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return _imp__frozen_module_names_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp__override_frozen_modules_for_tests_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        override_: i32 = convert_int(value);
        return _imp__override_frozen_modules_for_tests_impl(receiver, override_);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp__override_multi_interp_extensions_check_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        override_: i32 = convert_int(value);
        return _imp__override_multi_interp_extensions_check_impl(receiver, override_);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_create_dynamic_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        spec: ptr[PyObject] = value;
        file: ptr[PyObject] = NULL;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            file = value;
        }
        return _imp_create_dynamic_impl(receiver, spec, file);
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_create_dynamic_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2)
        and not check_positional("create_dynamic", int(nargs), 1, 2) {
        return NULL;
    }
    return _imp_create_dynamic_bound(receiver, args, nargs);
}

impl _imp_exec_dynamic_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        mod: ptr[PyObject] = value;
        return return_int(_imp_exec_dynamic_impl(receiver, mod));
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_exec_builtin_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        mod: ptr[PyObject] = value;
        return return_int(_imp_exec_builtin_impl(receiver, mod));
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_source_hash_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        key: i64 = convert_long(value);
        value = clinic_args[1];
        source: BufferArgument = convert_buffer(
            value, "source_hash", argument_label("source", 2)
        );
        try {
            return _imp_source_hash_impl(receiver, key, source);
        } finally {
            source.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _imp_source_hash_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 2 and nargs <= 2 {
        return _imp_source_hash_bound(receiver, args, nargs);
    }
    values = unpack_stack(_imp_source_hash_signature, args, nargs, kwnames);
    if values {
        unpacked = _imp_source_hash_bound(receiver, values, 2);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _imp_source_hash_signature,
        args,
        nargs,
        kwnames,
        _imp_source_hash_bound,
        receiver
    );
}
