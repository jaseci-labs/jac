import from jaclang.runtime.object_model { field }
import from jaclang.compiler.ir.enums {
    NATIVE_ERASED_ANNOTATIONS,
    NATIVE_ERASED_TYPE_MARKERS,
    TYPE_PARAM_CONSTRUCTORS
}


glob NATIVE_SUPPORTED_STDLIB: set[str] = {
         "sys",
         "math",
         "time",
         "os",
         "random",
         "struct",
         "enum",
         "collections.abc"
     },
     NATIVE_ERASED_ABC_BASES: frozenset = frozenset({"ABC"}),
     NATIVE_ERASED_BASES: frozenset = NATIVE_ERASED_ABC_BASES,
     NATIVE_ERASED_IDENTITY_CALLS: frozenset = frozenset({"cast"}),
     NATIVE_ERASED_FIELD_MARKERS: frozenset = frozenset({"field"}),
     NATIVE_ERASED_IMPORTS: dict[str, frozenset] = {
         "abc": NATIVE_ERASED_ABC_BASES,
         "jaclang.runtime.object_model": NATIVE_ERASED_FIELD_MARKERS,
         "typing": TYPE_PARAM_CONSTRUCTORS
             | NATIVE_ERASED_IDENTITY_CALLS
             | NATIVE_ERASED_TYPE_MARKERS
             | NATIVE_ERASED_ANNOTATIONS
     };

def native_erased_import_names(module_name: str, names: list[str]) -> bool {
    allowed = NATIVE_ERASED_IMPORTS.get(module_name.lstrip('.'));
    if allowed is None or not names {
        return False;
    }
    for n in names {
        if n not in allowed {
            return False;
        }
    }
    return True;
}
