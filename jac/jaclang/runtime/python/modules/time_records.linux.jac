"""<time.h>, <sys/time.h> and <sys/times.h> records as the Linux C library lays them out."""
import from c {
    obj timespec {
        has tv_sec: i64 = 0,
            tv_nsec: i64 = 0;
    }  obj timeval {
        has tv_sec: i64 = 0,
            tv_usec: i64 = 0;
    }  obj tm {
        has tm_sec: i32 = 0,
            tm_min: i32 = 0,
            tm_hour: i32 = 0,
            tm_mday: i32 = 0,
            tm_mon: i32 = 0,
            tm_year: i32 = 0,
            tm_wday: i32 = 0,
            tm_yday: i32 = 0,
            tm_isdst: i32 = 0,
            tm_gmtoff: i64 = 0,
            tm_zone: ptr[u8] = ptr[u8]();
    }
    # clock_t is long.
    obj tms {
        has tms_utime: i64 = 0,
            tms_stime: i64 = 0,
            tms_cutime: i64 = 0,
            tms_cstime: i64 = 0;
    }
}
