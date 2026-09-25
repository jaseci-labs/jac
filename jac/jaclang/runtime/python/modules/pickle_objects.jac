"""Shared native global-name resolution for pickle readers and writers.

Import compatibility maps remain retained standard-library data. Attribute
traversal, identity validation and map selection execute in native Jac.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_Copy,
    PyDict_Keys,
    PyErr_GetRaisedException,
    PyErr_SetRaisedException,
    PyImport_Import,
    PyImport_ImportModuleAttrString,
    PyList_GetItemRef,
    PyObject,
    PyObject_GetAttr,
    PyObject_Str,
    PyTuple_Size,
    Py_NewRef,
    jacpy_audit_pickle_find,
    jacpy_dict_get,
    jacpy_error_is,
    jacpy_error_pending,
    jacpy_is_none,
    jacpy_is_tuple,
    jacpy_is_unicode,
    jacpy_list_size,
    jacpy_optional_attr,
    jacpy_release,
    jacpy_tuple_item
}
import from jaclang.runtime.python.capi {
    repr_value,
    required,
    checked,
    boundary_failure,
    object_tuple,
    text_object,
    text_value
}
import from jaclang.runtime.python.modules.pickle_stream {
    stream_error,
    builtin_stream_error
}

def attribute_path(
    value: ptr[PyObject], name: ptr[PyObject], dotted: bool
) -> ptr[PyObject] {
    if not dotted {
        return required(PyObject_GetAttr(value, name));
    }
    current = Py_NewRef(value);
    try {
        for component in text_value(name).split(".") {
            field = text_object(component);
            try {
                result = required(PyObject_GetAttr(current, field));
                jacpy_release(current);
                current = result;
            } finally {
                jacpy_release(field);
            }
        }
        return Py_NewRef(current);
    } finally {
        jacpy_release(current);
    }
}

def mapped_names(
    module: ptr[PyObject], name: ptr[PyObject], reverse: bool
) -> ptr[PyObject] {
    names: ptr[PyObject] = NULL;
    modules: ptr[PyObject] = NULL;
    key: ptr[PyObject] = NULL;
    try {
        names = required(
            PyImport_ImportModuleAttrString(
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
            PyImport_ImportModuleAttrString(
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

def find_global(
    module: ptr[PyObject], name: ptr[PyObject], protocol: int, fix_imports: bool
) -> ptr[PyObject] {
    if jacpy_is_unicode(module) == 0 or jacpy_is_unicode(name) == 0 {
        builtin_stream_error("TypeError", "module and name must be strings");
    }
    checked(jacpy_audit_pickle_find(module, name));
    names: ptr[PyObject] = NULL;
    mapped_module: ptr[PyObject] = NULL;
    mapped_name: ptr[PyObject] = NULL;
    imported: ptr[PyObject] = NULL;
    try {
        names = mapped_names(module, name, False)
            if protocol < 3 and fix_imports
            else object_tuple([module, name]);
        if jacpy_is_tuple(names) == 0 or PyTuple_Size(names) != 2 {
            builtin_stream_error("RuntimeError", "invalid pickle import mapping");
        }
        mapped_module = required(jacpy_tuple_item(names, 0));
        mapped_name = required(jacpy_tuple_item(names, 1));
        imported = required(PyImport_Import(mapped_module));
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

def global_names(
    value: ptr[PyObject], preferred: ptr[PyObject], error: ptr[PyObject]
) -> ptr[PyObject] {
    name: ptr[PyObject] = NULL;
    module: ptr[PyObject] = NULL;
    try {
        if preferred != 0 {
            name = Py_NewRef(preferred);
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
            module = NULL;
        }
        if module == 0 {
            live = required(PyImport_ImportModuleAttrString("sys", "modules"));
            snapshot: ptr[PyObject] = NULL;
            keys: ptr[PyObject] = NULL;
            try {
                snapshot = required(PyDict_Copy(live));
                keys = required(PyDict_Keys(snapshot));
                for i in range(int(jacpy_list_size(keys))) {
                    candidate = required(PyList_GetItemRef(keys, i64(i)));
                    imported: ptr[PyObject] = NULL;
                    found: ptr[PyObject] = NULL;
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
                                jacpy_release(PyErr_GetRaisedException());
                                continue;
                            }
                            raise boundary_failure();
                        }
                        if found == value {
                            module = Py_NewRef(candidate);
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
        imported: ptr[PyObject] = NULL;
        found: ptr[PyObject] = NULL;
        try {
            imported = required(PyImport_Import(module));
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
                cause = PyErr_GetRaisedException();
                reason: ptr[PyObject] = NULL;
                try {
                    reason = required(PyObject_Str(cause));
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
                    PyErr_SetRaisedException(Py_NewRef(cause));
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
