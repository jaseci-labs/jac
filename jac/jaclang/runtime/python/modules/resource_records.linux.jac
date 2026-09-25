"""<sys/resource.h> records and prlimit as the Linux C library provides them."""
import from c {
    obj timeval {
        has tv_sec: i64 = 0,
            tv_usec: i64 = 0;
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
    }  def prlimit(
        pid: i32,
        resource: i32,
        new_limit: &mut Pinned[rlimit] | None,
        old_limit: &mut rlimit
    ) -> i32;
}

glob:pub PLATFORM: str = "linux",
     HAS_PRLIMIT: bool = True;
