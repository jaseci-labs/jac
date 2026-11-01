"""The Argument Clinic signatures of _thread.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/thread.jac from them. Taken from
CPython 3.14.6 Modules/_threadmodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_thread",
         version="3.14.6",
         sources=["Modules/_threadmodule.c"],
         functions=[
             Function(
                 name="_get_name",
                 full_name="_thread._get_name",
                 c_basename="_thread__get_name",
                 docstring="_get_name($module, /)\n"
                 "--\n"
                 "\n"
                 "Get the name of the current thread.",
                 condition="(defined(HAVE_PTHREAD_GETNAME_NP) || defined(HAVE_PTHREAD_GET_NAME_NP) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="set_name",
                 full_name="_thread.set_name",
                 c_basename="_thread_set_name",
                 docstring="set_name($module, /, name)\n"
                 "--\n"
                 "\n"
                 "Set the name of the current thread.",
                 condition="(defined(HAVE_PTHREAD_SETNAME_NP) || defined(HAVE_PTHREAD_SET_NAME_NP) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="name", converter="unicode", format_unit="U")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             )
         ],
         docs={
             "acquire_doc": "acquire($self, /, blocking=True, timeout=-1)\n"
             "--\n"
             "\n"
             "Lock the lock.  Without argument, this blocks if the lock is already\n"
             "locked (even by the same thread), waiting for another thread to release\n"
             "the lock, and return True once the lock is acquired.\n"
             "With an argument, this will only block if the argument is true,\n"
             "and the return value reflects whether the lock is acquired.\n"
             "The blocking operation is interruptible.",
             "acquire_lock_doc": "acquire_lock($self, /, blocking=True, timeout=-1)\n"
             "--\n"
             "\n"
             "An obsolete synonym of acquire().",
             "enter_doc": "__enter__($self, /)\n" "--\n" "\n" "Lock the lock.",
             "release_doc": "release($self, /)\n"
             "--\n"
             "\n"
             "Release the lock, allowing another thread that is blocked waiting for\n"
             "the lock to acquire the lock.  The lock must be in the locked state,\n"
             "but it needn't be locked by the same thread that unlocks it.",
             "release_lock_doc": "release_lock($self, /)\n"
             "--\n"
             "\n"
             "An obsolete synonym of release().",
             "lock_exit_doc": "__exit__($self, /, *exc_info)\n"
             "--\n"
             "\n"
             "Release the lock.",
             "locked_doc": "locked($self, /)\n"
             "--\n"
             "\n"
             "Return whether the lock is in the locked state.",
             "locked_lock_doc": "locked_lock($self, /)\n"
             "--\n"
             "\n"
             "An obsolete synonym of locked().",
             "lock_doc": "lock()\n"
             "--\n"
             "\n"
             "A lock object is a synchronization primitive.  To create a lock,\n"
             "call threading.Lock().  Methods are:\n"
             "\n"
             "acquire() -- lock the lock, possibly blocking until it can be obtained\n"
             "release() -- unlock of the lock\n"
             "locked() -- test whether the lock is currently locked\n"
             "\n"
             "A lock is not owned by the thread that locked it; another thread may\n"
             "unlock it.  A thread attempting to lock a lock that it has already locked\n"
             "will block until another thread unlocks it.  Deadlocks may ensue.",
             "rlock_acquire_doc": "acquire($self, /, blocking=True, timeout=-1)\n"
             "--\n"
             "\n"
             "Lock the lock.  `blocking` indicates whether we should wait\n"
             "for the lock to be available or not.  If `blocking` is False\n"
             "and another thread holds the lock, the method will return False\n"
             "immediately.  If `blocking` is True and another thread holds\n"
             "the lock, the method will wait for the lock to be released,\n"
             "take it and then return True.\n"
             "(note: the blocking operation is interruptible.)\n"
             "\n"
             "In all other cases, the method will return True immediately.\n"
             "Precisely, if the current thread already holds the lock, its\n"
             "internal counter is simply incremented. If nobody holds the lock,\n"
             "the lock is taken and its internal counter initialized to 1.",
             "rlock_enter_doc": "__enter__($self, /)\n" "--\n" "\n" "Lock the lock.",
             "rlock_release_doc": "release($self, /)\n"
             "--\n"
             "\n"
             "Release the lock, allowing another thread that is blocked waiting for\n"
             "the lock to acquire the lock.  The lock must be in the locked state,\n"
             "and must be locked by the same thread that unlocks it; otherwise a\n"
             "`RuntimeError` is raised.\n"
             "\n"
             "Do note that if the lock was acquire()d several times in a row by the\n"
             "current thread, release() needs to be called as many times for the lock\n"
             "to be available for other threads.",
             "rlock_exit_doc": "__exit__($self, /, *exc_info)\n"
             "--\n"
             "\n"
             "Release the lock.",
             "rlock_locked_doc": "locked()\n"
             "\n"
             "Return a boolean indicating whether this object is locked right now.",
             "rlock_acquire_restore_doc": "_acquire_restore($self, state, /)\n"
             "--\n"
             "\n"
             "For internal use by `threading.Condition`.",
             "rlock_release_save_doc": "_release_save($self, /)\n"
             "--\n"
             "\n"
             "For internal use by `threading.Condition`.",
             "rlock_recursion_count_doc": "_recursion_count($self, /)\n"
             "--\n"
             "\n"
             "For internal use by reentrancy checks.",
             "rlock_is_owned_doc": "_is_owned($self, /)\n"
             "--\n"
             "\n"
             "For internal use by `threading.Condition`.",
             "daemon_threads_allowed_doc": "daemon_threads_allowed($module, /)\n"
             "--\n"
             "\n"
             "Return True if daemon threads are allowed in the current interpreter,\n"
             "and False otherwise.\n",
             "start_new_thread_doc": "start_new_thread($module, function, args, kwargs={}, /)\n"
             "--\n"
             "\n"
             "Start a new thread and return its identifier.\n"
             "\n"
             "The thread will call the function with positional arguments from the\n"
             "tuple args and keyword arguments taken from the optional dictionary\n"
             "kwargs.  The thread exits when the function returns; the return value\n"
             "is ignored.  The thread will also exit when the function raises an\n"
             "unhandled exception; a stack trace will be printed unless the exception\n"
             "is SystemExit.",
             "start_new_doc": "start_new($module, function, args, kwargs={}, /)\n"
             "--\n"
             "\n"
             "An obsolete synonym of start_new_thread().",
             "start_joinable_doc": "start_joinable_thread($module, /, function, handle=None, daemon=True)\n"
             "--\n"
             "\n"
             "*For internal use only*: start a new thread.\n"
             "\n"
             "Like start_new_thread(), this starts a new thread calling the given function.\n"
             "Unlike start_new_thread(), this returns a handle object with methods to join\n"
             "or detach the given thread.\n"
             "This function is not for third-party code, please use the\n"
             "`threading` module instead. During finalization the runtime will not wait for\n"
             "the thread to exit if daemon is True. If handle is provided it must be a\n"
             "newly created thread._ThreadHandle instance.",
             "exit_doc": "exit($module, /)\n"
             "--\n"
             "\n"
             "This is synonymous to ``raise SystemExit''.  It will cause the current\n"
             "thread to exit silently unless the exception is caught.",
             "exit_thread_doc": "exit_thread($module, /)\n"
             "--\n"
             "\n"
             "An obsolete synonym of exit().",
             "interrupt_doc": "interrupt_main($module, signum=signal.SIGINT, /)\n"
             "--\n"
             "\n"
             "Simulate the arrival of the given signal in the main thread,\n"
             "where the corresponding signal handler will be executed.\n"
             "If *signum* is omitted, SIGINT is assumed.\n"
             "A subthread can use this function to interrupt the main thread.\n"
             "\n"
             "Note: the default signal handler for SIGINT raises ``KeyboardInterrupt``.",
             "allocate_lock_doc": "allocate_lock($module, /)\n"
             "--\n"
             "\n"
             "Create a new lock object. See help(type(threading.Lock())) for\n"
             "information about locks.",
             "allocate_doc": "allocate($module, /)\n"
             "--\n"
             "\n"
             "An obsolete synonym of allocate_lock().",
             "get_ident_doc": "get_ident($module, /)\n"
             "--\n"
             "\n"
             "Return a non-zero integer that uniquely identifies the current thread\n"
             "amongst other threads that exist simultaneously.\n"
             "This may be used to identify per-thread resources.\n"
             "Even though on some platforms threads identities may appear to be\n"
             "allocated consecutive numbers starting at 1, this behavior should not\n"
             "be relied upon, and the number should be seen purely as a magic cookie.\n"
             "A thread's identity may be reused for another thread after it exits.",
             "get_native_id_doc": "get_native_id($module, /)\n"
             "--\n"
             "\n"
             "Return a non-negative integer identifying the thread as reported\n"
             "by the OS (kernel). This may be used to uniquely identify a\n"
             "particular thread within a system.",
             "_count_doc": "_count($module, /)\n"
             "--\n"
             "\n"
             "Return the number of currently running Python threads, excluding\n"
             "the main thread. The returned number comprises all threads created\n"
             "through `start_new_thread()` as well as `threading.Thread`, and not\n"
             "yet finished.\n"
             "\n"
             "This function is meant for internal and specialized purposes only.\n"
             "In most applications `threading.enumerate()` should be used instead.",
             "stack_size_doc": "stack_size($module, size=0, /)\n"
             "--\n"
             "\n"
             "Return the thread stack size used when creating new threads.  The\n"
             "optional size argument specifies the stack size (in bytes) to be used\n"
             "for subsequently created threads, and must be 0 (use platform or\n"
             "configured default) or a positive integer value of at least 32,768 (32k).\n"
             "If changing the thread stack size is unsupported, a ThreadError\n"
             "exception is raised.  If the specified size is invalid, a ValueError\n"
             "exception is raised, and the stack size is unmodified.  32k bytes\n"
             " currently the minimum supported stack size value to guarantee\n"
             "sufficient stack space for the interpreter itself.\n"
             "\n"
             "Note that some platforms may have particular restrictions on values for\n"
             "the stack size, such as requiring a minimum stack size larger than 32 KiB or\n"
             "requiring allocation in multiples of the system memory page size\n"
             "- platform documentation should be referred to for more information\n"
             "(4 KiB pages are common; using multiples of 4096 for the stack size is\n"
             "the suggested approach in the absence of more specific information).",
             "ExceptHookArgs__doc__": "ExceptHookArgs\n"
             "\n"
             "Type used to pass arguments to threading.excepthook.",
             "excepthook_doc": "_excepthook($module, args, /)\n"
             "--\n"
             "\n"
             "Handle uncaught Thread.run() exception.",
             "thread__is_main_interpreter_doc": "_is_main_interpreter($module, /)\n"
             "--\n"
             "\n"
             "Return True if the current interpreter is the main Python interpreter.",
             "shutdown_doc": "_shutdown($module, /)\n"
             "--\n"
             "\n"
             "Wait for all non-daemon threads (other than the calling thread) to stop.",
             "thread__make_thread_handle_doc": "_make_thread_handle($module, ident, /)\n"
             "--\n"
             "\n"
             "Internal only. Make a thread handle for threads not spawned\n"
             "by the _thread or threading module.",
             "thread__get_main_thread_ident_doc": "_get_main_thread_ident($module, /)\n"
             "--\n"
             "\n"
             "Internal only. Return a non-zero integer that uniquely identifies the main thread\n"
             "of the main interpreter.",
             "thread_doc": "This module provides primitive operations to write multi-threaded programs.\n"
             "The 'threading' module provides a more convenient interface."
         }
     );
