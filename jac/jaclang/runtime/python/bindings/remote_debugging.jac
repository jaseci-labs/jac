def:priv unwinder_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

glob:priv unwinder_type = TypeDefinition(
         "_remote_debugging.RemoteUnwinder",
         "RemoteUnwinder(pid, *, all_threads=False, debug=False)\n--\n\nInspects another Python process; this build has no remote debugging support.",
         [],
         u64(0),
         TypeHooks(create=unwinder_new)
     ),
     frame_info_type = TypeDefinition(
         "_remote_debugging.FrameInfo",
         "A frame of a remote process's stack.",
         [],
         u64(0),
         TypeHooks()
     );

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_remote_debugging",
         "Remote process inspection; unavailable in this build.",
         [],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__remote_debugging -> ptr[PyObject];

impl unwinder_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_RuntimeError, ptr[u8]("Remote debugging support has not been compiled in")
    );
    return NULL;
}

impl execute(module: ptr[PyObject]) -> i32 {
    if not add_owned(module, "RemoteUnwinder", unwinder_type.create(module)) {
        return i32(-1);
    }
    return i32(0)
        if add_owned(module, "FrameInfo", frame_info_type.create(module))
        else i32(-1);
}

impl PyInit__remote_debugging -> ptr[PyObject] {
    return definition.initialize();
}
