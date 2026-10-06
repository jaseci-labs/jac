"""The _codecs_tw module: getcodec() and the module's map capsules."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks
}
import from jaclang.runtime.python.modules.codecs_tw {
    codecs_tw_exec,
    codecs_tw_getcodec
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    return codecs_tw_exec(module);
}

def:priv getcodec(module: ptr[PyObject], encoding: ptr[PyObject]) -> ptr[PyObject] {
    return codecs_tw_getcodec(module, encoding);
}

glob:priv definition = ModuleDefinition(
         "_codecs_tw",
         "",
         [
             MethodDefinition(
                 "getcodec", MethodCallbacks(positional=getcodec), "", flags=8
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__codecs_tw -> ptr[PyObject] {
    return definition.initialize();
}
