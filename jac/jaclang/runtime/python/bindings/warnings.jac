glob:priv definition = ModuleDefinition(
         "_warnings",
         "_warnings provides basic warning filtering support.\nIt is a helper module to speed up interpreter start-up.",
         module_methods,
         hooks=ModuleHooks(execute=warnings_module_exec)
     );

def:pub PyInit__warnings -> ptr[PyObject];

import from c {
    def _PyWarnings_Init -> ptr[PyObject] {
        return PyInit__warnings();
    }
}

impl PyInit__warnings -> ptr[PyObject] {
    return definition.initialize();
}
