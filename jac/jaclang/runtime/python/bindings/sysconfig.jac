"""The _sysconfig module over its generated clinic table."""

glob:priv definition = ModuleDefinition(
         "_sysconfig", "A helper for the sysconfig module.", module_methods
     );

def:pub PyInit__sysconfig -> ptr[PyObject] {
    return definition.initialize();
}
