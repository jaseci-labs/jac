def:priv _weakref_getweakrefcount_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _weakref__remove_dead_weakref_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _weakref__remove_dead_weakref_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _weakref_getweakrefs_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _weakref_proxy_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _weakref_proxy_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

glob module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "getweakrefcount",
             MethodCallbacks(positional=_weakref_getweakrefcount_call),
             "getweakrefcount($module, object, /)\n--\n\nReturn the number of weak references to 'object'.",
             8
         ),
         MethodDefinition(
             "_remove_dead_weakref",
             MethodCallbacks(fast=_weakref__remove_dead_weakref_call),
             "_remove_dead_weakref($module, dct, key, /)\n--\n\nAtomically remove key from dict if it points to a dead weakref.",
             128
         ),
         MethodDefinition(
             "getweakrefs",
             MethodCallbacks(positional=_weakref_getweakrefs_call),
             "getweakrefs($module, object, /)\n--\n\nReturn a list of all weak reference objects pointing to 'object'.",
             8
         ),
         MethodDefinition(
             "proxy",
             MethodCallbacks(fast=_weakref_proxy_call),
             "proxy($module, object, callback=None, /)\n--\n\nCreate a proxy object that weakly references 'object'.\n\n'callback', if given, is called with a reference to the\nproxy when 'object' is about to be finalized.",
             128
         ),

     ];

impl _weakref_getweakrefcount_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        object_: ptr[PyObject] = value;
        return return_ssize(_weakref_getweakrefcount_impl(receiver, object_));
    } except boundary_failure {
        return NULL;
    }
}

impl _weakref__remove_dead_weakref_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        if jacpy_is_dict(value) == 0 {
            bad_argument("_remove_dead_weakref", "argument 1", "dict", value);
        }
        dct: ptr[PyObject] = value;
        value = clinic_args[1];
        key: ptr[PyObject] = value;
        return _weakref__remove_dead_weakref_impl(receiver, dct, key);
    } except boundary_failure {
        return NULL;
    }
}

impl _weakref__remove_dead_weakref_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2)
        and not check_positional("_remove_dead_weakref", int(nargs), 2, 2) {
        return NULL;
    }
    return _weakref__remove_dead_weakref_bound(receiver, args, nargs);
}

impl _weakref_getweakrefs_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        object_: ptr[PyObject] = value;
        return _weakref_getweakrefs_impl(receiver, object_);
    } except boundary_failure {
        return NULL;
    }
}

impl _weakref_proxy_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        object_: ptr[PyObject] = value;
        callback: ptr[PyObject] = NULL;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            callback = value;
        }
        return _weakref_proxy_impl(receiver, object_, callback);
    } except boundary_failure {
        return NULL;
    }
}

impl _weakref_proxy_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2) and not check_positional("proxy", int(nargs), 1, 2) {
        return NULL;
    }
    return _weakref_proxy_bound(receiver, args, nargs);
}
