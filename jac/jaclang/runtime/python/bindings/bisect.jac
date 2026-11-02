"""The _bisect module: its clinic-generated functions and module definition."""

glob:priv definition = ModuleDefinition("_bisect", module_doc, module_methods);

def:pub PyInit__bisect -> ptr[PyObject] {
    return definition.initialize();
}
