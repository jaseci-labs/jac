"""<time.h> records for a target with no time_records.<os>.jac: the LP64 POSIX layout.

The time and select modules reject a target without generated constants, so
these declarations only keep cpython_api.jac and those modules well typed.
"""
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
    }  obj tms {
        has tms_utime: i64 = 0,
            tms_stime: i64 = 0,
            tms_cutime: i64 = 0,
            tms_cstime: i64 = 0;
    }
}
