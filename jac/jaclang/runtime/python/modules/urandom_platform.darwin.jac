import from c { def getentropy(buffer: ptr, length: u64) -> i32;  }

glob HAVE_GETENTROPY: Final[bool] = True;

def getentropy_fill(buffer: ptr[u8], length: i64) -> i32;

impl getentropy_fill(buffer: ptr[u8], length: i64) -> i32 {
    return getentropy(ptr(buffer), u64(length));
}
