"""Python Random type, signatures, and native Mersenne Twister state lifetime."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_state_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    TypeSlot,
    jacpy_binding_allocate,
    jacpy_binding_free,
    jacpy_binding_typeof,
    jacpy_binding_slot,
    jacpy_binding_base
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_clear,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke
}
import from jaclang.runtime.python.modules.random {
    mt19937,
    jacpy_random_new,
    jacpy_random_seed,
    jacpy_random_float,
    jacpy_random_getstate,
    jacpy_random_setstate,
    jacpy_random_bits
}
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_none,
    jacpy_float,
    jacpy_is_none,
    jacpy_dict_size,
    jacpy_long_u64,
    jacpy_long_sign,
    jacpy_index,
    jacpy_error_pending,
    object_error
}

def:priv state_of(instance: u64) -> (mt19937 | None) {
    if jacpy_binding_native_present(instance, random_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, random_type.handle);
        if isinstance(state, mt19937) {
            return state;
        }
    }
    object_error("SystemError", "native Random state is unavailable");
    return None;
}

def:priv create(type: u64, args: u64, kwargs: u64) -> u64 {
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return 0;
    }
    if jacpy_binding_native_set(instance, random_type.handle, jacpy_random_new()) < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv deallocate(instance: u64) {
    jacpy_binding_native_clear(instance, random_type.handle);
    jacpy_binding_free(instance);
}

glob:priv init_signature = CallSignature("Random", ["seed"], 0, 1, 1),
     seed_signature = CallSignature("seed", ["n"], 0, 1, 1);

def:priv initialize(instance: u64, args: u64, kwargs: u64) -> i32 {
    type = jacpy_binding_typeof(instance);
    base = jacpy_binding_base(type, random_type.handle);
    if base == 0 {
        return i32(-1);
    }
    reject_keywords = type == base
        or jacpy_binding_slot(type, i64(TypeSlot.NEW.value))
            == jacpy_binding_slot(base, i64(TypeSlot.NEW.value));
    jacpy_release(base);
    if reject_keywords and kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
        object_error("TypeError", "Random() takes no keyword arguments");
        return i32(-1);
    }
    bound = BoundArguments([u64(0)]);
    if not init_signature.bind(bound, args, 0) {
        return i32(-1);
    }
    state = state_of(instance);
    if state is None {
        return i32(-1);
    }
    seed = bound.values[0];
    return i32(
        jacpy_random_seed(
            state, u64(0) if seed == 0 or jacpy_is_none(seed) != 0 else seed
        )
    );
}

def:priv seed_bound(args: BoundArguments) -> u64 {
    state = state_of(args.context);
    if state is None {
        return 0;
    }
    seed = args.values[0];
    if jacpy_random_seed(
        state, u64(0) if seed == 0 or jacpy_is_none(seed) != 0 else seed
    )
        < 0 {
        return 0;
    }
    return jacpy_none();
}

def:priv seed_call(instance: u64, args: u64) -> u64 {
    return invoke(seed_signature, args, 0, seed_bound, instance);
}

def:priv random_call(instance: u64, unused: u64) -> u64 {
    state = state_of(instance);
    if state is None {
        return 0;
    }
    return jacpy_float(jacpy_random_float(state));
}

def:priv getstate_call(instance: u64, unused: u64) -> u64 {
    state = state_of(instance);
    if state is None {
        return 0;
    }
    return jacpy_random_getstate(state);
}

def:priv setstate_call(instance: u64, value: u64) -> u64 {
    state = state_of(instance);
    if state is None or jacpy_random_setstate(state, value) < 0 {
        return 0;
    }
    return jacpy_none();
}

def:priv bits_call(instance: u64, value: u64) -> u64 {
    index = jacpy_index(value);
    if index == 0 {
        return 0;
    }
    if jacpy_long_sign(index) < 0 {
        jacpy_release(index);
        object_error("ValueError", "number of bits must be non-negative");
        return 0;
    }
    bits = jacpy_long_u64(index);
    jacpy_release(index);
    if jacpy_error_pending() != 0 {
        return 0;
    }
    state = state_of(instance);
    if state is None {
        return 0;
    }
    return jacpy_random_bits(state, bits);
}

glob:priv random_type = TypeDefinition(
         "_random.Random",
         "Random() -> create a random number generator with its own internal state.",
         [
             MethodDefinition(
                 "seed",
                 MethodCallbacks(positional=seed_call),
                 "seed($self, n=None, /)\n--\n\nInitialize generator state.",
                 flags=1
             ),
             MethodDefinition(
                 "random",
                 MethodCallbacks(positional=random_call),
                 "random($self, /)\n--\n\nReturn a random float in [0, 1).",
                 flags=4
             ),
             MethodDefinition(
                 "getstate",
                 MethodCallbacks(positional=getstate_call),
                 "getstate($self, /)\n--\n\nReturn generator state.",
                 flags=4
             ),
             MethodDefinition(
                 "setstate",
                 MethodCallbacks(positional=setstate_call),
                 "setstate($self, state, /)\n--\n\nRestore generator state.",
                 flags=8
             ),
             MethodDefinition(
                 "getrandbits",
                 MethodCallbacks(positional=bits_call),
                 "getrandbits($self, k, /)\n--\n\nReturn an integer with k random bits.",
                 flags=8
             )
         ],
         u64(TypeFlags.BASETYPE.value),
         TypeHooks(create=create, initialize=initialize, dealloc=deallocate)
     );

def:priv execute(module: u64) -> i32 {
    return i32(0)
        if add_state_owned(module, 0, "Random", random_type.create(module))
        else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "_random",
         "Mersenne Twister implemented in native Jac.",
         [],
         ModuleHooks(execute=execute),
         1
     );

def:pub PyInit__random -> u64 {
    return definition.initialize();
}
