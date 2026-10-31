import from jaclang.runtime.python.modules.time_records { timespec, timeval }
import from jaclang.runtime.python.layouts_platform { CLOCK_MONOTONIC, SYS_gettid }
import from c {
    def syscall(number: i64, *args: any) -> i64;  def pthread_condattr_setclock(
        attr: ptr[u8], clock_id: i32
    ) -> i32;  def sem_timedwait(sema: ptr, abstime: ptr) -> i32;
}

glob PYTIME_MACH_CLOCK: Final[i64] = 0,
     PYTHREAD_CONDATTR_MONOTONIC: Final[i64] = 1,
     PYTHREAD_USE_SEMAPHORES: Final[i64] = 1,
     THREAD_STACK_SIZE: Final[i64] = 0;

def mach_ticks -> u64;

def mach_timebase -> tuple[i64, i64];

def native_thread_id -> u64;

def condattr_set_monotonic(attr: ptr[u8]) -> i32;

def semaphore_timedwait(sema: ptr, abstime: ptr[timespec]) -> i32;

def timeval_store(tv: ptr[timeval], seconds: i64, microseconds: i64);

impl mach_ticks -> u64 {
    return u64(0);
}

impl mach_timebase -> tuple[i64, i64] {
    return (i64(1), i64(1));
}

impl native_thread_id -> u64 {
    tid: i64 = syscall(SYS_gettid, i64(0));
    return u64.wrap(tid);
}

impl condattr_set_monotonic(attr: ptr[u8]) -> i32 {
    return pthread_condattr_setclock(attr, CLOCK_MONOTONIC);
}

impl semaphore_timedwait(sema: ptr, abstime: ptr[timespec]) -> i32 {
    return sem_timedwait(sema, ptr(abstime));
}

impl timeval_store(tv: ptr[timeval], seconds: i64, microseconds: i64) {
    tv.view(1)[0].tv_sec = seconds;
    tv.view(1)[0].tv_usec = microseconds;
}
