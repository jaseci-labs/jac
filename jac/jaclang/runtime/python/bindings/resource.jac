"""The resource module: generated clinic tables, struct_rusage and the constants."""

import from jaclang.runtime.python.cpython_api {
    PyLong_FromLong,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyObject,
    jacpy_exception_type,
    jacpy_struct_sequence_type
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodDefinition,
    add_owned,
    add_state_owned
}
import from jaclang.runtime.python.bindings.clinic.resource { module_methods }
import from jaclang.runtime.python.modules.resource_records { PLATFORM, HAS_PRLIMIT }
import from jaclang.runtime.python.modules.resource_constants {
    CONSTANTS,
    RLIM_INFINITY
}

glob:priv INTERNAL: list[str] = ["RLIM_INFINITY", "RLIM_NLIMITS"];

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" or len(CONSTANTS) == 0 {
        object_error(
            "ImportError",
            "resource has no resource_records/resource_constants for this target platform"
        );
        return i32(-1);
    }
    if PyModule_AddObjectRef(module, "error", jacpy_exception_type("OSError")) < 0 {
        return i32(-1);
    }
    usage = jacpy_struct_sequence_type(
        "resource.struct_rusage",
        "struct_rusage: Result from getrusage.\n\nThis object may be accessed either as a tuple of\n    (utime,stime,maxrss,ixrss,idrss,isrss,minflt,majflt,\n    nswap,inblock,oublock,msgsnd,msgrcv,nsignals,nvcsw,nivcsw)\nor via the attributes ru_utime, ru_stime, ru_maxrss, and so on.",
        "ru_utime\tuser time used\nru_stime\tsystem time used\nru_maxrss\tmax. resident set size\nru_ixrss\tshared memory size\nru_idrss\tunshared data size\nru_isrss\tunshared stack size\nru_minflt\tpage faults not requiring I/O\nru_majflt\tpage faults requiring I/O\nru_nswap\tnumber of swap outs\nru_inblock\tblock input operations\nru_oublock\tblock output operations\nru_msgsnd\tIPC messages sent\nru_msgrcv\tIPC messages received\nru_nsignals\tsignals received\nru_nvcsw\tvoluntary context switches\nru_nivcsw\tinvoluntary context switches",
        16
    );
    if not add_state_owned(module, 0, "struct_rusage", usage) {
        return i32(-1);
    }
    for (name, value) in CONSTANTS {
        if name not in INTERNAL and PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0)
        if add_owned(module, "RLIM_INFINITY", PyLong_FromLong(RLIM_INFINITY))
        else i32(-1);
}

def:priv methods -> list[MethodDefinition] {
    return [
        method
        for method in module_methods
        if HAS_PRLIMIT or method.name != "prlimit"
    ];
}

glob:priv definition = ModuleDefinition(
         "resource", "", methods(), ModuleHooks(execute=execute), 1
     );

def:pub PyInit_resource -> ptr[PyObject] {
    return definition.initialize();
}
