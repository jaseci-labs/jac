"""The _tracemalloc module over its generated clinic table."""

glob:priv definition = ModuleDefinition(
         "_tracemalloc",
         "Debug module to trace memory blocks allocated by Python.",
         module_methods
     );

def:pub PyInit__tracemalloc -> ptr[PyObject] {
    return definition.initialize();
}
