"""The _lsprof module: the Profiler type and the two stats struct sequences."""

import from jaclang.runtime.python.cpython_api { jacpy_struct_sequence_type, PyObject }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    jacpy_binding_untrack,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.lsprof {
    Profiler_doc,
    Profiler_methods,
    profiler_init_init
}
import from jaclang.runtime.python.modules.lsprof {
    Profiler_token,
    profiler_finalize,
    profiler_new
}

# Untracked first: flushing unmatched calls can run the user's timer.
def:priv profiler_dealloc(instance: ptr[PyObject]) {
    jacpy_binding_untrack(instance);
    profiler_finalize(instance);
    dispose_payload(instance, Profiler_token.handle);
}

def:priv profiler_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, Profiler_token.handle, visitor, context);
}

glob:priv profiler_type = TypeDefinition(
         "_lsprof.Profiler",
         Profiler_doc,
         Profiler_methods,
         u64(TypeFlags.BASETYPE.value | TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=profiler_new,
             initialize=profiler_init_init,
             dealloc=profiler_dealloc,
             traverse=profiler_traverse
         )
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    Profiler_token.handle = profiler_type.handle;
    if not add_state_owned(module, 0, "Profiler", profiler_type.create(module))
        or not add_state_owned(
            module,
            1,
            "profiler_entry",
            jacpy_struct_sequence_type(
                "_lsprof.profiler_entry",
                "",
                "code\tcode object or built-in function name\ncallcount\thow many times this was called\nreccallcount\thow many times called recursively\ntotaltime\ttotal time in this entry\ninlinetime\tinline time in this entry (not in subcalls)\ncalls\tdetails of the calls",
                6
            )
        )
        or not add_state_owned(
            module,
            2,
            "profiler_subentry",
            jacpy_struct_sequence_type(
                "_lsprof.profiler_subentry",
                "",
                "code\tcalled code object or built-in function name\ncallcount\thow many times this is called\nreccallcount\thow many times this is called recursively\ntotaltime\ttotal time spent in this call\ninlinetime\tinline time (not in further subcalls)",
                5
            )
        ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_lsprof", "Fast profiler", [], ModuleHooks(execute=execute), 3
     );

def:pub PyInit__lsprof -> ptr[PyObject] {
    return definition.initialize();
}
