def:priv class_getitem -> MethodDefinition;

def:priv ordered_array_methods -> list[MethodDefinition];

def:priv install_method_tables -> bool;

def:pub PyInit_array -> ptr[PyObject];

impl class_getitem -> MethodDefinition {
    return MethodDefinition(
        "__class_getitem__",
        MethodCallbacks(positional=Py_GenericAlias),
        array_methods___class_getitem___doc,
        i64(METH_O | METH_CLASS)
    );
}

impl ordered_array_methods -> list[MethodDefinition] {
    selected: list[MethodDefinition] = [];
    for name in [
        "append",
        "buffer_info",
        "byteswap",
        "clear",
        "__copy__",
        "count",
        "__deepcopy__",
        "extend",
        "fromfile",
        "fromlist",
        "frombytes",
        "fromunicode",
        "index",
        "insert",
        "pop",
        "__reduce_ex__",
        "remove",
        "reverse",
        "tofile",
        "tolist",
        "tobytes",
        "tounicode",
        "__sizeof__"
    ] {
        for method in array_methods {
            if method.name == name {
                selected.append(method);
            }
        }
    }
    selected.append(class_getitem());
    return selected;
}

impl install_method_tables -> bool {
    array_methods_slot = addressof(array_slots) + ARRAY_SLOTS_METHODS;
    iter_methods_slot = addressof(arrayiter_slots) + ARRAYITER_SLOTS_METHODS;
    if array_methods_slot.view(1)[0].pfunc {
        return True;
    }
    array_table = method_table(ordered_array_methods());
    if not array_table {
        return False;
    }
    iter_table = method_table(arrayiterator_methods);
    if not iter_table {
        return False;
    }
    module_table = method_table(module_methods);
    if not module_table {
        return False;
    }
    array_methods_slot.view(1)[0].pfunc = ptr(array_table);
    iter_methods_slot.view(1)[0].pfunc = ptr(iter_table);
    addressof(arraymodule).view(1)[0].m_methods = module_table;
    return True;
}

impl PyInit_array -> ptr[PyObject] {
    definition = addressof(arraymodule).view(1);
    if int(definition[0].m_free) == 0 {
        if not install_method_tables() {
            return NULL;
        }
        definition[0].m_traverse = int(ptr(array_traverse));
        definition[0].m_clear = int(ptr(array_clear));
        definition[0].m_free = int(ptr(array_free));
    }
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(arraymodule)));
}
