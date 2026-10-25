def:priv _thread__get_name_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _thread_set_name_signature = CallSignature(
         "set_name", ["name"], 1, 1, 0, parser=PARSE_KEYWORDS
     );

def:priv _thread_set_name_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _thread_set_name_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob acquire_doc: str = "acquire($self, /, blocking=True, timeout=-1)\n--\n\nLock the lock.  Without argument, this blocks if the lock is already\nlocked (even by the same thread), waiting for another thread to release\nthe lock, and return True once the lock is acquired.\nWith an argument, this will only block if the argument is true,\nand the return value reflects whether the lock is acquired.\nThe blocking operation is interruptible.",
     acquire_lock_doc: str = "acquire_lock($self, /, blocking=True, timeout=-1)\n--\n\nAn obsolete synonym of acquire().",
     enter_doc: str = "__enter__($self, /)\n--\n\nLock the lock.",
     release_doc: str = "release($self, /)\n--\n\nRelease the lock, allowing another thread that is blocked waiting for\nthe lock to acquire the lock.  The lock must be in the locked state,\nbut it needn't be locked by the same thread that unlocks it.",
     release_lock_doc: str = "release_lock($self, /)\n--\n\nAn obsolete synonym of release().",
     lock_exit_doc: str = "__exit__($self, /, *exc_info)\n--\n\nRelease the lock.",
     locked_doc: str = "locked($self, /)\n--\n\nReturn whether the lock is in the locked state.",
     locked_lock_doc: str = "locked_lock($self, /)\n--\n\nAn obsolete synonym of locked().",
     lock_doc: str = "lock()\n--\n\nA lock object is a synchronization primitive.  To create a lock,\ncall threading.Lock().  Methods are:\n\nacquire() -- lock the lock, possibly blocking until it can be obtained\nrelease() -- unlock of the lock\nlocked() -- test whether the lock is currently locked\n\nA lock is not owned by the thread that locked it; another thread may\nunlock it.  A thread attempting to lock a lock that it has already locked\nwill block until another thread unlocks it.  Deadlocks may ensue.",
     rlock_acquire_doc: str = "acquire($self, /, blocking=True, timeout=-1)\n--\n\nLock the lock.  `blocking` indicates whether we should wait\nfor the lock to be available or not.  If `blocking` is False\nand another thread holds the lock, the method will return False\nimmediately.  If `blocking` is True and another thread holds\nthe lock, the method will wait for the lock to be released,\ntake it and then return True.\n(note: the blocking operation is interruptible.)\n\nIn all other cases, the method will return True immediately.\nPrecisely, if the current thread already holds the lock, its\ninternal counter is simply incremented. If nobody holds the lock,\nthe lock is taken and its internal counter initialized to 1.",
     rlock_enter_doc: str = "__enter__($self, /)\n--\n\nLock the lock.",
     rlock_release_doc: str = "release($self, /)\n--\n\nRelease the lock, allowing another thread that is blocked waiting for\nthe lock to acquire the lock.  The lock must be in the locked state,\nand must be locked by the same thread that unlocks it; otherwise a\n`RuntimeError` is raised.\n\nDo note that if the lock was acquire()d several times in a row by the\ncurrent thread, release() needs to be called as many times for the lock\nto be available for other threads.",
     rlock_exit_doc: str = "__exit__($self, /, *exc_info)\n--\n\nRelease the lock.",
     rlock_locked_doc: str = "locked()\n\nReturn a boolean indicating whether this object is locked right now.",
     rlock_acquire_restore_doc: str = "_acquire_restore($self, state, /)\n--\n\nFor internal use by `threading.Condition`.",
     rlock_release_save_doc: str = "_release_save($self, /)\n--\n\nFor internal use by `threading.Condition`.",
     rlock_recursion_count_doc: str = "_recursion_count($self, /)\n--\n\nFor internal use by reentrancy checks.",
     rlock_is_owned_doc: str = "_is_owned($self, /)\n--\n\nFor internal use by `threading.Condition`.",
     daemon_threads_allowed_doc: str = "daemon_threads_allowed($module, /)\n--\n\nReturn True if daemon threads are allowed in the current interpreter,\nand False otherwise.\n",
     start_new_thread_doc: str = "start_new_thread($module, function, args, kwargs={}, /)\n--\n\nStart a new thread and return its identifier.\n\nThe thread will call the function with positional arguments from the\ntuple args and keyword arguments taken from the optional dictionary\nkwargs.  The thread exits when the function returns; the return value\nis ignored.  The thread will also exit when the function raises an\nunhandled exception; a stack trace will be printed unless the exception\nis SystemExit.",
     start_new_doc: str = "start_new($module, function, args, kwargs={}, /)\n--\n\nAn obsolete synonym of start_new_thread().",
     start_joinable_doc: str = "start_joinable_thread($module, /, function, handle=None, daemon=True)\n--\n\n*For internal use only*: start a new thread.\n\nLike start_new_thread(), this starts a new thread calling the given function.\nUnlike start_new_thread(), this returns a handle object with methods to join\nor detach the given thread.\nThis function is not for third-party code, please use the\n`threading` module instead. During finalization the runtime will not wait for\nthe thread to exit if daemon is True. If handle is provided it must be a\nnewly created thread._ThreadHandle instance.",
     exit_doc: str = "exit($module, /)\n--\n\nThis is synonymous to ``raise SystemExit''.  It will cause the current\nthread to exit silently unless the exception is caught.",
     exit_thread_doc: str = "exit_thread($module, /)\n--\n\nAn obsolete synonym of exit().",
     interrupt_doc: str = "interrupt_main($module, signum=signal.SIGINT, /)\n--\n\nSimulate the arrival of the given signal in the main thread,\nwhere the corresponding signal handler will be executed.\nIf *signum* is omitted, SIGINT is assumed.\nA subthread can use this function to interrupt the main thread.\n\nNote: the default signal handler for SIGINT raises ``KeyboardInterrupt``.",
     allocate_lock_doc: str = "allocate_lock($module, /)\n--\n\nCreate a new lock object. See help(type(threading.Lock())) for\ninformation about locks.",
     allocate_doc: str = "allocate($module, /)\n--\n\nAn obsolete synonym of allocate_lock().",
     get_ident_doc: str = "get_ident($module, /)\n--\n\nReturn a non-zero integer that uniquely identifies the current thread\namongst other threads that exist simultaneously.\nThis may be used to identify per-thread resources.\nEven though on some platforms threads identities may appear to be\nallocated consecutive numbers starting at 1, this behavior should not\nbe relied upon, and the number should be seen purely as a magic cookie.\nA thread's identity may be reused for another thread after it exits.",
     get_native_id_doc: str = "get_native_id($module, /)\n--\n\nReturn a non-negative integer identifying the thread as reported\nby the OS (kernel). This may be used to uniquely identify a\nparticular thread within a system.",
     _count_doc: str = "_count($module, /)\n--\n\nReturn the number of currently running Python threads, excluding\nthe main thread. The returned number comprises all threads created\nthrough `start_new_thread()` as well as `threading.Thread`, and not\nyet finished.\n\nThis function is meant for internal and specialized purposes only.\nIn most applications `threading.enumerate()` should be used instead.",
     stack_size_doc: str = "stack_size($module, size=0, /)\n--\n\nReturn the thread stack size used when creating new threads.  The\noptional size argument specifies the stack size (in bytes) to be used\nfor subsequently created threads, and must be 0 (use platform or\nconfigured default) or a positive integer value of at least 32,768 (32k).\nIf changing the thread stack size is unsupported, a ThreadError\nexception is raised.  If the specified size is invalid, a ValueError\nexception is raised, and the stack size is unmodified.  32k bytes\n currently the minimum supported stack size value to guarantee\nsufficient stack space for the interpreter itself.\n\nNote that some platforms may have particular restrictions on values for\nthe stack size, such as requiring a minimum stack size larger than 32 KiB or\nrequiring allocation in multiples of the system memory page size\n- platform documentation should be referred to for more information\n(4 KiB pages are common; using multiples of 4096 for the stack size is\nthe suggested approach in the absence of more specific information).",
     ExceptHookArgs__doc__: str = "ExceptHookArgs\n\nType used to pass arguments to threading.excepthook.",
     excepthook_doc: str = "_excepthook($module, args, /)\n--\n\nHandle uncaught Thread.run() exception.",
     thread__is_main_interpreter_doc: str = "_is_main_interpreter($module, /)\n--\n\nReturn True if the current interpreter is the main Python interpreter.",
     shutdown_doc: str = "_shutdown($module, /)\n--\n\nWait for all non-daemon threads (other than the calling thread) to stop.",
     thread__make_thread_handle_doc: str = "_make_thread_handle($module, ident, /)\n--\n\nInternal only. Make a thread handle for threads not spawned\nby the _thread or threading module.",
     thread__get_main_thread_ident_doc: str = "_get_main_thread_ident($module, /)\n--\n\nInternal only. Return a non-zero integer that uniquely identifies the main thread\nof the main interpreter.",
     thread_doc: str = "This module provides primitive operations to write multi-threaded programs.\nThe 'threading' module provides a more convenient interface.",
     module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "_get_name",
             MethodCallbacks(positional=_thread__get_name_call),
             "_get_name($module, /)\n--\n\nGet the name of the current thread.",
             4
         ),
         MethodDefinition(
             "set_name",
             MethodCallbacks(fast_keywords=_thread_set_name_call),
             "set_name($module, /, name)\n--\n\nSet the name of the current thread.",
             130
         ),

     ];

impl _thread__get_name_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return _thread__get_name_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl _thread_set_name_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        name: ptr[PyObject] = convert_unicode(
            value, "set_name", argument_label("name", 1)
        );
        return _thread_set_name_impl(receiver, name);
    } except boundary_failure {
        return NULL;
    }
}

impl _thread_set_name_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return _thread_set_name_bound(receiver, args, nargs);
    }
    values = unpack_stack(_thread_set_name_signature, args, nargs, kwnames);
    if values {
        unpacked = _thread_set_name_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _thread_set_name_signature,
        args,
        nargs,
        kwnames,
        _thread_set_name_bound,
        receiver
    );
}
