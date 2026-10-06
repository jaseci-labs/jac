"""POSIX semaphores as macOS provides them.

macOS has no sem_timedwait(), so a timed acquire polls (semaphore.c's
sem_timedwait_save); sem_getvalue() fails with ENOSYS (configure's
HAVE_BROKEN_SEM_GETVALUE); SEM_FAILED is (sem_t *)-1. suseconds_t is 32 bits.
"""

import from c {
    obj timeval {
        has tv_sec: i64 = 0,
            tv_usec: i32 = 0;
    }  obj timespec {
        has tv_sec: i64 = 0,
            tv_nsec: i64 = 0;
    }
}

glob PLATFORM: str = "darwin",
     HAVE_SEM_OPEN: bool = True,
     HAVE_SEM_TIMEDWAIT: bool = False,
     HAVE_BROKEN_SEM_GETVALUE: bool = True,
     HAVE_BROKEN_SEM_UNLINK: bool = False,
     SEM_FAILED: int = -1;

# Never called: HAVE_SEM_TIMEDWAIT is False.
def timed_wait(handle: ptr, deadline: timespec) -> i32 {
    return i32(-1);
}

def timeval_from(seconds: i64, microseconds: i64) -> timeval {
    return timeval(tv_sec=seconds, tv_usec=i32(microseconds));
}

def timeval_usec(value: timeval) -> i64 {
    return i64(value.tv_usec);
}
