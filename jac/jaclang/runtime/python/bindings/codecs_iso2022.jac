"""The _codecs_iso2022 module: getcodec() and the module's map capsules."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks
}
import from jaclang.runtime.python.modules.codecs_iso2022 {
    codecs_iso2022_exec,
    codecs_iso2022_getcodec
}

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
