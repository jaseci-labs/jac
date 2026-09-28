"""Python Random type, signatures, and native Mersenne Twister state lifetime."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyFloat_FromDouble,
    PyLong_AsUnsignedLongLong,
    PyNumber_Index,
    PyObject,
    PyType_GetSlot,
    Py_TYPE,
    jacpy_dict_size,
    jacpy_error_pending,
    jacpy_is_none,
    jacpy_long_sign,
    jacpy_none,
    jacpy_release
}
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
import from jaclang.runtime.python.capi { object_error }

def:priv state_of(instance: ptr[PyObject]) -> (mt19937 | None) {
    if jacpy_binding_native_present(instance, random_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, random_type.handle);
        if isinstance(state, mt19937) {
            return state;
        }
    }
    object_error("SystemError", "native Random state is unavailable");
    return None;
}

def:priv create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return NULL;
    }
    if jacpy_binding_native_set(instance, random_type.handle, jacpy_random_new()) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def:priv deallocate(instance: ptr[PyObject]) {
    jacpy_binding_native_clear(instance, random_type.handle);
    jacpy_binding_free(instance);
}

glob:priv init_signature = CallSignature("Random", ["seed"], 0, 1, 1),
     seed_signature = CallSignature("seed", ["n"], 0, 1, 1);

def:priv initialize(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    type = Py_TYPE(instance);
    base = jacpy_binding_base(type, random_type.handle);
    if base == 0 {
        return i32(-1);
    }
    reject_keywords = type == base
        or PyType_GetSlot(type, i32(TypeSlot.NEW.value))
            == PyType_GetSlot(base, i32(TypeSlot.NEW.value));
    jacpy_release(base);
    if reject_keywords and kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
        object_error("TypeError", "Random() takes no keyword arguments");
        return i32(-1);
    }
    bound = BoundArguments([NULL]);
    if not init_signature.bind(bound, args, NULL) {
        return i32(-1);
    }
    state = state_of(instance);
    if state is None {
        return i32(-1);
    }
    seed = bound.values[0];
    return i32(
        jacpy_random_seed(
            state, NULL if seed == 0 or jacpy_is_none(seed) != 0 else seed
        )
    );
}

def:priv seed_bound(args: BoundArguments) -> ptr[PyObject] {
    state = state_of(args.context);
    if state is None {
        return NULL;
    }
    seed = args.values[0];
    if jacpy_random_seed(state, NULL if seed == 0 or jacpy_is_none(seed) != 0 else seed)
        < 0 {
        return NULL;
    }
    return jacpy_none();
}

def:priv seed_call(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(seed_signature, args, NULL, seed_bound, instance);
}

def:priv random_call(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_of(instance);
    if state is None {
        return NULL;
    }
    return PyFloat_FromDouble(jacpy_random_float(state));
}

def:priv getstate_call(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_of(instance);
    if state is None {
        return NULL;
    }
    return jacpy_random_getstate(state);
}

def:priv setstate_call(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_of(instance);
    if state is None or jacpy_random_setstate(state, value) < 0 {
        return NULL;
    }
    return jacpy_none();
}

def:priv bits_call(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    index = PyNumber_Index(value);
    if index == 0 {
        return NULL;
    }
    if jacpy_long_sign(index) < 0 {
        jacpy_release(index);
        object_error("ValueError", "number of bits must be non-negative");
        return NULL;
    }
    bits = PyLong_AsUnsignedLongLong(index);
    jacpy_release(index);
    if jacpy_error_pending() != 0 {
        return NULL;
    }
    state = state_of(instance);
    if state is None {
        return NULL;
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

def:priv execute(module: ptr[PyObject]) -> i32 {
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

def:pub PyInit__random -> ptr[PyObject] {
    return definition.initialize();
}
