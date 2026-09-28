"""The _multiprocessing module: SemLock, sem_unlink() and the flags dict."""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    PyDict_New,
    PyDict_SetItemString,
    PyLong_FromLong,
    PyObject,
    PyType_GetDict
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_owned
}
import from jaclang.runtime.python.bindings.type {
    PropertyCallbacks,
    PropertyDefinition,
    TypeDefinition,
    TypeFlags,
    TypeHooks
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.multiprocessing {
    SemLock_methods,
    _multiprocessing_SemLock_new,
    module_methods
}
import from jaclang.runtime.python.modules.multiprocessing {
    SemLock_token,
    semlock_handle,
    semlock_name,
    semlock_of
}
import from jaclang.runtime.python.modules.multiprocessing_constants { SEM_VALUE_MAX }
import from jaclang.runtime.python.modules.semaphore_platform {
    HAVE_BROKEN_SEM_GETVALUE,
    HAVE_BROKEN_SEM_UNLINK,
    HAVE_SEM_OPEN,
    HAVE_SEM_TIMEDWAIT
}

glob:priv INT_MAX: i64 = 0x7FFFFFFF;

def:priv semlock_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SemLock_token.handle);
}

def:priv semlock_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, SemLock_token.handle, visitor, context);
}

def:priv handle_member(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = semlock_of(instance);
    return semlock_handle(state) if state is not None else ptr[PyObject]();
}

def:priv kind_member(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = semlock_of(instance);
    return PyLong_FromLong(i64(state.kind)) if state is not None else ptr[PyObject]();
}

def:priv maxvalue_member(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = semlock_of(instance);
    return PyLong_FromLong(i64(state.maxvalue))
        if state is not None
        else ptr[PyObject]();
}

def:priv name_member(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = semlock_of(instance);
    return semlock_name(state) if state is not None else ptr[PyObject]();
}

glob:priv semlock_type = TypeDefinition(
         "_multiprocessing.SemLock",
         "Semaphore/Mutex type",
         SemLock_methods,
         u64(TypeFlags.BASETYPE.value | TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=_multiprocessing_SemLock_new,
             dealloc=semlock_dealloc,
             traverse=semlock_traverse
         ),
         [
             PropertyDefinition("handle", PropertyCallbacks(read=handle_member)),
             PropertyDefinition("kind", PropertyCallbacks(read=kind_member)),
             PropertyDefinition("maxvalue", PropertyCallbacks(read=maxvalue_member)),
             PropertyDefinition("name", PropertyCallbacks(read=name_member))
         ]
     );

# SemLock, with SEM_VALUE_MAX in its dict; a value that is negative as a C
# int is published as INT_MAX.
def:priv add_semlock(module: ptr[PyObject]) -> bool {
    SemLock_token.handle = semlock_type.handle;
    semlock = semlock_type.create(module);
    if not semlock {
        return False;
    }
    limit = SEM_VALUE_MAX & 0xFFFFFFFF;
    if limit >= 0x80000000 {
        limit = INT_MAX;
    }
    namespace = PyType_GetDict(semlock);
    value = PyLong_FromLong(limit);
    stored = bool(namespace)
        and bool(value)
        and PyDict_SetItemString(namespace, "SEM_VALUE_MAX", value) == 0;
    jacpy_release(value);
    jacpy_release(namespace);
    if not stored {
        jacpy_release(semlock);
        return False;
    }
    return add_owned(module, "SemLock", semlock);
}

# The configuration macros multiprocessing reads from _multiprocessing.flags.
def:priv add_flags(module: ptr[PyObject]) -> bool {
    flags = PyDict_New();
    if not flags {
        return False;
    }
    for (name, present) in [
        ("HAVE_SEM_OPEN", HAVE_SEM_OPEN),
        ("HAVE_SEM_TIMEDWAIT", HAVE_SEM_TIMEDWAIT),
        ("HAVE_BROKEN_SEM_GETVALUE", HAVE_BROKEN_SEM_GETVALUE),
        ("HAVE_BROKEN_SEM_UNLINK", HAVE_BROKEN_SEM_UNLINK)
    ] {
        if not present {
            continue;
        }
        value = PyLong_FromLong(1);
        if not value or PyDict_SetItemString(flags, name, value) < 0 {
            jacpy_release(value);
            jacpy_release(flags);
            return False;
        }
        jacpy_release(value);
    }
    return add_owned(module, "flags", flags);
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    if HAVE_SEM_OPEN and not add_semlock(module) {
        return i32(-1);
    }
    return i32(0) if add_flags(module) else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "_multiprocessing", "", module_methods, ModuleHooks(execute=execute)
     );

def:pub PyInit__multiprocessing -> ptr[PyObject] {
    return definition.initialize();
}
