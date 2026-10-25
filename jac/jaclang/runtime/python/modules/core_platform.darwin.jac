import from jaclang.runtime.python.modules.time_records { timespec, timeval }
import from c {
    def mach_absolute_time -> u64;  def mach_timebase_info(
        info: &mut MachTimebase
    ) -> i32;  def pthread_threadid_np(thread: ptr, thread_id: &mut u64) -> i32;  obj MachTimebase {
        has numer: u32 = 0,
            denom: u32 = 0;
    }
}

glob PYTIME_MACH_CLOCK: Final[i64] = 1,
     PYTHREAD_CONDATTR_MONOTONIC: Final[i64] = 0,
     PYTHREAD_USE_SEMAPHORES: Final[i64] = 0,
     THREAD_STACK_SIZE: Final[i64] = 0x1000000;

def mach_ticks -> u64;

def mach_timebase -> tuple[i64, i64];

def native_thread_id -> u64;

def condattr_set_monotonic(attr: ptr[u8]) -> i32;

def semaphore_timedwait(sema: ptr, abstime: ptr[timespec]) -> i32;

def timeval_store(tv: ptr[timeval], seconds: i64, microseconds: i64);

impl mach_ticks -> u64 {
    return mach_absolute_time();
}

impl mach_timebase -> tuple[i64, i64] {
    timebase: own MachTimebase = MachTimebase();
    mach_timebase_info(&mut timebase);
    return (i64(timebase.numer), i64(timebase.denom));
}

impl native_thread_id -> u64 {
    native_id: u64 = 0;
    pthread_threadid_np(ptr(), &mut native_id);
    return native_id;
}

impl condattr_set_monotonic(attr: ptr[u8]) -> i32 {
    return i32(-1);
}

impl semaphore_timedwait(sema: ptr, abstime: ptr[timespec]) -> i32 {
    return i32(-1);
}

impl timeval_store(tv: ptr[timeval], seconds: i64, microseconds: i64) {
    tv.view(1)[0].tv_sec = seconds;
    tv.view(1)[0].tv_usec = i32(microseconds);
}
