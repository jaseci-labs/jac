def:priv install_method_tables -> bool;

def:pub PyInit_itertools -> ptr[PyObject];

impl install_method_tables -> bool {
    module_def = addressof(itertoolsmodule);
    if module_def.view(1)[0].m_methods {
        return True;
    }
    chain_table_methods = list(chain_methods);
    chain_table_methods.append(
        MethodDefinition(
            "__class_getitem__",
            MethodCallbacks(positional=Py_GenericAlias),
            chain_class_getitem_doc,
            i64(METH_O | METH_CLASS)
        )
    );
    chain_table = method_table(chain_table_methods);
    if not chain_table {
        return False;
    }
    module_table = method_table(module_methods);
    if not module_table {
        return False;
    }
    addressof(chain_slots).view(1)[0].pfunc = ptr(chain_table);
    module_def.view(1)[0].m_methods = module_table;
    return True;
}

impl PyInit_itertools -> ptr[PyObject] {
    if not install_method_tables() {
        return NULL;
    }
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(itertoolsmodule)));
}
