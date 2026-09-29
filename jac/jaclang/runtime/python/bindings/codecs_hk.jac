"""The _codecs_hk module: getcodec() and the module's map capsules."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks
}
import from jaclang.runtime.python.modules.codecs_hk {
    codecs_hk_exec,
    codecs_hk_getcodec
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    return codecs_hk_exec(module);
}

def:priv getcodec(module: ptr[PyObject], encoding: ptr[PyObject]) -> ptr[PyObject] {
    return codecs_hk_getcodec(module, encoding);
}

glob:priv definition = ModuleDefinition(
         "_codecs_hk",
         "",
         [
             MethodDefinition(
                 "getcodec", MethodCallbacks(positional=getcodec), "", flags=8
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__codecs_hk -> ptr[PyObject] {
    return definition.initialize();
}
