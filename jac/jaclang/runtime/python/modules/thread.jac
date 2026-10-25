import from c {
    def PyThread_start_joinable_thread(
        func: ptr, arg: ptr, ident: &mut u64, handle: &mut u64
    ) -> i32;  def PyThread_join_thread(handle: u64) -> i32;  def PyThread_detach_thread(
        handle: u64
    ) -> i32;  def PyThread_get_thread_native_id -> u64;  def PyThread_get_stacksize -> u64;  def PyThread_set_stacksize(
        size: u64
    ) -> i32;  def PyThread_init_thread;  def _PyThreadState_New(
        interp: ptr[u8], whence: i32
    ) -> ptr[PyThreadState];  def PyThreadState_Clear(tstate: ptr[PyThreadState]);  def PyThreadState_Delete(
        tstate: ptr[PyThreadState]
    );  def _PyThreadState_DeleteCurrent(tstate: ptr[PyThreadState]);  def _PyThreadState_Bind(
        tstate: ptr[PyThreadState]
    );  def PyEval_AcquireThread(tstate: ptr[PyThreadState]);  def _PyThreadState_MustExit(
        tstate: ptr[PyThreadState]
    ) -> i32;  def Py_IsFinalizing -> i32;  def _PyMutex_LockTimed(
        m: ptr[PyMutex], timeout_ns: i64, flags: i32
    ) -> i32;  def _PyMutex_TryUnlock(m: ptr[PyMutex]) -> i32;  def PyMutex_Lock(
        m: ptr[PyMutex]
    );  def PyMutex_Unlock(m: ptr[PyMutex]);  def PyMutex_IsLocked(
        m: ptr[PyMutex]
    ) -> i32;  def _PyEvent_IsSet(evt: ptr[u8]) -> i32;  def _PyEvent_Notify(
        evt: ptr[u8]
    );  def PyEvent_Wait(evt: ptr[u8]);  def PyEvent_WaitTimed(
        evt: ptr[u8], timeout_ns: i64, detach: i32
    ) -> i32;  def _PyOnceFlag_CallOnceSlow(
        flag: ptr[u8], once_fn: ptr, arg: ptr
    ) -> i32;  def _PyRecursiveMutex_IsLockedByCurrentThread(m: ptr[u8]) -> i32;  def _PyRecursiveMutex_Lock(
        m: ptr[u8]
    );  def _PyRecursiveMutex_LockTimed(m: ptr[u8], timeout: i64, flags: i32) -> i32;  def _PyRecursiveMutex_Unlock(
        m: ptr[u8]
    );  def _PyRecursiveMutex_TryUnlock(m: ptr[u8]) -> i32;  def PyType_GenericAlloc(
        type: ptr[PyTypeObject], nitems: i64
    ) -> ptr[PyObject];  def PyType_GetModuleByDef(
        type: ptr[PyTypeObject], mod_def: ptr[PyModuleDef]
    ) -> ptr[PyObject];  def PyType_FromSpec(spec: ptr[PyType_Spec]) -> ptr[PyObject];  def _PyObject_GenericSetAttrWithDict(
        ob: ptr[PyObject],
        name: ptr[PyObject],
        value: ptr[PyObject],
        dict_arg: ptr[PyObject]
    ) -> i32;  def _PyObject_GenericGetAttrWithDict(
        ob: ptr[PyObject], name: ptr[PyObject], dict_arg: ptr[PyObject], suppress: i32
    ) -> ptr[PyObject];  def _PyObject_SetDeferredRefcount(op: ptr[PyObject]);  def PyCFunction_New(
        ml: ptr[PyMethodDef], self: ptr[PyObject]
    ) -> ptr[PyObject];  def PyFile_WriteString(s: ptr[u8], f: ptr[PyObject]) -> i32;  def PyFile_WriteObject(
        v: ptr[PyObject], f: ptr[PyObject], flags: i32
    ) -> i32;  def _PyFile_Flush(file: ptr[PyObject]) -> i32;  def _PyErr_Display(
        file: ptr[PyObject],
        unused: ptr[PyObject],
        value: ptr[PyObject],
        tb: ptr[PyObject]
    );  def _PySys_GetOptionalAttr(
        name: ptr[PyObject], value: &mut ptr[PyObject]
    ) -> i32;  def PyErr_SetInterruptEx(signum: i32) -> i32;  def _Py_write_noraise(
        fd: i32, buf: ptr, count: u64
    ) -> i64;  def floor(value: f64) -> f64;  def jacpy_stack_address(
        slots: &mut SignalBuffer
    ) -> int;  def _PyTime_AsMicroseconds(t: i64, round: i32) -> i64;  def strlen(
        text: ptr[u8]
    ) -> u64;  def PyModule_GetState(m: ptr[PyObject]) -> ptr;  glob PY_TIMEOUT_MAX:
             i64; obj ThreadHandle {
        has link: llist_node,
            shutdown_node: llist_node,
            ident: u64,
            os_handle: u64,
            has_os_handle: i32,
            state: i32,
            mutex: u8,
            thread_is_exiting: u8,
            once: u8,
            refcount: i64;
    }  obj BootState {
        has tstate: ptr[PyThreadState],
            func: ptr[PyObject],
            args: ptr[PyObject],
            kwargs: ptr[PyObject],
            handle: ptr[ThreadHandle],
            handle_ready: u8;
    }  obj PyThreadHandleObject {
        has ob_base: _object,
            handle: ptr[ThreadHandle];
    }  obj lockobject {
        has ob_base: _object,
            lock: u8;
    }  obj rlockobject {
        has ob_base: _object,
            mutex: u8,
            thread: u64,
            level: u64;
    }  obj localdummyobject {
        has ob_base: _object,
            weakreflist: ptr[PyObject];
    }  obj localobject {
        has ob_base: _object,
            args: ptr[PyObject],
            kw: ptr[PyObject],
            weakreflist: ptr[PyObject],
            localdicts: ptr[PyObject],
            thread_watchdogs: ptr[PyObject];
    }  obj ThreadModuleState {
        has excepthook_type: ptr[PyTypeObject],
            lock_type: ptr[PyTypeObject],
            local_type: ptr[PyTypeObject],
            local_dummy_type: ptr[PyTypeObject],
            thread_handle_type: ptr[PyTypeObject],
            shutdown_handles: llist_node;
    }
}

glob:priv THREAD_HANDLE_NOT_STARTED: Final[i32] = 1,
     THREAD_HANDLE_STARTING: Final[i32] = 2,
     THREAD_HANDLE_RUNNING: Final[i32] = 3,
     THREAD_HANDLE_DONE: Final[i32] = 4,
     THREAD_HANDLE_SIZE: Final[i64] = 72,
     THREAD_HANDLE_SHUTDOWN_NODE: Final[i64] = 16,
     THREAD_HANDLE_MUTEX: Final[i64] = 56,
     THREAD_HANDLE_EXITING: Final[i64] = 57,
     THREAD_HANDLE_ONCE: Final[i64] = 58,
     THREAD_HANDLE_REFCOUNT: Final[i64] = 64,
     BOOTSTATE_SIZE: Final[i64] = 48,
     BOOTSTATE_HANDLE_READY: Final[i64] = 40,
     LOCK_MUTEX: Final[i64] = 16,
     RLOCK_MUTEX: Final[i64] = 16,
     RLOCK_THREAD: Final[i64] = 24,
     THREAD_MODULE_STATE_SIZE: Final[i64] = 56,
     THREAD_MODULE_STATE_SHUTDOWN_HANDLES: Final[i64] = 40,
     LOCALDUMMY_WEAKREFLIST: Final[i64] = 16,
     LOCAL_WEAKREFLIST: Final[i64] = 32,
     PYTHREAD_INVALID_THREAD_ID: Final[u64] = 18446744073709551615,
     UNSET_TIMEOUT: Final[i64] = -1000000000,
     PYOS_MIN_STACK_SIZE: Final[i64] = 49152,
     SYSTEM_PAGE_SIZE: Final[i64] = 4096,
     PYTIME_MAX: Final[i64] = 9223372036854775807;

def:priv type_flag(op: ptr[PyObject], flag: u64) -> bool;

def:priv runtime_at(offset: i64) -> ptr[u8];

def:priv tstate_field(tstate: ptr[PyThreadState], offset: i64) -> ptr[ptr[PyObject]];

def get_thread_state(module: ptr[PyObject]) -> ptr[ThreadModuleState];

def:priv shutdown_handles_of(state: ptr[ThreadModuleState]) -> ptr[llist_node];

def:priv handle_mutex(handle: ptr[ThreadHandle]) -> ptr[PyMutex];

def:priv handle_exiting(handle: ptr[ThreadHandle]) -> ptr[u8];

def:priv handle_once(handle: ptr[ThreadHandle]) -> ptr[u8];

def:priv handle_shutdown_node(handle: ptr[ThreadHandle]) -> ptr[llist_node];

def:priv once_call(flag: ptr[u8], once_fn: ptr, arg: ptr) -> i32;

def:priv get_thread_handle_state(handle: ptr[ThreadHandle]) -> i32;

def:priv set_thread_handle_state(handle: ptr[ThreadHandle], state: i32);

def:priv ThreadHandle_ident(handle: ptr[ThreadHandle]) -> u64;

def:priv ThreadHandle_get_os_handle(handle: ptr[ThreadHandle]) -> tuple[i32, u64];

def:priv add_to_shutdown_handles(
    state: ptr[ThreadModuleState], handle: ptr[ThreadHandle]
);

def clear_shutdown_handles(state: ptr[ThreadModuleState]);

def:priv remove_from_shutdown_handles(handle: ptr[ThreadHandle]);

def:priv ThreadHandle_new -> ptr[ThreadHandle];

def:priv ThreadHandle_incref(self_: ptr[ThreadHandle]);

def:priv detach_thread(self_: ptr[ThreadHandle]) -> i32;

def:priv ThreadHandle_decref(self_: ptr[ThreadHandle]);

import from c {
    def _PyThread_AfterFork(state: ptr[u8]) {
        current = PyThread_get_thread_ident_ex();
        head = ptr[llist_node](state + _pythread_runtime_state_HANDLES);
        item = head.view(1)[0].next;
        while item != head {
            following = item.view(1)[0].next;
            handle = ptr[ThreadHandle](item);
            if handle.view(1)[0].ident == current {
                item = following;
                continue;
            }

            if handle.view(1)[0].state == THREAD_HANDLE_NOT_STARTED {
                item = following;
                continue;
            }

            handle.view(1)[0].state = THREAD_HANDLE_DONE;
            handle_once(handle).view(1)[0] = _Py_ONCE_INITIALIZED;
            ptr[u8](handle_mutex(handle)).view(1)[0] = _Py_UNLOCKED;
            _PyEvent_Notify(handle_exiting(handle));
            llist_remove(item);
            remove_from_shutdown_handles(handle);
            item = following;
        }
    }
}

def:priv thread_bootstate_free(boot: ptr[BootState], decref: bool);

def thread_run(boot_raw: ptr);

def force_done(arg: ptr) -> i32;

def:priv ThreadHandle_start(
    self_: ptr[ThreadHandle],
    func: ptr[PyObject],
    args: ptr[PyObject],
    kwargs: ptr[PyObject]
) -> i32;

def join_thread(arg: ptr) -> i32;

def:priv check_started(self_: ptr[ThreadHandle]) -> i32;

def:priv ThreadHandle_join(self_: ptr[ThreadHandle], timeout_in: i64) -> i32;

def set_done(arg: ptr) -> i32;

def:priv ThreadHandle_set_done(self_: ptr[ThreadHandle]) -> i32;

def:priv handle_of(op: ptr[PyObject]) -> ptr[ThreadHandle];

def:priv PyThreadHandleObject_new(type: ptr[PyTypeObject]) -> ptr[PyObject];

def PyThreadHandleObject_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def PyThreadHandleObject_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def PyThreadHandleObject_dealloc(op: ptr[PyObject]);

def PyThreadHandleObject_repr(op: ptr[PyObject]) -> ptr[PyObject];

def PyThreadHandleObject_get_ident(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def PyThreadHandleObject_join(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def PyThreadHandleObject_is_done(
    op: ptr[PyObject], dummy: ptr[PyObject]
) -> ptr[PyObject];

def PyThreadHandleObject_set_done(
    op: ptr[PyObject], dummy: ptr[PyObject]
) -> ptr[PyObject];

def:priv lock_mutex(op: ptr[PyObject]) -> ptr[PyMutex];

def lock_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def lock_dealloc(self_: ptr[PyObject]);

def:priv lock_acquire_parse_args(
    args: ptr[PyObject], kwds: ptr[PyObject]
) -> tuple[i32, i64];

def lock_PyThread_acquire_lock(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def lock_PyThread_release_lock(
    op: ptr[PyObject], dummy: ptr[PyObject]
) -> ptr[PyObject];

def lock_locked_lock(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def lock_repr(op: ptr[PyObject]) -> ptr[PyObject];

def lock__at_fork_reinit(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def lock_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def:priv rlock_mutex(op: ptr[PyObject]) -> ptr[u8];

def rlock_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def:priv rlock_locked_impl(op: ptr[PyObject]) -> i32;

def rlock_dealloc(self_: ptr[PyObject]);

def rlock_acquire(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def rlock_release(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def rlock_locked(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def:priv parse_restore_state(args: ptr[PyObject]) -> tuple[bool, i64, u64];

def rlock_acquire_restore(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def rlock_release_save(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def rlock_recursion_count(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def rlock_is_owned(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def rlock_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def rlock_repr(op: ptr[PyObject]) -> ptr[PyObject];

def rlock__at_fork_reinit(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def newlockobject(module: ptr[PyObject]) -> ptr[PyObject];

def localdummy_dealloc(op: ptr[PyObject]);

def:priv create_sentinel_wr(self_: ptr[PyObject]) -> ptr[PyObject];

def local_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject];

def local_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def local_clear(op: ptr[PyObject]) -> i32;

def local_dealloc(op: ptr[PyObject]);

def:priv create_localdummies(state: ptr[ThreadModuleState]) -> i32;

def:priv drop_local_dict(self_: ptr[PyObject], key: ptr[PyObject]);

def:priv create_localsdict(
    self_: ptr[PyObject], state: ptr[ThreadModuleState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def:priv _ldict(self_: ptr[PyObject], state: ptr[ThreadModuleState]) -> ptr[PyObject];

def local_setattro(op: ptr[PyObject], name: ptr[PyObject], v: ptr[PyObject]) -> i32;

def local_getattro(op: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def clear_locals(
    locals_and_key: ptr[PyObject], dummyweakref: ptr[PyObject]
) -> ptr[PyObject];

def thread_daemon_threads_allowed(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def:priv do_start_new_thread(
    state: ptr[ThreadModuleState],
    func: ptr[PyObject],
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    handle: ptr[ThreadHandle],
    daemon: bool
) -> i32;

def thread_PyThread_start_new_thread(
    module: ptr[PyObject], fargs: ptr[PyObject]
) -> ptr[PyObject];

def thread_PyThread_start_joinable_thread(
    module: ptr[PyObject], fargs: ptr[PyObject], fkwargs: ptr[PyObject]
) -> ptr[PyObject];

def thread_PyThread_exit_thread(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def thread_PyThread_interrupt_main(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

def thread_PyThread_allocate_lock(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def thread_get_ident(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def thread_get_native_id(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def thread__count(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def thread_stack_size(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv thread_excepthook_file(
    file: ptr[PyObject],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_traceback: ptr[PyObject],
    thread: ptr[PyObject]
) -> i32;

def thread_excepthook(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def thread__is_main_interpreter(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def thread_shutdown(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def thread__make_thread_handle(
    module: ptr[PyObject], identobj: ptr[PyObject]
) -> ptr[PyObject];

def thread__get_main_thread_ident(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def _thread__get_name_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _thread_set_name_impl(
    module: ptr[PyObject], name_obj: ptr[PyObject]
) -> ptr[PyObject];

def thread_module_exec(module: ptr[PyObject]) -> i32;

def thread_module_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def:priv clear_type_slot(slot: ptr[ptr[PyTypeObject]]);

def thread_module_clear(module: ptr[PyObject]) -> i32;

def thread_module_free(module: ptr);

def install_clinic_methods(table: ptr[PyMethodDef], count: i64);

def clinic_methods_installed -> bool;

glob:priv CLINIC_METHODS_SLOT: Final[i64] = 18;

import from c {
    glob:priv wr_callback_def: PyMethodDef = PyMethodDef(
             ml_name=ptr[u8]("clear_locals"),
             ml_meth=ptr(clear_locals),
             ml_flags=METH_O,
             ml_doc=ptr[u8]()
         ),
         ThreadHandle_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("ident"), get=PyThreadHandleObject_get_ident),
             PyGetSetDef()
         ],
         ThreadHandle_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("join"),
                 ml_meth=ptr(PyThreadHandleObject_join),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_set_done"),
                 ml_meth=ptr(PyThreadHandleObject_set_done),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_done"),
                 ml_meth=ptr(PyThreadHandleObject_is_done),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         ThreadHandle_Type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(PyThreadHandleObject_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(PyThreadHandleObject_repr)),
             PyType_Slot(
                 slot=Py_tp_getset, pfunc=ptr(addressof(ThreadHandle_getsetlist))
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(PyThreadHandleObject_traverse)),
             PyType_Slot(
                 slot=Py_tp_methods, pfunc=ptr(addressof(ThreadHandle_methods))
             ),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(PyThreadHandleObject_tp_new)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         ThreadHandle_Type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_thread._ThreadHandle"),
             basicsize=24,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_IMMUTABLETYPE | Py_TPFLAGS_HAVE_GC
             ),
             slots=addressof(ThreadHandle_Type_slots)
         ),
         lock_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("acquire_lock"),
                 ml_meth=ptr(lock_PyThread_acquire_lock),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "acquire_lock($self, /, blocking=True, timeout=-1)\n--\n\nAn obsolete synonym of acquire()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("acquire"),
                 ml_meth=ptr(lock_PyThread_acquire_lock),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "acquire($self, /, blocking=True, timeout=-1)\n--\n\nLock the lock.  Without argument, this blocks if the lock is already\nlocked (even by the same thread), waiting for another thread to release\nthe lock, and return True once the lock is acquired.\nWith an argument, this will only block if the argument is true,\nand the return value reflects whether the lock is acquired.\nThe blocking operation is interruptible."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("release_lock"),
                 ml_meth=ptr(lock_PyThread_release_lock),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "release_lock($self, /)\n--\n\nAn obsolete synonym of release()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("release"),
                 ml_meth=ptr(lock_PyThread_release_lock),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "release($self, /)\n--\n\nRelease the lock, allowing another thread that is blocked waiting for\nthe lock to acquire the lock.  The lock must be in the locked state,\nbut it needn't be locked by the same thread that unlocks it."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("locked_lock"),
                 ml_meth=ptr(lock_locked_lock),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "locked_lock($self, /)\n--\n\nAn obsolete synonym of locked()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("locked"),
                 ml_meth=ptr(lock_locked_lock),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "locked($self, /)\n--\n\nReturn whether the lock is in the locked state."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__enter__"),
                 ml_meth=ptr(lock_PyThread_acquire_lock),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]("__enter__($self, /)\n--\n\nLock the lock.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__exit__"),
                 ml_meth=ptr(lock_PyThread_release_lock),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "__exit__($self, /, *exc_info)\n--\n\nRelease the lock."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_at_fork_reinit"),
                 ml_meth=ptr(lock__at_fork_reinit),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         lock_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(lock_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(lock_repr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "lock()\n--\n\nA lock object is a synchronization primitive.  To create a lock,\ncall threading.Lock().  Methods are:\n\nacquire() -- lock the lock, possibly blocking until it can be obtained\nrelease() -- unlock of the lock\nlocked() -- test whether the lock is currently locked\n\nA lock is not owned by the thread that locked it; another thread may\nunlock it.  A thread attempting to lock a lock that it has already locked\nwill block until another thread unlocks it.  Deadlocks may ensue."
                 )
             ),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(lock_methods))),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(lock_traverse)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(lock_new)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         lock_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_thread.lock"),
             basicsize=24,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(lock_type_slots)
         ),
         rlock_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("acquire"),
                 ml_meth=ptr(rlock_acquire),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "acquire($self, /, blocking=True, timeout=-1)\n--\n\nLock the lock.  `blocking` indicates whether we should wait\nfor the lock to be available or not.  If `blocking` is False\nand another thread holds the lock, the method will return False\nimmediately.  If `blocking` is True and another thread holds\nthe lock, the method will wait for the lock to be released,\ntake it and then return True.\n(note: the blocking operation is interruptible.)\n\nIn all other cases, the method will return True immediately.\nPrecisely, if the current thread already holds the lock, its\ninternal counter is simply incremented. If nobody holds the lock,\nthe lock is taken and its internal counter initialized to 1."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("release"),
                 ml_meth=ptr(rlock_release),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "release($self, /)\n--\n\nRelease the lock, allowing another thread that is blocked waiting for\nthe lock to acquire the lock.  The lock must be in the locked state,\nand must be locked by the same thread that unlocks it; otherwise a\n`RuntimeError` is raised.\n\nDo note that if the lock was acquire()d several times in a row by the\ncurrent thread, release() needs to be called as many times for the lock\nto be available for other threads."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("locked"),
                 ml_meth=ptr(rlock_locked),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "locked()\n\nReturn a boolean indicating whether this object is locked right now."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_is_owned"),
                 ml_meth=ptr(rlock_is_owned),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_is_owned($self, /)\n--\n\nFor internal use by `threading.Condition`."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_acquire_restore"),
                 ml_meth=ptr(rlock_acquire_restore),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "_acquire_restore($self, state, /)\n--\n\nFor internal use by `threading.Condition`."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_release_save"),
                 ml_meth=ptr(rlock_release_save),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_release_save($self, /)\n--\n\nFor internal use by `threading.Condition`."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_recursion_count"),
                 ml_meth=ptr(rlock_recursion_count),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_recursion_count($self, /)\n--\n\nFor internal use by reentrancy checks."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__enter__"),
                 ml_meth=ptr(rlock_acquire),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]("__enter__($self, /)\n--\n\nLock the lock.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__exit__"),
                 ml_meth=ptr(rlock_release),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "__exit__($self, /, *exc_info)\n--\n\nRelease the lock."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_at_fork_reinit"),
                 ml_meth=ptr(rlock__at_fork_reinit),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         rlock_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(rlock_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(rlock_repr)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(rlock_methods))),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(rlock_new)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(rlock_traverse)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         rlock_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_thread.RLock"),
             basicsize=40,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(rlock_type_slots)
         ),
         local_dummy_type_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=LOCALDUMMY_WEAKREFLIST,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         local_dummy_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(localdummy_dealloc)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("Thread-local dummy")),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(local_dummy_type_members))
             ),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         local_dummy_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_thread._localdummy"),
             basicsize=24,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(local_dummy_type_slots)
         ),
         local_type_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=LOCAL_WEAKREFLIST,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         local_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(local_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(local_getattro)),
             PyType_Slot(slot=Py_tp_setattro, pfunc=ptr(local_setattro)),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("_local()\n--\n\nThread-local data")
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(local_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(local_clear)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(local_new)),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(local_type_members))),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         local_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_thread._local"),
             basicsize=56,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(local_type_slots)
         ),
         ExceptHookArgs_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("exc_type"), doc=ptr[u8]("Exception type")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("exc_value"), doc=ptr[u8]("Exception value")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("exc_traceback"), doc=ptr[u8]("Exception traceback")
             ),
             PyStructSequence_Field(name=ptr[u8]("thread"), doc=ptr[u8]("Thread")),
             PyStructSequence_Field(name=ptr[u8](), doc=ptr[u8]())
         ],
         ExceptHookArgs_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("_thread._ExceptHookArgs"),
             doc=ptr[u8](
                 "ExceptHookArgs\n\nType used to pass arguments to threading.excepthook."
             ),
             fields=addressof(ExceptHookArgs_fields),
             n_in_sequence=4
         ),
         thread_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("start_new_thread"),
                 ml_meth=ptr(thread_PyThread_start_new_thread),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "start_new_thread($module, function, args, kwargs={}, /)\n--\n\nStart a new thread and return its identifier.\n\nThe thread will call the function with positional arguments from the\ntuple args and keyword arguments taken from the optional dictionary\nkwargs.  The thread exits when the function returns; the return value\nis ignored.  The thread will also exit when the function raises an\nunhandled exception; a stack trace will be printed unless the exception\nis SystemExit."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("start_new"),
                 ml_meth=ptr(thread_PyThread_start_new_thread),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "start_new($module, function, args, kwargs={}, /)\n--\n\nAn obsolete synonym of start_new_thread()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("start_joinable_thread"),
                 ml_meth=ptr(thread_PyThread_start_joinable_thread),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "start_joinable_thread($module, /, function, handle=None, daemon=True)\n--\n\n*For internal use only*: start a new thread.\n\nLike start_new_thread(), this starts a new thread calling the given function.\nUnlike start_new_thread(), this returns a handle object with methods to join\nor detach the given thread.\nThis function is not for third-party code, please use the\n`threading` module instead. During finalization the runtime will not wait for\nthe thread to exit if daemon is True. If handle is provided it must be a\nnewly created thread._ThreadHandle instance."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("daemon_threads_allowed"),
                 ml_meth=ptr(thread_daemon_threads_allowed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "daemon_threads_allowed($module, /)\n--\n\nReturn True if daemon threads are allowed in the current interpreter,\nand False otherwise.\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("allocate_lock"),
                 ml_meth=ptr(thread_PyThread_allocate_lock),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "allocate_lock($module, /)\n--\n\nCreate a new lock object. See help(type(threading.Lock())) for\ninformation about locks."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("allocate"),
                 ml_meth=ptr(thread_PyThread_allocate_lock),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "allocate($module, /)\n--\n\nAn obsolete synonym of allocate_lock()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("exit_thread"),
                 ml_meth=ptr(thread_PyThread_exit_thread),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "exit_thread($module, /)\n--\n\nAn obsolete synonym of exit()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("exit"),
                 ml_meth=ptr(thread_PyThread_exit_thread),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "exit($module, /)\n--\n\nThis is synonymous to ``raise SystemExit''.  It will cause the current\nthread to exit silently unless the exception is caught."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("interrupt_main"),
                 ml_meth=ptr(thread_PyThread_interrupt_main),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "interrupt_main($module, signum=signal.SIGINT, /)\n--\n\nSimulate the arrival of the given signal in the main thread,\nwhere the corresponding signal handler will be executed.\nIf *signum* is omitted, SIGINT is assumed.\nA subthread can use this function to interrupt the main thread.\n\nNote: the default signal handler for SIGINT raises ``KeyboardInterrupt``."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_ident"),
                 ml_meth=ptr(thread_get_ident),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_ident($module, /)\n--\n\nReturn a non-zero integer that uniquely identifies the current thread\namongst other threads that exist simultaneously.\nThis may be used to identify per-thread resources.\nEven though on some platforms threads identities may appear to be\nallocated consecutive numbers starting at 1, this behavior should not\nbe relied upon, and the number should be seen purely as a magic cookie.\nA thread's identity may be reused for another thread after it exits."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_native_id"),
                 ml_meth=ptr(thread_get_native_id),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_native_id($module, /)\n--\n\nReturn a non-negative integer identifying the thread as reported\nby the OS (kernel). This may be used to uniquely identify a\nparticular thread within a system."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_count"),
                 ml_meth=ptr(thread__count),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_count($module, /)\n--\n\nReturn the number of currently running Python threads, excluding\nthe main thread. The returned number comprises all threads created\nthrough `start_new_thread()` as well as `threading.Thread`, and not\nyet finished.\n\nThis function is meant for internal and specialized purposes only.\nIn most applications `threading.enumerate()` should be used instead."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("stack_size"),
                 ml_meth=ptr(thread_stack_size),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "stack_size($module, size=0, /)\n--\n\nReturn the thread stack size used when creating new threads.  The\noptional size argument specifies the stack size (in bytes) to be used\nfor subsequently created threads, and must be 0 (use platform or\nconfigured default) or a positive integer value of at least 32,768 (32k).\nIf changing the thread stack size is unsupported, a ThreadError\nexception is raised.  If the specified size is invalid, a ValueError\nexception is raised, and the stack size is unmodified.  32k bytes\n currently the minimum supported stack size value to guarantee\nsufficient stack space for the interpreter itself.\n\nNote that some platforms may have particular restrictions on values for\nthe stack size, such as requiring a minimum stack size larger than 32 KiB or\nrequiring allocation in multiples of the system memory page size\n- platform documentation should be referred to for more information\n(4 KiB pages are common; using multiples of 4096 for the stack size is\nthe suggested approach in the absence of more specific information)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_excepthook"),
                 ml_meth=ptr(thread_excepthook),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "_excepthook($module, args, /)\n--\n\nHandle uncaught Thread.run() exception."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_is_main_interpreter"),
                 ml_meth=ptr(thread__is_main_interpreter),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_is_main_interpreter($module, /)\n--\n\nReturn True if the current interpreter is the main Python interpreter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_shutdown"),
                 ml_meth=ptr(thread_shutdown),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_shutdown($module, /)\n--\n\nWait for all non-daemon threads (other than the calling thread) to stop."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_make_thread_handle"),
                 ml_meth=ptr(thread__make_thread_handle),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "_make_thread_handle($module, ident, /)\n--\n\nInternal only. Make a thread handle for threads not spawned\nby the _thread or threading module."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_get_main_thread_ident"),
                 ml_meth=ptr(thread__get_main_thread_ident),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_get_main_thread_ident($module, /)\n--\n\nInternal only. Return a non-zero integer that uniquely identifies the main thread\nof the main interpreter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         thread_module_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(thread_module_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ]; glob thread_module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_thread"),
             m_doc=ptr[u8](
                 "This module provides primitive operations to write multi-threaded programs.\nThe 'threading' module provides a more convenient interface."
             ),
             m_size=THREAD_MODULE_STATE_SIZE,
             m_methods=addressof(thread_methods),
             m_slots=addressof(thread_module_slots)
         );
}

impl type_flag(op: ptr[PyObject], flag: u64) -> bool {
    return type_has_feature(object_type(op), flag);
}

impl runtime_at(offset: i64) -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + offset;
}

impl tstate_field(tstate: ptr[PyThreadState], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](tstate) + offset);
}

impl get_thread_state(module: ptr[PyObject]) -> ptr[ThreadModuleState] {
    return ptr[ThreadModuleState](PyModule_GetState(module));
}

impl shutdown_handles_of(state: ptr[ThreadModuleState]) -> ptr[llist_node] {
    return ptr[llist_node](ptr[u8](state) + THREAD_MODULE_STATE_SHUTDOWN_HANDLES);
}

impl handle_mutex(handle: ptr[ThreadHandle]) -> ptr[PyMutex] {
    return ptr[PyMutex](ptr[u8](handle) + THREAD_HANDLE_MUTEX);
}

impl handle_exiting(handle: ptr[ThreadHandle]) -> ptr[u8] {
    return ptr[u8](handle) + THREAD_HANDLE_EXITING;
}

impl handle_once(handle: ptr[ThreadHandle]) -> ptr[u8] {
    return ptr[u8](handle) + THREAD_HANDLE_ONCE;
}

impl handle_shutdown_node(handle: ptr[ThreadHandle]) -> ptr[llist_node] {
    return ptr[llist_node](ptr[u8](handle) + THREAD_HANDLE_SHUTDOWN_NODE);
}

impl once_call(flag: ptr[u8], once_fn: ptr, arg: ptr) -> i32 {
    if load_u8(int(flag)) == _Py_ONCE_INITIALIZED {
        return 0;
    }
    return _PyOnceFlag_CallOnceSlow(flag, once_fn, arg);
}

impl get_thread_handle_state(handle: ptr[ThreadHandle]) -> i32 {
    PyMutex_Lock(handle_mutex(handle));
    state = handle.view(1)[0].state;
    PyMutex_Unlock(handle_mutex(handle));
    return state;
}

impl set_thread_handle_state(handle: ptr[ThreadHandle], state: i32) {
    PyMutex_Lock(handle_mutex(handle));
    handle.view(1)[0].state = state;
    PyMutex_Unlock(handle_mutex(handle));
}

impl ThreadHandle_ident(handle: ptr[ThreadHandle]) -> u64 {
    PyMutex_Lock(handle_mutex(handle));
    ident = handle.view(1)[0].ident;
    PyMutex_Unlock(handle_mutex(handle));
    return ident;
}

impl ThreadHandle_get_os_handle(handle: ptr[ThreadHandle]) -> tuple[i32, u64] {
    PyMutex_Lock(handle_mutex(handle));
    has_os_handle = handle.view(1)[0].has_os_handle;
    os_handle = u64(0);
    if has_os_handle != 0 {
        os_handle = handle.view(1)[0].os_handle;
    }
    PyMutex_Unlock(handle_mutex(handle));
    return (has_os_handle, os_handle);
}

impl add_to_shutdown_handles(state: ptr[ThreadModuleState], handle: ptr[ThreadHandle]) {
    runtime = ptr[u8](addressof(_PyRuntime));
    head_lock(runtime);
    lot_llist_insert_tail(shutdown_handles_of(state), handle_shutdown_node(handle));
    head_unlock(runtime);
}

impl clear_shutdown_handles(state: ptr[ThreadModuleState]) {
    runtime = ptr[u8](addressof(_PyRuntime));
    head_lock(runtime);
    head = shutdown_handles_of(state);
    item = head.view(1)[0].next;
    while item != head {
        following = item.view(1)[0].next;
        llist_remove(item);
        item = following;
    }
    head_unlock(runtime);
}

impl remove_from_shutdown_handles(handle: ptr[ThreadHandle]) {
    runtime = ptr[u8](addressof(_PyRuntime));
    head_lock(runtime);
    if handle.view(1)[0].shutdown_node.next {
        llist_remove(handle_shutdown_node(handle));
    }
    head_unlock(runtime);
}

impl ThreadHandle_new -> ptr[ThreadHandle] {
    self_ = ptr[ThreadHandle](PyMem_RawCalloc(u64(1), u64(THREAD_HANDLE_SIZE)));
    if not self_ {
        PyErr_NoMemory();
        return self_;
    }

    self_.view(1)[0].state = THREAD_HANDLE_NOT_STARTED;
    self_.view(1)[0].refcount = 1;

    runtime = ptr[u8](addressof(_PyRuntime));
    head_lock(runtime);
    lot_llist_insert_tail(
        ptr[llist_node](runtime + _PyRuntimeState_THREADS_HANDLES),
        ptr[llist_node](self_)
    );
    head_unlock(runtime);
    return self_;
}

impl ThreadHandle_incref(self_: ptr[ThreadHandle]) {
    __atomic_add_i64(int(self_) + THREAD_HANDLE_REFCOUNT, 1, 5);
}

impl detach_thread(self_: ptr[ThreadHandle]) -> i32 {
    if self_.view(1)[0].has_os_handle == 0 {
        return 0;
    }

    if PyThread_detach_thread(self_.view(1)[0].os_handle) != 0 {
        message = ptr[u8]("detach_thread: failed detaching thread\n");
        _Py_write_noraise(2, ptr(message), strlen(message));
        return -1;
    }
    return 0;
}

impl ThreadHandle_decref(self_: ptr[ThreadHandle]) {
    if __atomic_add_i64(int(self_) + THREAD_HANDLE_REFCOUNT, -1, 5) > 1 {
        return;
    }

    runtime = ptr[u8](addressof(_PyRuntime));
    head_lock(runtime);
    if self_.view(1)[0].link.next {
        llist_remove(ptr[llist_node](self_));
    }
    head_unlock(runtime);

    if self_.view(1)[0].state == THREAD_HANDLE_RUNNING and detach_thread(self_) == 0 {
        self_.view(1)[0].state = THREAD_HANDLE_DONE;
    }

    PyMem_RawFree(ptr(self_));
}

impl thread_bootstate_free(boot: ptr[BootState], decref: bool) {
    if decref {
        object_decref(boot.view(1)[0].func);
        object_decref(boot.view(1)[0].args);
        object_xdecref(boot.view(1)[0].kwargs);
    }
    ThreadHandle_decref(boot.view(1)[0].handle);
    PyMem_RawFree(ptr(boot));
}

impl thread_run(boot_raw: ptr) {
    boot = ptr[BootState](boot_raw);
    tstate = boot.view(1)[0].tstate;

    PyEvent_Wait(ptr[u8](boot) + BOOTSTATE_HANDLE_READY);

    handle = boot.view(1)[0].handle;
    ThreadHandle_incref(handle);

    if _PyThreadState_MustExit(tstate) != 0 {
        thread_bootstate_free(boot, False);
    } else {
        _PyThreadState_Bind(tstate);
        PyEval_AcquireThread(tstate);
        count_addr = int(tstate_interp(tstate)) + PyInterpreterState_THREADS_COUNT;
        __atomic_add_i64(count_addr, 1, 5);
        func = boot.view(1)[0].func;
        res = PyObject_Call(func, boot.view(1)[0].args, boot.view(1)[0].kwargs);
        if not res {
            if PyErr_ExceptionMatches(PyExc_SystemExit) != 0 {
                PyErr_Clear();
            } else {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored in thread started by %R"), func
                );
            }
        } else {
            object_decref(res);
        }
        thread_bootstate_free(boot, True);
        __atomic_add_i64(count_addr, -1, 5);
        PyThreadState_Clear(tstate);
        _PyThreadState_DeleteCurrent(tstate);
    }

    remove_from_shutdown_handles(handle);

    _PyEvent_Notify(handle_exiting(handle));
    ThreadHandle_decref(handle);
}

impl force_done(arg: ptr) -> i32 {
    handle = ptr[ThreadHandle](arg);
    _PyEvent_Notify(handle_exiting(handle));
    set_thread_handle_state(handle, THREAD_HANDLE_DONE);
    return 0;
}

impl ThreadHandle_start(
    self_: ptr[ThreadHandle],
    func: ptr[PyObject],
    args: ptr[PyObject],
    kwargs: ptr[PyObject]
) -> i32 {
    PyMutex_Lock(handle_mutex(self_));
    if self_.view(1)[0].state != THREAD_HANDLE_NOT_STARTED {
        PyMutex_Unlock(handle_mutex(self_));
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("thread already started"));
        return -1;
    }
    self_.view(1)[0].state = THREAD_HANDLE_STARTING;
    PyMutex_Unlock(handle_mutex(self_));

    boot = ptr[BootState](PyMem_RawMalloc(u64(BOOTSTATE_SIZE)));
    if not boot {
        PyErr_NoMemory();
        once_call(handle_once(self_), ptr(force_done), ptr(self_));
        return -1;
    }
    tstate = _PyThreadState_New(current_interp(), _PyThreadState_WHENCE_THREADING);
    boot.view(1)[0].tstate = tstate;
    if not tstate {
        PyMem_RawFree(ptr(boot));
        if PyErr_Occurred() == NULL {
            PyErr_NoMemory();
        }
        once_call(handle_once(self_), ptr(force_done), ptr(self_));
        return -1;
    }
    boot.view(1)[0].func = object_new_ref(func);
    boot.view(1)[0].args = object_new_ref(args);
    boot.view(1)[0].kwargs = object_xnewref(kwargs);
    boot.view(1)[0].handle = self_;
    ThreadHandle_incref(self_);
    boot.view(1)[0].handle_ready = u8(0);

    ident: u64 = 0;
    os_handle: u64 = 0;
    if PyThread_start_joinable_thread(
        ptr(thread_run), ptr(boot), &mut ident, &mut os_handle
    )
        != 0 {
        PyThreadState_Clear(tstate);
        PyThreadState_Delete(tstate);
        thread_bootstate_free(boot, True);
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("can't start new thread"));
        once_call(handle_once(self_), ptr(force_done), ptr(self_));
        return -1;
    }

    PyMutex_Lock(handle_mutex(self_));
    self_.view(1)[0].ident = ident;
    self_.view(1)[0].has_os_handle = 1;
    self_.view(1)[0].os_handle = os_handle;
    self_.view(1)[0].state = THREAD_HANDLE_RUNNING;
    PyMutex_Unlock(handle_mutex(self_));

    _PyEvent_Notify(ptr[u8](boot) + BOOTSTATE_HANDLE_READY);
    return 0;
}

impl join_thread(arg: ptr) -> i32 {
    handle = ptr[ThreadHandle](arg);
    (has_os_handle, os_handle) = ThreadHandle_get_os_handle(handle);
    if has_os_handle != 0 {
        save = PyEval_SaveThread();
        err = PyThread_join_thread(os_handle);
        PyEval_RestoreThread(save);
        if err != 0 {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("Failed joining thread"));
            return -1;
        }
    }
    set_thread_handle_state(handle, THREAD_HANDLE_DONE);
    return 0;
}

impl check_started(self_: ptr[ThreadHandle]) -> i32 {
    if get_thread_handle_state(self_) < THREAD_HANDLE_RUNNING {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("thread not started"));
        return -1;
    }
    return 0;
}

impl ThreadHandle_join(self_: ptr[ThreadHandle], timeout_in: i64) -> i32 {
    timeout_ns = timeout_in;
    if check_started(self_) < 0 {
        return -1;
    }

    if _PyEvent_IsSet(handle_exiting(self_)) == 0 {
        if ThreadHandle_ident(self_) == PyThread_get_thread_ident_ex() {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("Cannot join current thread"));
            return -1;
        }
        if Py_IsFinalizing() != 0 {
            PyErr_SetString(
                PyExc_PythonFinalizationError,
                ptr[u8]("cannot join thread at interpreter shutdown")
            );
            return -1;
        }
    }

    deadline = i64(0);
    if timeout_ns != -1 {
        deadline = _PyDeadline_Init(timeout_ns);
    }
    detach = i32(1);
    while PyEvent_WaitTimed(handle_exiting(self_), timeout_ns, detach) == 0 {
        if deadline != 0 {
            timeout_ns = _PyDeadline_Get(deadline);
            if timeout_ns < 0 {
                timeout_ns = 0;
            }
        }

        if timeout_ns != 0 {
            if Py_MakePendingCalls() < 0 {
                return -1;
            }
        } else {
            return 0;
        }
    }

    if once_call(handle_once(self_), ptr(join_thread), ptr(self_)) == -1 {
        return -1;
    }
    return 0;
}

impl set_done(arg: ptr) -> i32 {
    handle = ptr[ThreadHandle](arg);
    if detach_thread(handle) < 0 {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("failed detaching handle"));
        return -1;
    }
    _PyEvent_Notify(handle_exiting(handle));
    set_thread_handle_state(handle, THREAD_HANDLE_DONE);
    return 0;
}

impl ThreadHandle_set_done(self_: ptr[ThreadHandle]) -> i32 {
    if check_started(self_) < 0 {
        return -1;
    }
    if once_call(handle_once(self_), ptr(set_done), ptr(self_)) == -1 {
        return -1;
    }
    return 0;
}

impl handle_of(op: ptr[PyObject]) -> ptr[ThreadHandle] {
    return ptr[PyThreadHandleObject](op).view(1)[0].handle;
}

impl PyThreadHandleObject_new(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    handle = ThreadHandle_new();
    if not handle {
        return NULL;
    }
    self_ = type.view(1)[0].tp_alloc(type, 0);
    if not self_ {
        ThreadHandle_decref(handle);
        return NULL;
    }
    ptr[PyThreadHandleObject](self_).view(1)[0].handle = handle;
    return self_;
}

impl PyThreadHandleObject_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return PyThreadHandleObject_new(type);
}

impl PyThreadHandleObject_traverse(
    self_: ptr[PyObject], visitor: ptr, arg: ptr
) -> i32 {
    return visit_reference(ptr[PyObject](object_type(self_)), visitor, arg);
}

impl PyThreadHandleObject_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(ptr(op));
    tp = object_type(op);
    ThreadHandle_decref(handle_of(op));
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl PyThreadHandleObject_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    ident = ThreadHandle_ident(handle_of(op));
    return PyUnicode_FromFormat(
        "<%s object: ident=%llu>", object_type(op).view(1)[0].tp_name, ident
    );
}

impl PyThreadHandleObject_get_ident(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromUnsignedLongLong(ThreadHandle_ident(handle_of(op)));
}

impl PyThreadHandleObject_join(
    op: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    timeout_obj = NULL;
    if PyTuple_Size(args) != 0 {
        try {
            values = ArgumentFormat(name="join").parse(args, "|O");
        } except boundary_failure {
            return NULL;
        }
        timeout_obj = values[0].object;
    }

    timeout_ns: i64 = -1;
    if timeout_obj != NULL and timeout_obj != Py_None {
        if _PyTime_FromSecondsObject(
            &mut timeout_ns, timeout_obj, _PyTime_ROUND_TIMEOUT
        )
            < 0 {
            return NULL;
        }
    }

    if ThreadHandle_join(handle_of(op), timeout_ns) < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl PyThreadHandleObject_is_done(
    op: ptr[PyObject], dummy: ptr[PyObject]
) -> ptr[PyObject] {
    handle = handle_of(op);
    if _PyEvent_IsSet(handle_exiting(handle)) != 0 {
        if once_call(handle_once(handle), ptr(join_thread), ptr(handle)) == -1 {
            return NULL;
        }
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl PyThreadHandleObject_set_done(
    op: ptr[PyObject], dummy: ptr[PyObject]
) -> ptr[PyObject] {
    if ThreadHandle_set_done(handle_of(op)) < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl lock_mutex(op: ptr[PyObject]) -> ptr[PyMutex] {
    return ptr[PyMutex](ptr[u8](op) + LOCK_MUTEX);
}

impl lock_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ptr[PyObject](object_type(self_)), visitor, arg);
}

impl lock_dealloc(self_: ptr[PyObject]) {
    PyObject_GC_UnTrack(ptr(self_));
    PyObject_ClearWeakRefs(self_);
    tp = object_type(self_);
    tp.view(1)[0].tp_free(ptr(self_));
    object_decref(ptr[PyObject](tp));
}

impl lock_acquire_parse_args(
    args: ptr[PyObject], kwds: ptr[PyObject]
) -> tuple[i32, i64] {
    if (not kwds or PyDict_Size(kwds) == 0) and PyTuple_Size(args) == 0 {
        return (i32(0), UNSET_TIMEOUT);
    }
    try {
        values = ArgumentFormat(name="acquire").parse_keywords(
            args, kwds, "|pO", ["blocking", "timeout"]
        );
    } except boundary_failure {
        return (i32(-1), i64(0));
    }
    blocking = not values[0].given or values[0].flag;
    timeout_obj = values[1].object;

    unset_timeout = _PyTime_FromSeconds(-1);
    timeout: i64 = unset_timeout;

    if timeout_obj != NULL
        and _PyTime_FromSecondsObject(&mut timeout, timeout_obj, _PyTime_ROUND_TIMEOUT)
            < 0 {
        return (i32(-1), i64(0));
    }

    if not blocking and timeout != unset_timeout {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("can't specify a timeout for a non-blocking call")
        );
        return (i32(-1), i64(0));
    }
    if timeout < 0 and timeout != unset_timeout {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("timeout value must be a non-negative number")
        );
        return (i32(-1), i64(0));
    }
    if not blocking {
        timeout = 0;
    } elif timeout != unset_timeout {
        microseconds = _PyTime_AsMicroseconds(timeout, _PyTime_ROUND_TIMEOUT);
        if microseconds > PY_TIMEOUT_MAX {
            PyErr_SetString(PyExc_OverflowError, ptr[u8]("timeout value is too large"));
            return (i32(-1), i64(0));
        }
    }
    return (i32(0), timeout);
}

impl lock_PyThread_acquire_lock(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    (status, timeout) = lock_acquire_parse_args(args, kwds);
    if status < 0 {
        return NULL;
    }

    r = _PyMutex_LockTimed(
        lock_mutex(op), timeout, _PY_LOCK_HANDLE_SIGNALS | _PY_LOCK_DETACH
    );
    if r == PY_LOCK_INTR {
        return NULL;
    }
    return PyBool_FromLong(i64(1) if r == PY_LOCK_ACQUIRED else i64(0));
}

impl lock_PyThread_release_lock(
    op: ptr[PyObject], dummy: ptr[PyObject]
) -> ptr[PyObject] {
    if _PyMutex_TryUnlock(lock_mutex(op)) < 0 {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("release unlocked lock"));
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl lock_locked_lock(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(PyMutex_IsLocked(lock_mutex(op))));
}

impl lock_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    state = ptr[u8]("unlocked");
    if PyMutex_IsLocked(lock_mutex(op)) != 0 {
        state = ptr[u8]("locked");
    }
    return PyUnicode_FromFormat(
        "<%s %s object at %p>", state, object_type(op).view(1)[0].tp_name, ptr(op)
    );
}

impl lock__at_fork_reinit(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    ptr[u8](lock_mutex(op)).view(1)[0] = u8(0);
    return object_new_ref(Py_None);
}

impl lock_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if kwargs != NULL and _PyArg_NoKeywords(ptr[u8]("lock"), kwargs) == 0 {
        return NULL;
    }
    nargs = PyTuple_Size(args);
    if nargs != 0 and not check_positional("lock", int(nargs), 0, 0) {
        return NULL;
    }

    module = PyType_GetModuleByDef(type, ptr[PyModuleDef](addressof(thread_module)));
    return newlockobject(module);
}

impl rlock_mutex(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + RLOCK_MUTEX;
}

impl rlock_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ptr[PyObject](object_type(self_)), visitor, arg);
}

impl rlock_locked_impl(op: ptr[PyObject]) -> i32 {
    return PyMutex_IsLocked(ptr[PyMutex](rlock_mutex(op)));
}

impl rlock_dealloc(self_: ptr[PyObject]) {
    PyObject_GC_UnTrack(ptr(self_));
    PyObject_ClearWeakRefs(self_);
    tp = object_type(self_);
    tp.view(1)[0].tp_free(ptr(self_));
    object_decref(ptr[PyObject](tp));
}

impl rlock_acquire(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    (status, timeout) = lock_acquire_parse_args(args, kwds);
    if status < 0 {
        return NULL;
    }

    r = _PyRecursiveMutex_LockTimed(
        rlock_mutex(op), timeout, _PY_LOCK_HANDLE_SIGNALS | _PY_LOCK_DETACH
    );
    if r == PY_LOCK_INTR {
        return NULL;
    }
    return PyBool_FromLong(i64(1) if r == PY_LOCK_ACQUIRED else i64(0));
}

impl rlock_release(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    if _PyRecursiveMutex_TryUnlock(rlock_mutex(op)) < 0 {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("cannot release un-acquired lock"));
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl rlock_locked(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(rlock_locked_impl(op)));
}

impl parse_restore_state(args: ptr[PyObject]) -> tuple[bool, i64, u64] {
    try {
        values = ArgumentFormat(name="_acquire_restore").parse(args, "O");
    } except boundary_failure {
        return (False, i64(0), u64(0));
    }
    state = values[0].object;
    if not type_flag(state, Py_TPFLAGS_TUPLE_SUBCLASS) or PyTuple_Size(state) != 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "_acquire_restore() argument 1 must be sequence of length 2, not %.50s"
            ),
            object_type(state).view(1)[0].tp_name
        );
        return (False, i64(0), u64(0));
    }
    index = PyNumber_Index(tuple_get_item(state, 0));
    if not index {
        return (False, i64(0), u64(0));
    }
    count = PyLong_AsSsize_t(index);
    object_decref(index);
    if count == -1 and PyErr_Occurred() != NULL {
        return (False, i64(0), u64(0));
    }
    owner_obj = tuple_get_item(state, 1);
    if PyIndex_Check(owner_obj) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("_acquire_restore() argument 1 must be int, not %.50s"),
            object_type(owner_obj).view(1)[0].tp_name
        );
        return (False, i64(0), u64(0));
    }
    owner = PyLong_AsUnsignedLongLongMask(owner_obj);
    if owner == u64(0xFFFFFFFFFFFFFFFF) and PyErr_Occurred() != NULL {
        return (False, i64(0), u64(0));
    }
    return (True, count, owner);
}

impl rlock_acquire_restore(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, count, owner) = parse_restore_state(args);
    if not ok {
        return NULL;
    }

    _PyRecursiveMutex_Lock(rlock_mutex(op));
    __atomic_store_i64(int(op) + RLOCK_THREAD, i64.wrap(owner), 0);
    ptr[rlockobject](op).view(1)[0].level = wrapping_sub(u64.wrap(count), u64(1));
    return object_new_ref(Py_None);
}

impl rlock_release_save(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    if _PyRecursiveMutex_IsLockedByCurrentThread(rlock_mutex(op)) == 0 {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("cannot release un-acquired lock"));
        return NULL;
    }

    lock = ptr[rlockobject](op).view(1);
    owner = lock[0].thread;
    count = i64.wrap(wrapping_add(lock[0].level, u64(1)));

    lock[0].level = u64(0);
    _PyRecursiveMutex_Unlock(rlock_mutex(op));
    return Py_BuildValue(ptr[u8]("nK"), count, owner);
}

impl rlock_recursion_count(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    if _PyRecursiveMutex_IsLockedByCurrentThread(rlock_mutex(op)) != 0 {
        return PyLong_FromSize_t(
            wrapping_add(ptr[rlockobject](op).view(1)[0].level, u64(1))
        );
    }
    return PyLong_FromLong(0);
}

impl rlock_is_owned(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    owned = _PyRecursiveMutex_IsLockedByCurrentThread(rlock_mutex(op));
    return PyBool_FromLong(i64(owned));
}

impl rlock_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = type.view(1)[0].tp_alloc(type, 0);
    if not self_ {
        return NULL;
    }
    lock = ptr[rlockobject](self_).view(1);
    lock[0].mutex = u8(0);
    lock[0].thread = u64(0);
    lock[0].level = u64(0);
    return self_;
}

impl rlock_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    lock = ptr[rlockobject](op).view(1);
    owner = lock[0].thread;
    locked = rlock_locked_impl(op);
    count = u64(0);
    if locked != 0 {
        count = wrapping_add(lock[0].level, u64(1));
    }
    state = ptr[u8]("unlocked");
    if locked != 0 {
        state = ptr[u8]("locked");
    }
    return PyUnicode_FromFormat(
        "<%s %s object owner=%llu count=%zu at %p>",
        state,
        object_type(op).view(1)[0].tp_name,
        owner,
        count,
        ptr(op)
    );
}

impl rlock__at_fork_reinit(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    lock = ptr[rlockobject](op).view(1);
    lock[0].mutex = u8(0);
    lock[0].thread = u64(0);
    lock[0].level = u64(0);
    return object_new_ref(Py_None);
}

impl newlockobject(module: ptr[PyObject]) -> ptr[PyObject] {
    state = get_thread_state(module);
    type = state.view(1)[0].lock_type;
    self_ = type.view(1)[0].tp_alloc(type, 0);
    if not self_ {
        return NULL;
    }
    ptr[u8](lock_mutex(self_)).view(1)[0] = u8(0);
    return self_;
}

impl localdummy_dealloc(op: ptr[PyObject]) {
    if ptr[localdummyobject](op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    tp = object_type(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl create_sentinel_wr(self_: ptr[PyObject]) -> ptr[PyObject] {
    tstate = PyThreadState_Get();

    self_wr = PyWeakref_NewRef(self_, NULL);
    if not self_wr {
        return NULL;
    }

    args = PyTuple_New(2);
    if not args {
        object_decref(self_wr);
        return NULL;
    }
    tuple_set_item(args, 0, self_wr);
    tuple_set_item(
        args,
        1,
        object_new_ref(
            tstate_field(tstate, PyThreadState_THREADING_LOCAL_KEY).view(1)[0]
        )
    );

    cb = PyCFunction_New(addressof(wr_callback_def), args);
    object_decref(args);
    if not cb {
        return NULL;
    }

    wr = PyWeakref_NewRef(
        tstate_field(tstate, PyThreadState_THREADING_LOCAL_SENTINEL).view(1)[0], cb
    );
    object_decref(cb);
    return wr;
}

impl local_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    base_init = int(ptr[PyTypeObject](addressof(PyBaseObject_Type)).view(1)[0].tp_init);
    if int(type.view(1)[0].tp_init) == base_init {
        rc = i32(0);
        if args {
            rc = PyObject_IsTrue(args);
        }
        if rc == 0 and kw != NULL {
            rc = PyObject_IsTrue(kw);
        }
        if rc != 0 {
            if rc > 0 {
                PyErr_SetString(
                    PyExc_TypeError,
                    ptr[u8]("Initialization arguments are not supported")
                );
            }
            return NULL;
        }
    }

    module = PyType_GetModuleByDef(type, ptr[PyModuleDef](addressof(thread_module)));
    state = get_thread_state(module);

    self_ = type.view(1)[0].tp_alloc(type, 0);
    if not self_ {
        return NULL;
    }
    local = ptr[localobject](self_).view(1);

    _PyObject_SetDeferredRefcount(self_);

    local[0].args = object_xnewref(args);
    local[0].kw = object_xnewref(kw);

    local[0].localdicts = PyDict_New();
    if not local[0].localdicts {
        object_decref(self_);
        return NULL;
    }

    local[0].thread_watchdogs = PySet_New(NULL);
    if not local[0].thread_watchdogs {
        object_decref(self_);
        return NULL;
    }

    (status, localsdict, sentinel_wr) = create_localsdict(self_, state);
    if status < 0 {
        object_decref(self_);
        return NULL;
    }
    object_decref(localsdict);
    object_decref(sentinel_wr);
    return self_;
}

impl local_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    local = ptr[localobject](op).view(1);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(local[0].args, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(local[0].kw, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(local[0].localdicts, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(local[0].thread_watchdogs, visitor, arg);
}

impl local_clear(op: ptr[PyObject]) -> i32 {
    local = ptr[localobject](op).view(1);
    value = local[0].args;
    local[0].args = NULL;
    object_xdecref(value);
    value = local[0].kw;
    local[0].kw = NULL;
    object_xdecref(value);
    value = local[0].localdicts;
    local[0].localdicts = NULL;
    object_xdecref(value);
    value = local[0].thread_watchdogs;
    local[0].thread_watchdogs = NULL;
    object_xdecref(value);
    return 0;
}

impl local_dealloc(op: ptr[PyObject]) {
    if ptr[localobject](op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    PyObject_GC_UnTrack(ptr(op));
    local_clear(op);
    tp = object_type(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl create_localdummies(state: ptr[ThreadModuleState]) -> i32 {
    tstate = current_tstate();
    key_slot = tstate_field(tstate, PyThreadState_THREADING_LOCAL_KEY);
    if key_slot.view(1)[0] {
        return 0;
    }

    ld_type = state.view(1)[0].local_dummy_type;
    key_slot.view(1)[0] = ld_type.view(1)[0].tp_alloc(ld_type, 0);
    if not key_slot.view(1)[0] {
        return -1;
    }

    sentinel_slot = tstate_field(tstate, PyThreadState_THREADING_LOCAL_SENTINEL);
    sentinel_slot.view(1)[0] = ld_type.view(1)[0].tp_alloc(ld_type, 0);
    if not sentinel_slot.view(1)[0] {
        key = key_slot.view(1)[0];
        key_slot.view(1)[0] = NULL;
        object_decref(key);
        return -1;
    }
    return 0;
}

impl drop_local_dict(self_: ptr[PyObject], key: ptr[PyObject]) {
    exc = PyErr_GetRaisedException();
    if PyDict_DelItem(ptr[localobject](self_).view(1)[0].localdicts, key) < 0 {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while deleting thread local of %R"), self_
        );
    }
    PyErr_SetRaisedException(exc);
}

impl create_localsdict(
    self_: ptr[PyObject], state: ptr[ThreadModuleState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    tstate = current_tstate();
    if create_localdummies(state) < 0 {
        return (i32(-1), NULL, NULL);
    }

    ldict = PyDict_New();
    if not ldict {
        return (i32(-1), NULL, NULL);
    }

    key = tstate_field(tstate, PyThreadState_THREADING_LOCAL_KEY).view(1)[0];
    if PyDict_SetItem(ptr[localobject](self_).view(1)[0].localdicts, key, ldict) < 0 {
        object_decref(ldict);
        return (i32(-1), NULL, NULL);
    }

    wr = create_sentinel_wr(self_);
    if not wr {
        drop_local_dict(self_, key);
        object_decref(ldict);
        return (i32(-1), NULL, NULL);
    }

    if PySet_Add(ptr[localobject](self_).view(1)[0].thread_watchdogs, wr) < 0 {
        drop_local_dict(self_, key);
        object_decref(ldict);
        object_decref(wr);
        return (i32(-1), NULL, NULL);
    }
    return (i32(0), ldict, wr);
}

impl _ldict(self_: ptr[PyObject], state: ptr[ThreadModuleState]) -> ptr[PyObject] {
    if create_localdummies(state) < 0 {
        return NULL;
    }

    ldict = NULL;
    tstate = current_tstate();
    key = tstate_field(tstate, PyThreadState_THREADING_LOCAL_KEY).view(1)[0];
    if PyDict_GetItemRef(ptr[localobject](self_).view(1)[0].localdicts, key, &mut ldict)
        < 0 {
        return NULL;
    }
    if ldict {
        return ldict;
    }

    (status, created, wr) = create_localsdict(self_, state);
    if status < 0 {
        return NULL;
    }

    type = object_type(self_);
    base_init = int(ptr[PyTypeObject](addressof(PyBaseObject_Type)).view(1)[0].tp_init);
    if int(type.view(1)[0].tp_init) != base_init {
        local = ptr[localobject](self_).view(1);
        if type.view(1)[0].tp_init(self_, local[0].args, local[0].kw) < 0 {
            exc = PyErr_GetRaisedException();
            if PyDict_DelItem(local[0].localdicts, key) < 0 {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while deleting thread local of %R"),
                    self_
                );
            }
            if PySet_Discard(local[0].thread_watchdogs, wr) < 0 {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while discarding thread watchdog of %R"),
                    self_
                );
            }
            PyErr_SetRaisedException(exc);
            object_decref(created);
            object_decref(wr);
            return NULL;
        }
    }
    object_decref(wr);
    return created;
}

impl local_setattro(op: ptr[PyObject], name: ptr[PyObject], v: ptr[PyObject]) -> i32 {
    module = PyType_GetModuleByDef(
        object_type(op), ptr[PyModuleDef](addressof(thread_module))
    );
    state = get_thread_state(module);

    ldict = _ldict(op, state);
    if not ldict {
        return -1;
    }

    r = PyObject_RichCompareBool(name, py_id(_Py_ID___dict__), Py_EQ);
    if r == -1 {
        object_decref(ldict);
        return -1;
    }
    if r == 1 {
        PyErr_Format(
            PyExc_AttributeError,
            ptr[u8]("'%.100s' object attribute %R is read-only"),
            object_type(op).view(1)[0].tp_name,
            name
        );
        object_decref(ldict);
        return -1;
    }

    st = _PyObject_GenericSetAttrWithDict(op, name, v, ldict);
    object_decref(ldict);
    return st;
}

impl local_getattro(op: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    module = PyType_GetModuleByDef(
        object_type(op), ptr[PyModuleDef](addressof(thread_module))
    );
    state = get_thread_state(module);

    ldict = _ldict(op, state);
    if not ldict {
        return NULL;
    }

    r = PyObject_RichCompareBool(name, py_id(_Py_ID___dict__), Py_EQ);
    if r == 1 {
        return ldict;
    }
    if r == -1 {
        object_decref(ldict);
        return NULL;
    }

    if object_type(op) != state.view(1)[0].local_type {
        res = _PyObject_GenericGetAttrWithDict(op, name, ldict, 0);
        object_decref(ldict);
        return res;
    }

    value = NULL;
    if PyDict_GetItemRef(ldict, name, &mut value) != 0 {
        object_decref(ldict);
        return value;
    }

    res = _PyObject_GenericGetAttrWithDict(op, name, ldict, 0);
    object_decref(ldict);
    return res;
}

impl clear_locals(
    locals_and_key: ptr[PyObject], dummyweakref: ptr[PyObject]
) -> ptr[PyObject] {
    localweakref = PyTuple_GetItem(locals_and_key, 0);
    self_ = weakref_get_ref(localweakref);
    if not self_ {
        return object_new_ref(Py_None);
    }

    local = ptr[localobject](self_).view(1);
    if local[0].localdicts {
        key = PyTuple_GetItem(locals_and_key, 1);
        if PyDict_Pop(local[0].localdicts, key, None) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing thread local %R"), self_
            );
        }
    }
    if local[0].thread_watchdogs {
        if PySet_Discard(local[0].thread_watchdogs, dummyweakref) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing thread local %R"), self_
            );
        }
    }

    object_decref(self_);
    return object_new_ref(Py_None);
}

impl thread_daemon_threads_allowed(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    flags = ptr[u64](current_interp() + PyInterpreterState_FEATURE_FLAGS).view(1)[0];
    return PyBool_FromLong(
        i64(1) if (flags & Py_RTFLAGS_DAEMON_THREADS) != u64(0) else i64(0)
    );
}

impl do_start_new_thread(
    state: ptr[ThreadModuleState],
    func: ptr[PyObject],
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    handle: ptr[ThreadHandle],
    daemon: bool
) -> i32 {
    interp = current_interp();
    flags = ptr[u64](interp + PyInterpreterState_FEATURE_FLAGS).view(1)[0];
    if (flags & Py_RTFLAGS_THREADS) == u64(0) {
        PyErr_SetString(
            PyExc_RuntimeError,
            ptr[u8]("thread is not supported for isolated subinterpreters")
        );
        return -1;
    }
    if __atomic_load_i64(int(interp) + PyInterpreterState_FINALIZING, 0) != 0 {
        PyErr_SetString(
            PyExc_PythonFinalizationError,
            ptr[u8]("can't create new thread at interpreter shutdown")
        );
        return -1;
    }

    if not daemon {
        add_to_shutdown_handles(state, handle);
    }

    if ThreadHandle_start(handle, func, args, kwargs) < 0 {
        if not daemon {
            remove_from_shutdown_handles(handle);
        }
        return -1;
    }
    return 0;
}

impl thread_PyThread_start_new_thread(
    module: ptr[PyObject], fargs: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_thread_state(module);
    func = NULL;
    args = NULL;
    kwargs = NULL;
    if PyArg_UnpackTuple(
        fargs, ptr[u8]("start_new_thread"), 2, 3, &mut func, &mut args, &mut kwargs
    )
        == 0 {
        return NULL;
    }
    if PyCallable_Check(func) == 0 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("first arg must be callable"));
        return NULL;
    }
    if not type_flag(args, Py_TPFLAGS_TUPLE_SUBCLASS) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("2nd arg must be a tuple"));
        return NULL;
    }
    if kwargs != NULL and not type_flag(kwargs, Py_TPFLAGS_DICT_SUBCLASS) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("optional 3rd arg must be a dictionary")
        );
        return NULL;
    }

    shown_kwargs = kwargs or Py_None;
    if PySys_Audit("_thread.start_new_thread", "OOO", func, args, shown_kwargs) < 0 {
        return NULL;
    }

    handle = ThreadHandle_new();
    if not handle {
        return NULL;
    }

    st = do_start_new_thread(state, func, args, kwargs, handle, True);
    if st < 0 {
        ThreadHandle_decref(handle);
        return NULL;
    }
    ident = ThreadHandle_ident(handle);
    ThreadHandle_decref(handle);
    return PyLong_FromUnsignedLongLong(ident);
}

impl thread_PyThread_start_joinable_thread(
    module: ptr[PyObject], fargs: ptr[PyObject], fkwargs: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_thread_state(module);
    try {
        values = ArgumentFormat(name="start_joinable_thread").parse_keywords(
            fargs, fkwargs, "O|Op", ["function", "handle", "daemon"]
        );
    } except boundary_failure {
        return NULL;
    }
    func = values[0].object;
    hobj = values[1].object;
    daemon = not values[2].given or values[2].flag;

    if PyCallable_Check(func) == 0 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("thread function must be callable"));
        return NULL;
    }

    if not hobj {
        hobj = Py_None;
    } elif hobj != Py_None
        and object_type(hobj) != state.view(1)[0].thread_handle_type {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("'handle' must be a _ThreadHandle"));
        return NULL;
    }

    daemon_flag = i32(1) if daemon else i32(0);
    if PySys_Audit("_thread.start_joinable_thread", "OiO", func, daemon_flag, hobj)
        < 0 {
        return NULL;
    }

    if hobj == Py_None {
        hobj = PyThreadHandleObject_new(state.view(1)[0].thread_handle_type);
        if not hobj {
            return NULL;
        }
    } else {
        object_incref(hobj);
    }

    args = PyTuple_New(0);
    if not args {
        return NULL;
    }
    st = do_start_new_thread(state, func, args, NULL, handle_of(hobj), daemon);
    object_decref(args);
    if st < 0 {
        object_decref(hobj);
        return NULL;
    }
    return hobj;
}

impl thread_PyThread_exit_thread(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetNone(PyExc_SystemExit);
    return NULL;
}

impl thread_PyThread_interrupt_main(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    signum = i32(SIGINT);
    if PyTuple_Size(args) != 0 {
        try {
            values = ArgumentFormat(name="signum").parse(args, "|i");
        } except boundary_failure {
            return NULL;
        }
        signum = i32(values[0].signed);
    }

    if PyErr_SetInterruptEx(signum) != 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("signal number out of range"));
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl thread_PyThread_allocate_lock(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return newlockobject(module);
}

impl thread_get_ident(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    ident = PyThread_get_thread_ident_ex();
    if ident == PYTHREAD_INVALID_THREAD_ID {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("no current thread ident"));
        return NULL;
    }
    return PyLong_FromUnsignedLongLong(ident);
}

impl thread_get_native_id(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return PyLong_FromUnsignedLong(PyThread_get_thread_native_id());
}

impl thread__count(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    count = __atomic_load_i64(
        int(current_interp()) + PyInterpreterState_THREADS_COUNT, 5
    );
    return PyLong_FromSsize_t(count);
}

impl thread_stack_size(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    new_size = i64(0);
    if PyTuple_Size(args) != 0 {
        try {
            values = ArgumentFormat(name="stack_size").parse(args, "|n");
        } except boundary_failure {
            return NULL;
        }
        new_size = values[0].signed;
    }

    min_size = PYOS_MIN_STACK_SIZE + SYSTEM_PAGE_SIZE;
    if new_size != 0 and new_size < min_size {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("size must be at least %zi bytes"), min_size
        );
        return NULL;
    }

    old_size = PyThread_get_stacksize();

    rc = PyThread_set_stacksize(u64.wrap(new_size));
    if rc == -1 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("size not valid: %zd bytes"), new_size);
        return NULL;
    }
    if rc == -2 {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("setting stack size not supported")
        );
        return NULL;
    }
    return PyLong_FromSsize_t(i64.wrap(old_size));
}

impl thread_excepthook_file(
    file: ptr[PyObject],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_traceback: ptr[PyObject],
    thread: ptr[PyObject]
) -> i32 {
    if PyFile_WriteString(ptr[u8]("Exception in thread "), file) < 0 {
        return -1;
    }

    name = NULL;
    if thread != Py_None {
        if PyObject_GetOptionalAttr(thread, py_id(_Py_ID_name), &mut name) < 0 {
            return -1;
        }
    }
    if name {
        if PyFile_WriteObject(name, file, Py_PRINT_RAW) < 0 {
            object_decref(name);
            return -1;
        }
        object_decref(name);
    } else {
        ident = PyThread_get_thread_ident_ex();
        text = PyUnicode_FromFormat("%llu", ident);
        if text {
            if PyFile_WriteObject(text, file, Py_PRINT_RAW) < 0 {
                object_decref(text);
                return -1;
            }
            object_decref(text);
        } else {
            PyErr_Clear();
            if PyFile_WriteString(ptr[u8]("<failed to get thread name>"), file) < 0 {
                return -1;
            }
        }
    }

    if PyFile_WriteString(ptr[u8](":\n"), file) < 0 {
        return -1;
    }

    _PyErr_Display(file, exc_type, exc_value, exc_traceback);

    if _PyFile_Flush(file) < 0 {
        return -1;
    }
    return 0;
}

impl thread_excepthook(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    state = get_thread_state(module);

    if object_type(args) != state.view(1)[0].excepthook_type {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("_thread.excepthook argument type must be ExceptHookArgs")
        );
        return NULL;
    }

    exc_type = tuple_get_item(args, 0);
    if exc_type == PyExc_SystemExit {
        return object_new_ref(Py_None);
    }

    exc_value = tuple_get_item(args, 1);
    exc_tb = tuple_get_item(args, 2);
    thread = tuple_get_item(args, 3);

    file = NULL;
    if _PySys_GetOptionalAttr(py_id(_Py_ID_stderr), &mut file) < 0 {
        return NULL;
    }
    if not file or file == Py_None {
        object_xdecref(file);
        if thread == Py_None {
            return object_new_ref(Py_None);
        }

        file = PyObject_GetAttrString(thread, ptr[u8]("_stderr"));
        if not file {
            return NULL;
        }
        if file == Py_None {
            object_decref(file);

            return object_new_ref(Py_None);
        }
    }

    res = thread_excepthook_file(file, exc_type, exc_value, exc_tb, thread);
    object_decref(file);
    if res < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl thread__is_main_interpreter(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return PyBool_FromLong(i64(1) if is_main_interpreter(current_interp()) else i64(0));
}

impl thread_shutdown(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    ident = PyThread_get_thread_ident_ex();
    state = get_thread_state(self_);
    runtime = ptr[u8](addressof(_PyRuntime));

    while True {
        handle = ptr[ThreadHandle]();

        head_lock(runtime);
        head = shutdown_handles_of(state);
        item = head.view(1)[0].next;
        while item != head {
            following = item.view(1)[0].next;
            cur = ptr[ThreadHandle](ptr[u8](item) - THREAD_HANDLE_SHUTDOWN_NODE);
            if cur.view(1)[0].ident != ident {
                ThreadHandle_incref(cur);
                handle = cur;
                break;
            }
            item = following;
        }
        head_unlock(runtime);

        if not handle {
            break;
        }

        if ThreadHandle_join(handle, -1) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8](
                    "Exception ignored while joining a thread in _thread._shutdown()"
                )
            );
            ThreadHandle_decref(handle);
            return object_new_ref(Py_None);
        }

        ThreadHandle_decref(handle);
    }
    return object_new_ref(Py_None);
}

impl thread__make_thread_handle(
    module: ptr[PyObject], identobj: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_thread_state(module);
    if not type_flag(identobj, Py_TPFLAGS_LONG_SUBCLASS) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("ident must be an integer"));
        return NULL;
    }
    ident = PyLong_AsUnsignedLongLong(identobj);
    if PyErr_Occurred() != NULL {
        return NULL;
    }
    hobj = PyThreadHandleObject_new(state.view(1)[0].thread_handle_type);
    if not hobj {
        return NULL;
    }
    handle = handle_of(hobj);
    PyMutex_Lock(handle_mutex(handle));
    handle.view(1)[0].ident = ident;
    handle.view(1)[0].state = THREAD_HANDLE_RUNNING;
    PyMutex_Unlock(handle_mutex(handle));
    return hobj;
}

impl thread__get_main_thread_ident(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return PyLong_FromUnsignedLongLong(
        ptr[u64](runtime_at(_PyRuntimeState_MAIN_THREAD)).view(1)[0]
    );
}

impl _thread__get_name_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    name_slots: own SignalBuffer = SignalBuffer();
    name = ptr[u8](jacpy_stack_address(&mut name_slots));
    rc = get_thread_name(name, u64(100));
    if rc != 0 {
        jacpy_set_errno(i64(rc));
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyUnicode_DecodeFSDefault(name);
}

impl _thread_set_name_impl(
    module: ptr[PyObject], name_obj: ptr[PyObject]
) -> ptr[PyObject] {
    encoding = ptr[ptr[u8]](
        current_interp() + PyInterpreterState_UNICODE_FS_CODEC_ENCODING
    ).view(
        1
    )[0];
    name_encoded = PyUnicode_AsEncodedString(name_obj, encoding, ptr[u8]("replace"));
    if not name_encoded {
        return NULL;
    }

    if object_size(name_encoded) > PYTHREAD_NAME_MAXLEN {
        truncated = PyBytes_FromStringAndSize(
            PyBytes_AsString(name_encoded), PYTHREAD_NAME_MAXLEN
        );
        if not truncated {
            object_decref(name_encoded);
            return NULL;
        }
        object_decref(name_encoded);
        name_encoded = truncated;
    }

    rc = set_thread_name(PyBytes_AsString(name_encoded));
    object_decref(name_encoded);
    if rc != 0 {
        jacpy_set_errno(i64(rc));
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return object_new_ref(Py_None);
}

impl thread_module_exec(module: ptr[PyObject]) -> i32 {
    state = get_thread_state(module).view(1);
    d = PyModule_GetDict(module);

    PyThread_init_thread();

    state[0].thread_handle_type = ptr[PyTypeObject](
        PyType_FromSpec(addressof(ThreadHandle_Type_spec))
    );
    if not state[0].thread_handle_type {
        return -1;
    }
    if PyDict_SetItemString(
        d, ptr[u8]("_ThreadHandle"), ptr[PyObject](state[0].thread_handle_type)
    )
        < 0 {
        return -1;
    }

    state[0].lock_type = ptr[PyTypeObject](
        PyType_FromModuleAndSpec(module, addressof(lock_type_spec), NULL)
    );
    if not state[0].lock_type {
        return -1;
    }
    if PyModule_AddType(module, ptr[PyObject](state[0].lock_type)) < 0 {
        return -1;
    }

    if PyDict_SetItemString(d, ptr[u8]("LockType"), ptr[PyObject](state[0].lock_type))
        < 0 {
        return -1;
    }

    rlock_type = PyType_FromSpec(addressof(rlock_type_spec));
    if not rlock_type {
        return -1;
    }
    if PyModule_AddType(module, rlock_type) < 0 {
        object_decref(rlock_type);
        return -1;
    }
    object_decref(rlock_type);

    state[0].local_dummy_type = ptr[PyTypeObject](
        PyType_FromSpec(addressof(local_dummy_type_spec))
    );
    if not state[0].local_dummy_type {
        return -1;
    }

    state[0].local_type = ptr[PyTypeObject](
        PyType_FromModuleAndSpec(module, addressof(local_type_spec), NULL)
    );
    if not state[0].local_type {
        return -1;
    }
    if PyModule_AddType(module, ptr[PyObject](state[0].local_type)) < 0 {
        return -1;
    }

    if PyDict_SetItemString(d, ptr[u8]("error"), PyExc_RuntimeError) < 0 {
        return -1;
    }

    state[0].excepthook_type = ptr[PyTypeObject](
        PyStructSequence_NewType(addressof(ExceptHookArgs_desc))
    );
    if not state[0].excepthook_type {
        return -1;
    }
    if PyModule_AddType(module, ptr[PyObject](state[0].excepthook_type)) < 0 {
        return -1;
    }

    timeout_max = f64(PY_TIMEOUT_MAX) * 1e-6;
    time_max = PyTime_AsSecondsDouble(PYTIME_MAX);
    if time_max < timeout_max {
        timeout_max = time_max;
    }
    timeout_max = floor(timeout_max);

    if PyModule_Add(module, ptr[u8]("TIMEOUT_MAX"), PyFloat_FromDouble(timeout_max))
        < 0 {
        return -1;
    }

    llist_init(shutdown_handles_of(get_thread_state(module)));

    if HAS_THREAD_NAMES {
        if PyModule_AddIntConstant(
            module, ptr[u8]("_NAME_MAXLEN"), PYTHREAD_NAME_MAXLEN
        )
            < 0 {
            return -1;
        }
    }
    return 0;
}

impl thread_module_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    state = get_thread_state(module).view(1);
    status = visit_reference(ptr[PyObject](state[0].excepthook_type), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(ptr[PyObject](state[0].lock_type), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(ptr[PyObject](state[0].local_type), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(ptr[PyObject](state[0].local_dummy_type), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(ptr[PyObject](state[0].thread_handle_type), visitor, arg);
}

impl clear_type_slot(slot: ptr[ptr[PyTypeObject]]) {
    value = slot.view(1)[0];
    slot.view(1)[0] = ptr[PyTypeObject]();
    object_xdecref(ptr[PyObject](value));
}

impl thread_module_clear(module: ptr[PyObject]) -> i32 {
    state = get_thread_state(module);
    types = ptr[ptr[PyTypeObject]](state);
    clear_type_slot(types);
    clear_type_slot(types + 1);
    clear_type_slot(types + 2);
    clear_type_slot(types + 3);
    clear_type_slot(types + 4);

    clear_shutdown_handles(state);
    return 0;
}

impl thread_module_free(module: ptr) {
    thread_module_clear(ptr[PyObject](module));
}

impl install_clinic_methods(table: ptr[PyMethodDef], count: i64) {
    first = (addressof(thread_methods) + CLINIC_METHODS_SLOT).view(count);
    i = i64(0);
    while i < count {
        first[i] = (table + i).view(1)[0];
        i += 1;
    }
}

impl clinic_methods_installed -> bool {
    return int((addressof(thread_methods) + CLINIC_METHODS_SLOT).view(1)[0].ml_name)
        != 0;
}
