glob:priv LIBINTL: list[str] = [
         "gettext",
         "dgettext",
         "dcgettext",
         "textdomain",
         "bindtextdomain",
         "bind_textdomain_codeset"
     ];

def:priv add_constants(module: ptr[PyObject], categories: bool) -> bool;

def:priv execute(module: ptr[PyObject]) -> i32;

def:priv methods -> list[MethodDefinition];

glob:priv definition = ModuleDefinition(
         "_locale",
         "Support for POSIX locales.",
         methods(),
         ModuleHooks(execute=execute),
         1
     );

def:pub PyInit__locale -> ptr[PyObject];

impl add_constants(module: ptr[PyObject], categories: bool) -> bool {
    for (name, value) in CONSTANTS {
        if name.startswith("LC_") == categories
            and jacpy_module_add_int_text(module, name, value) < 0 {
            return False;
        }
    }
    return True;
}

impl execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            PyExc_ImportError,
            "_locale has no locale_constants.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    if not add_constants(module, True)
        or PyModule_AddIntConstant(module, ptr[u8]("CHAR_MAX"), jacpy_char_max()) < 0
        or not add_state_owned(
            module, ERROR, "Error", jacpy_binding_exception("locale.Error", NULL, "")
        )
        or not add_constants(module, False) {
        return i32(-1);
    }
    return i32(0);
}

impl methods -> list[MethodDefinition] {
    return [
        method
        for method in module_methods
        if HAS_LIBINTL or method.name not in LIBINTL
    ];
}

impl PyInit__locale -> ptr[PyObject] {
    return definition.initialize();
}
