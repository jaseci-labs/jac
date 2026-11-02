"""Facilities of the time module that the Linux C library provides beyond POSIX.1."""
import from jaclang.runtime.python.modules.time_records { timespec }
import from c {
    def clock_nanosleep(
        clock: i32, flags: i32, request: &timespec, remain: ptr
    ) -> i32;  def pthread_getcpuclockid(thread: u64, clock: &mut i32) -> i32;
}

glob HAS_CLOCK_NANOSLEEP: bool = True,
     HAS_PTHREAD_GETCPUCLOCKID: bool = True;
