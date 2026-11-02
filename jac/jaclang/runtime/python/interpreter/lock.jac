import from c {
    def memset(target: ptr, value: i32, size: u64) -> ptr;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def sched_yield -> i32;  def sem_init(
        sema: ptr, pshared: i32, value: u32
    ) -> i32;  def sem_destroy(sema: ptr) -> i32;  def sem_wait(sema: ptr) -> i32;  def sem_timedwait(
        sema: ptr, abstime: ptr
    ) -> i32;  def sem_post(sema: ptr) -> i32;  def PyTime_MonotonicRaw(
        result: &mut i64
    ) -> i32;  def PyTime_TimeRaw(result: &mut i64) -> i32;  def _PyTime_AsTimespec_clamp(
        t: i64, ts: ptr
    );  def PyEval_ReleaseThread(tstate: ptr[PyThreadState]);  def PyEval_AcquireThread(
        tstate: ptr[PyThreadState]
    );  def PyThread_get_thread_ident_ex -> u64;  def _PyEval_StopTheWorld(
        interp: ptr[u8]
    );  def _PyEval_StartTheWorld(interp: ptr[u8]);  def _Py_FatalErrorFunc(
        func: ptr[u8], message: ptr[u8]
    );  def _Py_FatalErrorFormat(func: ptr[u8], format: ptr[u8], *args: any);  obj LockStack {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0),
            w6: u64 = u64(0),
            w7: u64 = u64(0),
            w8: u64 = u64(0),
            w9: u64 = u64(0),
            w10: u64 = u64(0),
            w11: u64 = u64(0),
            w12: u64 = u64(0),
            w13: u64 = u64(0),
            w14: u64 = u64(0),
            w15: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut LockStack) -> int;  obj MutexEntry {
        has time_to_be_fair: i64,
            handed_off: i32;
    }  obj WaitEntry {
        has park_arg: ptr,
            addr: u64,
            node_next: ptr[llist_node],
            node_prev: ptr[llist_node],
            is_unparking: u8;
    }  obj ParkingBucket {
        has mutex: u64,
            root_next: u64,
            root_prev: u64,
            num_waiters: u64;
    }  obj ParkingBuckets8 {
        has b0: ParkingBucket,
            b1: ParkingBucket,
            b2: ParkingBucket,
            b3: ParkingBucket,
            b4: ParkingBucket,
            b5: ParkingBucket,
            b6: ParkingBucket,
            b7: ParkingBucket;
    }  obj ParkingBuckets64 {
        has b0: ParkingBuckets8,
            b1: ParkingBuckets8,
            b2: ParkingBuckets8,
            b3: ParkingBuckets8,
            b4: ParkingBuckets8,
            b5: ParkingBuckets8,
            b6: ParkingBuckets8,
            b7: ParkingBuckets8;
    }  obj ParkingBucketTable {
        has b0: ParkingBuckets64,
            b1: ParkingBuckets64,
            b2: ParkingBuckets64,
            b3: ParkingBuckets64,
            b256: ParkingBucket;
    }  obj UnparkCall {
        has call: Callable[[ptr, ptr, i32], None] = 0;
    }  obj OnceCall {
        has call: Callable[[ptr], i32] = 0;
    }  glob:priv buckets: ParkingBucketTable = ParkingBucketTable();
}

glob:priv TIME_TO_BE_FAIR_NS: Final[i64] = 1000000,
     MAX_SPIN_COUNT: Final[i64] = 0,
     NUM_BUCKETS: Final[i64] = 257,
     BUCKET_SIZE: Final[i64] = 32,
     BUCKET_ROOT: Final[i64] = 8,
     WAIT_ENTRY_NODE: Final[i64] = 16,
     WAIT_ENTRY_SEMA: Final[i64] = 40,
     RAW_MUTEX_ENTRY_SEMA: Final[i64] = 8,
     MUTEX_ENTRY_EXPECTED: Final[i64] = 16,
     LOCKED_BIT: Final[u64] = 1,
     HAS_PARKED_BIT: Final[u64] = 2,
     _Py_WRITE_LOCKED: Final[u64] = 1,
     _PyRWMutex_READER_SHIFT: Final[u64] = 2,
     MIN_ARRAY_SIZE: Final[i64] = 8,
     QSBR_ALIGNMENT: Final[i64] = 64;

def _Py_yield;

def load_u8_relaxed(addr: int) -> u8;

def load_u8(addr: int) -> u8;

def store_u8(addr: int, value: u8);

def cas_u8(addr: int, expected: u8, desired: u8) -> u8;

def exchange_u8(addr: int, value: u8) -> u8;

def load_uptr(addr: int) -> u64;

def load_uptr_relaxed(addr: int) -> u64;

def cas_uptr(addr: int, expected: u64, desired: u64) -> u64;

def exchange_uptr(addr: int, value: u64) -> u64;

def load_u32_relaxed(addr: int) -> u32;

def load_u32_acquire(addr: int) -> u32;

def store_u32(addr: int, value: u32);

def cas_u32(addr: int, expected: u32, desired: u32) -> u32;

def load_u64(addr: int) -> u64;

def load_u64_acquire(addr: int) -> u64;

def mutex_unpark(arg: ptr, park_arg: ptr, has_more_waiters: i32);

def raw_mutex_lock(m: ptr[u64]);

def raw_mutex_unlock(m: ptr[u64]);

def unlock_once(o: ptr[u8], res: i32) -> i32;

def call_once(once_fn: ptr, arg: ptr) -> i32;

def recursive_mutex_is_owned_by(m: ptr[u8], tid: u64) -> bool;

def recursive_mutex_level(m: ptr[u8]) -> ptr[u64];

def rwmutex_set_parked_and_wait(rwmutex: ptr[u64], bits: u64) -> u64;

def rwmutex_reader_count(bits: u64) -> u64;

def thread_state_is_attached(tstate: ptr[PyThreadState]) -> bool;

def _PySemaphore_PlatformWait(sema: ptr, timeout: i64) -> i32;

def lot_llist_init(head: ptr[llist_node]);

def lot_llist_insert_tail(head: ptr[llist_node], item: ptr[llist_node]);

def lot_llist_remove(item: ptr[llist_node]);

def bucket_for(addr: int) -> ptr[ParkingBucket];

def bucket_root(bucket: ptr[ParkingBucket]) -> ptr[llist_node];

def bucket_mutex(bucket: ptr[ParkingBucket]) -> ptr[u64];

def wait_node(waiter: ptr[WaitEntry]) -> ptr[llist_node];

def node_waiter(item: ptr[llist_node]) -> ptr[WaitEntry];

def wait_sema(waiter: ptr[WaitEntry]) -> ptr;

def enqueue(bucket: ptr[ParkingBucket], address: ptr, waiter: ptr[WaitEntry]);

def dequeue(bucket: ptr[ParkingBucket], address: ptr) -> ptr[WaitEntry];

def dequeue_all(bucket: ptr[ParkingBucket], address: ptr, dst: ptr[llist_node]);

def atomic_memcmp(addr: ptr, expected: ptr, addr_size: u64) -> bool;

def call_unpark(unpark_fn: ptr, arg: ptr, park_arg: ptr, has_more_waiters: i32);

def qsbr_field_ptr(base: ptr[u8], offset: i64) -> ptr[ptr[u8]];

def qsbr_field_size(base: ptr[u8], offset: i64) -> ptr[i64];

def qsbr_lt(a: u64, b: u64) -> bool;

def qsbr_leq(a: u64, b: u64) -> bool;

def qsbr_shared_current(shared: ptr[u8]) -> u64;

def qsbr_goal_reached(qsbr: ptr[u8], goal: u64) -> bool;

def qsbr_allocate(shared: ptr[u8]) -> ptr[u8];

def initialize_new_array(shared: ptr[u8]);

def grow_thread_array(shared: ptr[u8]) -> i32;

def qsbr_poll_scan(shared: ptr[u8]) -> u64;

import from c {
    def _PyMutex_LockTimed(m: ptr[PyMutex], timeout_ns: i64, flags: i32) -> i32 {
        bits = int(m);
        v = load_u8_relaxed(bits);
        if (v & _Py_LOCKED) == u8(0) {
            seen = cas_u8(bits, v, v | _Py_LOCKED);
            if seen == v {
                return PY_LOCK_ACQUIRED;
            }
            v = seen;
        }
        if timeout_ns == 0 {
            return PY_LOCK_FAILURE;
        }
        timeout: i64 = timeout_ns;
        now: i64 = 0;
        PyTime_MonotonicRaw(&mut now);
        endtime: i64 = 0;
        if timeout > 0 {
            endtime = _PyTime_Add(now, timeout);
        }
        slots: own LockStack = LockStack();
        block = ptr[u8](jacpy_stack_address(&mut slots));
        mentry = ptr[MutexEntry](block);
        mentry.view(1)[0].time_to_be_fair = now + TIME_TO_BE_FAIR_NS;
        mentry.view(1)[0].handed_off = i32(0);
        expected = block + MUTEX_ENTRY_EXPECTED;
        detach = i32(1) if (flags & _PY_LOCK_DETACH) != 0 else i32(0);
        spin_count: i64 = 0;
        while True {
            if (v & _Py_LOCKED) == u8(0) {
                seen = cas_u8(bits, v, v | _Py_LOCKED);
                if seen == v {
                    return PY_LOCK_ACQUIRED;
                }
                v = seen;
                continue;
            }
            if (v & _Py_HAS_PARKED) == u8(0) and spin_count < MAX_SPIN_COUNT {
                _Py_yield();
                spin_count = spin_count + 1;
                continue;
            }
            if timeout == 0 {
                return PY_LOCK_FAILURE;
            }
            newv = v;
            if (v & _Py_HAS_PARKED) == u8(0) {
                newv = v | _Py_HAS_PARKED;
                seen = cas_u8(bits, v, newv);
                if seen != v {
                    v = seen;
                    continue;
                }
            }
            expected.view(1)[0] = newv;
            ret = _PyParkingLot_Park(
                ptr(m), ptr(expected), u64(1), timeout, ptr(mentry), detach
            );
            if ret == Py_PARK_OK {
                if mentry.view(1)[0].handed_off != i32(0) {
                    return PY_LOCK_ACQUIRED;
                }
            } elif ret == Py_PARK_INTR and (flags & _PY_LOCK_HANDLE_SIGNALS) != 0 {
                if Py_MakePendingCalls() < 0 {
                    return PY_LOCK_INTR;
                }
            } elif ret == Py_PARK_TIMEOUT {
                return PY_LOCK_FAILURE;
            }
            if timeout > 0 {
                timeout = _PyDeadline_Get(endtime);
                if timeout <= 0 {
                    timeout = 0;
                }
            }
            v = load_u8_relaxed(bits);
        }
    }  def _PyMutex_TryUnlock(m: ptr[PyMutex]) -> i32 {
        bits = int(m);
        v = load_u8(bits);
        while True {
            if (v & _Py_LOCKED) == u8(0) {
                return -1;
            } elif (v & _Py_HAS_PARKED) != u8(0) {
                _PyParkingLot_Unpark(ptr(m), ptr(mutex_unpark), ptr(m));
                return 0;
            } else {
                seen = cas_u8(bits, v, _Py_UNLOCKED);
                if seen == v {
                    return 0;
                }
                v = seen;
            }
        }
    }  def _PyRawMutex_LockSlow(m: ptr[u64]) {
        slots: own LockStack = LockStack();
        waiter = ptr[u8](jacpy_stack_address(&mut slots));
        sema = ptr(waiter + RAW_MUTEX_ENTRY_SEMA);
        _PySemaphore_Init(sema);
        addr = int(m);
        v = load_uptr(addr);
        while True {
            if (v & LOCKED_BIT) == u64(0) {
                seen = cas_uptr(addr, v, v | LOCKED_BIT);
                if seen == v {
                    break;
                }
                v = seen;
                continue;
            }
            ptr[u64](waiter).view(1)[0] = v & ~LOCKED_BIT;
            desired = u64.wrap(int(waiter)) | LOCKED_BIT;
            seen = cas_uptr(addr, v, desired);
            if seen != v {
                v = seen;
                continue;
            }
            res = _PySemaphore_Wait(sema, i64(-1), i32(0));
            while res != Py_PARK_OK {
                res = _PySemaphore_Wait(sema, i64(-1), i32(0));
            }
        }
        _PySemaphore_Destroy(sema);
    }  def _PyRawMutex_UnlockSlow(m: ptr[u64]) {
        addr = int(m);
        v = load_uptr(addr);
        while True {
            if (v & LOCKED_BIT) == u64(0) {
                _Py_FatalErrorFunc(
                    ptr[u8]("_PyRawMutex_UnlockSlow"),
                    ptr[u8]("unlocking mutex that is not locked")
                );
            }
            waiter = v & ~LOCKED_BIT;
            if waiter != u64(0) {
                entry_words = ptr[u64](i64.wrap(waiter));
                next_waiter = entry_words.view(1)[0];
                seen = cas_uptr(addr, v, next_waiter);
                if seen == v {
                    _PySemaphore_Wakeup(
                        ptr(ptr[u8](entry_words) + RAW_MUTEX_ENTRY_SEMA)
                    );
                    return;
                }
                v = seen;
            } else {
                seen = cas_uptr(addr, v, u64(0));
                if seen == v {
                    return;
                }
                v = seen;
            }
        }
    }  def _PyEvent_IsSet(evt: ptr[u8]) -> i32 {
        v = load_u8(int(evt));
        return i32(1) if v == _Py_LOCKED else i32(0);
    }  def _PyEvent_Notify(evt: ptr[u8]) {
        v = exchange_u8(int(evt), _Py_LOCKED);
        if v == _Py_UNLOCKED {
            return;
        } elif v == _Py_LOCKED {
            return;
        } else {
            _PyParkingLot_UnparkAll(ptr(evt));
        }
    }  def PyEvent_Wait(evt: ptr[u8]) {
        while PyEvent_WaitTimed(evt, i64(-1), i32(1)) == 0 {
            continue;
        }
    }  def PyEvent_WaitTimed(evt: ptr[u8], timeout_ns: i64, detach: i32) -> i32 {
        slots: own LockStack = LockStack();
        expected = ptr[u8](jacpy_stack_address(&mut slots));
        addr = int(evt);
        while True {
            v = load_u8(addr);
            if v == _Py_LOCKED {
                return 1;
            }
            if v == _Py_UNLOCKED {
                if cas_u8(addr, v, _Py_HAS_PARKED) != v {
                    continue;
                }
            }
            expected.view(1)[0] = _Py_HAS_PARKED;
            _PyParkingLot_Park(
                ptr(evt), ptr(expected), u64(1), timeout_ns, ptr(), detach
            );
            return i32(1) if load_u8(addr) == _Py_LOCKED else i32(0);
        }
    }  def _PyOnceFlag_CallOnceSlow(flag: ptr[u8], once_fn: ptr, arg: ptr) -> i32 {
        slots: own LockStack = LockStack();
        expected = ptr[u8](jacpy_stack_address(&mut slots));
        addr = int(flag);
        v = load_u8(addr);
        while True {
            if v == _Py_UNLOCKED {
                seen = cas_u8(addr, v, _Py_LOCKED);
                if seen != v {
                    v = seen;
                    continue;
                }
                res = call_once(once_fn, arg);
                return unlock_once(flag, res);
            }
            if v == _Py_ONCE_INITIALIZED {
                return 0;
            }
            if (v & _Py_HAS_PARKED) == u8(0) {
                new_value = v | _Py_HAS_PARKED;
                seen = cas_u8(addr, v, new_value);
                if seen != v {
                    v = seen;
                    continue;
                }
                v = new_value;
            }
            expected.view(1)[0] = v;
            _PyParkingLot_Park(
                ptr(flag), ptr(expected), u64(1), i64(-1), ptr(), i32(1)
            );
            v = load_u8(addr);
        }
    }  def _PyRecursiveMutex_IsLockedByCurrentThread(m: ptr[u8]) -> i32 {
        if recursive_mutex_is_owned_by(m, PyThread_get_thread_ident_ex()) {
            return 1;
        }
        return 0;
    }  def _PyRecursiveMutex_Lock(m: ptr[u8]) {
        thread = PyThread_get_thread_ident_ex();
        if recursive_mutex_is_owned_by(m, thread) {
            level = recursive_mutex_level(m);
            level.view(1)[0] = level.view(1)[0] + u64(1);
            return;
        }
        PyMutex_Lock(ptr[PyMutex](m));
        __atomic_store_i64(int(m) + _PyRecursiveMutex_THREAD, i64.wrap(thread), 0);
    }  def _PyRecursiveMutex_LockTimed(m: ptr[u8], timeout: i64, flags: i32) -> i32 {
        thread = PyThread_get_thread_ident_ex();
        if recursive_mutex_is_owned_by(m, thread) {
            level = recursive_mutex_level(m);
            level.view(1)[0] = level.view(1)[0] + u64(1);
            return PY_LOCK_ACQUIRED;
        }
        s = _PyMutex_LockTimed(ptr[PyMutex](m), timeout, flags);
        if s == PY_LOCK_ACQUIRED {
            __atomic_store_i64(int(m) + _PyRecursiveMutex_THREAD, i64.wrap(thread), 0);
        }
        return s;
    }  def _PyRecursiveMutex_Unlock(m: ptr[u8]) {
        if _PyRecursiveMutex_TryUnlock(m) < 0 {
            _Py_FatalErrorFunc(
                ptr[u8]("_PyRecursiveMutex_Unlock"),
                ptr[u8](
                    "unlocking a recursive mutex that is not owned by the current thread"
                )
            );
        }
    }  def _PyRecursiveMutex_TryUnlock(m: ptr[u8]) -> i32 {
        thread = PyThread_get_thread_ident_ex();
        if not recursive_mutex_is_owned_by(m, thread) {
            return -1;
        }
        level = recursive_mutex_level(m);
        if level.view(1)[0] > u64(0) {
            level.view(1)[0] = level.view(1)[0] - u64(1);
            return 0;
        }
        __atomic_store_i64(int(m) + _PyRecursiveMutex_THREAD, 0, 0);
        PyMutex_Unlock(ptr[PyMutex](m));
        return 0;
    }  def _PyRWMutex_RLock(rwmutex: ptr[u64]) {
        addr = int(rwmutex);
        bits = load_uptr_relaxed(addr);
        while True {
            if (bits & _Py_WRITE_LOCKED) != u64(0) {
                bits = rwmutex_set_parked_and_wait(rwmutex, bits);
                continue;
            } elif (bits & HAS_PARKED_BIT) != u64(0) {
                bits = rwmutex_set_parked_and_wait(rwmutex, bits);
                continue;
            } else {
                newval = wrapping_add(bits, u64(1) << _PyRWMutex_READER_SHIFT);
                seen = cas_uptr(addr, bits, newval);
                if seen != bits {
                    bits = seen;
                    continue;
                }
                return;
            }
        }
    }  def _PyRWMutex_RUnlock(rwmutex: ptr[u64]) {
        bits = u64.wrap(__atomic_add_i64(int(rwmutex), i64(-4), 5));
        bits = wrapping_sub(bits, u64(1) << _PyRWMutex_READER_SHIFT);
        if rwmutex_reader_count(bits) == u64(0) and (bits & HAS_PARKED_BIT) != u64(0) {
            _PyParkingLot_UnparkAll(ptr(rwmutex));
            return;
        }
    }  def _PyRWMutex_Lock(rwmutex: ptr[u64]) {
        addr = int(rwmutex);
        bits = load_uptr_relaxed(addr);
        while True {
            if (bits & ~HAS_PARKED_BIT) == u64(0) {
                seen = cas_uptr(addr, bits, bits | _Py_WRITE_LOCKED);
                if seen != bits {
                    bits = seen;
                    continue;
                }
                return;
            }
            bits = rwmutex_set_parked_and_wait(rwmutex, bits);
        }
    }  def _PyRWMutex_Unlock(rwmutex: ptr[u64]) {
        old_bits = exchange_uptr(int(rwmutex), u64(0));
        if (old_bits & HAS_PARKED_BIT) != u64(0) {
            _PyParkingLot_UnparkAll(ptr(rwmutex));
        }
    }  def _PySeqLock_LockWrite(seqlock: ptr[u32]) {
        addr = int(seqlock);
        prev = load_u32_relaxed(addr);
        while True {
            if (prev & u32(1)) != u32(0) {
                _Py_yield();
                prev = load_u32_relaxed(addr);
            } else {
                seen = cas_u32(addr, prev, wrapping_add(prev, u32(1)));
                if seen == prev {
                    __atomic_fence(3);
                    break;
                }
                prev = seen;
                _Py_yield();
            }
        }
    }  def _PySeqLock_AbandonWrite(seqlock: ptr[u32]) {
        addr = int(seqlock);
        new_seq = wrapping_sub(load_u32_relaxed(addr), u32(1));
        store_u32(addr, new_seq);
    }  def _PySeqLock_UnlockWrite(seqlock: ptr[u32]) {
        addr = int(seqlock);
        new_seq = wrapping_add(load_u32_relaxed(addr), u32(1));
        store_u32(addr, new_seq);
    }  def _PySeqLock_BeginRead(seqlock: ptr[u32]) -> u32 {
        addr = int(seqlock);
        sequence = load_u32_acquire(addr);
        while (sequence & u32(1)) != u32(0) {
            _Py_yield();
            sequence = load_u32_acquire(addr);
        }
        return sequence;
    }  def _PySeqLock_EndRead(seqlock: ptr[u32], previous: u32) -> i32 {
        __atomic_fence(2);
        if load_u32_relaxed(int(seqlock)) == previous {
            return 1;
        }
        _Py_yield();
        return 0;
    }  def _PySeqLock_AfterFork(seqlock: ptr[u32]) -> i32 {
        if (seqlock.view(1)[0] & u32(1)) != u32(0) {
            seqlock.view(1)[0] = u32(0);
            return 1;
        }
        return 0;
    }  def PyMutex_Lock(m: ptr[PyMutex]) {
        _PyMutex_LockTimed(m, i64(-1), _PY_LOCK_DETACH);
    }  def PyMutex_Unlock(m: ptr[PyMutex]) {
        if _PyMutex_TryUnlock(m) < 0 {
            _Py_FatalErrorFunc(
                ptr[u8]("PyMutex_Unlock"), ptr[u8]("unlocking mutex that is not locked")
            );
        }
    }  def PyMutex_IsLocked(m: ptr[PyMutex]) -> i32 {
        if (load_u8(int(m)) & _Py_LOCKED) != u8(0) {
            return 1;
        }
        return 0;
    }
}

import from c {
    def _PySemaphore_Init(sema: ptr) {
        if sem_init(sema, i32(0), u32(0)) < 0 {
            _Py_FatalErrorFunc(
                ptr[u8]("_PySemaphore_Init"), ptr[u8]("parking_lot: sem_init failed")
            );
        }
    }  def _PySemaphore_Destroy(sema: ptr) {
        sem_destroy(sema);
    }  def _PySemaphore_Wait(sema: ptr, timeout_ns: i64, detach: i32) -> i32 {
        tstate = ptr[PyThreadState]();
        if detach != 0 {
            tstate = current_tstate();
            attached = False;
            if tstate {
                attached = thread_state_is_attached(tstate);
            }
            if attached {
                PyEval_ReleaseThread(tstate);
            } else {
                tstate = ptr[PyThreadState]();
            }
        }
        res = _PySemaphore_PlatformWait(sema, timeout_ns);
        if tstate {
            PyEval_AcquireThread(tstate);
        }
        return res;
    }  def _PySemaphore_Wakeup(sema: ptr) {
        err = sem_post(sema);
        if err != 0 {
            _Py_FatalErrorFunc(
                ptr[u8]("_PySemaphore_Wakeup"), ptr[u8]("parking_lot: sem_post failed")
            );
        }
    }  def _PyParkingLot_Park(
        addr: ptr, expected: ptr, size: u64, timeout_ns: i64, park_arg: ptr, detach: i32
    ) -> i32 {
        slots: own LockStack = LockStack();
        waiter = ptr[WaitEntry](jacpy_stack_address(&mut slots));
        waiter.view(1)[0].park_arg = park_arg;
        waiter.view(1)[0].addr = u64.wrap(int(addr));
        waiter.view(1)[0].is_unparking = u8(0);
        sema = wait_sema(waiter);
        bucket = bucket_for(int(addr));
        mutex = bucket_mutex(bucket);
        raw_mutex_lock(mutex);
        if not atomic_memcmp(addr, expected, size) {
            raw_mutex_unlock(mutex);
            return Py_PARK_AGAIN;
        }
        _PySemaphore_Init(sema);
        enqueue(bucket, addr, waiter);
        raw_mutex_unlock(mutex);
        tstate = ptr[PyThreadState]();
        if detach != 0 {
            tstate = current_tstate();
            attached = False;
            if tstate {
                attached = thread_state_is_attached(tstate);
            }
            if attached {
                PyEval_ReleaseThread(tstate);
            } else {
                tstate = ptr[PyThreadState]();
            }
        }
        res = _PySemaphore_Wait(sema, timeout_ns, i32(0));
        if res != Py_PARK_OK {
            raw_mutex_lock(mutex);
            if waiter.view(1)[0].is_unparking != u8(0) {
                raw_mutex_unlock(mutex);
                res = _PySemaphore_Wait(sema, i64(-1), i32(0));
                while res != Py_PARK_OK {
                    res = _PySemaphore_Wait(sema, i64(-1), i32(0));
                }
            } else {
                lot_llist_remove(wait_node(waiter));
                bucket.view(1)[0].num_waiters = bucket.view(1)[0].num_waiters - u64(1);
                raw_mutex_unlock(mutex);
            }
        }
        _PySemaphore_Destroy(sema);
        if tstate {
            PyEval_AcquireThread(tstate);
        }
        return res;
    }  def _PyParkingLot_Unpark(addr: ptr, unpark_fn: ptr, arg: ptr) {
        bucket = bucket_for(int(addr));
        mutex = bucket_mutex(bucket);
        raw_mutex_lock(mutex);
        waiter = dequeue(bucket, addr);
        if waiter {
            has_more_waiters = i32(1)
                if bucket.view(1)[0].num_waiters > u64(0)
                else i32(0);
            call_unpark(unpark_fn, arg, waiter.view(1)[0].park_arg, has_more_waiters);
        } else {
            call_unpark(unpark_fn, arg, ptr(), i32(0));
        }
        raw_mutex_unlock(mutex);
        if waiter {
            _PySemaphore_Wakeup(wait_sema(waiter));
        }
    }  def _PyParkingLot_UnparkAll(addr: ptr) {
        slots: own LockStack = LockStack();
        head = ptr[llist_node](jacpy_stack_address(&mut slots));
        lot_llist_init(head);
        bucket = bucket_for(int(addr));
        mutex = bucket_mutex(bucket);
        raw_mutex_lock(mutex);
        dequeue_all(bucket, addr, head);
        raw_mutex_unlock(mutex);
        item = head.view(1)[0].next;
        following = item.view(1)[0].next;
        while item != head {
            waiter = node_waiter(item);
            lot_llist_remove(item);
            _PySemaphore_Wakeup(wait_sema(waiter));
            item = following;
            following = item.view(1)[0].next;
        }
    }  def _PyParkingLot_AfterFork {
        memset(ptr(addressof(buckets)), i32(0), u64(NUM_BUCKETS * BUCKET_SIZE));
        base = ptr[ParkingBucket](addressof(buckets));
        for i in range(NUM_BUCKETS) {
            lot_llist_init(bucket_root(base + i));
        }
    }
}

import from c {
    def _PyCriticalSection_BeginSlow(c: ptr, m: ptr[PyMutex]) {
        return;
    }  def _PyCriticalSection2_BeginSlow(
        c: ptr, m1: ptr[PyMutex], m2: ptr[PyMutex], is_m1_locked: i32
    ) {
        return;
    }  def _PyCriticalSection_SuspendAll(tstate: ptr[PyThreadState]) {
        return;
    }  def _PyCriticalSection_Resume(tstate: ptr[PyThreadState]) {
        return;
    }  def PyCriticalSection_Begin(c: ptr, op: ptr[PyObject]) {
        return;
    }  def PyCriticalSection_BeginMutex(c: ptr, m: ptr[PyMutex]) {
        return;
    }  def PyCriticalSection_End(c: ptr) {
        return;
    }  def PyCriticalSection2_Begin(c: ptr, a: ptr[PyObject], b: ptr[PyObject]) {
        return;
    }  def PyCriticalSection2_BeginMutex(c: ptr, m1: ptr[PyMutex], m2: ptr[PyMutex]) {
        return;
    }  def PyCriticalSection2_End(c: ptr) {
        return;
    }
}

import from c {
    def _Py_qsbr_advance(shared: ptr[u8]) -> u64 {
        old = u64.wrap(
            __atomic_add_i64(int(shared) + _qsbr_shared_WR_SEQ, i64.wrap(QSBR_INCR), 5)
        );
        return wrapping_add(old, QSBR_INCR);
    }  def _Py_qsbr_shared_next(shared: ptr[u8]) -> u64 {
        return wrapping_add(qsbr_shared_current(shared), QSBR_INCR);
    }  def _Py_qsbr_poll(qsbr: ptr[u8], goal: u64) -> bool {
        if qsbr_goal_reached(qsbr, goal) {
            return True;
        }
        rd_seq = qsbr_poll_scan(
            qsbr_field_ptr(qsbr, _qsbr_thread_state_SHARED).view(1)[0]
        );
        return qsbr_leq(goal, rd_seq);
    }  def _Py_qsbr_attach(qsbr: ptr[u8]) {
        seq = qsbr_shared_current(
            qsbr_field_ptr(qsbr, _qsbr_thread_state_SHARED).view(1)[0]
        );
        __atomic_store_i64(int(qsbr) + _qsbr_thread_state_SEQ, i64.wrap(seq), 5);
    }  def _Py_qsbr_detach(qsbr: ptr[u8]) {
        __atomic_store_i64(
            int(qsbr) + _qsbr_thread_state_SEQ, i64.wrap(QSBR_OFFLINE), 3
        );
    }  def _Py_qsbr_reserve(interp: ptr[u8]) -> i64 {
        shared = interp + PyInterpreterState_QSBR;
        mutex = ptr[PyMutex](shared + _qsbr_shared_MUTEX);
        PyMutex_Lock(mutex);
        qsbr = qsbr_allocate(shared);
        if not qsbr {
            _PyEval_StopTheWorld(interp);
            if grow_thread_array(shared) == 0 {
                qsbr = qsbr_allocate(shared);
            }
            _PyEval_StartTheWorld(interp);
        }
        index: i64 = -1;
        if qsbr {
            array = qsbr_field_ptr(shared, _qsbr_shared_ARRAY).view(1)[0];
            index = (int(qsbr) - int(array)) // _qsbr_pad_SIZE;
        }
        PyMutex_Unlock(mutex);
        return index;
    }  def _Py_qsbr_register(tstate: ptr[u8], interp: ptr[u8], index: i64) {
        shared = interp + PyInterpreterState_QSBR;
        mutex = ptr[PyMutex](shared + _qsbr_shared_MUTEX);
        PyMutex_Lock(mutex);
        array = qsbr_field_ptr(shared, _qsbr_shared_ARRAY).view(1)[0];
        qsbr = array + index * _qsbr_pad_SIZE;
        qsbr_field_ptr(qsbr, _qsbr_thread_state_TSTATE).view(1)[0] = tstate;
        qsbr_field_ptr(tstate, _PyThreadStateImpl_QSBR).view(1)[0] = qsbr;
        PyMutex_Unlock(mutex);
    }  def _Py_qsbr_unregister(tstate: ptr[PyThreadState]) {
        tstate_imp = ptr[u8](tstate);
        interp = ptr[ptr[u8]](tstate_imp + PyThreadState_INTERP).view(1)[0];
        shared = interp + PyInterpreterState_QSBR;
        mutex = ptr[PyMutex](shared + _qsbr_shared_MUTEX);
        PyMutex_Lock(mutex);
        qsbr_slot = qsbr_field_ptr(tstate_imp, _PyThreadStateImpl_QSBR);
        qsbr = qsbr_slot.view(1)[0];
        qsbr_slot.view(1)[0] = ptr[u8]();
        qsbr_field_ptr(qsbr, _qsbr_thread_state_TSTATE).view(1)[0] = ptr[u8]();
        (qsbr + _qsbr_thread_state_ALLOCATED).view(1)[0] = u8(0);
        freelist = qsbr_field_ptr(shared, _qsbr_shared_FREELIST);
        qsbr_field_ptr(qsbr, _qsbr_thread_state_FREELIST_NEXT).view(1)[0] = freelist.view(
            1
        )[0];
        freelist.view(1)[0] = qsbr;
        PyMutex_Unlock(mutex);
    }  def _Py_qsbr_fini(interp: ptr[u8]) {
        shared = interp + PyInterpreterState_QSBR;
        raw_slot = qsbr_field_ptr(shared, _qsbr_shared_ARRAY_RAW);
        PyMem_RawFree(ptr(raw_slot.view(1)[0]));
        qsbr_field_ptr(shared, _qsbr_shared_ARRAY).view(1)[0] = ptr[u8]();
        raw_slot.view(1)[0] = ptr[u8]();
        qsbr_field_size(shared, _qsbr_shared_ARRAY_LEN).view(1)[0] = 0;
        qsbr_field_ptr(shared, _qsbr_shared_FREELIST).view(1)[0] = ptr[u8]();
    }  def _Py_qsbr_after_fork(tstate: ptr[u8]) {
        this_qsbr = qsbr_field_ptr(tstate, _PyThreadStateImpl_QSBR).view(1)[0];
        shared = qsbr_field_ptr(this_qsbr, _qsbr_thread_state_SHARED).view(1)[0];
        (shared + _qsbr_shared_MUTEX).view(1)[0] = u8(0);
        size = qsbr_field_size(shared, _qsbr_shared_ARRAY_LEN).view(1)[0];
        array = qsbr_field_ptr(shared, _qsbr_shared_ARRAY).view(1)[0];
        freelist = qsbr_field_ptr(shared, _qsbr_shared_FREELIST);
        for i in range(size) {
            qsbr = array + i * _qsbr_pad_SIZE;
            if qsbr != this_qsbr
                and (qsbr + _qsbr_thread_state_ALLOCATED).view(1)[0] != u8(0) {
                qsbr_field_ptr(qsbr, _qsbr_thread_state_TSTATE).view(1)[0] = ptr[u8]();
                (qsbr + _qsbr_thread_state_ALLOCATED).view(1)[0] = u8(0);
                qsbr_field_ptr(qsbr, _qsbr_thread_state_FREELIST_NEXT).view(1)[0] = freelist.view(
                    1
                )[0];
                freelist.view(1)[0] = qsbr;
            }
        }
    }
}

impl _Py_yield {
    sched_yield();
}

impl load_u8_relaxed(addr: int) -> u8 {
    return u8.wrap(__atomic_load_i8(addr, 0));
}

impl load_u8(addr: int) -> u8 {
    return u8.wrap(__atomic_load_i8(addr, 5));
}

impl store_u8(addr: int, value: u8) {
    __atomic_store_i8(addr, i8.wrap(value), 5);
}

impl cas_u8(addr: int, expected: u8, desired: u8) -> u8 {
    return u8.wrap(__atomic_cas_i8(addr, i8.wrap(expected), i8.wrap(desired), 5));
}

impl exchange_u8(addr: int, value: u8) -> u8 {
    return u8.wrap(__atomic_swap_i8(addr, i8.wrap(value), 5));
}

impl load_uptr(addr: int) -> u64 {
    return u64.wrap(__atomic_load_i64(addr, 5));
}

impl load_uptr_relaxed(addr: int) -> u64 {
    return u64.wrap(__atomic_load_i64(addr, 0));
}

impl cas_uptr(addr: int, expected: u64, desired: u64) -> u64 {
    return u64.wrap(__atomic_cas_i64(addr, i64.wrap(expected), i64.wrap(desired), 5));
}

impl exchange_uptr(addr: int, value: u64) -> u64 {
    return u64.wrap(__atomic_swap_i64(addr, i64.wrap(value), 5));
}

impl load_u32_relaxed(addr: int) -> u32 {
    return u32.wrap(__atomic_load_i32(addr, 0));
}

impl load_u32_acquire(addr: int) -> u32 {
    return u32.wrap(__atomic_load_i32(addr, 2));
}

impl store_u32(addr: int, value: u32) {
    __atomic_store_i32(addr, i32.wrap(value), 5);
}

impl cas_u32(addr: int, expected: u32, desired: u32) -> u32 {
    return u32.wrap(__atomic_cas_i32(addr, i32.wrap(expected), i32.wrap(desired), 5));
}

impl load_u64(addr: int) -> u64 {
    return u64.wrap(__atomic_load_i64(addr, 5));
}

impl load_u64_acquire(addr: int) -> u64 {
    return u64.wrap(__atomic_load_i64(addr, 2));
}

impl mutex_unpark(arg: ptr, park_arg: ptr, has_more_waiters: i32) {
    v: u8 = u8(0);
    if park_arg {
        mentry = ptr[MutexEntry](park_arg);
        now: i64 = 0;
        PyTime_MonotonicRaw(&mut now);
        should_be_fair = now > mentry.view(1)[0].time_to_be_fair;
        mentry.view(1)[0].handed_off = i32(1) if should_be_fair else i32(0);
        if should_be_fair {
            v = v | _Py_LOCKED;
        }
        if has_more_waiters != 0 {
            v = v | _Py_HAS_PARKED;
        }
    }
    store_u8(int(arg), v);
}

impl raw_mutex_lock(m: ptr[u64]) {
    if cas_uptr(int(m), u64(0), LOCKED_BIT) == u64(0) {
        return;
    }
    _PyRawMutex_LockSlow(m);
}

impl raw_mutex_unlock(m: ptr[u64]) {
    if cas_uptr(int(m), LOCKED_BIT, u64(0)) == LOCKED_BIT {
        return;
    }
    _PyRawMutex_UnlockSlow(m);
}

impl unlock_once(o: ptr[u8], res: i32) -> i32 {
    new_value: u8 = _Py_UNLOCKED;
    if res == -1 {
        new_value = _Py_UNLOCKED;
    } elif res == 0 {
        new_value = _Py_ONCE_INITIALIZED;
    } else {
        _Py_FatalErrorFunc(
            ptr[u8]("unlock_once"), ptr[u8]("invalid result from _PyOnceFlag_CallOnce")
        );
    }
    old_value = exchange_u8(int(o), new_value);
    if (old_value & _Py_HAS_PARKED) != u8(0) {
        _PyParkingLot_UnparkAll(ptr(o));
    }
    return res;
}

impl call_once(once_fn: ptr, arg: ptr) -> i32 {
    slot = ptr[OnceCall](__thread_local("jac_lock_call_once"));
    slot.view(1)[0].call = int(once_fn);
    return slot.view(1)[0].call(arg);
}

impl recursive_mutex_is_owned_by(m: ptr[u8], tid: u64) -> bool {
    return u64.wrap(__atomic_load_i64(int(m) + _PyRecursiveMutex_THREAD, 0)) == tid;
}

impl recursive_mutex_level(m: ptr[u8]) -> ptr[u64] {
    return ptr[u64](m + _PyRecursiveMutex_LEVEL);
}

impl rwmutex_set_parked_and_wait(rwmutex: ptr[u64], bits: u64) -> u64 {
    slots: own LockStack = LockStack();
    expected = ptr[u64](jacpy_stack_address(&mut slots));
    addr = int(rwmutex);
    current = bits;
    if (current & HAS_PARKED_BIT) == u64(0) {
        newval = current | HAS_PARKED_BIT;
        seen = cas_uptr(addr, current, newval);
        if seen != current {
            return seen;
        }
        current = newval;
    }
    expected.view(1)[0] = current;
    _PyParkingLot_Park(ptr(rwmutex), ptr(expected), u64(8), i64(-1), ptr(), i32(1));
    return load_uptr_relaxed(addr);
}

impl rwmutex_reader_count(bits: u64) -> u64 {
    return bits >> _PyRWMutex_READER_SHIFT;
}

impl thread_state_is_attached(tstate: ptr[PyThreadState]) -> bool {
    state = __atomic_load_i32(int(tstate) + PyThreadState_STATE, 0);
    return state == _Py_THREAD_ATTACHED;
}

impl _PySemaphore_PlatformWait(sema: ptr, timeout: i64) -> i32 {
    slots: own LockStack = LockStack();
    ts = ptr[u8](jacpy_stack_address(&mut slots));
    res = Py_PARK_OK;
    err: i32 = 0;
    now: i64 = 0;
    if timeout >= 0 {
        PyTime_TimeRaw(&mut now);
        deadline = _PyTime_Add(now, timeout);
        _PyTime_AsTimespec_clamp(deadline, ptr(ts));
        err = sem_timedwait(sema, ptr(ts));
    } else {
        err = sem_wait(sema);
    }
    if err == -1 {
        err = i32.wrap(jacpy_errno());
        if err == EINTR {
            res = Py_PARK_INTR;
        } elif err == ETIMEDOUT {
            res = Py_PARK_TIMEOUT;
        } else {
            _Py_FatalErrorFormat(
                ptr[u8]("_PySemaphore_PlatformWait"),
                ptr[u8]("unexpected error from semaphore: %d"),
                err
            );
        }
    }
    return res;
}

impl lot_llist_init(head: ptr[llist_node]) {
    head.view(1)[0].next = head;
    head.view(1)[0].prev = head;
}

impl lot_llist_insert_tail(head: ptr[llist_node], item: ptr[llist_node]) {
    tail = head.view(1)[0].prev;
    item.view(1)[0].prev = tail;
    item.view(1)[0].next = head;
    tail.view(1)[0].next = item;
    head.view(1)[0].prev = item;
}

impl lot_llist_remove(item: ptr[llist_node]) {
    prev = item.view(1)[0].prev;
    following = item.view(1)[0].next;
    prev.view(1)[0].next = following;
    following.view(1)[0].prev = prev;
    item.view(1)[0].prev = ptr[llist_node]();
    item.view(1)[0].next = ptr[llist_node]();
}

impl bucket_for(addr: int) -> ptr[ParkingBucket] {
    index = u64.wrap(addr) % u64(NUM_BUCKETS);
    return ptr[ParkingBucket](addressof(buckets)) + i64(index);
}

impl bucket_root(bucket: ptr[ParkingBucket]) -> ptr[llist_node] {
    head = ptr[llist_node](ptr[u8](bucket) + BUCKET_ROOT);
    if not head.view(1)[0].next {
        lot_llist_init(head);
    }
    return head;
}

impl bucket_mutex(bucket: ptr[ParkingBucket]) -> ptr[u64] {
    return ptr[u64](bucket);
}

impl wait_node(waiter: ptr[WaitEntry]) -> ptr[llist_node] {
    return ptr[llist_node](ptr[u8](waiter) + WAIT_ENTRY_NODE);
}

impl node_waiter(item: ptr[llist_node]) -> ptr[WaitEntry] {
    return ptr[WaitEntry](int(item) - WAIT_ENTRY_NODE);
}

impl wait_sema(waiter: ptr[WaitEntry]) -> ptr {
    return ptr(ptr[u8](waiter) + WAIT_ENTRY_SEMA);
}

impl enqueue(bucket: ptr[ParkingBucket], address: ptr, waiter: ptr[WaitEntry]) {
    lot_llist_insert_tail(bucket_root(bucket), wait_node(waiter));
    bucket.view(1)[0].num_waiters = bucket.view(1)[0].num_waiters + u64(1);
}

impl dequeue(bucket: ptr[ParkingBucket], address: ptr) -> ptr[WaitEntry] {
    head = bucket_root(bucket);
    target = u64.wrap(int(address));
    item = head.view(1)[0].next;
    while item != head {
        waiter = node_waiter(item);
        if waiter.view(1)[0].addr == target {
            lot_llist_remove(item);
            bucket.view(1)[0].num_waiters = bucket.view(1)[0].num_waiters - u64(1);
            waiter.view(1)[0].is_unparking = u8(1);
            return waiter;
        }
        item = item.view(1)[0].next;
    }
    return ptr[WaitEntry]();
}

impl dequeue_all(bucket: ptr[ParkingBucket], address: ptr, dst: ptr[llist_node]) {
    head = bucket_root(bucket);
    target = u64.wrap(int(address));
    item = head.view(1)[0].next;
    following = item.view(1)[0].next;
    while item != head {
        waiter = node_waiter(item);
        if waiter.view(1)[0].addr == target {
            lot_llist_remove(item);
            lot_llist_insert_tail(dst, item);
            bucket.view(1)[0].num_waiters = bucket.view(1)[0].num_waiters - u64(1);
            waiter.view(1)[0].is_unparking = u8(1);
        }
        item = following;
        following = item.view(1)[0].next;
    }
}

impl atomic_memcmp(addr: ptr, expected: ptr, addr_size: u64) -> bool {
    a = int(addr);
    if addr_size == u64(1) {
        return __atomic_load_i8(a, 5) == ptr[i8](expected).view(1)[0];
    } elif addr_size == u64(2) {
        return __atomic_load_i16(a, 5) == ptr[i16](expected).view(1)[0];
    } elif addr_size == u64(4) {
        return __atomic_load_i32(a, 5) == ptr[i32](expected).view(1)[0];
    } elif addr_size == u64(8) {
        return __atomic_load_i64(a, 5) == ptr[i64](expected).view(1)[0];
    }
    return False;
}

impl call_unpark(unpark_fn: ptr, arg: ptr, park_arg: ptr, has_more_waiters: i32) {
    slot = ptr[UnparkCall](__thread_local("jac_lock_call_unpark"));
    slot.view(1)[0].call = int(unpark_fn);
    slot.view(1)[0].call(arg, park_arg, has_more_waiters);
}

impl qsbr_field_ptr(base: ptr[u8], offset: i64) -> ptr[ptr[u8]] {
    return ptr[ptr[u8]](base + offset);
}

impl qsbr_field_size(base: ptr[u8], offset: i64) -> ptr[i64] {
    return ptr[i64](base + offset);
}

impl qsbr_lt(a: u64, b: u64) -> bool {
    return i64.wrap(wrapping_sub(a, b)) < 0;
}

impl qsbr_leq(a: u64, b: u64) -> bool {
    return i64.wrap(wrapping_sub(a, b)) <= 0;
}

impl qsbr_shared_current(shared: ptr[u8]) -> u64 {
    return load_u64_acquire(int(shared) + _qsbr_shared_WR_SEQ);
}

impl qsbr_goal_reached(qsbr: ptr[u8], goal: u64) -> bool {
    shared = qsbr_field_ptr(qsbr, _qsbr_thread_state_SHARED).view(1)[0];
    rd_seq = load_u64(int(shared) + _qsbr_shared_RD_SEQ);
    return qsbr_leq(goal, rd_seq);
}

impl qsbr_allocate(shared: ptr[u8]) -> ptr[u8] {
    freelist = qsbr_field_ptr(shared, _qsbr_shared_FREELIST);
    qsbr = freelist.view(1)[0];
    if not qsbr {
        return ptr[u8]();
    }
    next_slot = qsbr_field_ptr(qsbr, _qsbr_thread_state_FREELIST_NEXT);
    freelist.view(1)[0] = next_slot.view(1)[0];
    next_slot.view(1)[0] = ptr[u8]();
    qsbr_field_ptr(qsbr, _qsbr_thread_state_SHARED).view(1)[0] = shared;
    (qsbr + _qsbr_thread_state_ALLOCATED).view(1)[0] = u8(1);
    return qsbr;
}

impl initialize_new_array(shared: ptr[u8]) {
    size = qsbr_field_size(shared, _qsbr_shared_ARRAY_LEN).view(1)[0];
    array = qsbr_field_ptr(shared, _qsbr_shared_ARRAY).view(1)[0];
    freelist = qsbr_field_ptr(shared, _qsbr_shared_FREELIST);
    for i in range(size) {
        qsbr = array + i * _qsbr_pad_SIZE;
        tstate = qsbr_field_ptr(qsbr, _qsbr_thread_state_TSTATE).view(1)[0];
        if tstate {
            qsbr_field_ptr(tstate, _PyThreadStateImpl_QSBR).view(1)[0] = qsbr;
        }
        if (qsbr + _qsbr_thread_state_ALLOCATED).view(1)[0] == u8(0) {
            qsbr_field_ptr(qsbr, _qsbr_thread_state_FREELIST_NEXT).view(1)[0] = freelist.view(
                1
            )[0];
            freelist.view(1)[0] = qsbr;
        }
    }
}

impl grow_thread_array(shared: ptr[u8]) -> i32 {
    size_slot = qsbr_field_size(shared, _qsbr_shared_ARRAY_LEN);
    size = size_slot.view(1)[0];
    new_size = size * 2;
    if new_size < MIN_ARRAY_SIZE {
        new_size = MIN_ARRAY_SIZE;
    }
    alloc_size = u64(new_size) * u64(_qsbr_pad_SIZE) + u64(QSBR_ALIGNMENT) - u64(1);
    raw = PyMem_RawCalloc(u64(1), alloc_size);
    if not raw {
        return -1;
    }
    array = ptr[u8]((int(raw) + (QSBR_ALIGNMENT - 1)) & ~(QSBR_ALIGNMENT - 1));
    array_slot = qsbr_field_ptr(shared, _qsbr_shared_ARRAY);
    raw_slot = qsbr_field_ptr(shared, _qsbr_shared_ARRAY_RAW);
    old_raw = raw_slot.view(1)[0];
    if array_slot.view(1)[0] {
        memcpy(ptr(array), ptr(array_slot.view(1)[0]), u64(size * _qsbr_pad_SIZE));
    }
    array_slot.view(1)[0] = array;
    raw_slot.view(1)[0] = ptr[u8](raw);
    size_slot.view(1)[0] = new_size;
    qsbr_field_ptr(shared, _qsbr_shared_FREELIST).view(1)[0] = ptr[u8]();
    initialize_new_array(shared);
    PyMem_RawFree(ptr(old_raw));
    return 0;
}

impl qsbr_poll_scan(shared: ptr[u8]) -> u64 {
    __atomic_fence(5);
    base = int(shared);
    min_seq = load_u64(base + _qsbr_shared_WR_SEQ);
    array = qsbr_field_ptr(shared, _qsbr_shared_ARRAY).view(1)[0];
    size = qsbr_field_size(shared, _qsbr_shared_ARRAY_LEN).view(1)[0];
    for i in range(size) {
        qsbr = array + i * _qsbr_pad_SIZE;
        seq = load_u64(int(qsbr) + _qsbr_thread_state_SEQ);
        if seq != QSBR_OFFLINE and qsbr_lt(seq, min_seq) {
            min_seq = seq;
        }
    }
    rd_seq = load_u64(base + _qsbr_shared_RD_SEQ);
    if qsbr_lt(rd_seq, min_seq) {
        __atomic_cas_i64(
            base + _qsbr_shared_RD_SEQ, i64.wrap(rd_seq), i64.wrap(min_seq), 5
        );
        rd_seq = min_seq;
    }
    return rd_seq;
}
