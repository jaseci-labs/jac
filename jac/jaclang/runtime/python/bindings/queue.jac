"""SimpleQueue type and Python signatures over shared native FIFO state."""
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
    jacpy_binding_typeof,
    jacpy_binding_slot,
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
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_none,
    jacpy_boolean,
    jacpy_int,
    jacpy_truth,
    jacpy_lock_new,
    object_error
}
import from c { def jacpy_binding_generic_alias(type: u64, argument: u64) -> u64;  }

def:priv state_of(instance: u64) -> (queue_state | None) {
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
def:priv create(type: u64, args: u64, kwargs: u64) -> u64 {
    base = jacpy_binding_base(type, queue_type.handle);
    if base == 0 {
        return 0;
    }
    reject_arguments = type == base
        or jacpy_binding_slot(type, i64(TypeSlot.INIT.value))
            == jacpy_binding_slot(base, i64(TypeSlot.INIT.value));
    jacpy_release(base);
    if reject_arguments {
        bound = BoundArguments([]);
        if not init_signature.bind(bound, args, kwargs) {
            return 0;
        }
    }
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return 0;
    }
    lock = jacpy_lock_new();
    if lock == 0 {
        jacpy_release(instance);
        return 0;
    }
    if jacpy_binding_native_set(instance, queue_type.handle, jacpy_queue_new(lock))
        < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv deallocate(instance: u64) {
    dispose_payload(instance, queue_type.handle);
}

def:priv clear(instance: u64) -> i32 {
    return clear_payload(instance, queue_type.handle);
}

def:priv traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, queue_type.handle, visitor, context);
}

glob:priv put_signature = CallSignature("put", ["item", "block", "timeout"], 1, 3),
     put_nowait_signature = CallSignature("put_nowait", ["item"], 1, 1),
     get_signature = CallSignature("get", ["block", "timeout"], 0, 2);

def:priv put_bound(args: BoundArguments) -> u64 {
    if len(args.values) > 1
        and args.values[1] != 0
        and jacpy_truth(args.values[1]) < 0 {
        return 0;
    }
    state = state_of(args.context);
    if state is None {
        return 0;
    }
    jacpy_queue_put(state, args.values[0]);
    return jacpy_none();
}

def:priv put_call(instance: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(put_signature, args, kwargs, put_bound, instance);
}

def:priv put_nowait_call(instance: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(put_nowait_signature, args, kwargs, put_bound, instance);
}

def:priv get_item(instance: u64, block: i64, timeout: u64) -> u64 {
    state = state_of(instance);
    if state is None {
        return 0;
    }
    module = jacpy_binding_owner(jacpy_binding_typeof(instance), definition.handle);
    if module == 0 {
        return 0;
    }
    return jacpy_queue_get(state, jacpy_binding_state_get(module, 1), block, timeout);
}

def:priv get_bound(args: BoundArguments) -> u64 {
    block: i64 = 1;
    if args.values[0] != 0 {
        block = jacpy_truth(args.values[0]);
        if block < 0 {
            return 0;
        }
    }
    if args.values[1] == 0 {
        args.values[1] = jacpy_none();
    }
    return get_item(args.context, block, args.values[1]);
}

def:priv get_call(instance: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(get_signature, args, kwargs, get_bound, instance);
}

def:priv get_nowait_call(instance: u64, unused: u64) -> u64 {
    timeout = jacpy_none();
    result = get_item(instance, 0, timeout);
    jacpy_release(timeout);
    return result;
}

def:priv empty_call(instance: u64, unused: u64) -> u64 {
    state = state_of(instance);
    if state is None {
        return 0;
    }
    return jacpy_boolean(i64(jacpy_queue_size(state) == 0));
}

def:priv size_call(instance: u64, unused: u64) -> u64 {
    state = state_of(instance);
    if state is None {
        return 0;
    }
    return jacpy_int(jacpy_queue_size(state));
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
                 MethodCallbacks(positional=jacpy_binding_generic_alias),
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

def:priv execute(module: u64) -> i32 {
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

def:pub PyInit__queue -> u64 {
    return definition.initialize();
}
