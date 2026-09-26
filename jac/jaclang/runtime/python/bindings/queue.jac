"""SimpleQueue type and Python signatures over shared native FIFO state."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyLong_FromLongLong,
    PyObject,
    PyObject_IsTrue,
    PyType_GetSlot,
    Py_GenericAlias,
    Py_TYPE,
    jacpy_lock_new,
    jacpy_none,
    jacpy_release
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception,
    jacpy_binding_state_get
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    TypeSlot,
    jacpy_binding_allocate,
    jacpy_binding_base,
    jacpy_binding_owner
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present,
    dispose_payload,
    clear_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke
}
import from jaclang.runtime.python.modules.queue {
    queue_state,
    jacpy_queue_new,
    jacpy_queue_put,
    jacpy_queue_get,
    jacpy_queue_size
}
import from jaclang.runtime.python.capi { object_error }
def:priv state_of(instance: ptr[PyObject]) -> (queue_state | None) {
    if jacpy_binding_native_present(instance, queue_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, queue_type.handle);
        if isinstance(state, queue_state) {
            return state;
        }
    }
    object_error("SystemError", "native SimpleQueue state is unavailable");
    return None;
}

glob:priv init_signature = CallSignature("SimpleQueue", [], 0, 0);
def:priv create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    base = jacpy_binding_base(type, queue_type.handle);
    if base == 0 {
        return NULL;
    }
    reject_arguments = type == base
        or PyType_GetSlot(type, i32(TypeSlot.INIT.value))
            == PyType_GetSlot(base, i32(TypeSlot.INIT.value));
    jacpy_release(base);
    if reject_arguments {
        bound = BoundArguments([]);
        if not init_signature.bind(bound, args, kwargs) {
            return NULL;
        }
    }
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return NULL;
    }
    lock = jacpy_lock_new();
    if lock == 0 {
        jacpy_release(instance);
        return NULL;
    }
    if jacpy_binding_native_set(instance, queue_type.handle, jacpy_queue_new(lock))
        < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

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

glob:priv put_signature = CallSignature("put", ["item", "block", "timeout"], 1, 3),
     put_nowait_signature = CallSignature("put_nowait", ["item"], 1, 1),
     get_signature = CallSignature("get", ["block", "timeout"], 0, 2);

def:priv put_bound(args: BoundArguments) -> ptr[PyObject] {
    if len(args.values) > 1
        and args.values[1] != 0
        and PyObject_IsTrue(args.values[1]) < 0 {
        return NULL;
    }
    state = state_of(args.context);
    if state is None {
        return NULL;
    }
    jacpy_queue_put(state, args.values[0]);
    return jacpy_none();
}

def:priv put_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(put_signature, args, kwargs, put_bound, instance);
}

def:priv put_nowait_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(put_nowait_signature, args, kwargs, put_bound, instance);
}

def:priv get_item(
    instance: ptr[PyObject], block: i64, timeout: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_of(instance);
    if state is None {
        return NULL;
    }
    module = jacpy_binding_owner(Py_TYPE(instance), definition.handle);
    if module == 0 {
        return NULL;
    }
    return jacpy_queue_get(state, jacpy_binding_state_get(module, 1), block, timeout);
}

def:priv get_bound(args: BoundArguments) -> ptr[PyObject] {
    block: i64 = 1;
    if args.values[0] != 0 {
        block = PyObject_IsTrue(args.values[0]);
        if block < 0 {
            return NULL;
        }
    }
    if args.values[1] == 0 {
        args.values[1] = jacpy_none();
    }
    return get_item(args.context, block, args.values[1]);
}

def:priv get_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(get_signature, args, kwargs, get_bound, instance);
}

def:priv get_nowait_call(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    timeout = jacpy_none();
    result = get_item(instance, 0, timeout);
    jacpy_release(timeout);
    return result;
}

def:priv empty_call(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_of(instance);
    if state is None {
        return NULL;
    }
    return PyBool_FromLong(i64(jacpy_queue_size(state) == 0));
}

def:priv size_call(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLongLong(jacpy_queue_size(state));
}

glob:priv queue_type = TypeDefinition(
         "_queue.SimpleQueue",
         "SimpleQueue()\n--\n\nSimple, unbounded, reentrant FIFO queue.",
         [
             MethodDefinition(
                 "put",
                 MethodCallbacks(keywords=put_call),
                 "put($self, /, item, block=True, timeout=None)\n--\n\nOperate on the FIFO queue."
             ),
             MethodDefinition(
                 "put_nowait",
                 MethodCallbacks(keywords=put_nowait_call),
                 "put_nowait($self, /, item)\n--\n\nOperate on the FIFO queue."
             ),
             MethodDefinition(
                 "get",
                 MethodCallbacks(keywords=get_call),
                 "get($self, /, block=True, timeout=None)\n--\n\nOperate on the FIFO queue."
             ),
             MethodDefinition(
                 "get_nowait",
                 MethodCallbacks(positional=get_nowait_call),
                 "get_nowait($self, /)\n--\n\nGet an item or raise Empty.",
                 flags=4
             ),
             MethodDefinition(
                 "empty",
                 MethodCallbacks(positional=empty_call),
                 "empty($self, /)\n--\n\nReturn whether the queue is empty.",
                 flags=4
             ),
             MethodDefinition(
                 "qsize",
                 MethodCallbacks(positional=size_call),
                 "qsize($self, /)\n--\n\nReturn the approximate queue size.",
                 flags=4
             ),
             MethodDefinition(
                 "__class_getitem__",
                 MethodCallbacks(positional=Py_GenericAlias),
                 "Create a generic queue alias.",
                 flags=24
             )
         ],
         u64(
             TypeFlags.BASETYPE.value
                 | TypeFlags.GC.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.MANAGED_WEAKREF.value
         ),
         TypeHooks(create=create, dealloc=deallocate, traverse=traverse, clear=clear)
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    if not add_state_owned(
        module,
        1,
        "Empty",
        jacpy_binding_exception(
            "_queue.Empty", "", "Exception raised by Queue.get(block=0)/get_nowait()."
        )
    ) {
        return i32(-1);
    }
    return i32(0)
        if add_state_owned(module, 0, "SimpleQueue", queue_type.create(module))
        else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "_queue", "Native Jac FIFO queue.", [], ModuleHooks(execute=execute), 2
     );

def:pub PyInit__queue -> ptr[PyObject] {
    return definition.initialize();
}
