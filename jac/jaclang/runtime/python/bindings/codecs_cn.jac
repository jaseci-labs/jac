"""The _codecs_cn module: getcodec() and the module's map capsules."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks
}
import from jaclang.runtime.python.modules.codecs_cn {
    codecs_cn_exec,
    codecs_cn_getcodec
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    return codecs_cn_exec(module);
}

def:priv getcodec(module: ptr[PyObject], encoding: ptr[PyObject]) -> ptr[PyObject] {
    return codecs_cn_getcodec(module, encoding);
}

glob:priv definition = ModuleDefinition(
         "_codecs_cn",
         "",
         [
             MethodDefinition(
                 "getcodec", MethodCallbacks(positional=getcodec), "", flags=8
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__codecs_cn -> ptr[PyObject] {
    return definition.initialize();
}
