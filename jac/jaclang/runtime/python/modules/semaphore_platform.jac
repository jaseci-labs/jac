"""POSIX semaphores for a target with no semaphore_platform.<os>.jac.

HAVE_SEM_OPEN is False, so _multiprocessing offers no SemLock there;
timed_wait() is never called.
"""

import from c {
    obj timeval {
        has tv_sec: i64 = 0,
            tv_usec: i64 = 0;
    }  obj timespec {
        has tv_sec: i64 = 0,
            tv_nsec: i64 = 0;
    }
}

glob PLATFORM: str = "",
     HAVE_SEM_OPEN: bool = False,
     HAVE_SEM_TIMEDWAIT: bool = False,
     HAVE_BROKEN_SEM_GETVALUE: bool = False,
     HAVE_BROKEN_SEM_UNLINK: bool = False,
     SEM_FAILED: int = 0;

def timed_wait(handle: ptr, deadline: timespec) -> i32 {
    return i32(-1);
}

def timeval_from(seconds: i64, microseconds: i64) -> timeval {
    return timeval(tv_sec=seconds, tv_usec=microseconds);
}

def timeval_usec(value: timeval) -> i64 {
    return value.tv_usec;
}
