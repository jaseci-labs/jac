glob:priv definition = ModuleDefinition(
         "_imp",
         "(Extremely) low-level import machinery bits as used by importlib.",
         module_methods,
         hooks=ModuleHooks(execute=imp_module_exec)
     );

def:pub PyInit__imp -> ptr[PyObject];

impl PyInit__imp -> ptr[PyObject] {
    return definition.initialize();
}
