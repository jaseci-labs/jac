glob:priv definition = ModuleDefinition(
         "marshal",
         module_doc,
         module_methods,
         hooks=ModuleHooks(execute=marshal_module_exec)
     );

def:pub PyInit_marshal -> ptr[PyObject];

import from c {
    def PyMarshal_Init -> ptr[PyObject] {
        return PyInit_marshal();
    }
}

impl PyInit_marshal -> ptr[PyObject] {
    return definition.initialize();
}
