"""The posix module: the generated clinic tables, the DirEntry and
ScandirIterator types, the constants, configuration tables, environ,
_have_functions and the module state, as posixmodule_exec() sets them up.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
The functions a target compiles are the METHODS of its posix_constants
table (each clinic macro's guard evaluated against the target's
pyconfig.h); the glue's per-target tables add the one definition each
target has of getgrouplist, initgroups and sendfile.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_New,
    PyDict_SetItemString,
    PyExc_ImportError,
    PyExc_OSError,
    PyList_Append,
    PyList_New,
    PyLong_FromLong,
    PyMethodDef,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyObject,
    PyObject_SelfIter,
    PyType_Modified,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    _PyType_AddMethod,
    jacpy_release
}
import from jaclang.runtime.python.layouts { METH_NOARGS, PyTypeObject as TypeLayout }
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.object_model.genericalias { Py_GenericAlias }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    add_owned,
    add_state_owned,
    jacpy_binding_module_native_set,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeFlags,
    TypeHooks
}
import from jaclang.runtime.python.bindings.clinic.posix {
    DirEntry_methods,
    module_methods,
    module_methods_darwin,
    module_methods_linux,
    os_sched_param_new
}
import from jaclang.runtime.python.modules.posix_constants {
    CONFSTR_TABLE,
    CONSTANTS,
    HAVE_CONFSTR,
    HAVE_EVENTFD,
    HAVE_FACCESSAT,
    HAVE_FCHDIR,
    HAVE_FCHMOD,
    HAVE_FCHMODAT,
    HAVE_FCHOWN,
    HAVE_FCHOWNAT,
    HAVE_FDOPENDIR,
    HAVE_FEXECVE,
    HAVE_FPATHCONF,
    HAVE_FSTATAT,
    HAVE_FSTATVFS,
    HAVE_FTRUNCATE,
    HAVE_FUTIMENS,
    HAVE_FUTIMES,
    HAVE_FUTIMESAT,
    HAVE_LCHFLAGS,
    HAVE_LCHMOD,
    HAVE_LCHOWN,
    HAVE_LINKAT,
    HAVE_LSTAT,
    HAVE_LUTIMES,
    HAVE_MEMFD_CREATE,
    HAVE_MKDIRAT,
    HAVE_MKFIFOAT,
    HAVE_MKNODAT,
    HAVE_OPENAT,
    HAVE_PATHCONF,
    HAVE_PTSNAME_R,
    HAVE_READLINKAT,
    HAVE_RENAMEAT,
    HAVE_SYMLINKAT,
    HAVE_SYSCONF,
    HAVE_TIMERFD_CREATE,
    HAVE_UNLINKAT,
    HAVE_UTIMENSAT,
    METHODS,
    PATHCONF_TABLE,
    SYSCONF_TABLE
}
import from jaclang.runtime.python.modules.posix_platform { PLATFORM, runtime_function }
import from jaclang.runtime.python.modules.posix_core {
    PosixState,
    STATE_BILLION,
    STATE_COUNT,
    STATE_DIR_ENTRY_TYPE,
    STATE_SCANDIR_ITERATOR_TYPE,
    STATE_SCHED_PARAM_TYPE,
    STATE_ST_MODE,
    convertenviron,
    state_object
}
import from jaclang.runtime.python.modules.posix_stat {
    DIR_ENTRY_MEMBERS,
    DIR_ENTRY_RECORD_SIZE,
    DirEntry_dealloc,
    DirEntry_repr,
    DirEntry_token,
    ScandirIterator_close,
    ScandirIterator_dealloc,
    ScandirIterator_enter,
    ScandirIterator_exit,
    ScandirIterator_finalize,
    ScandirIterator_iternext,
    ScandirIterator_token,
    posix_stat_exec
}
import from jaclang.runtime.python.modules.posix_files { posix_files_exec }
import from jaclang.runtime.python.modules.posix_fileio { posix_fileio_exec }
import from jaclang.runtime.python.modules.posix_process {
    posix_process_exec,
    sched_param_reduce
}
import from jaclang.runtime.python.modules.posix_ids { posix_ids_exec }

import from c {
    # os_sched_param_reduce_method, added to sched_param after it is made.
    glob:priv sched_param_reduce_method: PyMethodDef = PyMethodDef(
             ml_name=ptr[u8]("__reduce__"),
             ml_meth=ptr(sched_param_reduce),
             ml_flags=METH_NOARGS,
             ml_doc=ptr[u8]()
         );
}

glob:priv POSIX_DOC: str = "This module provides access to operating system functionality that is\nstandardized by the C Standard and the POSIX standard (a thinly\ndisguised Unix interface).  Refer to the library manual and\ncorresponding Unix manual entries for more information on calls.",
     METH_O: i64 = 8,
     METH_CLASS: i64 = 16,
     METH_VARARGS: i64 = 1,
     METH_NOARGS_FLAG: i64 = 4;

glob:priv dir_entry_type = TypeDefinition(
         "posix.DirEntry",
         "",
         DirEntry_methods
             + [
                 MethodDefinition(
                     "__class_getitem__",
                     MethodCallbacks(positional=Py_GenericAlias),
                     "DirEntry is generic over the type of the path (str or bytes)",
                     flags=METH_O | METH_CLASS
                 )
             ],
         u64(TypeFlags.DISALLOW_INSTANTIATION.value),
         TypeHooks(dealloc=DirEntry_dealloc, repr=DirEntry_repr),
         members=DIR_ENTRY_MEMBERS,
         record_size=DIR_ENTRY_RECORD_SIZE
     ),
     scandir_iterator_type = TypeDefinition(
         "posix.ScandirIterator",
         "",
         [
             MethodDefinition(
                 "__enter__",
                 MethodCallbacks(positional=ScandirIterator_enter),
                 "",
                 flags=METH_NOARGS_FLAG
             ),
             MethodDefinition(
                 "__exit__",
                 MethodCallbacks(positional=ScandirIterator_exit),
                 "",
                 flags=METH_VARARGS
             ),
             MethodDefinition(
                 "close",
                 MethodCallbacks(positional=ScandirIterator_close),
                 "",
                 flags=METH_NOARGS_FLAG
             )
         ],
         u64(TypeFlags.DISALLOW_INSTANTIATION.value),
         TypeHooks(
             dealloc=ScandirIterator_dealloc,
             finalize=ScandirIterator_finalize,
             iter=PyObject_SelfIter,
             next=ScandirIterator_iternext
         )
     );

# sched_param's tp_new: the glue's os_sched_param_new.
def:priv sched_param_new(
    type_object: ptr[TypeLayout], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return os_sched_param_new(ptr[PyObject](type_object), args, kwargs);
}

# setup_confname_table(): a {name: value} dict published as `name`.
def:priv add_confname_table(
    module: ptr[PyObject], entries: list[tuple[str, i64]], name: str
) -> bool {
    table = PyDict_New();
    if not table {
        return False;
    }
    for (key, value) in entries {
        number = PyLong_FromLong(value);
        if not number {
            jacpy_release(table);
            return False;
        }
        status = PyDict_SetItemString(table, key, number);
        jacpy_release(number);
        if status < 0 {
            jacpy_release(table);
            return False;
        }
    }
    return add_owned(module, name, table);
}

# have_functions[]: the HAVE_* labels os.py reads, a label with a run-time
# probe present only where the function exists (mkfifoat and mknodat are
# macOS 13 functions; every other probe holds on the supported targets).
def:priv have_functions -> list[tuple[str, bool]] {
    return [
        ("HAVE_EVENTFD", bool(HAVE_EVENTFD)),
        ("HAVE_TIMERFD_CREATE", bool(HAVE_TIMERFD_CREATE)),
        ("HAVE_FACCESSAT", bool(HAVE_FACCESSAT)),
        ("HAVE_FCHDIR", bool(HAVE_FCHDIR)),
        ("HAVE_FCHMOD", bool(HAVE_FCHMOD)),
        ("HAVE_FCHMODAT", bool(HAVE_FCHMODAT)),
        ("HAVE_FCHOWN", bool(HAVE_FCHOWN)),
        ("HAVE_FCHOWNAT", bool(HAVE_FCHOWNAT)),
        ("HAVE_FEXECVE", bool(HAVE_FEXECVE)),
        ("HAVE_FDOPENDIR", bool(HAVE_FDOPENDIR)),
        ("HAVE_FPATHCONF", bool(HAVE_FPATHCONF)),
        ("HAVE_FSTATAT", bool(HAVE_FSTATAT)),
        ("HAVE_FSTATVFS", bool(HAVE_FSTATVFS)),
        ("HAVE_FTRUNCATE", bool(HAVE_FTRUNCATE)),
        ("HAVE_FUTIMENS", bool(HAVE_FUTIMENS)),
        ("HAVE_FUTIMES", bool(HAVE_FUTIMES)),
        ("HAVE_FUTIMESAT", bool(HAVE_FUTIMESAT)),
        ("HAVE_LINKAT", bool(HAVE_LINKAT)),
        ("HAVE_LCHFLAGS", bool(HAVE_LCHFLAGS)),
        ("HAVE_LCHMOD", bool(HAVE_LCHMOD)),
        ("HAVE_LCHOWN", bool(HAVE_LCHOWN)),
        ("HAVE_LSTAT", bool(HAVE_LSTAT)),
        ("HAVE_LUTIMES", bool(HAVE_LUTIMES)),
        ("HAVE_MEMFD_CREATE", bool(HAVE_MEMFD_CREATE)),
        ("HAVE_MKDIRAT", bool(HAVE_MKDIRAT)),
        ("HAVE_MKFIFOAT", bool(HAVE_MKFIFOAT) and bool(runtime_function("mkfifoat"))),
        ("HAVE_MKNODAT", bool(HAVE_MKNODAT) and bool(runtime_function("mknodat"))),
        ("HAVE_OPENAT", bool(HAVE_OPENAT)),
        ("HAVE_READLINKAT", bool(HAVE_READLINKAT)),
        ("HAVE_RENAMEAT", bool(HAVE_RENAMEAT)),
        ("HAVE_SYMLINKAT", bool(HAVE_SYMLINKAT)),
        ("HAVE_UNLINKAT", bool(HAVE_UNLINKAT)),
        ("HAVE_UTIMENSAT", bool(HAVE_UTIMENSAT)),
        ("HAVE_PTSNAME_R", bool(HAVE_PTSNAME_R))
    ];
}

def:priv add_have_functions(module: ptr[PyObject]) -> bool {
    labels = PyList_New(0);
    if not labels {
        return False;
    }
    for (label, present) in have_functions() {
        if not present {
            continue;
        }
        text = PyUnicode_FromString(label);
        if not text {
            jacpy_release(labels);
            return False;
        }
        status = PyList_Append(labels, text);
        jacpy_release(text);
        if status != 0 {
            jacpy_release(labels);
            return False;
        }
    }
    return add_owned(module, "_have_functions", labels);
}

# sched_param's tp_new and __reduce__, set once the process area made it.
def:priv finish_sched_param(module: ptr[PyObject]) -> bool {
    sched_type = state_object(module, STATE_SCHED_PARAM_TYPE);
    if not sched_type {
        return True;
    }
    layout = ptr[TypeLayout](sched_type);
    layout.view(1)[0].tp_new = sched_param_new;
    if _PyType_AddMethod(sched_type, addressof(sched_param_reduce_method)) < 0 {
        return False;
    }
    PyType_Modified(sched_type);
    return True;
}

def:priv add_scandir_types(module: ptr[PyObject]) -> bool {
    iterator_type = scandir_iterator_type.create(module);
    if not iterator_type {
        return False;
    }
    jacpy_binding_state_set(module, i64(STATE_SCANDIR_ITERATOR_TYPE), iterator_type);
    jacpy_release(iterator_type);
    return add_state_owned(
        module, STATE_DIR_ENTRY_TYPE, "DirEntry", dir_entry_type.create(module)
    );
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" or len(METHODS) == 0 {
        object_error(
            PyExc_ImportError,
            "posix has no posix_platform/posix_constants for this target platform"
        );
        return i32(-1);
    }
    DirEntry_token.handle = dir_entry_type.handle;
    ScandirIterator_token.handle = scandir_iterator_type.handle;
    jacpy_binding_module_native_set(module, PosixState());
    if not add_owned(module, "environ", convertenviron()) {
        return i32(-1);
    }
    for (name, value) in CONSTANTS {
        if PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    if (HAVE_FPATHCONF or HAVE_PATHCONF)
        and not add_confname_table(module, PATHCONF_TABLE, "pathconf_names") {
        return i32(-1);
    }
    if HAVE_CONFSTR
        and not add_confname_table(module, CONFSTR_TABLE, "confstr_names") {
        return i32(-1);
    }
    if HAVE_SYSCONF
        and not add_confname_table(module, SYSCONF_TABLE, "sysconf_names") {
        return i32(-1);
    }
    if PyModule_AddObjectRef(module, "error", PyExc_OSError) < 0 {
        return i32(-1);
    }
    if not posix_stat_exec(module)
        or not posix_process_exec(module)
        or not finish_sched_param(module)
        or not posix_fileio_exec(module)
        or not add_scandir_types(module)
        or not posix_ids_exec(module)
        or not posix_files_exec(module) {
        return i32(-1);
    }
    billion = PyLong_FromLong(1000000000);
    if not billion {
        return i32(-1);
    }
    jacpy_binding_state_set(module, i64(STATE_BILLION), billion);
    jacpy_release(billion);
    st_mode = PyUnicode_InternFromString("st_mode");
    if not st_mode {
        return i32(-1);
    }
    jacpy_binding_state_set(module, i64(STATE_ST_MODE), st_mode);
    jacpy_release(st_mode);
    return i32(0) if add_have_functions(module) else i32(-1);
}

# posix_methods[]: the functions this target compiles.
def:priv methods -> list[MethodDefinition] {
    per_target = module_methods_darwin
        if PLATFORM == "darwin"
        else (module_methods_linux if PLATFORM == "linux" else []);
    compiled = [name for (name, present) in METHODS];
    return [
        method
        for method in module_methods + per_target
        if method.name in compiled
    ];
}

glob:priv definition = ModuleDefinition(
         "posix", POSIX_DOC, methods(), ModuleHooks(execute=execute), STATE_COUNT
     );

def:pub PyInit_posix -> ptr[PyObject] {
    return definition.initialize();
}
