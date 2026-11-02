"""<fcntl.h> struct flock as the macOS C library lays it out."""
import from c {
    obj flock_record {
        has l_start: i64 = 0,
            l_len: i64 = 0,
            l_pid: i32 = 0,
            l_type: i16 = 0,
            l_whence: i16 = 0;
    }
}

glob PLATFORM: str = "darwin";
