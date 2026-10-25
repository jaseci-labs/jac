import from c {
    obj arena_block {
        has ab_size: u64,
            ab_offset: u64,
            ab_next: ptr[arena_block],
            ab_mem: ptr[u8];
    }  obj arena_header {
        has a_head: ptr[arena_block],
            a_cur: ptr[arena_block],
            a_objects: ptr[PyObject];
    }
}

glob:priv DEFAULT_BLOCK_SIZE: Final[u64] = 8192,
     ALIGNMENT: Final[u64] = 8,
     ARENA_BLOCK_SIZE: Final[u64] = 32,
     ARENA_HEADER_SIZE: Final[u64] = 24;

def block_new(size: u64) -> ptr[arena_block];

def block_free(first: ptr[arena_block]);

def block_alloc(first: ptr[arena_block], request: u64) -> ptr;

import from c {
    def _PyArena_New -> ptr {
        arena = ptr[arena_header](PyMem_Malloc(ARENA_HEADER_SIZE));
        if not arena {
            return ptr(PyErr_NoMemory());
        }
        arena.view(1)[0].a_head = block_new(DEFAULT_BLOCK_SIZE);
        arena.view(1)[0].a_cur = arena.view(1)[0].a_head;
        if not arena.view(1)[0].a_head {
            PyMem_Free(ptr(arena));
            return ptr(PyErr_NoMemory());
        }
        arena.view(1)[0].a_objects = PyList_New(0);
        if not arena.view(1)[0].a_objects {
            block_free(arena.view(1)[0].a_head);
            PyMem_Free(ptr(arena));
            return ptr(PyErr_NoMemory());
        }
        return ptr(arena);
    }  def _PyArena_Free(arena_raw: ptr) {
        arena = ptr[arena_header](arena_raw);
        block_free(arena.view(1)[0].a_head);
        object_decref(arena.view(1)[0].a_objects);
        PyMem_Free(arena_raw);
    }  def _PyArena_Malloc(arena_raw: ptr, size: u64) -> ptr {
        arena = ptr[arena_header](arena_raw);
        p = block_alloc(arena.view(1)[0].a_cur, size);
        if not p {
            return ptr(PyErr_NoMemory());
        }
        cur = arena.view(1)[0].a_cur;
        if cur.view(1)[0].ab_next {
            arena.view(1)[0].a_cur = cur.view(1)[0].ab_next;
        }
        return p;
    }  def _PyArena_AddPyObject(arena_raw: ptr, op: ptr[PyObject]) -> i32 {
        arena = ptr[arena_header](arena_raw);
        r = PyList_Append(arena.view(1)[0].a_objects, op);
        if r >= 0 {
            object_decref(op);
        }
        return r;
    }
}

impl block_new(size: u64) -> ptr[arena_block] {
    b = ptr[arena_block](PyMem_Malloc(wrapping_add(ARENA_BLOCK_SIZE, size)));
    if not b {
        return ptr[arena_block]();
    }
    b.view(1)[0].ab_size = size;
    b.view(1)[0].ab_mem = ptr[u8](b) + i64(ARENA_BLOCK_SIZE);
    b.view(1)[0].ab_next = ptr[arena_block]();
    mem = u64(int(b.view(1)[0].ab_mem));
    aligned = wrapping_add(mem, ALIGNMENT - 1) & ~(ALIGNMENT - 1);
    b.view(1)[0].ab_offset = aligned - mem;
    return b;
}

impl block_free(first: ptr[arena_block]) {
    b = first;
    while b {
        next_block = b.view(1)[0].ab_next;
        PyMem_Free(ptr(b));
        b = next_block;
    }
}

impl block_alloc(first: ptr[arena_block], request: u64) -> ptr {
    b = first;
    size = wrapping_add(request, ALIGNMENT - 1) & ~(ALIGNMENT - 1);
    if wrapping_add(b.view(1)[0].ab_offset, size) > b.view(1)[0].ab_size {
        newbl = block_new(DEFAULT_BLOCK_SIZE if size < DEFAULT_BLOCK_SIZE else size);
        if not newbl {
            return ptr();
        }
        b.view(1)[0].ab_next = newbl;
        b = newbl;
    }
    p = b.view(1)[0].ab_mem + i64(b.view(1)[0].ab_offset);
    b.view(1)[0].ab_offset = b.view(1)[0].ab_offset + size;
    return ptr(p);
}
