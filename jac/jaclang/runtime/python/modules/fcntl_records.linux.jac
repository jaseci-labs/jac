"""<fcntl.h> struct flock as glibc lays it out on 64-bit Linux (off_t is 64 bits)."""
import from c {
    obj flock_record {
        has l_type: i16 = 0,
            l_whence: i16 = 0,
            l_start: i64 = 0,
            l_len: i64 = 0,
            l_pid: i32 = 0;
    }
}

glob PLATFORM: str = "linux";
