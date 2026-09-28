"""The _locale module: locale.Error and the locale and langinfo constants over the generated clinic table.

The constants come from locale_constants.<os>.jac, generated from the target's
<locale.h> and <langinfo.h>. CHAR_MAX follows the target ABI's char, so it is
read from the C library. The gettext functions exist only where the C library
has <libintl.h>.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_char_max,
    NULL,
    PyExc_ImportError,
    PyModule_AddIntConstant,
    PyObject
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception
}
import from jaclang.runtime.python.bindings.clinic.locale { module_methods }
import from jaclang.runtime.python.modules.locale { ERROR }
import from jaclang.runtime.python.modules.locale_constants { CONSTANTS, PLATFORM }
import from jaclang.runtime.python.modules.locale_platform { HAS_LIBINTL }

glob:priv LIBINTL: list[str] = [
         "gettext",
         "dgettext",
         "dcgettext",
         "textdomain",
         "bindtextdomain",
         "bind_textdomain_codeset"
     ];

def:priv add_constants(module: ptr[PyObject], categories: bool) -> bool {
    for (name, value) in CONSTANTS {
        if name.startswith("LC_") == categories
            and PyModule_AddIntConstant(module, name, value) < 0 {
            return False;
        }
    }
    return True;
}

"""Categories, CHAR_MAX and Error first, then the langinfo keys, as C adds them."""
def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            PyExc_ImportError,
            "_locale has no locale_constants.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    if not add_constants(module, True)
        or PyModule_AddIntConstant(module, "CHAR_MAX", jacpy_char_max()) < 0
        or not add_state_owned(
            module, ERROR, "Error", jacpy_binding_exception("locale.Error", NULL, "")
        )
        or not add_constants(module, False) {
        return i32(-1);
    }
    return i32(0);
}

def:priv methods -> list[MethodDefinition] {
    return [
        method
        for method in module_methods
        if HAS_LIBINTL or method.name not in LIBINTL
    ];
}

glob:priv definition = ModuleDefinition(
         "_locale",
         "Support for POSIX locales.",
         methods(),
         ModuleHooks(execute=execute),
         1
     );

def:pub PyInit__locale -> ptr[PyObject] {
    return definition.initialize();
}
