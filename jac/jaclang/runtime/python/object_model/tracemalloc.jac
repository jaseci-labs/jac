import from c {
    def malloc(size: u64) -> ptr;  def free(block: ptr);  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def strlen(text: ptr[u8]) -> u64;  def PyThread_tss_create(
        key: ptr
    ) -> i32;  def PyThread_tss_delete(key: ptr);  def PyThread_tss_get(
        key: ptr
    ) -> ptr;  def PyThread_tss_set(key: ptr, value: ptr) -> i32;  def PyMem_GetAllocator(
        domain: i32, allocator: ptr[PyMemAllocatorEx]
    );  def PyMem_SetAllocator(domain: i32, allocator: ptr[PyMemAllocatorEx]);  def PyRefTracer_SetTracer(
        tracer: ptr, data: ptr
    ) -> i32;  def _PyCode_SafeAddr2Line(co: ptr[PyObject], addrq: i32) -> i32;  def _PyObject_IsFreed(
        op: ptr[PyObject]
    ) -> i32;  def _Py_FatalErrorFunc(func: ptr[u8], message: ptr[u8]);  def _Py_DumpASCII(
        fd: i32, text: ptr[PyObject]
    );  def _Py_DumpDecimal(fd: i32, value: u64);  obj TraceStack {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut TraceStack) -> int;  obj trace_t {
        has size: u64,
            traceback: ptr[u8];
    }  obj get_traces_t {
        has traces: ptr,
            domains: ptr,
            tracebacks: ptr,
            lst: ptr[PyObject],
            domain: u32;
    }  glob:priv tracemalloc_hashtable_alloc: list[ptr] = [ptr(malloc), ptr(free)];
}

glob:priv TRACEMALLOC_NOT_INITIALIZED: Final[i32] = 0,
     TRACEMALLOC_INITIALIZED: Final[i32] = 1,
     TRACEMALLOC_FINALIZED: Final[i32] = 2,
     DEFAULT_DOMAIN: Final[u32] = u32(0),
     MAX_NFRAME: Final[i32] = 65535,
     UINT16_MAX: Final[u16] = u16(65535),
     TRACE_SIZE: Final[u64] = u64(16),
     STACKREF_NULL: Final[u64] = u64(1),
     PyHASH_MULTIPLIER: Final[u64] = u64(1000003);

def tm_field(offset: i64) -> ptr[u8];

def tm_tracing -> ptr[i32];

def tm_initialized -> ptr[i32];

def tm_max_nframe -> ptr[i32];

def tm_allocator(offset: i64) -> ptr[PyMemAllocatorEx];

def tm_traced_memory -> ptr[u64];

def tm_peak_traced_memory -> ptr[u64];

def tm_slot(offset: i64) -> ptr[ptr];

def tm_filenames -> ptr;

def tm_tracebacks -> ptr;

def tm_traces -> ptr;

def tm_domains -> ptr;

def tm_empty_traceback -> ptr[u8];

def tm_reentrant_key -> ptr;

def tables_lock;

def tables_unlock;

def tb_hash(traceback: ptr[u8]) -> ptr[u64];

def tb_nframe(traceback: ptr[u8]) -> ptr[u16];

def tb_total_nframe(traceback: ptr[u8]) -> ptr[u16];

def tb_frame(traceback: ptr[u8], index: i64) -> ptr[u8];

def traceback_size(nframe: i64) -> u64;

def frame_filename(frame: ptr[u8]) -> ptr[PyObject];

def set_frame_filename(frame: ptr[u8], filename: ptr[PyObject]);

def frame_lineno(frame: ptr[u8]) -> ptr[u32];

def anon_unknown -> ptr[PyObject];

def to_ptr(key: u64) -> ptr;

def get_reentrant -> bool;

def set_reentrant(reentrant: bool);

def hashtable_hash_pyobject(key: ptr) -> u64;

def hashtable_compare_unicode(key1: ptr, key2: ptr) -> i32;

def hashtable_hash_uint(key_raw: ptr) -> u64;

def hashtable_new(
    hash_func: ptr, compare_func: ptr, key_destroy_func: ptr, value_destroy_func: ptr
) -> ptr;

def raw_malloc(size: u64) -> ptr;

def raw_free(block: ptr);

def hashtable_hash_traceback(key: ptr) -> u64;

def hashtable_compare_traceback(key1: ptr, key2: ptr) -> i32;

def frame_safe_get_code(f: ptr[u8]) -> ptr[PyObject];

def frame_safe_get_lasti(f: ptr[u8]) -> i32;

def tracemalloc_get_frame(pyframe: ptr[u8], frame: ptr[u8]);

def traceback_hash(traceback: ptr[u8]) -> u64;

def traceback_get_frames(traceback: ptr[u8]);

def traceback_new -> ptr[u8];

def tracemalloc_create_traces_table -> ptr;

def tracemalloc_destroy_domain(value: ptr);

def tracemalloc_create_domains_table -> ptr;

def tracemalloc_get_traces_table(domain: u32) -> ptr;

def tracemalloc_remove_trace_unlocked(domain: u32, block: u64);

def tracemalloc_add_trace_unlocked(domain: u32, block: u64, size: u64) -> i32;

def tracemalloc_alloc(
    need_gil: bool, use_calloc: bool, ctx: ptr, nelem: u64, elsize: u64
) -> ptr;

def tracemalloc_realloc(need_gil: bool, ctx: ptr, block: ptr, new_size: u64) -> ptr;

def tracemalloc_free(ctx: ptr, block: ptr);

def tracemalloc_malloc_gil(ctx: ptr, size: u64) -> ptr;

def tracemalloc_calloc_gil(ctx: ptr, nelem: u64, elsize: u64) -> ptr;

def tracemalloc_realloc_gil(ctx: ptr, block: ptr, new_size: u64) -> ptr;

def tracemalloc_raw_malloc(ctx: ptr, size: u64) -> ptr;

def tracemalloc_raw_calloc(ctx: ptr, nelem: u64, elsize: u64) -> ptr;

def tracemalloc_raw_realloc(ctx: ptr, block: ptr, new_size: u64) -> ptr;

def tracemalloc_clear_filename(value: ptr);

def tracemalloc_clear_traces_unlocked;

def tracemalloc_deinit;

def frame_to_pyobject(frame: ptr[u8]) -> ptr[PyObject];

def traceback_to_pyobject(traceback: ptr[u8], intern_table: ptr) -> ptr[PyObject];

def trace_to_pyobject(
    domain: u32, trace: ptr[trace_t], intern_tracebacks: ptr
) -> ptr[PyObject];

def tracemalloc_copy_trace(traces: ptr, key: ptr, value: ptr, user_data: ptr) -> i32;

def tracemalloc_copy_traces(traces: ptr) -> ptr;

def tracemalloc_copy_domain(domains: ptr, key: ptr, value: ptr, user_data: ptr) -> i32;

def tracemalloc_copy_domains(domains: ptr) -> ptr;

def tracemalloc_get_traces_fill(
    traces: ptr, key: ptr, value: ptr, user_data: ptr
) -> i32;

def tracemalloc_get_traces_domain(
    domains: ptr, key: ptr, value: ptr, user_data: ptr
) -> i32;

def tracemalloc_pyobject_decref(value: ptr);

def tracemalloc_get_traceback_unlocked(domain: u32, block: u64) -> ptr[u8];

def puts(fd: i32, text: ptr[u8]);

def _PyMem_DumpFrame(fd: i32, frame: ptr[u8]);

def tracemalloc_get_tracemalloc_memory_cb(
    domains: ptr, key: ptr, value: ptr, user_data: ptr
) -> i32;

def _PyTraceMalloc_TraceRef(op: ptr[PyObject], event: i32, ignore: ptr) -> i32;

import from c {
    def _PyTraceMalloc_Init -> PyStatus {
        PyMem_GetAllocator(
            PYMEM_DOMAIN_RAW, tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_RAW)
        );

        if PyThread_tss_create(tm_reentrant_key()) != 0 {
            return status_err(
                ptr[u8]("_PyTraceMalloc_Init"), ptr[u8]("memory allocation failed")
            );
        }

        tm_slot(_PyRuntimeState_TRACEMALLOC_FILENAMES).view(1)[0] = hashtable_new(
            ptr(hashtable_hash_pyobject),
            ptr(hashtable_compare_unicode),
            ptr(tracemalloc_clear_filename),
            ptr()
        );

        tm_slot(_PyRuntimeState_TRACEMALLOC_TRACEBACKS).view(1)[0] = hashtable_new(
            ptr(hashtable_hash_traceback),
            ptr(hashtable_compare_traceback),
            ptr(raw_free),
            ptr()
        );

        tm_slot(_PyRuntimeState_TRACEMALLOC_TRACES).view(1)[0] = tracemalloc_create_traces_table();
        tm_slot(_PyRuntimeState_TRACEMALLOC_DOMAINS).view(1)[0] = tracemalloc_create_domains_table();

        if not tm_filenames()
            or not tm_tracebacks()
            or not tm_traces()
            or not tm_domains() {
            return status_err(
                ptr[u8]("_PyTraceMalloc_Init"), ptr[u8]("memory allocation failed")
            );
        }

        empty = tm_empty_traceback();
        tb_nframe(empty).view(1)[0] = u16(1);
        tb_total_nframe(empty).view(1)[0] = u16(1);

        set_frame_filename(tb_frame(empty, 0), anon_unknown());
        frame_lineno(tb_frame(empty, 0)).view(1)[0] = u32(0);
        tb_hash(empty).view(1)[0] = traceback_hash(empty);

        tm_initialized().view(1)[0] = TRACEMALLOC_INITIALIZED;
        return status_ok();
    }  def _PyTraceMalloc_Start(max_nframe: i32) -> i32 {
        if max_nframe < 1 or max_nframe > MAX_NFRAME {
            PyErr_Format(
                PyExc_ValueError,
                "the number of frames must be in range [1; %i]",
                MAX_NFRAME
            );
            return i32(-1);
        }

        if _PyTraceMalloc_IsTracing() != 0 {
            return i32(0);
        }

        tm_max_nframe().view(1)[0] = max_nframe;

        size = traceback_size(i64(max_nframe));
        buffer = raw_malloc(size);
        tm_slot(_PyRuntimeState_TRACEMALLOC_TRACEBACK).view(1)[0] = buffer;
        if not buffer {
            PyErr_NoMemory();
            return i32(-1);
        }

        slots: own TraceStack = TraceStack();
        alloc = ptr[PyMemAllocatorEx](jacpy_stack_address(&mut slots));
        alloc.view(1)[0].malloc = int(ptr(tracemalloc_raw_malloc));
        alloc.view(1)[0].calloc = int(ptr(tracemalloc_raw_calloc));
        alloc.view(1)[0].realloc = int(ptr(tracemalloc_raw_realloc));
        alloc.view(1)[0].free = int(ptr(tracemalloc_free));

        raw = tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_RAW);
        alloc.view(1)[0].ctx = ptr(raw);
        PyMem_GetAllocator(PYMEM_DOMAIN_RAW, raw);
        PyMem_SetAllocator(PYMEM_DOMAIN_RAW, alloc);

        alloc.view(1)[0].malloc = int(ptr(tracemalloc_malloc_gil));
        alloc.view(1)[0].calloc = int(ptr(tracemalloc_calloc_gil));
        alloc.view(1)[0].realloc = int(ptr(tracemalloc_realloc_gil));
        alloc.view(1)[0].free = int(ptr(tracemalloc_free));

        mem = tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_MEM);
        alloc.view(1)[0].ctx = ptr(mem);
        PyMem_GetAllocator(PYMEM_DOMAIN_MEM, mem);
        PyMem_SetAllocator(PYMEM_DOMAIN_MEM, alloc);

        obj_alloc = tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_OBJ);
        alloc.view(1)[0].ctx = ptr(obj_alloc);
        PyMem_GetAllocator(PYMEM_DOMAIN_OBJ, obj_alloc);
        PyMem_SetAllocator(PYMEM_DOMAIN_OBJ, alloc);

        if PyRefTracer_SetTracer(ptr(_PyTraceMalloc_TraceRef), ptr()) < 0 {
            return i32(-1);
        }

        tables_lock();
        __atomic_store_i32(int(tm_tracing()), i32(1), 0);
        tables_unlock();

        return i32(0);
    }  def _PyTraceMalloc_Stop {
        tables_lock();

        if tm_tracing().view(1)[0] == 0 {
            tables_unlock();
            return;
        }

        __atomic_store_i32(int(tm_tracing()), i32(0), 0);

        PyMem_SetAllocator(
            PYMEM_DOMAIN_RAW, tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_RAW)
        );
        PyMem_SetAllocator(
            PYMEM_DOMAIN_MEM, tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_MEM)
        );
        PyMem_SetAllocator(
            PYMEM_DOMAIN_OBJ, tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_OBJ)
        );

        tracemalloc_clear_traces_unlocked();

        traceback_slot = tm_slot(_PyRuntimeState_TRACEMALLOC_TRACEBACK);
        raw_free(traceback_slot.view(1)[0]);
        traceback_slot.view(1)[0] = ptr();

        tables_unlock();

        PyRefTracer_SetTracer(ptr(), ptr());
    }  def _PyMem_DumpTraceback(fd: i32, block: ptr) {
        tables_lock();
        if tm_tracing().view(1)[0] == 0 {
            puts(
                fd,
                ptr[u8](
                    "Enable tracemalloc to get the memory block allocation traceback\n\n"
                )
            );
            tables_unlock();
            return;
        }

        traceback = tracemalloc_get_traceback_unlocked(
            DEFAULT_DOMAIN, u64.wrap(int(block))
        );
        if not traceback {
            tables_unlock();
            return;
        }

        puts(fd, ptr[u8]("Memory block allocated at (most recent call first):\n"));
        nframe = i64(tb_nframe(traceback).view(1)[0]);
        i: i64 = 0;
        while i < nframe {
            _PyMem_DumpFrame(fd, tb_frame(traceback, i));
            i += 1;
        }
        puts(fd, ptr[u8]("\n"));

        tables_unlock();
    }  def PyTraceMalloc_Track(domain: u32, block: u64, size: u64) -> i32 {
        if __atomic_load_i32(int(tm_tracing()), 0) == 0 {
            return i32(-2);
        }
        gil_state = PyGILState_Ensure();
        tables_lock();

        result: i32 = -2;
        if tm_tracing().view(1)[0] != 0 {
            result = tracemalloc_add_trace_unlocked(domain, block, size);
        }

        tables_unlock();
        PyGILState_Release(gil_state);
        return result;
    }  def PyTraceMalloc_Untrack(domain: u32, block: u64) -> i32 {
        if __atomic_load_i32(int(tm_tracing()), 0) == 0 {
            return i32(-2);
        }

        tables_lock();

        result: i32 = -2;
        if tm_tracing().view(1)[0] != 0 {
            tracemalloc_remove_trace_unlocked(domain, block);
            result = i32(0);
        }

        tables_unlock();
        return result;
    }  def _PyTraceMalloc_Fini {
        tracemalloc_deinit();
    }  def _PyTraceMalloc_GetTraceback(domain: u32, block: u64) -> ptr[PyObject] {
        tables_lock();

        traceback = tracemalloc_get_traceback_unlocked(domain, block);
        result = NULL;
        if traceback {
            set_reentrant(True);
            result = traceback_to_pyobject(traceback, ptr());
            set_reentrant(False);
        } else {
            result = object_new_ref(Py_None);
        }

        tables_unlock();
        return result;
    }  def _PyTraceMalloc_IsTracing -> i32 {
        tables_lock();
        tracing = tm_tracing().view(1)[0];
        tables_unlock();
        return tracing;
    }  def _PyTraceMalloc_ClearTraces {
        tables_lock();
        if tm_tracing().view(1)[0] != 0 {
            tracemalloc_clear_traces_unlocked();
        }
        tables_unlock();
    }  def _PyTraceMalloc_GetTraces -> ptr[PyObject] {
        tables_lock();
        set_reentrant(True);

        slots: own TraceStack = TraceStack();
        get_traces = ptr[get_traces_t](jacpy_stack_address(&mut slots));
        get_traces.view(1)[0].domain = DEFAULT_DOMAIN;
        get_traces.view(1)[0].traces = ptr();
        get_traces.view(1)[0].domains = ptr();
        get_traces.view(1)[0].tracebacks = ptr();
        get_traces.view(1)[0].lst = PyList_New(0);
        if get_traces.view(1)[0].lst and tm_tracing().view(1)[0] != 0 {
            no_memory = False;
            get_traces.view(1)[0].tracebacks = hashtable_new(
                ptr(_Py_hashtable_hash_ptr),
                ptr(_Py_hashtable_compare_direct),
                ptr(),
                ptr(tracemalloc_pyobject_decref)
            );
            if not get_traces.view(1)[0].tracebacks {
                no_memory = True;
            }

            if not no_memory {
                get_traces.view(1)[0].traces = tracemalloc_copy_traces(tm_traces());
                if not get_traces.view(1)[0].traces {
                    no_memory = True;
                }
            }

            if not no_memory {
                get_traces.view(1)[0].domains = tracemalloc_copy_domains(tm_domains());
                if not get_traces.view(1)[0].domains {
                    no_memory = True;
                }
            }

            if no_memory {
                PyErr_NoMemory();
                old = get_traces.view(1)[0].lst;
                get_traces.view(1)[0].lst = NULL;
                object_decref(old);
            } else {
                err = _Py_hashtable_foreach(
                    get_traces.view(1)[0].traces,
                    ptr(tracemalloc_get_traces_fill),
                    ptr(get_traces)
                );
                if err == 0 {
                    err = _Py_hashtable_foreach(
                        get_traces.view(1)[0].domains,
                        ptr(tracemalloc_get_traces_domain),
                        ptr(get_traces)
                    );
                }
                if err != 0 {
                    old = get_traces.view(1)[0].lst;
                    get_traces.view(1)[0].lst = NULL;
                    object_decref(old);
                }
            }
        }

        set_reentrant(False);
        tables_unlock();

        if get_traces.view(1)[0].tracebacks {
            _Py_hashtable_destroy(get_traces.view(1)[0].tracebacks);
        }
        if get_traces.view(1)[0].traces {
            _Py_hashtable_destroy(get_traces.view(1)[0].traces);
        }
        if get_traces.view(1)[0].domains {
            _Py_hashtable_destroy(get_traces.view(1)[0].domains);
        }

        return get_traces.view(1)[0].lst;
    }  def _PyTraceMalloc_GetObjectTraceback(obj_: ptr[PyObject]) -> ptr[PyObject] {
        presize = type_preheader_size(object_type(obj_));
        block = u64.wrap(int(ptr[u8](obj_) - presize));
        return _PyTraceMalloc_GetTraceback(DEFAULT_DOMAIN, block);
    }  def _PyTraceMalloc_GetTracebackLimit -> i32 {
        return tm_max_nframe().view(1)[0];
    }  def _PyTraceMalloc_GetMemory -> u64 {
        tables_lock();
        slots: own TraceStack = TraceStack();
        size = ptr[u64](jacpy_stack_address(&mut slots));
        if tm_tracing().view(1)[0] != 0 {
            size.view(1)[0] = _Py_hashtable_size(tm_tracebacks());
            size.view(1)[0] = size.view(1)[0] + _Py_hashtable_size(tm_filenames());

            size.view(1)[0] = size.view(1)[0] + _Py_hashtable_size(tm_traces());
            _Py_hashtable_foreach(
                tm_domains(), ptr(tracemalloc_get_tracemalloc_memory_cb), ptr(size)
            );
        } else {
            size.view(1)[0] = u64(0);
        }
        tables_unlock();
        return size.view(1)[0];
    }  def _PyTraceMalloc_GetTracedMemory -> ptr[PyObject] {
        tables_lock();
        traced: i64 = 0;
        peak: i64 = 0;
        if tm_tracing().view(1)[0] != 0 {
            traced = i64.wrap(tm_traced_memory().view(1)[0]);
            peak = i64.wrap(tm_peak_traced_memory().view(1)[0]);
        }
        tables_unlock();

        return Py_BuildValue(ptr[u8]("nn"), traced, peak);
    }  def _PyTraceMalloc_ResetPeak {
        tables_lock();
        if tm_tracing().view(1)[0] != 0 {
            tm_peak_traced_memory().view(1)[0] = tm_traced_memory().view(1)[0];
        }
        tables_unlock();
    }
}

impl tm_field(offset: i64) -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + offset;
}

impl tm_tracing -> ptr[i32] {
    return ptr[i32](tm_field(_PyRuntimeState_TRACEMALLOC_TRACING));
}

impl tm_initialized -> ptr[i32] {
    return ptr[i32](tm_field(_PyRuntimeState_TRACEMALLOC_INITIALIZED));
}

impl tm_max_nframe -> ptr[i32] {
    return ptr[i32](tm_field(_PyRuntimeState_TRACEMALLOC_MAX_NFRAME));
}

impl tm_allocator(offset: i64) -> ptr[PyMemAllocatorEx] {
    return ptr[PyMemAllocatorEx](tm_field(offset));
}

impl tm_traced_memory -> ptr[u64] {
    return ptr[u64](tm_field(_PyRuntimeState_TRACEMALLOC_TRACED_MEMORY));
}

impl tm_peak_traced_memory -> ptr[u64] {
    return ptr[u64](tm_field(_PyRuntimeState_TRACEMALLOC_PEAK_TRACED_MEMORY));
}

impl tm_slot(offset: i64) -> ptr[ptr] {
    return ptr[ptr](tm_field(offset));
}

impl tm_filenames -> ptr {
    return tm_slot(_PyRuntimeState_TRACEMALLOC_FILENAMES).view(1)[0];
}

impl tm_tracebacks -> ptr {
    return tm_slot(_PyRuntimeState_TRACEMALLOC_TRACEBACKS).view(1)[0];
}

impl tm_traces -> ptr {
    return tm_slot(_PyRuntimeState_TRACEMALLOC_TRACES).view(1)[0];
}

impl tm_domains -> ptr {
    return tm_slot(_PyRuntimeState_TRACEMALLOC_DOMAINS).view(1)[0];
}

impl tm_empty_traceback -> ptr[u8] {
    return tm_field(_PyRuntimeState_TRACEMALLOC_EMPTY_TRACEBACK);
}

impl tm_reentrant_key -> ptr {
    return ptr(tm_field(_PyRuntimeState_TRACEMALLOC_REENTRANT_KEY));
}

impl tables_lock {
    pymutex_lock_flags(
        ptr[PyMutex](tm_field(_PyRuntimeState_TRACEMALLOC_TABLES_LOCK)),
        _Py_LOCK_DONT_DETACH
    );
}

impl tables_unlock {
    pymutex_unlock(ptr[PyMutex](tm_field(_PyRuntimeState_TRACEMALLOC_TABLES_LOCK)));
}

impl tb_hash(traceback: ptr[u8]) -> ptr[u64] {
    return ptr[u64](traceback + tracemalloc_traceback_HASH);
}

impl tb_nframe(traceback: ptr[u8]) -> ptr[u16] {
    return ptr[u16](traceback + tracemalloc_traceback_NFRAME);
}

impl tb_total_nframe(traceback: ptr[u8]) -> ptr[u16] {
    return ptr[u16](traceback + tracemalloc_traceback_TOTAL_NFRAME);
}

impl tb_frame(traceback: ptr[u8], index: i64) -> ptr[u8] {
    return traceback + tracemalloc_traceback_FRAMES + index * tracemalloc_frame_SIZE;
}

impl traceback_size(nframe: i64) -> u64 {
    return u64(tracemalloc_traceback_SIZE + tracemalloc_frame_SIZE * (nframe - 1));
}

impl frame_filename(frame: ptr[u8]) -> ptr[PyObject] {
    halves = ptr[u32](frame);
    low = u64(halves.view(2)[0]);
    high = u64(halves.view(2)[1]);
    return ptr[PyObject](i64.wrap(low | wrapping_shl(high, u64(32))));
}

impl set_frame_filename(frame: ptr[u8], filename: ptr[PyObject]) {
    bits = u64.wrap(int(filename));
    halves = ptr[u32](frame);
    halves.view(2)[0] = u32.wrap(bits);
    halves.view(2)[1] = u32.wrap(bits >> u64(32));
}

impl frame_lineno(frame: ptr[u8]) -> ptr[u32] {
    return ptr[u32](frame + tracemalloc_frame_LINENO);
}

impl anon_unknown -> ptr[PyObject] {
    return ptr[PyObject](
        ptr[u8](addressof(_PyRuntime))
            + _PyRuntimeState_GLOBAL_STRINGS
            + _Py_STR_anon_unknown
    );
}

impl to_ptr(key: u64) -> ptr {
    return ptr(ptr[u8](i64.wrap(key)));
}

impl get_reentrant -> bool {
    return bool(PyThread_tss_get(tm_reentrant_key()));
}

impl set_reentrant(reentrant: bool) {
    if reentrant {
        PyThread_tss_set(tm_reentrant_key(), ptr(addressof(_Py_TrueStruct)));
    } else {
        PyThread_tss_set(tm_reentrant_key(), ptr());
    }
}

impl hashtable_hash_pyobject(key: ptr) -> u64 {
    return u64.wrap(PyObject_Hash(ptr[PyObject](key)));
}

impl hashtable_compare_unicode(key1: ptr, key2: ptr) -> i32 {
    obj1 = ptr[PyObject](key1);
    obj2 = ptr[PyObject](key2);
    if obj1 and obj2 {
        return i32(PyUnicode_Compare(obj1, obj2) == 0);
    }
    return i32(obj1 == obj2);
}

impl hashtable_hash_uint(key_raw: ptr) -> u64 {
    return u64(u32.wrap(int(key_raw)));
}

impl hashtable_new(
    hash_func: ptr, compare_func: ptr, key_destroy_func: ptr, value_destroy_func: ptr
) -> ptr {
    return _Py_hashtable_new_full(
        hash_func,
        compare_func,
        key_destroy_func,
        value_destroy_func,
        ptr(addressof(tracemalloc_hashtable_alloc))
    );
}

impl raw_malloc(size: u64) -> ptr {
    raw = tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_RAW);
    return raw.view(1)[0].malloc(raw.view(1)[0].ctx, size);
}

impl raw_free(block: ptr) {
    raw = tm_allocator(_PyRuntimeState_TRACEMALLOC_ALLOCATORS_RAW);
    raw.view(1)[0].free(raw.view(1)[0].ctx, block);
}

impl hashtable_hash_traceback(key: ptr) -> u64 {
    return tb_hash(ptr[u8](key)).view(1)[0];
}

impl hashtable_compare_traceback(key1: ptr, key2: ptr) -> i32 {
    traceback1 = ptr[u8](key1);
    traceback2 = ptr[u8](key2);

    if tb_nframe(traceback1).view(1)[0] != tb_nframe(traceback2).view(1)[0] {
        return i32(0);
    }
    if tb_total_nframe(traceback1).view(1)[0]
        != tb_total_nframe(traceback2).view(1)[0] {
        return i32(0);
    }

    nframe = i64(tb_nframe(traceback1).view(1)[0]);
    i: i64 = 0;
    while i < nframe {
        frame1 = tb_frame(traceback1, i);
        frame2 = tb_frame(traceback2, i);

        if frame_lineno(frame1).view(1)[0] != frame_lineno(frame2).view(1)[0] {
            return i32(0);
        }
        if frame_filename(frame1) != frame_filename(frame2) {
            return i32(0);
        }
        i += 1;
    }
    return i32(1);
}

impl frame_safe_get_code(f: ptr[u8]) -> ptr[PyObject] {
    if not frame_ptr(f, _PyInterpreterFrame_F_GLOBALS)
        or not frame_ptr(f, _PyInterpreterFrame_F_BUILTINS) {
        return NULL;
    }

    bits = ptr[u64](f + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0];
    if bits == STACKREF_NULL {
        return NULL;
    }
    if is_ptr_freed(bits) {
        return NULL;
    }
    executable = stackref_borrow(bits);
    if _PyObject_IsFreed(executable) != 0 {
        return NULL;
    }
    if not object_is_type(executable, ptr[PyTypeObject](addressof(PyCode_Type))) {
        return NULL;
    }
    return executable;
}

impl frame_safe_get_lasti(f: ptr[u8]) -> i32 {
    co = frame_safe_get_code(f);
    if not co {
        return i32(-1);
    }
    bytecode = int(co) + PyCodeObject_CODE_ADAPTIVE;
    units = (int(frame_ptr(f, _PyInterpreterFrame_INSTR_PTR)) - bytecode) // 2;
    return i32.wrap(units) * i32(2);
}

impl tracemalloc_get_frame(pyframe: ptr[u8], frame: ptr[u8]) {
    set_frame_filename(frame, anon_unknown());

    lineno: i32 = -1;
    code = frame_code(pyframe);

    lasti = frame_safe_get_lasti(pyframe);
    if lasti >= 0 {
        lineno = _PyCode_SafeAddr2Line(code, lasti);
    }
    if lineno < 0 {
        lineno = 0;
    }
    frame_lineno(frame).view(1)[0] = u32(lineno);

    filename = ptr[ptr[PyObject]](ptr[u8](code) + PyCodeObject_FILENAME).view(1)[0];
    if not filename {
        return;
    }

    if not unicode_check(filename) {
        return;
    }

    filenames = ptr[_Py_hashtable_t](tm_filenames());
    ent = ptr[_Py_hashtable_entry_t](
        filenames.view(1)[0].get_entry_func(filenames, ptr(filename))
    );
    if ent {
        filename = ptr[PyObject](ent.view(1)[0].key);
    } else {
        if _Py_hashtable_set(ptr(filenames), ptr(object_new_ref(filename)), ptr())
            < 0 {
            object_decref(filename);
            return;
        }
    }

    set_frame_filename(frame, filename);
}

impl traceback_hash(traceback: ptr[u8]) -> u64 {
    len_ = i64(tb_nframe(traceback).view(1)[0]);
    mult = PyHASH_MULTIPLIER;

    x = u64(0x345678);
    index: i64 = 0;
    len_ -= 1;
    while len_ >= 0 {
        frame = tb_frame(traceback, index);
        y = u64.wrap(PyObject_Hash(frame_filename(frame)));
        y ^= u64(frame_lineno(frame).view(1)[0]);
        index += 1;

        x = wrapping_mul(x ^ y, mult);

        mult = wrapping_add(mult, u64.wrap(82520 + len_ + len_));
        len_ -= 1;
    }
    x ^= u64(tb_total_nframe(traceback).view(1)[0]);
    x = wrapping_add(x, u64(97531));
    return x;
}

impl traceback_get_frames(traceback: ptr[u8]) {
    tstate = current_tstate();
    current = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0];
    pyframe = frame_first_complete(current);
    max_nframe = tm_max_nframe().view(1)[0];
    while pyframe {
        nframe = tb_nframe(traceback);
        if i32(nframe.view(1)[0]) < max_nframe {
            tracemalloc_get_frame(pyframe, tb_frame(traceback, i64(nframe.view(1)[0])));
            nframe.view(1)[0] = nframe.view(1)[0] + u16(1);
        }
        total = tb_total_nframe(traceback);
        if total.view(1)[0] < UINT16_MAX {
            total.view(1)[0] = total.view(1)[0] + u16(1);
        }
        pyframe = frame_first_complete(
            frame_ptr(pyframe, _PyInterpreterFrame_PREVIOUS)
        );
    }
}

impl traceback_new -> ptr[u8] {
    traceback = ptr[u8](tm_slot(_PyRuntimeState_TRACEMALLOC_TRACEBACK).view(1)[0]);
    tb_nframe(traceback).view(1)[0] = u16(0);
    tb_total_nframe(traceback).view(1)[0] = u16(0);
    traceback_get_frames(traceback);
    if tb_nframe(traceback).view(1)[0] == u16(0) {
        return tm_empty_traceback();
    }
    tb_hash(traceback).view(1)[0] = traceback_hash(traceback);

    tracebacks = ptr[_Py_hashtable_t](tm_tracebacks());
    ent = ptr[_Py_hashtable_entry_t](
        tracebacks.view(1)[0].get_entry_func(tracebacks, ptr(traceback))
    );
    if ent {
        return ptr[u8](ent.view(1)[0].key);
    }

    size = traceback_size(i64(tb_nframe(traceback).view(1)[0]));
    copy = raw_malloc(size);
    if not copy {
        return ptr[u8]();
    }
    memcpy(copy, ptr(traceback), size);

    if _Py_hashtable_set(ptr(tracebacks), copy, ptr()) < 0 {
        raw_free(copy);
        return ptr[u8]();
    }
    return ptr[u8](copy);
}

impl tracemalloc_create_traces_table -> ptr {
    return hashtable_new(
        ptr(_Py_hashtable_hash_ptr),
        ptr(_Py_hashtable_compare_direct),
        ptr(),
        ptr(raw_free)
    );
}

impl tracemalloc_destroy_domain(value: ptr) {
    _Py_hashtable_destroy(value);
}

impl tracemalloc_create_domains_table -> ptr {
    return hashtable_new(
        ptr(hashtable_hash_uint),
        ptr(_Py_hashtable_compare_direct),
        ptr(),
        ptr(tracemalloc_destroy_domain)
    );
}

impl tracemalloc_get_traces_table(domain: u32) -> ptr {
    if domain == DEFAULT_DOMAIN {
        return tm_traces();
    }
    return _Py_hashtable_get(tm_domains(), to_ptr(u64(domain)));
}

impl tracemalloc_remove_trace_unlocked(domain: u32, block: u64) {
    traces = tracemalloc_get_traces_table(domain);
    if not traces {
        return;
    }

    trace = ptr[trace_t](_Py_hashtable_steal(traces, to_ptr(block)));
    if not trace {
        return;
    }
    traced = tm_traced_memory();
    traced.view(1)[0] = traced.view(1)[0] - trace.view(1)[0].size;
    raw_free(ptr(trace));
}

impl tracemalloc_add_trace_unlocked(domain: u32, block: u64, size: u64) -> i32 {
    traceback = traceback_new();
    if not traceback {
        return i32(-1);
    }

    traces = tracemalloc_get_traces_table(domain);
    if not traces {
        traces = tracemalloc_create_traces_table();
        if not traces {
            return i32(-1);
        }

        if _Py_hashtable_set(tm_domains(), to_ptr(u64(domain)), traces) < 0 {
            _Py_hashtable_destroy(traces);
            return i32(-1);
        }
    }

    traced = tm_traced_memory();
    trace = ptr[trace_t](_Py_hashtable_get(traces, to_ptr(block)));
    if trace {
        traced.view(1)[0] = traced.view(1)[0] - trace.view(1)[0].size;

        trace.view(1)[0].size = size;
        trace.view(1)[0].traceback = traceback;
    } else {
        trace = ptr[trace_t](raw_malloc(TRACE_SIZE));
        if not trace {
            return i32(-1);
        }
        trace.view(1)[0].size = size;
        trace.view(1)[0].traceback = traceback;
        res = _Py_hashtable_set(traces, to_ptr(block), ptr(trace));
        if res != 0 {
            raw_free(ptr(trace));
            return res;
        }
    }

    traced.view(1)[0] = traced.view(1)[0] + size;
    peak = tm_peak_traced_memory();
    if traced.view(1)[0] > peak.view(1)[0] {
        peak.view(1)[0] = traced.view(1)[0];
    }
    return i32(0);
}

impl tracemalloc_alloc(
    need_gil: bool, use_calloc: bool, ctx: ptr, nelem: u64, elsize: u64
) -> ptr {
    reentrant = get_reentrant();

    if not reentrant {
        set_reentrant(True);
    }

    alloc = ptr[PyMemAllocatorEx](ctx);
    block = ptr();
    if use_calloc {
        block = alloc.view(1)[0].calloc(alloc.view(1)[0].ctx, nelem, elsize);
    } else {
        block = alloc.view(1)[0].malloc(
            alloc.view(1)[0].ctx, wrapping_mul(nelem, elsize)
        );
    }

    if block and not reentrant {
        gil_state: i32 = 0;
        if need_gil {
            gil_state = PyGILState_Ensure();
        }
        tables_lock();

        if tm_tracing().view(1)[0] != 0 {
            if tracemalloc_add_trace_unlocked(
                DEFAULT_DOMAIN, u64.wrap(int(block)), wrapping_mul(nelem, elsize)
            )
                < 0 {
                alloc.view(1)[0].free(alloc.view(1)[0].ctx, block);
                block = ptr();
            }
        }

        tables_unlock();
        if need_gil {
            PyGILState_Release(gil_state);
        }
    }

    if not reentrant {
        set_reentrant(False);
    }
    return block;
}

impl tracemalloc_realloc(need_gil: bool, ctx: ptr, block: ptr, new_size: u64) -> ptr {
    reentrant = get_reentrant();

    if not reentrant {
        set_reentrant(True);
    }

    alloc = ptr[PyMemAllocatorEx](ctx);
    block2 = alloc.view(1)[0].realloc(alloc.view(1)[0].ctx, block, new_size);

    if block2 and not reentrant {
        gil_state: i32 = 0;
        if need_gil {
            gil_state = PyGILState_Ensure();
        }
        tables_lock();

        if tm_tracing().view(1)[0] != 0 {
            if block {
                if int(block2) != int(block) {
                    tracemalloc_remove_trace_unlocked(
                        DEFAULT_DOMAIN, u64.wrap(int(block))
                    );
                }

                if tracemalloc_add_trace_unlocked(
                    DEFAULT_DOMAIN, u64.wrap(int(block2)), new_size
                )
                    < 0 {
                    _Py_FatalErrorFunc(
                        ptr[u8]("tracemalloc_realloc"),
                        ptr[u8]("tracemalloc_realloc() failed to allocate a trace")
                    );
                }
            } else {
                if tracemalloc_add_trace_unlocked(
                    DEFAULT_DOMAIN, u64.wrap(int(block2)), new_size
                )
                    < 0 {
                    alloc.view(1)[0].free(alloc.view(1)[0].ctx, block2);
                    block2 = ptr();
                }
            }
        }

        tables_unlock();
        if need_gil {
            PyGILState_Release(gil_state);
        }
    }

    if not reentrant {
        set_reentrant(False);
    }
    return block2;
}

impl tracemalloc_free(ctx: ptr, block: ptr) {
    if not block {
        return;
    }

    alloc = ptr[PyMemAllocatorEx](ctx);
    alloc.view(1)[0].free(alloc.view(1)[0].ctx, block);

    if get_reentrant() {
        return;
    }

    tables_lock();

    if tm_tracing().view(1)[0] != 0 {
        tracemalloc_remove_trace_unlocked(DEFAULT_DOMAIN, u64.wrap(int(block)));
    }

    tables_unlock();
}

impl tracemalloc_malloc_gil(ctx: ptr, size: u64) -> ptr {
    return tracemalloc_alloc(False, False, ctx, u64(1), size);
}

impl tracemalloc_calloc_gil(ctx: ptr, nelem: u64, elsize: u64) -> ptr {
    return tracemalloc_alloc(False, True, ctx, nelem, elsize);
}

impl tracemalloc_realloc_gil(ctx: ptr, block: ptr, new_size: u64) -> ptr {
    return tracemalloc_realloc(False, ctx, block, new_size);
}

impl tracemalloc_raw_malloc(ctx: ptr, size: u64) -> ptr {
    return tracemalloc_alloc(True, False, ctx, u64(1), size);
}

impl tracemalloc_raw_calloc(ctx: ptr, nelem: u64, elsize: u64) -> ptr {
    return tracemalloc_alloc(True, True, ctx, nelem, elsize);
}

impl tracemalloc_raw_realloc(ctx: ptr, block: ptr, new_size: u64) -> ptr {
    return tracemalloc_realloc(True, ctx, block, new_size);
}

impl tracemalloc_clear_filename(value: ptr) {
    object_decref(ptr[PyObject](value));
}

impl tracemalloc_clear_traces_unlocked {
    set_reentrant(True);

    _Py_hashtable_clear(tm_traces());
    _Py_hashtable_clear(tm_domains());
    _Py_hashtable_clear(tm_tracebacks());
    _Py_hashtable_clear(tm_filenames());

    tm_traced_memory().view(1)[0] = u64(0);
    tm_peak_traced_memory().view(1)[0] = u64(0);

    set_reentrant(False);
}

impl tracemalloc_deinit {
    if tm_initialized().view(1)[0] != TRACEMALLOC_INITIALIZED {
        return;
    }
    tm_initialized().view(1)[0] = TRACEMALLOC_FINALIZED;

    _PyTraceMalloc_Stop();

    _Py_hashtable_destroy(tm_domains());
    _Py_hashtable_destroy(tm_traces());
    _Py_hashtable_destroy(tm_tracebacks());
    _Py_hashtable_destroy(tm_filenames());

    PyThread_tss_delete(tm_reentrant_key());
}

impl frame_to_pyobject(frame: ptr[u8]) -> ptr[PyObject] {
    frame_obj = PyTuple_New(2);
    if not frame_obj {
        return NULL;
    }

    tuple_set_item(frame_obj, 0, object_new_ref(frame_filename(frame)));

    lineno_obj = PyLong_FromUnsignedLong(u64(frame_lineno(frame).view(1)[0]));
    if not lineno_obj {
        object_decref(frame_obj);
        return NULL;
    }
    tuple_set_item(frame_obj, 1, lineno_obj);

    return frame_obj;
}

impl traceback_to_pyobject(traceback: ptr[u8], intern_table: ptr) -> ptr[PyObject] {
    frames = NULL;
    if intern_table {
        frames = ptr[PyObject](_Py_hashtable_get(intern_table, ptr(traceback)));
        if frames {
            return object_new_ref(frames);
        }
    }

    nframe = i64(tb_nframe(traceback).view(1)[0]);
    frames = PyTuple_New(nframe);
    if not frames {
        return NULL;
    }

    i: i64 = 0;
    while i < nframe {
        frame = frame_to_pyobject(tb_frame(traceback, i));
        if not frame {
            object_decref(frames);
            return NULL;
        }
        tuple_set_item(frames, i, frame);
        i += 1;
    }

    if intern_table {
        if _Py_hashtable_set(intern_table, ptr(traceback), ptr(frames)) < 0 {
            object_decref(frames);
            PyErr_NoMemory();
            return NULL;
        }

        object_incref(frames);
    }
    return frames;
}

impl trace_to_pyobject(
    domain: u32, trace: ptr[trace_t], intern_tracebacks: ptr
) -> ptr[PyObject] {
    trace_obj = PyTuple_New(4);
    if not trace_obj {
        return NULL;
    }

    obj_ = PyLong_FromSize_t(u64(domain));
    if not obj_ {
        object_decref(trace_obj);
        return NULL;
    }
    tuple_set_item(trace_obj, 0, obj_);

    obj_ = PyLong_FromSize_t(trace.view(1)[0].size);
    if not obj_ {
        object_decref(trace_obj);
        return NULL;
    }
    tuple_set_item(trace_obj, 1, obj_);

    obj_ = traceback_to_pyobject(trace.view(1)[0].traceback, intern_tracebacks);
    if not obj_ {
        object_decref(trace_obj);
        return NULL;
    }
    tuple_set_item(trace_obj, 2, obj_);

    obj_ = PyLong_FromUnsignedLong(
        u64(tb_total_nframe(trace.view(1)[0].traceback).view(1)[0])
    );
    if not obj_ {
        object_decref(trace_obj);
        return NULL;
    }
    tuple_set_item(trace_obj, 3, obj_);

    return trace_obj;
}

impl tracemalloc_copy_trace(traces: ptr, key: ptr, value: ptr, user_data: ptr) -> i32 {
    traces2 = user_data;
    trace = ptr[trace_t](value);

    trace2 = ptr[trace_t](raw_malloc(TRACE_SIZE));
    if not trace2 {
        return i32(-1);
    }
    trace2.view(1)[0].size = trace.view(1)[0].size;
    trace2.view(1)[0].traceback = trace.view(1)[0].traceback;
    if _Py_hashtable_set(traces2, key, ptr(trace2)) < 0 {
        raw_free(ptr(trace2));
        return i32(-1);
    }
    return i32(0);
}

impl tracemalloc_copy_traces(traces: ptr) -> ptr {
    traces2 = tracemalloc_create_traces_table();
    if not traces2 {
        return ptr();
    }

    err = _Py_hashtable_foreach(traces, ptr(tracemalloc_copy_trace), traces2);
    if err != 0 {
        _Py_hashtable_destroy(traces2);
        return ptr();
    }
    return traces2;
}

impl tracemalloc_copy_domain(
    domains: ptr, key: ptr, value: ptr, user_data: ptr
) -> i32 {
    domains2 = user_data;
    domain = u32.wrap(int(key));
    traces = value;

    traces2 = tracemalloc_copy_traces(traces);
    if not traces2 {
        return i32(-1);
    }
    if _Py_hashtable_set(domains2, to_ptr(u64(domain)), traces2) < 0 {
        _Py_hashtable_destroy(traces2);
        return i32(-1);
    }
    return i32(0);
}

impl tracemalloc_copy_domains(domains: ptr) -> ptr {
    domains2 = tracemalloc_create_domains_table();
    if not domains2 {
        return ptr();
    }

    err = _Py_hashtable_foreach(domains, ptr(tracemalloc_copy_domain), domains2);
    if err != 0 {
        _Py_hashtable_destroy(domains2);
        return ptr();
    }
    return domains2;
}

impl tracemalloc_get_traces_fill(
    traces: ptr, key: ptr, value: ptr, user_data: ptr
) -> i32 {
    get_traces = ptr[get_traces_t](user_data);
    trace = ptr[trace_t](value);

    trace_tuple = trace_to_pyobject(
        get_traces.view(1)[0].domain, trace, get_traces.view(1)[0].tracebacks
    );
    if not trace_tuple {
        return i32(1);
    }

    res = PyList_Append(get_traces.view(1)[0].lst, trace_tuple);
    object_decref(trace_tuple);
    if res < 0 {
        return i32(1);
    }
    return i32(0);
}

impl tracemalloc_get_traces_domain(
    domains: ptr, key: ptr, value: ptr, user_data: ptr
) -> i32 {
    get_traces = ptr[get_traces_t](user_data);
    domain = u32.wrap(int(key));
    traces = value;

    get_traces.view(1)[0].domain = domain;
    return _Py_hashtable_foreach(traces, ptr(tracemalloc_get_traces_fill), user_data);
}

impl tracemalloc_pyobject_decref(value: ptr) {
    object_decref(ptr[PyObject](value));
}

impl tracemalloc_get_traceback_unlocked(domain: u32, block: u64) -> ptr[u8] {
    if tm_tracing().view(1)[0] == 0 {
        return ptr[u8]();
    }

    traces = tracemalloc_get_traces_table(domain);
    if not traces {
        return ptr[u8]();
    }

    trace = ptr[trace_t](_Py_hashtable_get(traces, to_ptr(block)));
    if not trace {
        return ptr[u8]();
    }
    return trace.view(1)[0].traceback;
}

impl puts(fd: i32, text: ptr[u8]) {
    _Py_write_noraise(fd, ptr(text), strlen(text));
}

impl _PyMem_DumpFrame(fd: i32, frame: ptr[u8]) {
    puts(fd, ptr[u8]("  File \""));
    _Py_DumpASCII(fd, frame_filename(frame));
    puts(fd, ptr[u8]("\", line "));
    _Py_DumpDecimal(fd, u64(frame_lineno(frame).view(1)[0]));
    puts(fd, ptr[u8]("\n"));
}

impl tracemalloc_get_tracemalloc_memory_cb(
    domains: ptr, key: ptr, value: ptr, user_data: ptr
) -> i32 {
    size = ptr[u64](user_data);
    size.view(1)[0] = size.view(1)[0] + _Py_hashtable_size(value);
    return i32(0);
}

impl _PyTraceMalloc_TraceRef(op: ptr[PyObject], event: i32, ignore: ptr) -> i32 {
    if event != PyRefTracer_CREATE {
        return i32(0);
    }
    if get_reentrant() {
        return i32(0);
    }

    tables_lock();

    if tm_tracing().view(1)[0] != 0 {
        presize = type_preheader_size(object_type(op));
        block = u64.wrap(int(ptr[u8](op) - presize));

        trace = ptr[trace_t](_Py_hashtable_get(tm_traces(), to_ptr(block)));
        if trace {
            traceback = traceback_new();
            if traceback {
                trace.view(1)[0].traceback = traceback;
            }
        }
    }

    tables_unlock();
    return i32(0);
}
