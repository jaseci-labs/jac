"""The _queue module: SimpleQueue over native FIFO state, and Empty."""

import from jaclang.runtime.python.cpython_api { NULL, Py_GenericAlias, PyObject }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    clear_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.queue {
    SimpleQueue_doc,
    SimpleQueue_methods,
    queue_module_doc,
    simplequeue_methods___class_getitem___doc,
    simplequeue_new_new
}
import from jaclang.runtime.python.modules.queue { SimpleQueue_token }

def:priv deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, queue_type.handle);
}

def:priv clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, queue_type.handle);
}

def:priv traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, queue_type.handle, visitor, context);
}

glob:priv queue_type = TypeDefinition(
         "_queue.SimpleQueue",
         SimpleQueue_doc,
         SimpleQueue_methods
             + [
                 MethodDefinition(
                     "__class_getitem__",
                     MethodCallbacks(positional=Py_GenericAlias),
                     simplequeue_methods___class_getitem___doc,
                     24
                 )
             ],
         u64(
             TypeFlags.BASETYPE.value | TypeFlags.GC.value | TypeFlags.IMMUTABLE.value
         ),
         TypeHooks(
             create=simplequeue_new_new,
             dealloc=deallocate,
             traverse=traverse,
             clear=clear
         ),
         weaklist=True
     );

# queuemodule_exec(): Empty in state slot 1, SimpleQueue in slot 0.
def:priv execute(module: ptr[PyObject]) -> i32 {
    SimpleQueue_token.handle = queue_type.handle;
    if not add_state_owned(
        module,
        1,
        "Empty",
        jacpy_binding_exception(
            "_queue.Empty", NULL, "Exception raised by Queue.get(block=0)/get_nowait()."
        )
    ) {
        return i32(-1);
    }
    return i32(0)
        if add_state_owned(module, 0, "SimpleQueue", queue_type.create(module))
        else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "_queue", queue_module_doc, [], ModuleHooks(execute=execute), 2
     );

def:pub PyInit__queue -> ptr[PyObject] {
    return definition.initialize();
}
