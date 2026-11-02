"""The _statistics module: its clinic-generated function."""

glob:priv definition = ModuleDefinition(
         "_statistics", statistics_doc, module_methods
     );

def:pub PyInit__statistics -> ptr[PyObject] {
    return definition.initialize();
}
