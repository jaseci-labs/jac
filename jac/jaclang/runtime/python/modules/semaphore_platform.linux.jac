"""POSIX semaphores as glibc provides them.

glibc has sem_timedwait() and a working sem_getvalue(); SEM_FAILED is NULL.
The 2.17 baseline the Linux builds target predates sem_clockwait().
"""

import from c {
    obj timeval {
        has tv_sec: i64 = 0,
            tv_usec: i64 = 0;
    }  obj timespec {
        has tv_sec: i64 = 0,
            tv_nsec: i64 = 0;
    }  def sem_timedwait(semaphore: ptr, abstime: &timespec) -> i32;
}

glob PLATFORM: str = "linux",
     HAVE_SEM_OPEN: bool = True,
     HAVE_SEM_TIMEDWAIT: bool = True,
     HAVE_BROKEN_SEM_GETVALUE: bool = False,
     HAVE_BROKEN_SEM_UNLINK: bool = False,
     SEM_FAILED: int = 0;

def timed_wait(handle: ptr, deadline: timespec) -> i32 {
    return sem_timedwait(handle, &deadline);
}

def timeval_from(seconds: i64, microseconds: i64) -> timeval {
    return timeval(tv_sec=seconds, tv_usec=microseconds);
}

def timeval_usec(value: timeval) -> i64 {
    return value.tv_usec;
}
