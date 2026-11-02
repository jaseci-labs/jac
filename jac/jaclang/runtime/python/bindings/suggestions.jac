"""The _suggestions module over its generated clinic table."""

glob:priv definition = ModuleDefinition("_suggestions", "", module_methods);

def:pub PyInit__suggestions -> ptr[PyObject] {
    return definition.initialize();
}
