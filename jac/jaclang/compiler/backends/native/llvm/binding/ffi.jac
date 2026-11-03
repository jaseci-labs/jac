"""Native helpers the binding shares: C text and buffers copied into Jac
values, C string arrays, and the owned-handle base class."""
def c_bytes(address: ptr[u8], size: int) -> bytes {
    data = b"\x00" * size;
    if size > 0 {
        memcpy(data, ptr(address), u64(size));
    }
    return data;
}

def c_text(address: ptr[u8]) -> str {
    if not address {
        return "";
    }
    return c_bytes(address, int(strlen(address))).decode("utf-8", "replace");
}

def take_text(address: ptr[u8]) -> str {
    text = c_text(address);
    if address {
        LLVMPY_DisposeString(address);
    }
    return text;
}

def take_bytes(address: ptr[u8], size: int) -> bytes {
    data = c_bytes(address, size);
    LLVMPY_DisposeString(address);
    return data;
}

def c_copy(text: str) -> ptr[u8] {
    encoded = text.encode("utf-8");
    size = len(encoded);
    memory = ptr[u8](malloc(u64(size + 1)));
    if not memory {
        raise MemoryError("cannot allocate a C string for LLVM");
    }
    characters = memory.view(size + 1);
    for index in range(size) {
        characters[index] = u8(encoded[index]);
    }
    characters[size] = u8(0);
    return memory;
}

def c_text_array(values: list[str]) -> ptr[ptr[u8]] {
    count = len(values);
    table = ptr[ptr[u8]](malloc(u64(8 * (count + 1))));
    if not table {
        raise MemoryError("cannot allocate a C string array for LLVM");
    }
    cells = table.view(count + 1);
    for index in range(count) {
        cells[index] = c_copy(values[index]);
    }
    cells[count] = ptr[u8]();
    return table;
}

def free_text_array(table: ptr[ptr[u8]], count: int) {
    cells = table.view(count);
    for index in range(count) {
        free(ptr(cells[index]));
    }
    free(ptr(table));
}

class ObjectRef {
    has handle: ptr = ptr(),
        closed: bool = False;

    def init(self: ObjectRef, handle: ptr) {
        if not handle {
            raise ValueError("LLVM returned a NULL handle");
        }
        self.handle = handle;
        self.closed = False;
    }

    def _dispose(self: ObjectRef) {}

    def close(self: ObjectRef) {
        if not self.closed {
            self._dispose();
            self.detach();
        }
    }

    def detach(self: ObjectRef) {
        self.closed = True;
        self.handle = ptr();
    }

    def live(self: ObjectRef) -> ptr {
        if self.closed {
            raise RuntimeError("the LLVM object is already closed");
        }
        return self.handle;
    }

    def __enter__(self: ObjectRef) -> ObjectRef {
        self.live();
        return self;
    }

    def __exit__(self: ObjectRef, kind: any, value: any, trace: any) {
        self.close();
    }

    def __bool__(self: ObjectRef) -> bool {
        return bool(self.handle);
    }

    def __eq__(self: ObjectRef, other: any) -> bool {
        return isinstance(other, ObjectRef) and int(other.handle) == int(self.handle);
    }

    def __hash__(self: ObjectRef) -> int {
        return int(self.handle);
    }
}
