def:priv clinic_methods -> list[MethodDefinition];

def:pub PyInit__thread -> ptr[PyObject];

impl clinic_methods -> list[MethodDefinition] {
    selected: list[MethodDefinition] = [];
    if not HAS_THREAD_NAMES {
        return selected;
    }
    for name in ["set_name", "_get_name"] {
        for method in module_methods {
            if method.name == name {
                selected.append(method);
            }
        }
    }
    return selected;
}

impl PyInit__thread -> ptr[PyObject] {
    definition = addressof(thread_module).view(1);
    if int(definition[0].m_free) == 0 {
        methods = clinic_methods();
        if len(methods) > 0 and not clinic_methods_installed() {
            table = method_table(methods);
            if not table {
                return NULL;
            }
            install_clinic_methods(table, i64(len(methods)));
        }
        definition[0].m_traverse = int(ptr(thread_module_traverse));
        definition[0].m_clear = int(ptr(thread_module_clear));
        definition[0].m_free = int(ptr(thread_module_free));
    }
    return PyModuleDef_Init(ptr[PyModuleDef](addressof(thread_module)));
}
