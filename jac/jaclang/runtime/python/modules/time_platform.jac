"""Time facilities for a target with no time_platform.<os>.jac: none beyond POSIX.1."""
import from jaclang.runtime.python.modules.time_records { timespec }

glob HAS_CLOCK_NANOSLEEP: bool = False,
     HAS_PTHREAD_GETCPUCLOCKID: bool = False;

def clock_nanosleep(clock: i32, flags: i32, request: &timespec, remain: ptr) -> i32 {
    return i32(-1);
}

def pthread_getcpuclockid(thread: u64, clock: &mut i32) -> i32 {
    return i32(-1);
}
