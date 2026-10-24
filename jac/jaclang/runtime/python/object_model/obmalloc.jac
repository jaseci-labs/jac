import from c {
    def malloc(size: u64) -> ptr;  def calloc(nelem: u64, elsize: u64) -> ptr;  def realloc(
        block: ptr, size: u64
    ) -> ptr;  def free(block: ptr);  def mmap(
        address: ptr, length: u64, prot: i32, flags: i32, fd: i32, offset: i64
    ) -> ptr;  def munmap(address: ptr, length: u64) -> i32;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memset(target: ptr, value: i32, size: u64) -> ptr;  def memcmp(
        left: ptr, right: ptr, size: u64
    ) -> i32;  def strlen(text: ptr[u8]) -> u64;  def strcmp(
        left: ptr[u8], right: ptr[u8]
    ) -> i32;  def wcslen(text: ptr[i32]) -> u64;  def fputs(
        text: ptr[u8], stream: ptr
    ) -> i32;  def fputc(character: i32, stream: ptr) -> i32;  def fprintf(
        stream: ptr, format: ptr[u8], *args: any
    ) -> i32;  def fflush(stream: ptr) -> i32;  def PyOS_snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def Py_GETENV(name: ptr[u8]) -> ptr[u8];  def _Py_FatalErrorFunc(
        func: ptr[u8], message: ptr[u8]
    );  def _Py_FatalErrorFormat(func: ptr[u8], format: ptr[u8], *args: any);  def _PyMem_DumpTraceback(
        fd: i32, block: ptr
    );  def jacpy_stdio_stream(stream: i32) -> ptr;  def _PyMutex_LockTimed(
        m: ptr[PyMutex], timeout_ns: i64, flags: i32
    ) -> i32;  def _Py_qsbr_poll(qsbr: ptr[u8], goal: u64) -> bool;  def PyInterpreterState_Head -> ptr[
        u8
    ];  def PyInterpreterState_Next(interp: ptr[u8]) -> ptr[u8];  def _Py_IsMainInterpreterFinalizing(
        interp: ptr[u8]
    ) -> i32;  def mi_malloc(size: u64) -> ptr;  def mi_calloc(
        count: u64, size: u64
    ) -> ptr;  def mi_realloc(block: ptr, newsize: u64) -> ptr;  def mi_free(
        block: ptr
    );  def _mi_page_free(page: ptr, pq: ptr, force: bool);  def mi_heap_get_default -> ptr;  def mi_heap_visit_blocks(
        heap: ptr, visit_all_blocks: bool, visit_fn: ptr, arg: ptr
    ) -> bool;  obj ObmallocStack {
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
            w15: u64 = u64(0),
            w16: u64 = u64(0),
            w17: u64 = u64(0),
            w18: u64 = u64(0),
            w19: u64 = u64(0),
            w20: u64 = u64(0),
            w21: u64 = u64(0),
            w22: u64 = u64(0),
            w23: u64 = u64(0),
            w24: u64 = u64(0),
            w25: u64 = u64(0),
            w26: u64 = u64(0),
            w27: u64 = u64(0),
            w28: u64 = u64(0),
            w29: u64 = u64(0),
            w30: u64 = u64(0),
            w31: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut ObmallocStack) -> int;  obj MemWorkItem {
        has ptr_: u64,
            qsbr_goal: u64;
    }  obj MemWorkChunk {
        has node_next: ptr[llist_node],
            node_prev: ptr[llist_node],
            rd_idx: i64,
            wr_idx: i64;
    }  obj ObmallocWords8 {
        has w0: u64,
            w1: u64,
            w2: u64,
            w3: u64,
            w4: u64,
            w5: u64,
            w6: u64,
            w7: u64;
    }  obj ObmallocWords64 {
        has w0: ObmallocWords8,
            w1: ObmallocWords8,
            w2: ObmallocWords8,
            w3: ObmallocWords8,
            w4: ObmallocWords8,
            w5: ObmallocWords8,
            w6: ObmallocWords8,
            w7: ObmallocWords8;
    }  obj ObmallocWords512 {
        has w0: ObmallocWords64,
            w1: ObmallocWords64,
            w2: ObmallocWords64,
            w3: ObmallocWords64,
            w4: ObmallocWords64,
            w5: ObmallocWords64,
            w6: ObmallocWords64,
            w7: ObmallocWords64;
    }  obj ObmallocWords4096 {
        has w0: ObmallocWords512,
            w1: ObmallocWords512,
            w2: ObmallocWords512,
            w3: ObmallocWords512,
            w4: ObmallocWords512,
            w5: ObmallocWords512,
            w6: ObmallocWords512,
            w7: ObmallocWords512;
    }  obj ObmallocWords32768 {
        has w0: ObmallocWords4096,
            w1: ObmallocWords4096,
            w2: ObmallocWords4096,
            w3: ObmallocWords4096,
            w4: ObmallocWords4096,
            w5: ObmallocWords4096,
            w6: ObmallocWords4096,
            w7: ObmallocWords4096;
    }  obj ObmallocStateStorage {
        has w0: ObmallocWords32768,
            w1: ObmallocWords64,
            w2: ObmallocWords64,
            w3: ObmallocWords8,
            w4: u64,
            w5: u64;
    }
}

glob:priv pydebug: i32 = 0,
     PY_SSIZE_T_MAX_SIZE: u64 = u64(0x7FFFFFFFFFFFFFFF),
     WCHAR_SIZE: u64 = u64(4),
     MEM_WORK_CHUNK_ARRAY: i64 = 32,
     SST: i64 = 8,
     PYMEM_DEBUG_EXTRA_BYTES: u64 = u64(24),
     ERASED_SIZE: i64 = 64;

import from c {
    def _PyMem_RawMalloc(ctx: ptr, size: u64) -> ptr {
        if size == u64(0) {
            return malloc(u64(1));
        }
        return malloc(size);
    }  def _PyMem_RawCalloc(ctx: ptr, nelem: u64, elsize: u64) -> ptr {
        if nelem == u64(0) or elsize == u64(0) {
            return calloc(u64(1), u64(1));
        }
        return calloc(nelem, elsize);
    }  def _PyMem_RawRealloc(ctx: ptr, ptr_: ptr, size: u64) -> ptr {
        if size == u64(0) {
            return realloc(ptr_, u64(1));
        }
        return realloc(ptr_, size);
    }  def _PyMem_RawFree(ctx: ptr, ptr_: ptr) {
        free(ptr_);
    }  def _PyMem_mi_page_clear_qsbr(page: ptr) {
        return;
    }  def _PyMem_mi_page_is_safe_to_free(page: ptr) -> bool {
        return True;
    }  def _PyMem_mi_page_maybe_free(page: ptr, pq: ptr, force: bool) -> bool {
        _mi_page_free(page, pq, force);
        return True;
    }  def _PyMem_mi_page_reclaimed(page: ptr) {
        return;
    }  def _PyMem_mi_heap_collect_qsbr(heap: ptr) {
        return;
    }  def _PyMem_MiMalloc(ctx: ptr, size: u64) -> ptr {
        return mi_malloc(size);
    }  def _PyMem_MiCalloc(ctx: ptr, nelem: u64, elsize: u64) -> ptr {
        return mi_calloc(nelem, elsize);
    }  def _PyMem_MiRealloc(ctx: ptr, ptr_: ptr, size: u64) -> ptr {
        return mi_realloc(ptr_, size);
    }  def _PyMem_MiFree(ctx: ptr, ptr_: ptr) {
        mi_free(ptr_);
    }  def _PyObject_MiMalloc(ctx: ptr, nbytes: u64) -> ptr {
        return mi_malloc(nbytes);
    }  def _PyObject_MiCalloc(ctx: ptr, nelem: u64, elsize: u64) -> ptr {
        return mi_calloc(nelem, elsize);
    }  def _PyObject_MiRealloc(ctx: ptr, ptr_: ptr, nbytes: u64) -> ptr {
        return mi_realloc(ptr_, nbytes);
    }  def _PyObject_MiFree(ctx: ptr, ptr_: ptr) {
        mi_free(ptr_);
    }  glob:priv MALLOC_ALLOC: PyMemAllocatorEx = PyMemAllocatorEx(
             malloc=_PyMem_RawMalloc,
             calloc=_PyMem_RawCalloc,
             realloc=_PyMem_RawRealloc,
             free=_PyMem_RawFree
         ),
         MIMALLOC_ALLOC: PyMemAllocatorEx = PyMemAllocatorEx(
             malloc=_PyMem_MiMalloc,
             calloc=_PyMem_MiCalloc,
             realloc=_PyMem_MiRealloc,
             free=_PyMem_MiFree
         ),
         MIMALLOC_OBJALLOC: PyMemAllocatorEx = PyMemAllocatorEx(
             malloc=_PyObject_MiMalloc,
             calloc=_PyObject_MiCalloc,
             realloc=_PyObject_MiRealloc,
             free=_PyObject_MiFree
         ),
         PYMALLOC_ALLOC: PyMemAllocatorEx = PyMemAllocatorEx(
             malloc=_PyObject_Malloc,
             calloc=_PyObject_Calloc,
             realloc=_PyObject_Realloc,
             free=_PyObject_Free
         ); def _PyMem_DefaultRawMalloc(size: u64) -> ptr {
        return _PyMem_RawMalloc(ptr(), size);
    }  def _PyMem_DefaultRawCalloc(nelem: u64, elsize: u64) -> ptr {
        return _PyMem_RawCalloc(ptr(), nelem, elsize);
    }  def _PyMem_DefaultRawRealloc(ptr_: ptr, size: u64) -> ptr {
        return _PyMem_RawRealloc(ptr(), ptr_, size);
    }  def _PyMem_DefaultRawFree(ptr_: ptr) {
        _PyMem_RawFree(ptr(), ptr_);
    }  def _PyMem_DefaultRawWcsdup(str_: ptr[i32]) -> ptr[i32] {
        length = wcslen(str_);
        if length > PY_SSIZE_T_MAX_SIZE // WCHAR_SIZE - u64(1) {
            return ptr[i32]();
        }
        size = (length + u64(1)) * WCHAR_SIZE;
        str2 = ptr[i32](_PyMem_DefaultRawMalloc(size));
        if not str2 {
            return ptr[i32]();
        }
        memcpy(ptr(str2), ptr(str_), size);
        return str2;
    }  def _PyMem_ArenaAlloc(ctx: ptr, size: u64) -> ptr {
        block = mmap(ptr(), size, ARENA_MMAP_PROT, ARENA_MMAP_FLAGS, i32(-1), i64(0));

        if int(block) == -1 {
            return ptr();
        }
        return block;
    }  def _PyMem_ArenaFree(ctx: ptr, ptr_: ptr, size: u64) {
        if not ptr_ {
            return;
        }
        munmap(ptr_, size);
    }
}

def runtime_field(offset: i64) -> ptr[u8];

def runtime_allocator(offset: i64) -> ptr[PyMemAllocatorEx];

def allocators_mutex -> ptr[PyMutex];

def debug_api_alloc(api: ptr[u8]) -> ptr[PyMemAllocatorEx];

def object_arena -> ptr[PyObjectArenaAllocator];

def is_debug_enabled_slot -> ptr[i32];

def domain_allocator(domain: i32) -> ptr[PyMemAllocatorEx];

def fill_debug_allocator(alloc: ptr[PyMemAllocatorEx], api: ptr[u8], is_raw: bool);

def set_default_allocator_unlocked(
    domain: i32, debug: i32, old_alloc: ptr[PyMemAllocatorEx]
) -> i32;

import from c {
    def _PyMem_GetAllocatorName(name: ptr[u8], allocator: ptr[i32]) -> i32 {
        if not name or name.view(1)[0] == u8(0) {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_DEFAULT;
        } elif strcmp(name, ptr[u8]("default")) == 0 {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_DEFAULT;
        } elif strcmp(name, ptr[u8]("debug")) == 0 {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_DEBUG;
        } elif strcmp(name, ptr[u8]("pymalloc")) == 0 {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_PYMALLOC;
        } elif strcmp(name, ptr[u8]("pymalloc_debug")) == 0 {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_PYMALLOC_DEBUG;
        } elif strcmp(name, ptr[u8]("mimalloc")) == 0 {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_MIMALLOC;
        } elif strcmp(name, ptr[u8]("mimalloc_debug")) == 0 {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_MIMALLOC_DEBUG;
        } elif strcmp(name, ptr[u8]("malloc")) == 0 {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_MALLOC;
        } elif strcmp(name, ptr[u8]("malloc_debug")) == 0 {
            allocator.view(1)[0] = PYMEM_ALLOCATOR_MALLOC_DEBUG;
        } else {
            return i32(-1);
        }
        return i32(0);
    }
}

def set_up_allocators_unlocked(allocator: i32) -> i32;

import from c {
    def _PyMem_SetupAllocators(allocator: i32) -> i32 {
        PyMutex_Lock(allocators_mutex());
        res = set_up_allocators_unlocked(allocator);
        PyMutex_Unlock(allocators_mutex());
        return res;
    }
}

def pymemallocator_eq(a: ptr[PyMemAllocatorEx], b: ptr[PyMemAllocatorEx]) -> bool;

def get_current_allocator_name_unlocked -> ptr[u8];

import from c {
    def _PyMem_GetCurrentAllocatorName -> ptr[u8] {
        PyMutex_Lock(allocators_mutex());
        name = get_current_allocator_name_unlocked();
        PyMutex_Unlock(allocators_mutex());
        return name;
    }  def _PyMem_DebugEnabled -> i32 {
        return is_debug_enabled_slot().view(1)[0];
    }
}

def _PyMem_PymallocEnabled -> i32;

def _PyMem_MimallocEnabled -> i32;

def set_up_debug_hooks_domain_unlocked(domain: i32);

def set_up_debug_hooks_unlocked;

import from c {
    def PyMem_SetupDebugHooks {
        PyMutex_Lock(allocators_mutex());
        set_up_debug_hooks_unlocked();
        PyMutex_Unlock(allocators_mutex());
    }
}

def get_allocator_unlocked(domain: i32, allocator: ptr[PyMemAllocatorEx]);

def set_allocator_unlocked(domain: i32, allocator: ptr[PyMemAllocatorEx]);

import from c {
    def PyMem_GetAllocator(domain: i32, allocator: ptr[PyMemAllocatorEx]) {
        PyMutex_Lock(allocators_mutex());
        get_allocator_unlocked(domain, allocator);
        PyMutex_Unlock(allocators_mutex());
    }  def PyMem_SetAllocator(domain: i32, allocator: ptr[PyMemAllocatorEx]) {
        PyMutex_Lock(allocators_mutex());
        set_allocator_unlocked(domain, allocator);
        PyMutex_Unlock(allocators_mutex());
    }  def PyObject_GetArenaAllocator(allocator: ptr[PyObjectArenaAllocator]) {
        PyMutex_Lock(allocators_mutex());
        memcpy(ptr(allocator), ptr(object_arena()), u64(PyObjectArenaAllocator_SIZE));
        PyMutex_Unlock(allocators_mutex());
    }  def PyObject_SetArenaAllocator(allocator: ptr[PyObjectArenaAllocator]) {
        PyMutex_Lock(allocators_mutex());
        memcpy(ptr(object_arena()), ptr(allocator), u64(PyObjectArenaAllocator_SIZE));
        PyMutex_Unlock(allocators_mutex());
    }  def _PyObject_VirtualAlloc(size: u64) -> ptr {
        arena = object_arena();
        return arena.view(1)[0].alloc(arena.view(1)[0].ctx, size);
    }  def _PyObject_VirtualFree(obj_: ptr, size: u64) {
        arena = object_arena();
        arena.view(1)[0].free(arena.view(1)[0].ctx, obj_, size);
    }  def PyMem_RawMalloc(size: u64) -> ptr {
        if size > PY_SSIZE_T_MAX_SIZE {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_RAW);
        return al.view(1)[0].malloc(al.view(1)[0].ctx, size);
    }  def PyMem_RawCalloc(nelem: u64, elsize: u64) -> ptr {
        if elsize != u64(0) and nelem > PY_SSIZE_T_MAX_SIZE // elsize {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_RAW);
        return al.view(1)[0].calloc(al.view(1)[0].ctx, nelem, elsize);
    }  def PyMem_RawRealloc(ptr_: ptr, new_size: u64) -> ptr {
        if new_size > PY_SSIZE_T_MAX_SIZE {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_RAW);
        return al.view(1)[0].realloc(al.view(1)[0].ctx, ptr_, new_size);
    }  def PyMem_RawFree(ptr_: ptr) {
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_RAW);
        al.view(1)[0].free(al.view(1)[0].ctx, ptr_);
    }  def PyMem_Malloc(size: u64) -> ptr {
        if size > PY_SSIZE_T_MAX_SIZE {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_MEM);
        return al.view(1)[0].malloc(al.view(1)[0].ctx, size);
    }  def PyMem_Calloc(nelem: u64, elsize: u64) -> ptr {
        if elsize != u64(0) and nelem > PY_SSIZE_T_MAX_SIZE // elsize {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_MEM);
        return al.view(1)[0].calloc(al.view(1)[0].ctx, nelem, elsize);
    }  def PyMem_Realloc(ptr_: ptr, new_size: u64) -> ptr {
        if new_size > PY_SSIZE_T_MAX_SIZE {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_MEM);
        return al.view(1)[0].realloc(al.view(1)[0].ctx, ptr_, new_size);
    }  def PyMem_Free(ptr_: ptr) {
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_MEM);
        al.view(1)[0].free(al.view(1)[0].ctx, ptr_);
    }  def _PyMem_RawWcsdup(str_: ptr[i32]) -> ptr[i32] {
        length = wcslen(str_);
        if length > PY_SSIZE_T_MAX_SIZE // WCHAR_SIZE - u64(1) {
            return ptr[i32]();
        }
        size = (length + u64(1)) * WCHAR_SIZE;
        str2 = ptr[i32](PyMem_RawMalloc(size));
        if not str2 {
            return ptr[i32]();
        }
        memcpy(ptr(str2), ptr(str_), size);
        return str2;
    }  def _PyMem_RawStrdup(str_: ptr[u8]) -> ptr[u8] {
        size = strlen(str_) + u64(1);
        copy = ptr[u8](PyMem_RawMalloc(size));
        if not copy {
            return ptr[u8]();
        }
        memcpy(ptr(copy), ptr(str_), size);
        return copy;
    }  def _PyMem_Strdup(str_: ptr[u8]) -> ptr[u8] {
        size = strlen(str_) + u64(1);
        copy = ptr[u8](PyMem_Malloc(size));
        if not copy {
            return ptr[u8]();
        }
        memcpy(ptr(copy), ptr(str_), size);
        return copy;
    }
}

def llist_init(head: ptr[llist_node]);

def llist_empty(head: ptr[llist_node]) -> bool;

def llist_remove(item: ptr[llist_node]);

def llist_concat(head1: ptr[llist_node], head2: ptr[llist_node]);

def thread_interp(tstate: ptr[u8]) -> ptr[u8];

def thread_qsbr(tstate: ptr[u8]) -> ptr[u8];

def work_item_at(buf: ptr[MemWorkChunk], index: i64) -> ptr[MemWorkItem];

def work_item_should_decref(ptr_: u64) -> bool;

def free_work_item(ptr_: u64, cb: ptr, state: ptr);

def free_delayed(ptr_: u64, size: u64);

import from c {
    def _PyMem_FreeDelayed(ptr_: ptr, size: u64) {
        if ptr_ {
            free_delayed(u64.wrap(int(ptr_)), size);
        }
    }
}

def work_queue_first(head: ptr[llist_node]) -> ptr[MemWorkChunk];

def process_queue(
    head: ptr[llist_node], tstate: ptr[u8], keep_empty: bool, cb: ptr, state: ptr
);

def process_interp_queue(queue: ptr[u8], tstate: ptr[u8], cb: ptr, state: ptr);

def maybe_process_interp_queue(queue: ptr[u8], tstate: ptr[u8], cb: ptr, state: ptr);

import from c {
    def _PyMem_ProcessDelayed(tstate: ptr[PyThreadState]) {
        tstate_impl = ptr[u8](tstate);
        interp = thread_interp(tstate_impl);

        qsbr = thread_qsbr(tstate_impl);
        (qsbr + _qsbr_thread_state_SHOULD_PROCESS).view(1)[0] = u8(0);

        process_queue(
            ptr[llist_node](tstate_impl + _PyThreadStateImpl_MEM_FREE_QUEUE),
            tstate_impl,
            True,
            ptr(),
            ptr()
        );

        maybe_process_interp_queue(
            interp + PyInterpreterState_MEM_FREE_QUEUE, tstate_impl, ptr(), ptr()
        );
    }  def _PyMem_ProcessDelayedNoDealloc(
        tstate: ptr[PyThreadState], cb: ptr, state: ptr
    ) {
        tstate_impl = ptr[u8](tstate);
        interp = thread_interp(tstate_impl);

        process_queue(
            ptr[llist_node](tstate_impl + _PyThreadStateImpl_MEM_FREE_QUEUE),
            tstate_impl,
            True,
            cb,
            state
        );

        maybe_process_interp_queue(
            interp + PyInterpreterState_MEM_FREE_QUEUE, tstate_impl, cb, state
        );
    }  def _PyMem_AbandonDelayed(tstate: ptr[PyThreadState]) {
        tstate_impl = ptr[u8](tstate);
        interp = thread_interp(tstate_impl);
        queue = ptr[llist_node](tstate_impl + _PyThreadStateImpl_MEM_FREE_QUEUE);
        if llist_empty(queue) {
            return;
        }

        buf = work_queue_first(queue);
        if buf.view(1)[0].rd_idx == buf.view(1)[0].wr_idx {
            llist_remove(ptr[llist_node](buf));
            PyMem_Free(ptr(buf));

            return;
        }
        interp_queue = interp + PyInterpreterState_MEM_FREE_QUEUE;
        m = ptr[PyMutex](interp_queue + _Py_mem_interp_free_queue_MUTEX);
        PyMutex_Lock(m);

        llist_concat(
            ptr[llist_node](interp_queue + _Py_mem_interp_free_queue_HEAD), queue
        );

        this_tstate = ptr[u8](PyThreadState_GetUnchecked());
        process_interp_queue(interp_queue, this_tstate, ptr(), ptr());
        PyMutex_Unlock(m);
    }  def _PyMem_FiniDelayed(interp: ptr[u8]) {
        head = ptr[llist_node](
            interp + PyInterpreterState_MEM_FREE_QUEUE + _Py_mem_interp_free_queue_HEAD
        );
        while not llist_empty(head) {
            buf = work_queue_first(head);
            rd_idx = buf.view(1)[0].rd_idx;
            if rd_idx < buf.view(1)[0].wr_idx {
                item = work_item_at(buf, rd_idx);
                buf.view(1)[0].rd_idx = rd_idx + 1;

                free_work_item(item.view(1)[0].ptr_, ptr(), ptr());
                continue;
            }
            llist_remove(ptr[llist_node](buf));
            PyMem_Free(ptr(buf));
        }
    }  def PyObject_Malloc(size: u64) -> ptr {
        if size > PY_SSIZE_T_MAX_SIZE {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
        return al.view(1)[0].malloc(al.view(1)[0].ctx, size);
    }  def PyObject_Calloc(nelem: u64, elsize: u64) -> ptr {
        if elsize != u64(0) and nelem > PY_SSIZE_T_MAX_SIZE // elsize {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
        return al.view(1)[0].calloc(al.view(1)[0].ctx, nelem, elsize);
    }  def PyObject_Realloc(ptr_: ptr, new_size: u64) -> ptr {
        if new_size > PY_SSIZE_T_MAX_SIZE {
            return ptr();
        }
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
        return al.view(1)[0].realloc(al.view(1)[0].ctx, ptr_, new_size);
    }  def PyObject_Free(ptr_: ptr) {
        al = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
        al.view(1)[0].free(al.view(1)[0].ctx, ptr_);
    }  glob:priv obmalloc_state_main: ObmallocStateStorage = ObmallocStateStorage(); obj ObmallocStatics {
        has obmalloc_state_initialized: u8,
            last_final_leaks: i64;
    }  glob:priv obmalloc_statics: ObmallocStatics = ObmallocStatics();
}

def interp_obmalloc(interp: ptr[u8]) -> ptr[ptr[u8]];

def has_own_state(interp: ptr[u8]) -> bool;

def get_state -> ptr[u8];

def om_usedpools(state: ptr[u8]) -> ptr[ptr[pool_header]];

def usedpool(state: ptr[u8], size: u32) -> ptr[pool_header];

def om_arenas(state: ptr[u8]) -> ptr[ptr[arena_object]];

def om_maxarenas(state: ptr[u8]) -> ptr[u32];

def om_unused_arena_objects(state: ptr[u8]) -> ptr[ptr[arena_object]];

def om_usable_arenas(state: ptr[u8]) -> ptr[ptr[arena_object]];

def om_nfp2lasta(state: ptr[u8]) -> ptr[ptr[arena_object]];

def om_counter(state: ptr[u8], offset: i64) -> ptr[u64];

def om_raw_allocated_blocks(state: ptr[u8]) -> ptr[i64];

def om_map_root(state: ptr[u8]) -> ptr[ptr[ptr[arena_coverage_t]]];

def om_map_count(state: ptr[u8], offset: i64) -> ptr[i32];

def pool_count(pool: ptr[pool_header]) -> u32;

def set_pool_count(pool: ptr[pool_header], count: u32);

def index2size(i: u32) -> u32;

def pool_numblocks(i: u32) -> u32;

def pool_addr(p: u64) -> ptr[pool_header];

def count_blocks(
    heap: ptr, area: ptr, block: ptr, block_size: u64, allocated_blocks: ptr
) -> u8;

def get_mimalloc_allocated_blocks(interp: ptr[u8]) -> i64;

import from c {
    def _PyInterpreterState_GetAllocatedBlocks(interp: ptr[u8]) -> i64 {
        if _PyMem_MimallocEnabled() != 0 {
            return get_mimalloc_allocated_blocks(interp);
        }
        if not has_own_state(interp) {
            _Py_FatalErrorFunc(
                ptr[u8]("_PyInterpreterState_GetAllocatedBlocks"),
                ptr[u8]("the interpreter doesn't have its own allocator")
            );
        }
        state = interp_obmalloc(interp).view(1)[0];
        if not state {
            return 0;
        }
        n = om_raw_allocated_blocks(state).view(1)[0];

        allarenas = om_arenas(state).view(1)[0];
        maxarenas = om_maxarenas(state).view(1)[0];
        i: u32 = 0;
        while i < maxarenas {
            ao = allarenas + i64(i);
            i = i + u32(1);
            address = ao.view(1)[0].address;

            if address == u64(0) {
                continue;
            }

            base = (address + POOL_SIZE_MASK) & ~POOL_SIZE_MASK;

            limit = u64.wrap(int(ao.view(1)[0].pool_address));
            while base < limit {
                n = n + i64(pool_count(ptr[pool_header](i64.wrap(base))));
                base = base + POOL_SIZE;
            }
        }
        return n;
    }
}

def interpreter_leaks(interp: ptr[u8]) -> ptr[i64];

import from c {
    def _PyInterpreterState_FinalizeAllocatedBlocks(interp: ptr[u8]) {
        if _PyMem_MimallocEnabled() != 0 {
            leaked = _PyInterpreterState_GetAllocatedBlocks(interp);
            leaks = interpreter_leaks(interp);
            leaks.view(1)[0] = leaks.view(1)[0] + leaked;
            return;
        }
        if has_own_state(interp) {
            if interp_obmalloc(interp).view(1)[0] {
                leaked = _PyInterpreterState_GetAllocatedBlocks(interp);
                leaks = interpreter_leaks(interp);
                leaks.view(1)[0] = leaks.view(1)[0] + leaked;
                if _PyMem_obmalloc_state_on_heap(interp) and leaked == 0 {
                    free_obmalloc_arenas(interp);
                }
            }
        }
    }
}

import from c {
    def _Py_FinalizeAllocatedBlocks(runtime: ptr[u8]) {
        leaks = get_num_global_allocated_blocks(runtime);
        addressof(obmalloc_statics).view(1)[0].last_final_leaks = leaks;
        ptr[i64](runtime + _PyRuntimeState_OBMALLOC_INTERPRETER_LEAKS).view(1)[0] = 0;
    }
}

def get_num_global_allocated_blocks(runtime: ptr[u8]) -> i64;

import from c {
    def _Py_GetGlobalAllocatedBlocks -> i64 {
        return get_num_global_allocated_blocks(ptr[u8](addressof(_PyRuntime)));
    }
}

def arena_map_get(state: ptr[u8], p: u64, create: bool) -> ptr[arena_coverage_t];

def arena_map_lookup(state: ptr[u8], p: u64) -> ptr[arena_coverage_t];

def arena_map_mark_used(state: ptr[u8], arena_base: u64, is_used: bool) -> i32;

def arena_map_is_used(state: ptr[u8], p: u64) -> bool;

def new_arena(state: ptr[u8]) -> ptr[arena_object];

def address_in_range(state: ptr[u8], p: u64, pool: ptr[pool_header]) -> bool;

def pymalloc_pool_extend(pool: ptr[pool_header], size: u32);

def allocate_from_new_pool(state: ptr[u8], size: u32) -> ptr[u8];

def pymalloc_alloc(state: ptr[u8], ctx: ptr, nbytes: u64) -> ptr[u8];

import from c {
    def _PyObject_Malloc(ctx: ptr, nbytes: u64) -> ptr {
        state = get_state();
        bp = pymalloc_alloc(state, ctx, nbytes);
        if bp {
            return ptr(bp);
        }
        raw = PyMem_RawMalloc(nbytes);
        if raw {
            blocks = om_raw_allocated_blocks(state);
            blocks.view(1)[0] = blocks.view(1)[0] + 1;
        }
        return raw;
    }  def _PyObject_Calloc(ctx: ptr, nelem: u64, elsize: u64) -> ptr {
        nbytes = wrapping_mul(nelem, elsize);
        state = get_state();
        bp = pymalloc_alloc(state, ctx, nbytes);
        if bp {
            memset(ptr(bp), 0, nbytes);
            return ptr(bp);
        }
        raw = PyMem_RawCalloc(nelem, elsize);
        if raw {
            blocks = om_raw_allocated_blocks(state);
            blocks.view(1)[0] = blocks.view(1)[0] + 1;
        }
        return raw;
    }
}

def insert_to_usedpool(state: ptr[u8], pool: ptr[pool_header]);

def insert_to_freepool(state: ptr[u8], pool: ptr[pool_header]);

def pymalloc_free(state: ptr[u8], ctx: ptr, p: ptr) -> bool;

import from c {
    def _PyObject_Free(ctx: ptr, p: ptr) {
        if not p {
            return;
        }
        state = get_state();
        if not pymalloc_free(state, ctx, p) {
            PyMem_RawFree(p);
            blocks = om_raw_allocated_blocks(state);
            blocks.view(1)[0] = blocks.view(1)[0] - 1;
        }
    }
}

def pymalloc_realloc(state: ptr[u8], ctx: ptr, p: ptr, nbytes: u64) -> tuple[i32, ptr];

import from c {
    def _PyObject_Realloc(ctx: ptr, ptr_: ptr, nbytes: u64) -> ptr {
        if not ptr_ {
            return _PyObject_Malloc(ctx, nbytes);
        }
        state = get_state();
        (done, ptr2) = pymalloc_realloc(state, ctx, ptr_, nbytes);
        if done != i32(0) {
            return ptr2;
        }
        return PyMem_RawRealloc(ptr_, nbytes);
    }
}

def read_size_t(p: ptr[u8]) -> u64;

def write_size_t(p: ptr[u8], n: u64);

def fill_mem_debug(api: ptr[u8], data: ptr[u8], c: i32, nbytes: u64, is_alloc: bool);

def _PyMem_DebugRawAlloc(use_calloc: bool, ctx: ptr, nbytes: u64) -> ptr;

def _PyMem_DebugCheckGIL(func: ptr[u8]);

import from c {
    def _PyMem_DebugRawMalloc(ctx: ptr, nbytes: u64) -> ptr {
        return _PyMem_DebugRawAlloc(False, ctx, nbytes);
    }  def _PyMem_DebugRawCalloc(ctx: ptr, nelem: u64, elsize: u64) -> ptr {
        return _PyMem_DebugRawAlloc(True, ctx, wrapping_mul(nelem, elsize));
    }  def _PyMem_DebugRawFree(ctx: ptr, p: ptr) {
        if not p {
            return;
        }
        api = ptr[u8](ctx);
        al = debug_api_alloc(api);

        q = ptr[u8](p) - 2 * SST;
        _PyMem_DebugCheckAddress(ptr[u8]("_PyMem_DebugRawFree"), api.view(1)[0], p);
        nbytes = read_size_t(q) + (PYMEM_DEBUG_EXTRA_BYTES - u64(2 * SST));
        memset(ptr(q), PYMEM_DEADBYTE, u64(2 * SST));
        fill_mem_debug(api, ptr[u8](p), PYMEM_DEADBYTE, nbytes, False);
        al.view(1)[0].free(al.view(1)[0].ctx, ptr(q));
    }  def _PyMem_DebugRawRealloc(ctx: ptr, p: ptr, nbytes: u64) -> ptr {
        if not p {
            return _PyMem_DebugRawAlloc(False, ctx, nbytes);
        }
        api = ptr[u8](ctx);
        al = debug_api_alloc(api);
        _PyMem_DebugCheckAddress(ptr[u8]("_PyMem_DebugRawRealloc"), api.view(1)[0], p);
        data = ptr[u8](p);

        head = data - 2 * SST;
        original_nbytes = read_size_t(head);
        if nbytes > PY_SSIZE_T_MAX_SIZE - PYMEM_DEBUG_EXTRA_BYTES {
            return ptr();
        }
        total = nbytes + PYMEM_DEBUG_EXTRA_BYTES;
        tail = data + i64.wrap(original_nbytes);

        save_slots: own ObmallocStack = ObmallocStack();
        save = ptr[u8](jacpy_stack_address(&mut save_slots));
        save_size = u64(2 * ERASED_SIZE);
        if original_nbytes <= save_size {
            memcpy(ptr(save), ptr(data), original_nbytes);
            memset(
                ptr(data - 2 * SST),
                PYMEM_DEADBYTE,
                original_nbytes + PYMEM_DEBUG_EXTRA_BYTES
            );
        } else {
            memcpy(ptr(save), ptr(data), u64(ERASED_SIZE));
            memset(ptr(head), PYMEM_DEADBYTE, u64(ERASED_SIZE + 2 * SST));
            memcpy(ptr(save + ERASED_SIZE), ptr(tail - ERASED_SIZE), u64(ERASED_SIZE));
            memset(
                ptr(tail - ERASED_SIZE),
                PYMEM_DEADBYTE,
                u64(ERASED_SIZE) + PYMEM_DEBUG_EXTRA_BYTES - u64(2 * SST)
            );
        }

        r = ptr[u8](al.view(1)[0].realloc(al.view(1)[0].ctx, ptr(head), total));
        new_nbytes = nbytes;
        if not r {
            new_nbytes = original_nbytes;
        } else {
            head = r;
        }
        data = head + 2 * SST;
        write_size_t(head, new_nbytes);
        (head + SST).view(1)[0] = api.view(1)[0];
        memset(ptr(head + SST + 1), PYMEM_FORBIDDENBYTE, u64(SST - 1));
        tail = data + i64.wrap(new_nbytes);
        memset(ptr(tail), PYMEM_FORBIDDENBYTE, u64(SST));

        if original_nbytes <= save_size {
            restored = new_nbytes if new_nbytes < original_nbytes else original_nbytes;
            memcpy(ptr(data), ptr(save), restored);
        } else {
            i = original_nbytes - u64(ERASED_SIZE);
            first = new_nbytes if new_nbytes < u64(ERASED_SIZE) else u64(ERASED_SIZE);
            memcpy(ptr(data), ptr(save), first);
            if new_nbytes > i {
                rest = new_nbytes - i;
                last = rest if rest < u64(ERASED_SIZE) else u64(ERASED_SIZE);
                memcpy(ptr(data + i64.wrap(i)), ptr(save + ERASED_SIZE), last);
            }
        }
        if not r {
            return ptr();
        }
        if new_nbytes > original_nbytes {
            memset(
                ptr(data + i64.wrap(original_nbytes)),
                PYMEM_CLEANBYTE,
                new_nbytes - original_nbytes
            );
        }
        return ptr(data);
    }  def _PyMem_DebugMalloc(ctx: ptr, nbytes: u64) -> ptr {
        _PyMem_DebugCheckGIL(ptr[u8]("_PyMem_DebugMalloc"));
        return _PyMem_DebugRawMalloc(ctx, nbytes);
    }  def _PyMem_DebugCalloc(ctx: ptr, nelem: u64, elsize: u64) -> ptr {
        _PyMem_DebugCheckGIL(ptr[u8]("_PyMem_DebugCalloc"));
        return _PyMem_DebugRawCalloc(ctx, nelem, elsize);
    }  def _PyMem_DebugFree(ctx: ptr, ptr_: ptr) {
        _PyMem_DebugCheckGIL(ptr[u8]("_PyMem_DebugFree"));
        _PyMem_DebugRawFree(ctx, ptr_);
    }  def _PyMem_DebugRealloc(ctx: ptr, ptr_: ptr, nbytes: u64) -> ptr {
        _PyMem_DebugCheckGIL(ptr[u8]("_PyMem_DebugRealloc"));
        return _PyMem_DebugRawRealloc(ctx, ptr_, nbytes);
    }
}

def _PyMem_DebugCheckAddress(func: ptr[u8], api: u8, p: ptr);

def _PyObject_DebugDumpAddress(p: ptr);

def printone(out: ptr, msg: ptr[u8], value: u64) -> u64;

import from c {
    def _PyDebugAllocatorStats(
        out: ptr, block_name: ptr[u8], num_blocks: i32, sizeof_block: u64
    ) {
        slots1: own ObmallocStack = ObmallocStack();
        slots2: own ObmallocStack = ObmallocStack();
        buf1 = ptr[u8](jacpy_stack_address(&mut slots1));
        buf2 = ptr[u8](jacpy_stack_address(&mut slots2));
        PyOS_snprintf(
            buf1,
            u64(128),
            ptr[u8]("%d %ss * %zd bytes each"),
            num_blocks,
            block_name,
            i64.wrap(sizeof_block)
        );
        PyOS_snprintf(buf2, u64(128), ptr[u8]("%48s "), buf1);
        printone(out, buf2, wrapping_mul(u64.wrap(i64(num_blocks)), sizeof_block));
    }  def _PyMem_obmalloc_state_on_heap(interp: ptr[u8]) -> bool {
        state = interp_obmalloc(interp).view(1)[0];
        if not state {
            return False;
        }
        return state != ptr[u8](addressof(obmalloc_state_main));
    }
}

def init_obmalloc_pools(interp: ptr[u8]);

import from c {
    def _PyMem_init_obmalloc(interp: ptr[u8]) -> i32 {
        slot = interp_obmalloc(interp);
        if interp == ptr[u8](_PyInterpreterState_Main())
            or _PyInterpreterState_HasFeature(
                ptr[PyInterpreterState](interp), Py_RTFLAGS_USE_MAIN_OBMALLOC
            )
                != 0 {
            slot.view(1)[0] = ptr[u8](addressof(obmalloc_state_main));
            statics = addressof(obmalloc_statics);
            if statics.view(1)[0].obmalloc_state_initialized == u8(0) {
                init_obmalloc_pools(interp);
                statics.view(1)[0].obmalloc_state_initialized = u8(1);
            }
        } else {
            state = ptr[u8](PyMem_RawCalloc(u64(1), u64(_obmalloc_state_SIZE)));
            if not state {
                return i32(-1);
            }
            slot.view(1)[0] = state;
            init_obmalloc_pools(interp);
        }

        return i32(0);
    }
}

def free_obmalloc_arenas(interp: ptr[u8]);

def _collect_alloc_stats(
    heap: ptr, area: ptr, block: ptr, block_size: u64, arg: ptr
) -> u8;

def py_mimalloc_print_stats(out: ptr);

def pymalloc_print_stats(out: ptr);

import from c {
    def _PyObject_DebugMallocStats(out: ptr) -> i32 {
        if _PyMem_MimallocEnabled() != 0 {
            py_mimalloc_print_stats(out);
            return i32(1);
        }
        if _PyMem_PymallocEnabled() != 0 {
            pymalloc_print_stats(out);
            return i32(1);
        }
        return i32(0);
    }
}

impl runtime_field(offset: i64) -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + offset;
}

impl runtime_allocator(offset: i64) -> ptr[PyMemAllocatorEx] {
    return ptr[PyMemAllocatorEx](ptr[u8](addressof(_PyRuntime)) + offset);
}

impl allocators_mutex -> ptr[PyMutex] {
    return ptr[PyMutex](runtime_field(_PyRuntimeState_ALLOCATORS_MUTEX));
}

impl debug_api_alloc(api: ptr[u8]) -> ptr[PyMemAllocatorEx] {
    return ptr[PyMemAllocatorEx](api + debug_alloc_api_t_ALLOC);
}

impl object_arena -> ptr[PyObjectArenaAllocator] {
    return ptr[PyObjectArenaAllocator](
        runtime_field(_PyRuntimeState_ALLOCATORS_OBJ_ARENA)
    );
}

impl is_debug_enabled_slot -> ptr[i32] {
    return ptr[i32](runtime_field(_PyRuntimeState_ALLOCATORS_IS_DEBUG_ENABLED));
}

impl domain_allocator(domain: i32) -> ptr[PyMemAllocatorEx] {
    if domain == PYMEM_DOMAIN_RAW {
        return runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_RAW);
    } elif domain == PYMEM_DOMAIN_MEM {
        return runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_MEM);
    } elif domain == PYMEM_DOMAIN_OBJ {
        return runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
    }
    return ptr[PyMemAllocatorEx]();
}

impl fill_debug_allocator(alloc: ptr[PyMemAllocatorEx], api: ptr[u8], is_raw: bool) {
    alloc.view(1)[0].ctx = ptr(api);
    if is_raw {
        alloc.view(1)[0].malloc = _PyMem_DebugRawMalloc;
        alloc.view(1)[0].calloc = _PyMem_DebugRawCalloc;
        alloc.view(1)[0].realloc = _PyMem_DebugRawRealloc;
        alloc.view(1)[0].free = _PyMem_DebugRawFree;
    } else {
        alloc.view(1)[0].malloc = _PyMem_DebugMalloc;
        alloc.view(1)[0].calloc = _PyMem_DebugCalloc;
        alloc.view(1)[0].realloc = _PyMem_DebugRealloc;
        alloc.view(1)[0].free = _PyMem_DebugFree;
    }
}

impl set_default_allocator_unlocked(
    domain: i32, debug: i32, old_alloc: ptr[PyMemAllocatorEx]
) -> i32 {
    if old_alloc {
        get_allocator_unlocked(domain, old_alloc);
    }
    new_alloc = ptr[PyMemAllocatorEx]();
    if domain == PYMEM_DOMAIN_RAW {
        new_alloc = addressof(MALLOC_ALLOC);
    } elif domain == PYMEM_DOMAIN_MEM {
        new_alloc = addressof(PYMALLOC_ALLOC);
    } elif domain == PYMEM_DOMAIN_OBJ {
        new_alloc = addressof(PYMALLOC_ALLOC);
    } else {
        return i32(-1);
    }
    set_allocator_unlocked(domain, new_alloc);
    if debug != 0 {
        set_up_debug_hooks_domain_unlocked(domain);
    }
    return i32(0);
}

impl set_up_allocators_unlocked(allocator: i32) -> i32 {
    if allocator == PYMEM_ALLOCATOR_NOT_SET {
        return i32(0);
    }
    if allocator == PYMEM_ALLOCATOR_DEFAULT {
        set_default_allocator_unlocked(
            PYMEM_DOMAIN_RAW, pydebug, ptr[PyMemAllocatorEx]()
        );
        set_default_allocator_unlocked(
            PYMEM_DOMAIN_MEM, pydebug, ptr[PyMemAllocatorEx]()
        );
        set_default_allocator_unlocked(
            PYMEM_DOMAIN_OBJ, pydebug, ptr[PyMemAllocatorEx]()
        );
        is_debug_enabled_slot().view(1)[0] = pydebug;
    } elif allocator == PYMEM_ALLOCATOR_DEBUG {
        set_default_allocator_unlocked(
            PYMEM_DOMAIN_RAW, i32(1), ptr[PyMemAllocatorEx]()
        );
        set_default_allocator_unlocked(
            PYMEM_DOMAIN_MEM, i32(1), ptr[PyMemAllocatorEx]()
        );
        set_default_allocator_unlocked(
            PYMEM_DOMAIN_OBJ, i32(1), ptr[PyMemAllocatorEx]()
        );
        is_debug_enabled_slot().view(1)[0] = i32(1);
    } elif allocator == PYMEM_ALLOCATOR_PYMALLOC
        or allocator == PYMEM_ALLOCATOR_PYMALLOC_DEBUG {
        set_allocator_unlocked(PYMEM_DOMAIN_RAW, addressof(MALLOC_ALLOC));
        set_allocator_unlocked(PYMEM_DOMAIN_MEM, addressof(PYMALLOC_ALLOC));
        set_allocator_unlocked(PYMEM_DOMAIN_OBJ, addressof(PYMALLOC_ALLOC));
        if allocator == PYMEM_ALLOCATOR_PYMALLOC_DEBUG {
            is_debug_enabled_slot().view(1)[0] = i32(1);
            set_up_debug_hooks_unlocked();
        } else {
            is_debug_enabled_slot().view(1)[0] = i32(0);
        }
    } elif allocator == PYMEM_ALLOCATOR_MIMALLOC
        or allocator == PYMEM_ALLOCATOR_MIMALLOC_DEBUG {
        set_allocator_unlocked(PYMEM_DOMAIN_RAW, addressof(MALLOC_ALLOC));
        set_allocator_unlocked(PYMEM_DOMAIN_MEM, addressof(MIMALLOC_ALLOC));
        set_allocator_unlocked(PYMEM_DOMAIN_OBJ, addressof(MIMALLOC_OBJALLOC));
        if allocator == PYMEM_ALLOCATOR_MIMALLOC_DEBUG {
            is_debug_enabled_slot().view(1)[0] = i32(1);
            set_up_debug_hooks_unlocked();
        } else {
            is_debug_enabled_slot().view(1)[0] = i32(0);
        }
    } elif allocator == PYMEM_ALLOCATOR_MALLOC
        or allocator == PYMEM_ALLOCATOR_MALLOC_DEBUG {
        set_allocator_unlocked(PYMEM_DOMAIN_RAW, addressof(MALLOC_ALLOC));
        set_allocator_unlocked(PYMEM_DOMAIN_MEM, addressof(MALLOC_ALLOC));
        set_allocator_unlocked(PYMEM_DOMAIN_OBJ, addressof(MALLOC_ALLOC));
        if allocator == PYMEM_ALLOCATOR_MALLOC_DEBUG {
            is_debug_enabled_slot().view(1)[0] = i32(1);
            set_up_debug_hooks_unlocked();
        } else {
            is_debug_enabled_slot().view(1)[0] = i32(0);
        }
    } else {
        return i32(-1);
    }
    return i32(0);
}

impl pymemallocator_eq(a: ptr[PyMemAllocatorEx], b: ptr[PyMemAllocatorEx]) -> bool {
    return memcmp(ptr(a), ptr(b), u64(PyMemAllocatorEx_SIZE)) == 0;
}

impl get_current_allocator_name_unlocked -> ptr[u8] {
    raw = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_RAW);
    mem = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_MEM);
    objalloc = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
    malloc_alloc = addressof(MALLOC_ALLOC);
    pymalloc = addressof(PYMALLOC_ALLOC);
    mimalloc = addressof(MIMALLOC_ALLOC);
    mimalloc_obj = addressof(MIMALLOC_OBJALLOC);
    if pymemallocator_eq(raw, malloc_alloc)
        and pymemallocator_eq(mem, malloc_alloc)
        and pymemallocator_eq(objalloc, malloc_alloc) {
        return ptr[u8]("malloc");
    }
    if pymemallocator_eq(raw, malloc_alloc)
        and pymemallocator_eq(mem, pymalloc)
        and pymemallocator_eq(objalloc, pymalloc) {
        return ptr[u8]("pymalloc");
    }
    if pymemallocator_eq(raw, malloc_alloc)
        and pymemallocator_eq(mem, mimalloc)
        and pymemallocator_eq(objalloc, mimalloc_obj) {
        return ptr[u8]("mimalloc");
    }

    slots: own ObmallocStack = ObmallocStack();
    tables = ptr[u8](jacpy_stack_address(&mut slots));
    dbg_raw = ptr[PyMemAllocatorEx](tables);
    dbg_mem = ptr[PyMemAllocatorEx](tables + PyMemAllocatorEx_SIZE);
    dbg_obj = ptr[PyMemAllocatorEx](tables + 2 * PyMemAllocatorEx_SIZE);
    api_raw = runtime_field(_PyRuntimeState_ALLOCATORS_DEBUG_RAW);
    api_mem = runtime_field(_PyRuntimeState_ALLOCATORS_DEBUG_MEM);
    api_obj = runtime_field(_PyRuntimeState_ALLOCATORS_DEBUG_OBJ);
    fill_debug_allocator(dbg_raw, api_raw, True);
    fill_debug_allocator(dbg_mem, api_mem, False);
    fill_debug_allocator(dbg_obj, api_obj, False);
    if pymemallocator_eq(raw, dbg_raw)
        and pymemallocator_eq(mem, dbg_mem)
        and pymemallocator_eq(objalloc, dbg_obj) {
        under_raw = debug_api_alloc(api_raw);
        under_mem = debug_api_alloc(api_mem);
        under_obj = debug_api_alloc(api_obj);
        if pymemallocator_eq(under_raw, malloc_alloc)
            and pymemallocator_eq(under_mem, malloc_alloc)
            and pymemallocator_eq(under_obj, malloc_alloc) {
            return ptr[u8]("malloc_debug");
        }
        if pymemallocator_eq(under_raw, malloc_alloc)
            and pymemallocator_eq(under_mem, pymalloc)
            and pymemallocator_eq(under_obj, pymalloc) {
            return ptr[u8]("pymalloc_debug");
        }
        if pymemallocator_eq(under_raw, malloc_alloc)
            and pymemallocator_eq(under_mem, mimalloc)
            and pymemallocator_eq(under_obj, mimalloc_obj) {
            return ptr[u8]("mimalloc_debug");
        }
    }
    return ptr[u8]();
}

impl _PyMem_PymallocEnabled -> i32 {
    if _PyMem_DebugEnabled() != 0 {
        dbg = debug_api_alloc(runtime_field(_PyRuntimeState_ALLOCATORS_DEBUG_OBJ));
        if int(dbg.view(1)[0].malloc) == int(ptr(_PyObject_Malloc)) {
            return i32(1);
        }
        return i32(0);
    }
    objalloc = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
    if int(objalloc.view(1)[0].malloc) == int(ptr(_PyObject_Malloc)) {
        return i32(1);
    }
    return i32(0);
}

impl _PyMem_MimallocEnabled -> i32 {
    if _PyMem_DebugEnabled() != 0 {
        dbg = debug_api_alloc(runtime_field(_PyRuntimeState_ALLOCATORS_DEBUG_OBJ));
        if int(dbg.view(1)[0].malloc) == int(ptr(_PyObject_MiMalloc)) {
            return i32(1);
        }
        return i32(0);
    }
    objalloc = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
    if int(objalloc.view(1)[0].malloc) == int(ptr(_PyObject_MiMalloc)) {
        return i32(1);
    }
    return i32(0);
}

impl set_up_debug_hooks_domain_unlocked(domain: i32) {
    if domain == PYMEM_DOMAIN_RAW {
        std_raw = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_RAW);
        if int(std_raw.view(1)[0].malloc) == int(ptr(_PyMem_DebugRawMalloc)) {
            return;
        }
        api = runtime_field(_PyRuntimeState_ALLOCATORS_DEBUG_RAW);
        get_allocator_unlocked(domain, debug_api_alloc(api));
        fill_debug_allocator(std_raw, api, True);
    } elif domain == PYMEM_DOMAIN_MEM {
        std_mem = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_MEM);
        if int(std_mem.view(1)[0].malloc) == int(ptr(_PyMem_DebugMalloc)) {
            return;
        }
        api = runtime_field(_PyRuntimeState_ALLOCATORS_DEBUG_MEM);
        get_allocator_unlocked(domain, debug_api_alloc(api));
        fill_debug_allocator(std_mem, api, False);
    } elif domain == PYMEM_DOMAIN_OBJ {
        std_obj = runtime_allocator(_PyRuntimeState_ALLOCATORS_STANDARD_OBJ);
        if int(std_obj.view(1)[0].malloc) == int(ptr(_PyMem_DebugMalloc)) {
            return;
        }
        api = runtime_field(_PyRuntimeState_ALLOCATORS_DEBUG_OBJ);
        get_allocator_unlocked(domain, debug_api_alloc(api));
        fill_debug_allocator(std_obj, api, False);
    }
}

impl set_up_debug_hooks_unlocked {
    set_up_debug_hooks_domain_unlocked(PYMEM_DOMAIN_RAW);
    set_up_debug_hooks_domain_unlocked(PYMEM_DOMAIN_MEM);
    set_up_debug_hooks_domain_unlocked(PYMEM_DOMAIN_OBJ);
    is_debug_enabled_slot().view(1)[0] = i32(1);
}

impl get_allocator_unlocked(domain: i32, allocator: ptr[PyMemAllocatorEx]) {
    current = domain_allocator(domain);
    if current {
        memcpy(ptr(allocator), ptr(current), u64(PyMemAllocatorEx_SIZE));
    } else {
        memset(ptr(allocator), 0, u64(PyMemAllocatorEx_SIZE));
    }
}

impl set_allocator_unlocked(domain: i32, allocator: ptr[PyMemAllocatorEx]) {
    current = domain_allocator(domain);

    if current {
        memcpy(ptr(current), ptr(allocator), u64(PyMemAllocatorEx_SIZE));
    }
}

impl llist_init(head: ptr[llist_node]) {
    head.view(1)[0].next = head;
    head.view(1)[0].prev = head;
}

impl llist_empty(head: ptr[llist_node]) -> bool {
    return head.view(1)[0].next == head;
}

impl llist_remove(item: ptr[llist_node]) {
    prev = item.view(1)[0].prev;
    nxt = item.view(1)[0].next;
    prev.view(1)[0].next = nxt;
    nxt.view(1)[0].prev = prev;
    item.view(1)[0].prev = ptr[llist_node]();
    item.view(1)[0].next = ptr[llist_node]();
}

impl llist_concat(head1: ptr[llist_node], head2: ptr[llist_node]) {
    if not llist_empty(head2) {
        head1.view(1)[0].prev.view(1)[0].next = head2.view(1)[0].next;
        head2.view(1)[0].next.view(1)[0].prev = head1.view(1)[0].prev;
        head1.view(1)[0].prev = head2.view(1)[0].prev;
        head2.view(1)[0].prev.view(1)[0].next = head1;
        llist_init(head2);
    }
}

impl thread_interp(tstate: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](tstate + PyThreadState_INTERP).view(1)[0];
}

impl thread_qsbr(tstate: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](tstate + _PyThreadStateImpl_QSBR).view(1)[0];
}

impl work_item_at(buf: ptr[MemWorkChunk], index: i64) -> ptr[MemWorkItem] {
    return ptr[MemWorkItem](ptr[u8](buf) + MEM_WORK_CHUNK_ARRAY) + index;
}

impl work_item_should_decref(ptr_: u64) -> bool {
    return (ptr_ & u64(1)) != u64(0);
}

impl free_work_item(ptr_: u64, cb: ptr, state: ptr) {
    if work_item_should_decref(ptr_) {
        object_decref(ptr[PyObject](i64.wrap(ptr_ - u64(1))));
    } else {
        PyMem_Free(ptr(ptr[u8](i64.wrap(ptr_))));
    }
}

impl free_delayed(ptr_: u64, size: u64) {
    free_work_item(ptr_, ptr(), ptr());
}

impl work_queue_first(head: ptr[llist_node]) -> ptr[MemWorkChunk] {
    return ptr[MemWorkChunk](head.view(1)[0].next);
}

impl process_queue(
    head: ptr[llist_node], tstate: ptr[u8], keep_empty: bool, cb: ptr, state: ptr
) {
    while not llist_empty(head) {
        buf = work_queue_first(head);
        rd_idx = buf.view(1)[0].rd_idx;
        if rd_idx < buf.view(1)[0].wr_idx {
            item = work_item_at(buf, rd_idx);
            if not _Py_qsbr_poll(thread_qsbr(tstate), item.view(1)[0].qsbr_goal) {
                return;
            }
            buf.view(1)[0].rd_idx = rd_idx + 1;

            free_work_item(item.view(1)[0].ptr_, cb, state);
            continue;
        }

        if keep_empty and buf.view(1)[0].node_next == head {
            buf.view(1)[0].rd_idx = 0;
            buf.view(1)[0].wr_idx = 0;
            return;
        }
        llist_remove(ptr[llist_node](buf));
        PyMem_Free(ptr(buf));
    }
}

impl process_interp_queue(queue: ptr[u8], tstate: ptr[u8], cb: ptr, state: ptr) {
    head = ptr[llist_node](queue + _Py_mem_interp_free_queue_HEAD);
    process_queue(head, tstate, False, cb, state);
    more_work = i32(0) if llist_empty(head) else i32(1);
    ptr[i32](queue + _Py_mem_interp_free_queue_HAS_WORK).view(1)[0] = more_work;
}

impl maybe_process_interp_queue(queue: ptr[u8], tstate: ptr[u8], cb: ptr, state: ptr) {
    if ptr[i32](queue + _Py_mem_interp_free_queue_HAS_WORK).view(1)[0] == 0 {
        return;
    }

    m = ptr[PyMutex](queue + _Py_mem_interp_free_queue_MUTEX);
    if _PyMutex_LockTimed(m, i64(0), i32(0)) == PY_LOCK_ACQUIRED {
        process_interp_queue(queue, tstate, cb, state);
        PyMutex_Unlock(m);
    }
}

impl interp_obmalloc(interp: ptr[u8]) -> ptr[ptr[u8]] {
    return ptr[ptr[u8]](interp + PyInterpreterState_OBMALLOC);
}

impl has_own_state(interp: ptr[u8]) -> bool {
    if interp == ptr[u8](_PyInterpreterState_Main()) {
        return True;
    }
    flags = ptr[u64](interp + PyInterpreterState_FEATURE_FLAGS).view(1)[0];
    if (flags & Py_RTFLAGS_USE_MAIN_OBMALLOC) == u64(0) {
        return True;
    }
    return _Py_IsMainInterpreterFinalizing(interp) != 0;
}

impl get_state -> ptr[u8] {
    tstate = ptr[u8](PyThreadState_GetUnchecked());
    interp = ptr[ptr[u8]](tstate + PyThreadState_INTERP).view(1)[0];
    return ptr[ptr[u8]](interp + PyInterpreterState_OBMALLOC).view(1)[0];
}

impl om_usedpools(state: ptr[u8]) -> ptr[ptr[pool_header]] {
    return ptr[ptr[pool_header]](state + _obmalloc_state_POOLS_USED);
}

impl usedpool(state: ptr[u8], size: u32) -> ptr[pool_header] {
    return (
        ptr[ptr[pool_header]](state + _obmalloc_state_POOLS_USED)
        + i64(wrapping_add(size, size))
    ).view(
        1
    )[0];
}

impl om_arenas(state: ptr[u8]) -> ptr[ptr[arena_object]] {
    return ptr[ptr[arena_object]](state + _obmalloc_state_MGMT_ARENAS);
}

impl om_maxarenas(state: ptr[u8]) -> ptr[u32] {
    return ptr[u32](state + _obmalloc_state_MGMT_MAXARENAS);
}

impl om_unused_arena_objects(state: ptr[u8]) -> ptr[ptr[arena_object]] {
    return ptr[ptr[arena_object]](state + _obmalloc_state_MGMT_UNUSED_ARENA_OBJECTS);
}

impl om_usable_arenas(state: ptr[u8]) -> ptr[ptr[arena_object]] {
    return ptr[ptr[arena_object]](state + _obmalloc_state_MGMT_USABLE_ARENAS);
}

impl om_nfp2lasta(state: ptr[u8]) -> ptr[ptr[arena_object]] {
    return ptr[ptr[arena_object]](state + _obmalloc_state_MGMT_NFP2LASTA);
}

impl om_counter(state: ptr[u8], offset: i64) -> ptr[u64] {
    return ptr[u64](state + offset);
}

impl om_raw_allocated_blocks(state: ptr[u8]) -> ptr[i64] {
    return ptr[i64](state + _obmalloc_state_MGMT_RAW_ALLOCATED_BLOCKS);
}

impl om_map_root(state: ptr[u8]) -> ptr[ptr[ptr[arena_coverage_t]]] {
    return ptr[ptr[ptr[arena_coverage_t]]](
        state + _obmalloc_state_USAGE_ARENA_MAP_ROOT
    );
}

impl om_map_count(state: ptr[u8], offset: i64) -> ptr[i32] {
    return ptr[i32](state + offset);
}

impl pool_count(pool: ptr[pool_header]) -> u32 {
    return ptr[u32](ptr[u8](pool) + pool_header_REF_COUNT).view(1)[0];
}

impl set_pool_count(pool: ptr[pool_header], count: u32) {
    ptr[u32](ptr[u8](pool) + pool_header_REF_COUNT).view(1)[0] = count;
}

impl index2size(i: u32) -> u32 {
    return wrapping_shl(wrapping_add(i, u32(1)), ALIGNMENT_SHIFT);
}

impl pool_numblocks(i: u32) -> u32 {
    return (u32.wrap(POOL_SIZE) - POOL_OVERHEAD) // index2size(i);
}

impl pool_addr(p: u64) -> ptr[pool_header] {
    return ptr[pool_header](i64.wrap(p & ~POOL_SIZE_MASK));
}

impl count_blocks(
    heap: ptr, area: ptr, block: ptr, block_size: u64, allocated_blocks: ptr
) -> u8 {
    counter = ptr[u64](allocated_blocks);
    used = ptr[u64](ptr[u8](area) + mi_heap_area_t_USED).view(1)[0];
    counter.view(1)[0] = counter.view(1)[0] + used;
    return u8(1);
}

impl get_mimalloc_allocated_blocks(interp: ptr[u8]) -> i64 {
    slots: own ObmallocStack = ObmallocStack();
    allocated_blocks = ptr[u64](jacpy_stack_address(&mut slots));
    heap = mi_heap_get_default();
    mi_heap_visit_blocks(heap, False, ptr(count_blocks), ptr(allocated_blocks));
    return i64.wrap(allocated_blocks.view(1)[0]);
}

impl interpreter_leaks(interp: ptr[u8]) -> ptr[i64] {
    runtime = ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
    return ptr[i64](runtime + _PyRuntimeState_OBMALLOC_INTERPRETER_LEAKS);
}

impl get_num_global_allocated_blocks(runtime: ptr[u8]) -> i64 {
    total: i64 = 0;

    if ptr[ptr[u8]](runtime + _PyRuntimeState_FINALIZING).view(1)[0] {
        interp = ptr[u8](_PyInterpreterState_Main());

        if interp {
            total = total + _PyInterpreterState_GetAllocatedBlocks(interp);
        }
    } else {
        _PyEval_StopTheWorldAll(addressof(_PyRuntime));
        head_mutex = ptr[PyMutex](runtime + _PyRuntimeState_INTERPRETERS_MUTEX);
        _PyMutex_LockTimed(head_mutex, i64(-1), _Py_LOCK_DONT_DETACH);
        interp = PyInterpreterState_Head();
        while interp {
            if has_own_state(interp) {
                total = total + _PyInterpreterState_GetAllocatedBlocks(interp);
            }
            interp = PyInterpreterState_Next(interp);
        }
        PyMutex_Unlock(head_mutex);
        _PyEval_StartTheWorldAll(addressof(_PyRuntime));
    }
    total = total
        + ptr[i64](runtime + _PyRuntimeState_OBMALLOC_INTERPRETER_LEAKS).view(1)[0];
    total = total + addressof(obmalloc_statics).view(1)[0].last_final_leaks;
    return total;
}

impl arena_map_get(state: ptr[u8], p: u64, create: bool) -> ptr[arena_coverage_t] {
    top = om_map_root(state) + i64.wrap((p >> MAP_TOP_SHIFT) & MAP_TOP_MASK);
    if not top.view(1)[0] {
        if not create {
            return ptr[arena_coverage_t]();
        }
        n = ptr[ptr[arena_coverage_t]](
            PyMem_RawCalloc(u64(1), u64(arena_map_mid_t_SIZE))
        );
        if not n {
            return ptr[arena_coverage_t]();
        }
        top.view(1)[0] = n;
        mid_count = om_map_count(state, _obmalloc_state_USAGE_ARENA_MAP_MID_COUNT);
        mid_count.view(1)[0] = mid_count.view(1)[0] + i32(1);
    }
    mid = top.view(1)[0] + i64.wrap((p >> MAP_MID_SHIFT) & MAP_MID_MASK);
    if not mid.view(1)[0] {
        if not create {
            return ptr[arena_coverage_t]();
        }
        bot = ptr[arena_coverage_t](PyMem_RawCalloc(u64(1), u64(arena_map_bot_t_SIZE)));
        if not bot {
            return ptr[arena_coverage_t]();
        }
        mid.view(1)[0] = bot;
        bot_count = om_map_count(state, _obmalloc_state_USAGE_ARENA_MAP_BOT_COUNT);
        bot_count.view(1)[0] = bot_count.view(1)[0] + i32(1);
    }
    return mid.view(1)[0];
}

impl arena_map_lookup(state: ptr[u8], p: u64) -> ptr[arena_coverage_t] {
    mid = (om_map_root(state) + i64.wrap((p >> MAP_TOP_SHIFT) & MAP_TOP_MASK)).view(1)[
        0
    ];
    if not mid {
        return ptr[arena_coverage_t]();
    }
    return (mid + i64.wrap((p >> MAP_MID_SHIFT) & MAP_MID_MASK)).view(1)[0];
}

impl arena_map_mark_used(state: ptr[u8], arena_base: u64, is_used: bool) -> i32 {
    n_hi = arena_map_get(state, arena_base, is_used);
    if not n_hi {
        return i32(0);
    }
    i3 = i64.wrap((arena_base >> MAP_BOT_SHIFT) & MAP_BOT_MASK);
    tail = i32.wrap(arena_base & ARENA_SIZE_MASK);
    hi = n_hi + i3;
    if tail == i32(0) {
        hi.view(1)[0].tail_hi = i32(-1) if is_used else i32(0);
    } else {
        hi.view(1)[0].tail_hi = tail if is_used else i32(0);
        arena_base_next = wrapping_add(arena_base, ARENA_SIZE);
        n_lo = arena_map_get(state, arena_base_next, is_used);
        if not n_lo {
            hi.view(1)[0].tail_hi = i32(0);

            return i32(0);
        }
        i3_next = i64.wrap((arena_base_next >> MAP_BOT_SHIFT) & MAP_BOT_MASK);
        (n_lo + i3_next).view(1)[0].tail_lo = tail if is_used else i32(0);
    }
    return i32(1);
}

impl arena_map_is_used(state: ptr[u8], p: u64) -> bool {
    n = arena_map_lookup(state, p);
    if not n {
        return False;
    }
    coverage = n + i64.wrap((p >> MAP_BOT_SHIFT) & MAP_BOT_MASK);

    hi = coverage.view(1)[0].tail_hi;
    lo = coverage.view(1)[0].tail_lo;
    tail = i32.wrap(p & ARENA_SIZE_MASK);
    return tail < lo or (tail >= hi and hi != i32(0));
}

impl new_arena(state: ptr[u8]) -> ptr[arena_object] {
    stats_slot = ptr[i32](runtime_field(_PyRuntimeState_OBMALLOC_DUMP_DEBUG_STATS));
    debug_stats = stats_slot.view(1)[0];
    if debug_stats == i32(-1) {
        opt = Py_GETENV(ptr[u8]("PYTHONMALLOCSTATS"));
        debug_stats = i32(0);
        if opt {
            if opt.view(1)[0] != u8(0) {
                debug_stats = i32(1);
            }
        }
        stats_slot.view(1)[0] = debug_stats;
    }
    if debug_stats != i32(0) {
        _PyObject_DebugMallocStats(jacpy_stdio_stream(i32(2)));
    }
    unused = om_unused_arena_objects(state);
    arenas_slot = om_arenas(state);
    maxarenas_slot = om_maxarenas(state);
    if not unused.view(1)[0] {
        maxarenas = maxarenas_slot.view(1)[0];

        numarenas = wrapping_shl(maxarenas, u32(1))
            if maxarenas != u32(0)
            else INITIAL_ARENA_OBJECTS;
        if numarenas <= maxarenas {
            return ptr[arena_object]();
        }
        nbytes = u64(numarenas) * u64(arena_object_SIZE);
        grown = ptr[arena_object](
            PyMem_RawRealloc(ptr(arenas_slot.view(1)[0]), nbytes)
        );
        if not grown {
            return ptr[arena_object]();
        }
        arenas_slot.view(1)[0] = grown;

        i = maxarenas;
        while i < numarenas {
            ao = grown + i64(i);

            ao.view(1)[0].address = u64(0);
            if i < numarenas - u32(1) {
                ao.view(1)[0].nextarena = grown + (i64(i) + 1);
            } else {
                ao.view(1)[0].nextarena = ptr[arena_object]();
            }
            i = i + u32(1);
        }

        unused.view(1)[0] = grown + i64(maxarenas);
        maxarenas_slot.view(1)[0] = numarenas;
    }

    arenaobj = unused.view(1)[0];
    unused.view(1)[0] = arenaobj.view(1)[0].nextarena;

    arena = object_arena();
    address = arena.view(1)[0].alloc(arena.view(1)[0].ctx, ARENA_SIZE);
    if address {
        if arena_map_mark_used(state, u64.wrap(int(address)), True) == i32(0) {
            arena.view(1)[0].free(arena.view(1)[0].ctx, address, ARENA_SIZE);
            address = ptr();
        }
    }
    if not address {
        arenaobj.view(1)[0].nextarena = unused.view(1)[0];
        unused.view(1)[0] = arenaobj;
        return ptr[arena_object]();
    }
    base = u64.wrap(int(address));
    arenaobj.view(1)[0].address = base;
    current = om_counter(state, _obmalloc_state_MGMT_NARENAS_CURRENTLY_ALLOCATED);
    current.view(1)[0] = current.view(1)[0] + u64(1);
    ntimes = om_counter(state, _obmalloc_state_MGMT_NTIMES_ARENA_ALLOCATED);
    ntimes.view(1)[0] = ntimes.view(1)[0] + u64(1);
    highwater = om_counter(state, _obmalloc_state_MGMT_NARENAS_HIGHWATER);
    if current.view(1)[0] > highwater.view(1)[0] {
        highwater.view(1)[0] = current.view(1)[0];
    }
    arenaobj.view(1)[0].freepools = ptr[pool_header]();

    arenaobj.view(1)[0].pool_address = ptr[u8](address);
    arenaobj.view(1)[0].nfreepools = MAX_POOLS_IN_ARENA;
    excess = base & POOL_SIZE_MASK;
    if excess != u64(0) {
        arenaobj.view(1)[0].nfreepools = MAX_POOLS_IN_ARENA - u32(1);
        arenaobj.view(1)[0].pool_address = ptr[u8](address)
            + i64.wrap(POOL_SIZE - excess);
    }
    arenaobj.view(1)[0].ntotalpools = arenaobj.view(1)[0].nfreepools;
    return arenaobj;
}

impl address_in_range(state: ptr[u8], p: u64, pool: ptr[pool_header]) -> bool {
    return arena_map_is_used(state, p);
}

impl pymalloc_pool_extend(pool: ptr[pool_header], size: u32) {
    nextoffset = pool.view(1)[0].nextoffset;
    if nextoffset <= pool.view(1)[0].maxnextoffset {
        block = ptr[u8](pool) + i64(nextoffset);
        pool.view(1)[0].freeblock = block;
        pool.view(1)[0].nextoffset = wrapping_add(nextoffset, index2size(size));
        ptr[ptr[u8]](block).view(1)[0] = ptr[u8]();
        return;
    }

    nxt = pool.view(1)[0].nextpool;
    prev = pool.view(1)[0].prevpool;
    nxt.view(1)[0].prevpool = prev;
    prev.view(1)[0].nextpool = nxt;
}

impl allocate_from_new_pool(state: ptr[u8], size: u32) -> ptr[u8] {
    usable = om_usable_arenas(state);
    nfp2lasta = om_nfp2lasta(state);
    if not usable.view(1)[0] {
        fresh = new_arena(state);
        usable.view(1)[0] = fresh;
        if not fresh {
            return ptr[u8]();
        }
        fresh.view(1)[0].nextarena = ptr[arena_object]();
        fresh.view(1)[0].prevarena = ptr[arena_object]();

        (nfp2lasta + i64(fresh.view(1)[0].nfreepools)).view(1)[0] = fresh;
    }
    ua = usable.view(1)[0];

    nf = ua.view(1)[0].nfreepools;
    if (nfp2lasta + i64(nf)).view(1)[0] == ua {
        (nfp2lasta + i64(nf)).view(1)[0] = ptr[arena_object]();
    }

    if nf > u32(1) {
        (nfp2lasta + i64(nf - u32(1))).view(1)[0] = ua;
    }

    pool = ua.view(1)[0].freepools;
    if pool {
        ua.view(1)[0].freepools = pool.view(1)[0].nextpool;
        ua.view(1)[0].nfreepools = nf - u32(1);
        if nf == u32(1) {
            nxt = ua.view(1)[0].nextarena;
            usable.view(1)[0] = nxt;
            if nxt {
                nxt.view(1)[0].prevarena = ptr[arena_object]();
            }
        }
    } else {
        pool = ptr[pool_header](ua.view(1)[0].pool_address);
        allarenas = om_arenas(state).view(1)[0];
        pool.view(1)[0].arenaindex = u32.wrap(
            (int(ua) - int(allarenas)) // arena_object_SIZE
        );
        pool.view(1)[0].szidx = DUMMY_SIZE_IDX;
        ua.view(1)[0].pool_address = ua.view(1)[0].pool_address + i64.wrap(POOL_SIZE);
        ua.view(1)[0].nfreepools = nf - u32(1);
        if nf == u32(1) {
            nxt = ua.view(1)[0].nextarena;
            usable.view(1)[0] = nxt;
            if nxt {
                nxt.view(1)[0].prevarena = ptr[arena_object]();
            }
        }
    }

    head = usedpool(state, size);
    pool.view(1)[0].nextpool = head;
    pool.view(1)[0].prevpool = head;
    head.view(1)[0].nextpool = pool;
    head.view(1)[0].prevpool = pool;
    set_pool_count(pool, u32(1));
    if pool.view(1)[0].szidx == size {
        reused = pool.view(1)[0].freeblock;
        pool.view(1)[0].freeblock = ptr[ptr[u8]](reused).view(1)[0];
        return reused;
    }

    pool.view(1)[0].szidx = size;
    block_size = index2size(size);
    bp = ptr[u8](pool) + i64(POOL_OVERHEAD);
    pool.view(1)[0].nextoffset = POOL_OVERHEAD + wrapping_shl(block_size, u32(1));
    pool.view(1)[0].maxnextoffset = u32.wrap(POOL_SIZE) - block_size;
    second = bp + i64(block_size);
    pool.view(1)[0].freeblock = second;
    ptr[ptr[u8]](second).view(1)[0] = ptr[u8]();
    return bp;
}

impl pymalloc_alloc(state: ptr[u8], ctx: ptr, nbytes: u64) -> ptr[u8] {
    if nbytes == u64(0) {
        return ptr[u8]();
    }
    if nbytes > SMALL_REQUEST_THRESHOLD {
        return ptr[u8]();
    }
    size = u32.wrap(wrapping_sub(nbytes, u64(1))) >> ALIGNMENT_SHIFT;
    pool = usedpool(state, size);
    if pool != pool.view(1)[0].nextpool {
        set_pool_count(pool, wrapping_add(pool_count(pool), u32(1)));
        bp = pool.view(1)[0].freeblock;
        nxt = ptr[ptr[u8]](bp).view(1)[0];
        pool.view(1)[0].freeblock = nxt;
        if not nxt {
            pymalloc_pool_extend(pool, size);
        }
        return bp;
    }

    return allocate_from_new_pool(state, size);
}

impl insert_to_usedpool(state: ptr[u8], pool: ptr[pool_header]) {
    nxt = usedpool(state, pool.view(1)[0].szidx);
    prev = nxt.view(1)[0].prevpool;

    pool.view(1)[0].nextpool = nxt;
    pool.view(1)[0].prevpool = prev;
    nxt.view(1)[0].prevpool = pool;
    prev.view(1)[0].nextpool = pool;
}

impl insert_to_freepool(state: ptr[u8], pool: ptr[pool_header]) {
    nxt = pool.view(1)[0].nextpool;
    prev = pool.view(1)[0].prevpool;
    nxt.view(1)[0].prevpool = prev;
    prev.view(1)[0].nextpool = nxt;

    ao = om_arenas(state).view(1)[0] + i64(pool.view(1)[0].arenaindex);
    pool.view(1)[0].nextpool = ao.view(1)[0].freepools;
    ao.view(1)[0].freepools = pool;
    nf = ao.view(1)[0].nfreepools;

    nfp2lasta = om_nfp2lasta(state);
    usable = om_usable_arenas(state);
    lastnf = (nfp2lasta + i64(nf)).view(1)[0];
    if lastnf == ao {
        p = ao.view(1)[0].prevarena;
        (nfp2lasta + i64(nf)).view(1)[0] = ptr[arena_object]();
        if p {
            if p.view(1)[0].nfreepools == nf {
                (nfp2lasta + i64(nf)).view(1)[0] = p;
            }
        }
    }
    nf = nf + u32(1);
    ao.view(1)[0].nfreepools = nf;

    if nf == ao.view(1)[0].ntotalpools and int(ao.view(1)[0].nextarena) != 0 {
        if not ao.view(1)[0].prevarena {
            usable.view(1)[0] = ao.view(1)[0].nextarena;
        } else {
            ao.view(1)[0].prevarena.view(1)[0].nextarena = ao.view(1)[0].nextarena;
        }

        if ao.view(1)[0].nextarena {
            ao.view(1)[0].nextarena.view(1)[0].prevarena = ao.view(1)[0].prevarena;
        }

        unused = om_unused_arena_objects(state);
        ao.view(1)[0].nextarena = unused.view(1)[0];
        unused.view(1)[0] = ao;

        arena_map_mark_used(state, ao.view(1)[0].address, False);

        arena = object_arena();
        arena.view(1)[0].free(
            arena.view(1)[0].ctx,
            ptr(ptr[u8](i64.wrap(ao.view(1)[0].address))),
            ARENA_SIZE
        );

        ao.view(1)[0].address = u64(0);
        current = om_counter(state, _obmalloc_state_MGMT_NARENAS_CURRENTLY_ALLOCATED);
        current.view(1)[0] = wrapping_sub(current.view(1)[0], u64(1));
        return;
    }
    if nf == u32(1) {
        ao.view(1)[0].nextarena = usable.view(1)[0];
        ao.view(1)[0].prevarena = ptr[arena_object]();
        if usable.view(1)[0] {
            usable.view(1)[0].view(1)[0].prevarena = ao;
        }
        usable.view(1)[0] = ao;
        if not (nfp2lasta + 1).view(1)[0] {
            (nfp2lasta + 1).view(1)[0] = ao;
        }
        return;
    }

    if not (nfp2lasta + i64(nf)).view(1)[0] {
        (nfp2lasta + i64(nf)).view(1)[0] = ao;
    }

    if ao == lastnf {
        return;
    }

    if ao.view(1)[0].prevarena {
        ao.view(1)[0].prevarena.view(1)[0].nextarena = ao.view(1)[0].nextarena;
    } else {
        usable.view(1)[0] = ao.view(1)[0].nextarena;
    }
    ao.view(1)[0].nextarena.view(1)[0].prevarena = ao.view(1)[0].prevarena;

    ao.view(1)[0].prevarena = lastnf;
    ao.view(1)[0].nextarena = lastnf.view(1)[0].nextarena;
    if ao.view(1)[0].nextarena {
        ao.view(1)[0].nextarena.view(1)[0].prevarena = ao;
    }
    lastnf.view(1)[0].nextarena = ao;
}

impl pymalloc_free(state: ptr[u8], ctx: ptr, p: ptr) -> bool {
    address = u64.wrap(int(p));
    pool = pool_addr(address);
    if not address_in_range(state, address, pool) {
        return False;
    }

    lastfree = pool.view(1)[0].freeblock;
    ptr[ptr[u8]](p).view(1)[0] = lastfree;
    pool.view(1)[0].freeblock = ptr[u8](p);
    count = wrapping_sub(pool_count(pool), u32(1));
    set_pool_count(pool, count);
    if not lastfree {
        insert_to_usedpool(state, pool);
        return True;
    }

    if count != u32(0) {
        return True;
    }

    insert_to_freepool(state, pool);
    return True;
}

impl pymalloc_realloc(
    state: ptr[u8], ctx: ptr, p: ptr, nbytes: u64
) -> tuple[i32, ptr] {
    address = u64.wrap(int(p));
    pool = pool_addr(address);
    if not address_in_range(state, address, pool) {
        return (i32(0), ptr());
    }

    size = u64(index2size(pool.view(1)[0].szidx));
    if nbytes <= size {
        if wrapping_mul(u64(4), nbytes) > wrapping_mul(u64(3), size) {
            return (i32(1), p);
        }
        size = nbytes;
    }
    bp = _PyObject_Malloc(ctx, nbytes);
    if bp {
        memcpy(bp, p, size);
        _PyObject_Free(ctx, p);
    }
    return (i32(1), bp);
}

impl read_size_t(p: ptr[u8]) -> u64 {
    result = u64(p.view(1)[0]);
    i: i64 = 1;
    while i < SST {
        result = wrapping_shl(result, u64(8)) | u64((p + i).view(1)[0]);
        i = i + 1;
    }
    return result;
}

impl write_size_t(p: ptr[u8], n: u64) {
    q = p + (SST - 1);
    value = n;
    i: i64 = 0;
    while i < SST {
        (q - i).view(1)[0] = u8.wrap(value & u64(0xff));
        value = value >> u64(8);
        i = i + 1;
    }
}

impl fill_mem_debug(api: ptr[u8], data: ptr[u8], c: i32, nbytes: u64, is_alloc: bool) {
    memset(ptr(data), c, nbytes);
}

impl _PyMem_DebugRawAlloc(use_calloc: bool, ctx: ptr, nbytes: u64) -> ptr {
    api = ptr[u8](ctx);
    al = debug_api_alloc(api);
    if nbytes > PY_SSIZE_T_MAX_SIZE - PYMEM_DEBUG_EXTRA_BYTES {
        return ptr();
    }
    total = nbytes + PYMEM_DEBUG_EXTRA_BYTES;
    p = ptr[u8]();
    if use_calloc {
        p = ptr[u8](al.view(1)[0].calloc(al.view(1)[0].ctx, u64(1), total));
    } else {
        p = ptr[u8](al.view(1)[0].malloc(al.view(1)[0].ctx, total));
    }
    if not p {
        return ptr();
    }
    data = p + 2 * SST;

    write_size_t(p, nbytes);
    (p + SST).view(1)[0] = api.view(1)[0];
    memset(ptr(p + SST + 1), PYMEM_FORBIDDENBYTE, u64(SST - 1));
    if nbytes > u64(0) and not use_calloc {
        fill_mem_debug(api, data, PYMEM_CLEANBYTE, nbytes, True);
    }

    tail = data + i64.wrap(nbytes);
    memset(ptr(tail), PYMEM_FORBIDDENBYTE, u64(SST));
    return ptr(data);
}

impl _PyMem_DebugCheckGIL(func: ptr[u8]) {
    if not PyThreadState_GetUnchecked() {
        _Py_FatalErrorFunc(
            func, ptr[u8]("Python memory allocator called without holding the GIL")
        );
    }
}

impl _PyMem_DebugCheckAddress(func: ptr[u8], api: u8, p: ptr) {
    q = ptr[u8](p);

    id = (q - SST).view(1)[0];
    if id != api {
        _PyObject_DebugDumpAddress(p);
        _Py_FatalErrorFormat(
            func,
            ptr[u8]("bad ID: Allocated using API '%c', verified using API '%c'"),
            i32(id),
            i32(api)
        );
    }

    i: i64 = SST - 1;
    while i >= 1 {
        if i32((q - i).view(1)[0]) != PYMEM_FORBIDDENBYTE {
            _PyObject_DebugDumpAddress(p);
            _Py_FatalErrorFunc(func, ptr[u8]("bad leading pad byte"));
        }
        i = i - 1;
    }
    nbytes = read_size_t(q - 2 * SST);
    tail = q + i64.wrap(nbytes);
    i = 0;
    while i < SST {
        if i32((tail + i).view(1)[0]) != PYMEM_FORBIDDENBYTE {
            _PyObject_DebugDumpAddress(p);
            _Py_FatalErrorFunc(func, ptr[u8]("bad trailing pad byte"));
        }
        i = i + 1;
    }
}

impl _PyObject_DebugDumpAddress(p: ptr) {
    err = jacpy_stdio_stream(i32(2));
    q = ptr[u8](p);
    fprintf(err, ptr[u8]("Debug memory block at address p=%p:"), p);
    if not p {
        fprintf(err, ptr[u8]("\n"));
        return;
    }
    id = (q - SST).view(1)[0];
    fprintf(err, ptr[u8](" API '%c'\n"), i32(id));
    nbytes = read_size_t(q - 2 * SST);
    fprintf(err, ptr[u8]("    %zu bytes originally requested\n"), i64.wrap(nbytes));

    fprintf(
        err,
        ptr[u8]("    The %d pad bytes at p-%d are "),
        i32.wrap(SST - 1),
        i32.wrap(SST - 1)
    );
    ok = True;
    i: i64 = 1;
    while i <= SST - 1 {
        if i32((q - i).view(1)[0]) != PYMEM_FORBIDDENBYTE {
            ok = False;
            break;
        }
        i = i + 1;
    }
    if ok {
        fputs(ptr[u8]("FORBIDDENBYTE, as expected.\n"), err);
    } else {
        fprintf(err, ptr[u8]("not all FORBIDDENBYTE (0x%02x):\n"), PYMEM_FORBIDDENBYTE);
        i = SST - 1;
        while i >= 1 {
            byte = i32((q - i).view(1)[0]);
            fprintf(err, ptr[u8]("        at p-%d: 0x%02x"), i32.wrap(i), byte);
            if byte != PYMEM_FORBIDDENBYTE {
                fputs(ptr[u8](" *** OUCH"), err);
            }
            fputc(i32(10), err);
            i = i - 1;
        }
        fputs(
            ptr[u8](
                "    Because memory is corrupted at the start, the count of bytes requested\n       may be bogus, and checking the trailing pad bytes may segfault.\n"
            ),
            err
        );
    }
    tail = q + i64.wrap(nbytes);
    fprintf(
        err, ptr[u8]("    The %d pad bytes at tail=%p are "), i32.wrap(SST), ptr(tail)
    );
    ok = True;
    i = 0;
    while i < SST {
        if i32((tail + i).view(1)[0]) != PYMEM_FORBIDDENBYTE {
            ok = False;
            break;
        }
        i = i + 1;
    }
    if ok {
        fputs(ptr[u8]("FORBIDDENBYTE, as expected.\n"), err);
    } else {
        fprintf(err, ptr[u8]("not all FORBIDDENBYTE (0x%02x):\n"), PYMEM_FORBIDDENBYTE);
        i = 0;
        while i < SST {
            byte = i32((tail + i).view(1)[0]);
            fprintf(err, ptr[u8]("        at tail+%d: 0x%02x"), i32.wrap(i), byte);
            if byte != PYMEM_FORBIDDENBYTE {
                fputs(ptr[u8](" *** OUCH"), err);
            }
            fputc(i32(10), err);
            i = i + 1;
        }
    }
    if nbytes > u64(0) {
        i = 0;
        fputs(ptr[u8]("    Data at p:"), err);

        while int(q) < int(tail) and i < 8 {
            fprintf(err, ptr[u8](" %02x"), i32(q.view(1)[0]));
            i = i + 1;
            q = q + 1;
        }

        if int(q) < int(tail) {
            if int(tail) - int(q) > 8 {
                fputs(ptr[u8](" ..."), err);
                q = tail - 8;
            }
            while int(q) < int(tail) {
                fprintf(err, ptr[u8](" %02x"), i32(q.view(1)[0]));
                q = q + 1;
            }
        }
        fputc(i32(10), err);
    }
    fputc(i32(10), err);
    fflush(err);
    _PyMem_DumpTraceback(jacpy_stdio_fileno(i32(2)), p);
}

impl printone(out: ptr, msg: ptr[u8], value: u64) -> u64 {
    slots: own ObmallocStack = ObmallocStack();
    buf = ptr[u8](jacpy_stack_address(&mut slots));
    origvalue = value;
    fputs(msg, out);
    i = i32.wrap(strlen(msg));
    while i < i32(35) {
        fputc(i32(32), out);
        i = i + i32(1);
    }
    fputc(i32(61), out);

    i = i32(22);
    (buf + i64(i)).view(1)[0] = u8(0);
    i = i - i32(1);
    (buf + i64(i)).view(1)[0] = u8(10);
    i = i - i32(1);
    k = i32(3);
    rest = value;
    while True {
        nextvalue = rest // u64(10);
        digit = u32.wrap(rest - nextvalue * u64(10));
        rest = nextvalue;
        (buf + i64(i)).view(1)[0] = u8.wrap(digit + u32(48));
        i = i - i32(1);
        k = k - i32(1);
        if k == i32(0) and rest != u64(0) and i >= i32(0) {
            k = i32(3);
            (buf + i64(i)).view(1)[0] = u8(44);
            i = i - i32(1);
        }
        if rest == u64(0) or i < i32(0) {
            break;
        }
    }
    while i >= i32(0) {
        (buf + i64(i)).view(1)[0] = u8(32);
        i = i - i32(1);
    }
    fputs(buf, out);
    return origvalue;
}

impl init_obmalloc_pools(interp: ptr[u8]) {
    used = om_usedpools(interp_obmalloc(interp).view(1)[0]);
    for x in range(OBMALLOC_USED_POOLS_SIZE // 2) {
        slot = used + 2 * x;
        head = ptr[pool_header](ptr[u8](slot) - 2 * 8);
        slot.view(1)[0] = head;
        (slot + 1).view(1)[0] = head;
    }
}

impl free_obmalloc_arenas(interp: ptr[u8]) {
    state = interp_obmalloc(interp).view(1)[0];
    allarenas = om_arenas(state).view(1)[0];
    maxarenas = om_maxarenas(state).view(1)[0];
    arena = object_arena();
    i: u32 = 0;
    while i < maxarenas {
        ao = allarenas + i64(i);
        arena.view(1)[0].free(
            arena.view(1)[0].ctx,
            ptr(ptr[u8](i64.wrap(ao.view(1)[0].address))),
            ARENA_SIZE
        );
        i = i + u32(1);
    }

    PyMem_RawFree(ptr(allarenas));

    map_root = om_map_root(state);
    for i1 in range(MAP_TOP_LENGTH) {
        mid = (map_root + i1).view(1)[0];
        if not mid {
            continue;
        }
        for i2 in range(MAP_MID_LENGTH) {
            bot = (mid + i2).view(1)[0];
            if not bot {
                continue;
            }
            PyMem_RawFree(ptr(bot));
        }
        PyMem_RawFree(ptr(mid));
    }
}

impl _collect_alloc_stats(
    heap: ptr, area: ptr, block: ptr, block_size: u64, arg: ptr
) -> u8 {
    stats = ptr[u64](arg);
    a = ptr[u8](area);
    used = ptr[u64](a + mi_heap_area_t_USED).view(1)[0];
    area_block_size = ptr[u64](a + mi_heap_area_t_BLOCK_SIZE).view(1)[0];
    full_block_size = ptr[u64](a + mi_heap_area_t_FULL_BLOCK_SIZE).view(1)[0];
    stats.view(5)[0] = stats.view(5)[0] + used;
    stats.view(5)[1] = stats.view(5)[1] + used * area_block_size;
    stats.view(5)[2] = stats.view(5)[2] + used * full_block_size;
    stats.view(5)[3] = stats.view(5)[3]
        + ptr[u64](a + mi_heap_area_t_RESERVED).view(1)[0];
    stats.view(5)[4] = stats.view(5)[4]
        + ptr[u64](a + mi_heap_area_t_COMMITTED).view(1)[0];
    return u8(1);
}

impl py_mimalloc_print_stats(out: ptr) {
    fprintf(
        out,
        ptr[u8]("Small block threshold = %zu, in %u size classes.\n"),
        i64.wrap(MI_SMALL_OBJ_SIZE_MAX),
        i32.wrap(MI_BIN_HUGE)
    );
    fprintf(
        out, ptr[u8]("Medium block threshold = %zu\n"), i64.wrap(MI_MEDIUM_OBJ_SIZE_MAX)
    );
    fprintf(
        out, ptr[u8]("Large object max size = %zu\n"), i64.wrap(MI_LARGE_OBJ_SIZE_MAX)
    );
    heap = mi_heap_get_default();
    slots: own ObmallocStack = ObmallocStack();
    stats = ptr[u64](jacpy_stack_address(&mut slots));
    memset(ptr(stats), 0, u64(5 * 8));
    mi_heap_visit_blocks(heap, False, ptr(_collect_alloc_stats), ptr(stats));
    fprintf(out, ptr[u8]("    Allocated Blocks: %zd\n"), i64.wrap(stats.view(5)[0]));
    fprintf(out, ptr[u8]("    Allocated Bytes: %zd\n"), i64.wrap(stats.view(5)[1]));
    fprintf(
        out,
        ptr[u8]("    Allocated Bytes w/ Overhead: %zd\n"),
        i64.wrap(stats.view(5)[2])
    );
    fprintf(out, ptr[u8]("    Bytes Reserved: %zd\n"), i64.wrap(stats.view(5)[3]));
    fprintf(out, ptr[u8]("    Bytes Committed: %zd\n"), i64.wrap(stats.view(5)[4]));
}

impl pymalloc_print_stats(out: ptr) {
    state = get_state();
    numclasses = NB_SMALL_SIZE_CLASSES;

    pools_slots: own ObmallocStack = ObmallocStack();
    blocks_slots: own ObmallocStack = ObmallocStack();
    free_slots: own ObmallocStack = ObmallocStack();
    buf_slots: own ObmallocStack = ObmallocStack();
    numpools = ptr[u64](jacpy_stack_address(&mut pools_slots));
    numblocks = ptr[u64](jacpy_stack_address(&mut blocks_slots));
    numfreeblocks = ptr[u64](jacpy_stack_address(&mut free_slots));
    buf = ptr[u8](jacpy_stack_address(&mut buf_slots));

    allocated_bytes: u64 = 0;

    available_bytes: u64 = 0;

    numfreepools: u32 = 0;

    arena_alignment: u64 = 0;

    pool_header_bytes: u64 = 0;

    quantization: u64 = 0;

    narenas: u64 = 0;

    total: u64 = 0;
    fprintf(
        out,
        ptr[u8]("Small block threshold = %d, in %u size classes.\n"),
        i32.wrap(SMALL_REQUEST_THRESHOLD),
        i32.wrap(numclasses)
    );
    i: u32 = 0;
    while i < numclasses {
        (numpools + i64(i)).view(1)[0] = u64(0);
        (numblocks + i64(i)).view(1)[0] = u64(0);
        (numfreeblocks + i64(i)).view(1)[0] = u64(0);
        i = i + u32(1);
    }

    allarenas = om_arenas(state).view(1)[0];
    maxarenas = om_maxarenas(state).view(1)[0];
    i = 0;
    while i < maxarenas {
        ao = allarenas + i64(i);
        i = i + u32(1);
        base = ao.view(1)[0].address;

        if base == u64(0) {
            continue;
        }
        narenas = narenas + u64(1);
        numfreepools = numfreepools + ao.view(1)[0].nfreepools;

        if (base & POOL_SIZE_MASK) != u64(0) {
            arena_alignment = arena_alignment + POOL_SIZE;
            base = base & ~POOL_SIZE_MASK;
            base = base + POOL_SIZE;
        }

        limit = u64.wrap(int(ao.view(1)[0].pool_address));
        while base < limit {
            p = ptr[pool_header](i64.wrap(base));
            base = base + POOL_SIZE;
            sz = p.view(1)[0].szidx;
            count = pool_count(p);
            if count == u32(0) {
                continue;
            }
            idx = i64(sz);
            (numpools + idx).view(1)[0] = (numpools + idx).view(1)[0] + u64(1);
            (numblocks + idx).view(1)[0] = (numblocks + idx).view(1)[0] + u64(count);
            freeblocks = pool_numblocks(sz) - count;
            (numfreeblocks + idx).view(1)[0] = (numfreeblocks + idx).view(1)[0]
                + u64(freeblocks);
        }
    }

    fputc(i32(10), out);
    fputs(
        ptr[u8](
            "class   size   num pools   blocks in use  avail blocks\n-----   ----   ---------   -------------  ------------\n"
        ),
        out
    );
    i = 0;
    while i < numclasses {
        idx = i64(i);
        cls = i;
        i = i + u32(1);
        pools = (numpools + idx).view(1)[0];
        b = (numblocks + idx).view(1)[0];
        f = (numfreeblocks + idx).view(1)[0];
        size = index2size(cls);
        if pools == u64(0) {
            continue;
        }
        fprintf(
            out,
            ptr[u8]("%5u %6u %11zu %15zu %13zu\n"),
            i32.wrap(cls),
            i32.wrap(size),
            i64.wrap(pools),
            i64.wrap(b),
            i64.wrap(f)
        );
        allocated_bytes = allocated_bytes + b * u64(size);
        available_bytes = available_bytes + f * u64(size);
        pool_header_bytes = pool_header_bytes + pools * u64(POOL_OVERHEAD);
        quantization = quantization
            + pools * ((POOL_SIZE - u64(POOL_OVERHEAD)) % u64(size));
    }
    fputc(i32(10), out);
    ntimes = om_counter(state, _obmalloc_state_MGMT_NTIMES_ARENA_ALLOCATED).view(1)[0];
    highwater = om_counter(state, _obmalloc_state_MGMT_NARENAS_HIGHWATER).view(1)[0];
    printone(out, ptr[u8]("# arenas allocated total"), ntimes);
    printone(out, ptr[u8]("# arenas reclaimed"), wrapping_sub(ntimes, narenas));
    printone(out, ptr[u8]("# arenas highwater mark"), highwater);
    printone(out, ptr[u8]("# arenas allocated current"), narenas);
    PyOS_snprintf(
        buf,
        u64(128),
        ptr[u8]("%zu arenas * %d bytes/arena"),
        i64.wrap(narenas),
        i32.wrap(ARENA_SIZE)
    );
    printone(out, buf, narenas * ARENA_SIZE);
    fputc(i32(10), out);

    total = printone(out, ptr[u8]("# bytes in allocated blocks"), allocated_bytes);
    total = total
        + printone(out, ptr[u8]("# bytes in available blocks"), available_bytes);
    PyOS_snprintf(
        buf,
        u64(128),
        ptr[u8]("%u unused pools * %d bytes"),
        i32.wrap(numfreepools),
        i32.wrap(POOL_SIZE)
    );
    total = total + printone(out, buf, u64(numfreepools) * POOL_SIZE);
    total = total
        + printone(out, ptr[u8]("# bytes lost to pool headers"), pool_header_bytes);
    total = total
        + printone(out, ptr[u8]("# bytes lost to quantization"), quantization);
    total = total
        + printone(out, ptr[u8]("# bytes lost to arena alignment"), arena_alignment);
    printone(out, ptr[u8]("Total"), total);

    fputs(ptr[u8]("\narena map counts\n"), out);
    mid_count = om_map_count(state, _obmalloc_state_USAGE_ARENA_MAP_MID_COUNT).view(1)[
        0
    ];
    bot_count = om_map_count(state, _obmalloc_state_USAGE_ARENA_MAP_BOT_COUNT).view(1)[
        0
    ];
    printone(out, ptr[u8]("# arena map mid nodes"), u64.wrap(i64(mid_count)));
    printone(out, ptr[u8]("# arena map bot nodes"), u64.wrap(i64(bot_count)));
    fputc(i32(10), out);
    total = printone(
        out, ptr[u8]("# bytes lost to arena map root"), u64(arena_map_top_t_SIZE)
    );
    total = total
        + printone(
            out,
            ptr[u8]("# bytes lost to arena map mid"),
            u64(arena_map_mid_t_SIZE) * u64.wrap(i64(mid_count))
        );
    total = total
        + printone(
            out,
            ptr[u8]("# bytes lost to arena map bot"),
            u64(arena_map_bot_t_SIZE) * u64.wrap(i64(bot_count))
        );
    printone(out, ptr[u8]("Total"), total);
}
