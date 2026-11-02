"""The _codecs_iso2022 module: getcodec() and the module's map capsules."""

def:priv execute(module: ptr[PyObject]) -> i32 {
    return codecs_iso2022_exec(module);
}

def:priv getcodec(module: ptr[PyObject], encoding: ptr[PyObject]) -> ptr[PyObject] {
    return codecs_iso2022_getcodec(module, encoding);
}

glob:priv definition = ModuleDefinition(
         "_codecs_iso2022",
         "",
         [
             MethodDefinition(
                 "getcodec", MethodCallbacks(positional=getcodec), "", flags=8
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__codecs_iso2022 -> ptr[PyObject] {
    return definition.initialize();
}
