"""Imported callable aliases preserve the declaration used by the checker."""
import from native_module_alias_pkg.values {
    alias_value as renamed_value,
    make_alias_value as renamed_factory
}

def imported_function_alias_probe -> int {
    return renamed_value(9);
}

def imported_factory_alias_probe -> int {
    first = renamed_factory();
    second = renamed_factory(value=23);
    return first.value + second.value;
}

with entry {
    print(imported_function_alias_probe());
}
