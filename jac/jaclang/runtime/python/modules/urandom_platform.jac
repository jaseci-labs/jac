glob HAVE_GETENTROPY: Final[bool] = False;

def getentropy_fill(buffer: ptr[u8], length: i64) -> i32;

impl getentropy_fill(buffer: ptr[u8], length: i64) -> i32 {
    return i32(-1);
}
