"""The _codecs_kr module: getcodec() and the module's map capsules."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks
}
import from jaclang.runtime.python.modules.codecs_kr {
    codecs_kr_exec,
    codecs_kr_getcodec
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    return codecs_kr_exec(module);
}

def:priv getcodec(module: ptr[PyObject], encoding: ptr[PyObject]) -> ptr[PyObject] {
    return codecs_kr_getcodec(module, encoding);
}

glob:priv definition = ModuleDefinition(
         "_codecs_kr",
         "",
         [
             MethodDefinition(
                 "getcodec", MethodCallbacks(positional=getcodec), "", flags=8
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__codecs_kr -> ptr[PyObject] {
    return definition.initialize();
}
