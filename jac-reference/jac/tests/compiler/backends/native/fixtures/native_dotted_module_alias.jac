import native_module_alias_pkg.values as values;
import native_module_alias_pkg.values;

def dotted_alias_probe -> int {
    return values.alias_value(values.AliasedValue().value) + values.ALIAS_COUNT;
}

def dotted_module_probe -> int {
    return native_module_alias_pkg.values.alias_value(4);
}
