glob:priv INT_MAX: i64 = 0x7FFFFFFF;

def:priv semlock_dealloc(instance: ptr[PyObject]);

def:priv semlock_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

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
         members=semlock_members,
         record_size=SEMLOCK_FIELDS_SIZE,
         generic_getattr=True,
         generic_setattr=True
     );

def:priv add_semlock(module: ptr[PyObject]) -> bool;

def:priv add_flags(module: ptr[PyObject]) -> bool;

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_multiprocessing", "", module_methods, ModuleHooks(execute=execute)
     );

def:pub PyInit__multiprocessing -> ptr[PyObject];

impl semlock_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SemLock_token.handle);
}

impl semlock_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, SemLock_token.handle, visitor, context);
}

impl add_semlock(module: ptr[PyObject]) -> bool {
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
        and PyDict_SetItemString(namespace, ptr[u8]("SEM_VALUE_MAX"), value) == 0;
    jacpy_release(value);
    jacpy_release(namespace);
    if not stored {
        jacpy_release(semlock);
        return False;
    }
    return add_owned(module, "SemLock", semlock);
}

impl add_flags(module: ptr[PyObject]) -> bool {
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
        if not value or dict_set_text(flags, name, value) < 0 {
            jacpy_release(value);
            jacpy_release(flags);
            return False;
        }
        jacpy_release(value);
    }
    return add_owned(module, "flags", flags);
}

impl execute(module: ptr[PyObject]) -> i32 {
    if HAVE_SEM_OPEN and not add_semlock(module) {
        return i32(-1);
    }
    return i32(0) if add_flags(module) else i32(-1);
}

impl PyInit__multiprocessing -> ptr[PyObject] {
    return definition.initialize();
}
