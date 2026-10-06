"""The _codecs_jp module: getcodec() and the module's map capsules."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks
}
import from jaclang.runtime.python.modules.codecs_jp {
    codecs_jp_exec,
    codecs_jp_getcodec
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    return codecs_jp_exec(module);
}

def:priv getcodec(module: ptr[PyObject], encoding: ptr[PyObject]) -> ptr[PyObject] {
    return codecs_jp_getcodec(module, encoding);
}

glob:priv definition = ModuleDefinition(
         "_codecs_jp",
         "",
         [
             MethodDefinition(
                 "getcodec", MethodCallbacks(positional=getcodec), "", flags=8
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__codecs_jp -> ptr[PyObject] {
    return definition.initialize();
}
