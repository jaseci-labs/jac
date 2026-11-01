import from c {
    def Py_ffi_closure_alloc(size: u64, codeloc: ptr[ptr]) -> ptr {
        return ffi_closure_alloc(size, codeloc);
        if not free_list {
            more_core();
        }
        if not free_list {
            return ptr();
        }
        item = free_list;
        free_list = ptr[ptr](item).view(1)[0];
        codeloc.view(1)[0] = item;
        return item;
    }  def mmap(
        address: ptr, length: u64, prot: i32, flags: i32, fd: i32, offset: i64
    ) -> ptr;  def sysconf(name: i32) -> i64;  def Py_ffi_closure_free(p: ptr) {
        ffi_closure_free(p);
        return;
        item = ptr[ptr](p);
        item.view(1)[0] = free_list;
        free_list = p;
    }
}

glob:priv PROT_EXEC: Final[i32] = 4;

glob:priv free_list: ptr = ptr(),
     _pagesize: i32 = 0;

def more_core;

impl more_core {
    if _pagesize == 0 {
        _pagesize = i32(sysconf(_SC_PAGESIZE));
    }

    count = _pagesize // i32(SIZEOF_FFI_CLOSURE);

    item = mmap(
        ptr(),
        u64(count) * u64(SIZEOF_FFI_CLOSURE),
        PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_PRIVATE | MAP_ANONYMOUS,
        i32(-1),
        i64(0)
    );
    if int(item) == -1 {
        return;
    }

    cursor = ptr[u8](item);
    for i in range(count) {
        ptr[ptr](cursor).view(1)[0] = free_list;
        free_list = ptr(cursor);
        cursor = cursor + SIZEOF_FFI_CLOSURE;
    }
}
