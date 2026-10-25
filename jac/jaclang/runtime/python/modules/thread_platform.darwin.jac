import from c {
    def pthread_getname_np(thread: u64, name: ptr[u8], size: u64) -> i32;  def pthread_setname_np(
        name: ptr[u8]
    ) -> i32;  def pthread_self -> u64;
}

glob HAS_THREAD_NAMES: bool = True,
     PYTHREAD_NAME_MAXLEN: i64 = 63;

def get_thread_name(name: ptr[u8], size: u64) -> i32;

def set_thread_name(name: ptr[u8]) -> i32;

impl get_thread_name(name: ptr[u8], size: u64) -> i32 {
    return pthread_getname_np(pthread_self(), name, size);
}

impl set_thread_name(name: ptr[u8]) -> i32 {
    return pthread_setname_np(name);
}
