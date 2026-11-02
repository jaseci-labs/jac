"""The _codecs module over its generated clinic table."""

glob:priv definition = ModuleDefinition("_codecs", "", module_methods);

def:pub PyInit__codecs -> ptr[PyObject] {
    return definition.initialize();
}
