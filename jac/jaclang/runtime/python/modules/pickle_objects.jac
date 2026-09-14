"""Shared native global-name resolution for pickle readers and writers.

Import compatibility maps remain retained standard-library data. Attribute
traversal, identity validation and map selection execute in native Jac.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    repr_value,
    jacpy_error_restore,
    jacpy_object_str,
    required,
    checked,
    boundary_failure,
    object_tuple,
    text_object,
    text_value,
    jacpy_retain,
    jacpy_release,
    jacpy_dict_get,
    jacpy_dict_copy,
    jacpy_dict_keys,
    jacpy_list_item,
    jacpy_list_size,
    jacpy_tuple_item,
    jacpy_is_tuple,
    jacpy_tuple_size,
    jacpy_is_unicode,
    jacpy_is_none,
    jacpy_getattr,
    jacpy_optional_attr,
    jacpy_import_attr,
    jacpy_import_object,
    jacpy_error_pending,
    jacpy_error_take,
    jacpy_error_is,
    jacpy_audit_pickle_find
}
import from jaclang.runtime.python.modules.pickle_stream {
    stream_error,
    builtin_stream_error
}

def attribute_path(value: u64, name: u64, dotted: bool) -> u64 {
    if not dotted {
        return required(jacpy_getattr(value, name));
    }
    current = jacpy_retain(value);
    try {
        for component in text_value(name).split(".") {
            field = text_object(component);
            try {
                result = required(jacpy_getattr(current, field));
                jacpy_release(current);
                current = result;
            } finally {
                jacpy_release(field);
            }
        }
        return jacpy_retain(current);
    } finally {
        jacpy_release(current);
    }
}

def mapped_names(module: u64, name: u64, reverse: bool) -> u64 {
    names: u64 = 0;
    modules: u64 = 0;
    key: u64 = 0;
    try {
        names = required(
            jacpy_import_attr(
                "_compat_pickle", "REVERSE_NAME_MAPPING" if reverse else "NAME_MAPPING"
            )
        );
        key = object_tuple([module, name]);
        pair = jacpy_dict_get(names, key);
        if pair != 0 {
            return pair;
        }
        if jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        modules = required(
            jacpy_import_attr(
                "_compat_pickle",
                "REVERSE_IMPORT_MAPPING" if reverse else "IMPORT_MAPPING"
            )
        );
        mapped = jacpy_dict_get(modules, module);
        if jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        if mapped == 0 {
            return object_tuple([module, name]);
        }
        try {
            return object_tuple([mapped, name]);
        } finally {
            jacpy_release(mapped);
        }
    } finally {
        jacpy_release(names);
        jacpy_release(modules);
        jacpy_release(key);
    }
}

def find_global(module: u64, name: u64, protocol: int, fix_imports: bool) -> u64 {
    if jacpy_is_unicode(module) == 0 or jacpy_is_unicode(name) == 0 {
        builtin_stream_error("TypeError", "module and name must be strings");
    }
    checked(jacpy_audit_pickle_find(module, name));
    names: u64 = 0;
    mapped_module: u64 = 0;
    mapped_name: u64 = 0;
    imported: u64 = 0;
    try {
        names = mapped_names(module, name, False)
            if protocol < 3 and fix_imports
            else object_tuple([module, name]);
        if jacpy_is_tuple(names) == 0 or jacpy_tuple_size(names) != 2 {
            builtin_stream_error("RuntimeError", "invalid pickle import mapping");
        }
        mapped_module = required(jacpy_tuple_item(names, 0));
        mapped_name = required(jacpy_tuple_item(names, 1));
        imported = required(jacpy_import_object(mapped_module));
        try {
            return attribute_path(imported, mapped_name, protocol >= 4);
        } except boundary_failure {
            if protocol >= 4
                and "." in text_value(mapped_name)
                and jacpy_error_is("AttributeError") != 0 {
                builtin_stream_error(
                    "AttributeError",
                    "Can't resolve path "
                        + repr_value(name)
                        + " on module "
                        + repr_value(module)
                );
            }
            raise boundary_failure();
        }
    } finally {
        jacpy_release(names);
        jacpy_release(mapped_module);
        jacpy_release(mapped_name);
        jacpy_release(imported);
    }
}

def global_names(value: u64, preferred: u64, error: u64) -> u64 {
    name: u64 = 0;
    module: u64 = 0;
    try {
        if preferred != 0 {
            name = jacpy_retain(preferred);
        } else {
            name = jacpy_optional_attr(value, "__qualname__");
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            if name == 0 {
                name = required(jacpy_optional_attr(value, "__name__"));
            }
        }
        if jacpy_is_unicode(name) == 0 {
            stream_error(error, "global name must be a string");
        }
        if "<locals>" in text_value(name).split(".") {
            stream_error(error, "Can't pickle local object " + repr_value(value));
        }
        module = jacpy_optional_attr(value, "__module__");
        if jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        if module != 0 and jacpy_is_none(module) != 0 {
            jacpy_release(module);
            module = 0;
        }
        if module == 0 {
            live = required(jacpy_import_attr("sys", "modules"));
            snapshot: u64 = 0;
            keys: u64 = 0;
            try {
                snapshot = required(jacpy_dict_copy(live));
                keys = required(jacpy_dict_keys(snapshot));
                for i in range(int(jacpy_list_size(keys))) {
                    candidate = required(jacpy_list_item(keys, i64(i)));
                    imported: u64 = 0;
                    found: u64 = 0;
                    try {
                        if jacpy_is_unicode(candidate) == 0
                            or text_value(candidate) in ["__main__", "__mp_main__"] {
                            continue;
                        }
                        imported = required(jacpy_dict_get(snapshot, candidate));
                        if jacpy_is_none(imported) != 0 {
                            continue;
                        }
                        try {
                            found = attribute_path(imported, name, True);
                        } except boundary_failure {
                            if jacpy_error_is("Exception") != 0 {
                                jacpy_release(jacpy_error_take());
                                continue;
                            }
                            raise boundary_failure();
                        }
                        if found == value {
                            module = jacpy_retain(candidate);
                            break;
                        }
                    } finally {
                        jacpy_release(candidate);
                        jacpy_release(imported);
                        jacpy_release(found);
                    }
                }
            } finally {
                jacpy_release(live);
                jacpy_release(snapshot);
                jacpy_release(keys);
            }
            if module == 0 {
                module = text_object("__main__");
            }
        }
        if jacpy_is_unicode(module) == 0 {
            stream_error(error, "module name must be a string");
        }
        imported: u64 = 0;
        found: u64 = 0;
        try {
            imported = required(jacpy_import_object(module));
            found = attribute_path(imported, name, True);
            if found != value {
                stream_error(
                    error,
                    "Can't pickle "
                        + repr_value(value)
                        + ": it's not the same object as "
                        + text_value(module)
                        + "."
                        + text_value(name)
                );
            }
        } except boundary_failure {
            if jacpy_error_is("ImportError") != 0
                or jacpy_error_is("AttributeError") != 0
                or jacpy_error_is("ValueError") != 0 {
                missing_attribute = jacpy_error_is("AttributeError") != 0;
                cause = jacpy_error_take();
                reason: u64 = 0;
                try {
                    reason = required(jacpy_object_str(cause));
                    message = "Can't pickle "
                        + repr_value(value)
                        + ": "
                        + (
                            "it's not found as "
                                + text_value(module)
                                + "."
                                + text_value(name)
                                if missing_attribute
                                else text_value(reason)
                        );
                    jacpy_error_restore(jacpy_retain(cause));
                    stream_error(error, message);
                } finally {
                    jacpy_release(cause);
                    jacpy_release(reason);
                }
            }
            raise boundary_failure();
        } finally {
            jacpy_release(imported);
            jacpy_release(found);
        }
        return object_tuple([module, name]);
    } finally {
        jacpy_release(name);
        jacpy_release(module);
    }
}
