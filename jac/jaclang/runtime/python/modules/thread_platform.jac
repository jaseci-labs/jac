glob HAS_THREAD_NAMES: bool = False,
     PYTHREAD_NAME_MAXLEN: i64 = 0;

def get_thread_name(name: ptr[u8], size: u64) -> i32;

def set_thread_name(name: ptr[u8]) -> i32;

impl get_thread_name(name: ptr[u8], size: u64) -> i32 {
    return i32(-1);
}

impl set_thread_name(name: ptr[u8]) -> i32 {
    return i32(-1);
}
