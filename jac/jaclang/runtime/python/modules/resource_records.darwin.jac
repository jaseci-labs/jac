"""<sys/resource.h> records as the macOS C library lays them out; no prlimit."""
import from c {
    # suseconds_t is 32 bits on macOS; the struct keeps 8-byte alignment.
    obj timeval {
        has tv_sec: i64 = 0,
            tv_usec: i32 = 0;
    }  obj rusage {
        has ru_utime: timeval = timeval(),
            ru_stime: timeval = timeval(),
            ru_maxrss: i64 = 0,
            ru_ixrss: i64 = 0,
            ru_idrss: i64 = 0,
            ru_isrss: i64 = 0,
            ru_minflt: i64 = 0,
            ru_majflt: i64 = 0,
            ru_nswap: i64 = 0,
            ru_inblock: i64 = 0,
            ru_oublock: i64 = 0,
            ru_msgsnd: i64 = 0,
            ru_msgrcv: i64 = 0,
            ru_nsignals: i64 = 0,
            ru_nvcsw: i64 = 0,
            ru_nivcsw: i64 = 0;
    }  obj rlimit {
        has rlim_cur: u64 = 0,
            rlim_max: u64 = 0;
    }
}

glob PLATFORM: str = "darwin",
     HAS_PRLIMIT: bool = False;

# macOS has no prlimit(2); the binding leaves resource.prlimit out there.
def prlimit(
    pid: i32,
    resource: i32,
    new_limit: &mut Pinned[rlimit] | None,
    old_limit: &mut rlimit
) -> i32 {
    return i32(-1);
}
