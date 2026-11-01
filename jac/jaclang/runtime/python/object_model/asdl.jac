import from c {
    def _PyArena_Malloc(arena: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;
}

glob:priv SIZE_MAX: Final[u64] = 18446744073709551615,
     POINTER_SIZE: Final[u64] = 8;

def asdl_seq_new(size: i64, arena: ptr, seq_size: i64, elements_offset: i64) -> ptr;

import from c {
    def _Py_asdl_generic_seq_new(size: i64, arena: ptr) -> ptr {
        return asdl_seq_new(
            size, arena, asdl_generic_seq_SIZE, asdl_generic_seq_TYPED_ELEMENTS
        );
    }  def _Py_asdl_identifier_seq_new(size: i64, arena: ptr) -> ptr {
        return asdl_seq_new(
            size, arena, asdl_generic_seq_SIZE, asdl_generic_seq_TYPED_ELEMENTS
        );
    }  def _Py_asdl_int_seq_new(size: i64, arena: ptr) -> ptr {
        return asdl_seq_new(
            size, arena, asdl_int_seq_SIZE, asdl_int_seq_TYPED_ELEMENTS
        );
    }
}

impl asdl_seq_new(size: i64, arena: ptr, seq_size: i64, elements_offset: i64) -> ptr {
    if size < 0 or (size != 0 and u64(size - 1) > SIZE_MAX // POINTER_SIZE) {
        PyErr_NoMemory();
        return ptr();
    }
    n: u64 = 0;
    if size != 0 {
        n = POINTER_SIZE * u64(size - 1);
    }
    if n > SIZE_MAX - u64(seq_size) {
        PyErr_NoMemory();
        return ptr();
    }
    n = n + u64(seq_size);
    seq = _PyArena_Malloc(arena, n);
    if not seq {
        PyErr_NoMemory();
        return ptr();
    }
    memset(seq, 0, n);
    header = ptr[asdl_seq](seq);
    header.view(1)[0].size = size;
    header.view(1)[0].elements = ptr[ptr](ptr[u8](seq) + elements_offset);
    return seq;
}
