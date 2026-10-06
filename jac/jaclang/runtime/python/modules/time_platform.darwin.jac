"""Facilities of the time module that macOS lacks: clock_nanosleep and pthread_getcpuclockid.

time.sleep() uses nanosleep() here, and time.pthread_getcpuclockid is not
published; the stand-ins keep the portable module well typed and are never
called.
"""
import from jaclang.runtime.python.modules.time_records { timespec }

glob HAS_CLOCK_NANOSLEEP: bool = False,
     HAS_PTHREAD_GETCPUCLOCKID: bool = False;

def clock_nanosleep(clock: i32, flags: i32, request: &timespec, remain: ptr) -> i32 {
    return i32(-1);
}

def pthread_getcpuclockid(thread: u64, clock: &mut i32) -> i32 {
    return i32(-1);
}
