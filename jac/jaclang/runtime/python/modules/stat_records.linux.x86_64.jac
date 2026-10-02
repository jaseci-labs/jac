"""struct stat as the Linux C library lays it out on x86_64."""
import from c {
    obj _Py_stat_struct {
        has st_dev: u64 = 0,
            st_ino: u64 = 0,
            st_nlink: u64 = 0,
            st_mode: u32 = 0,
            st_uid: u32 = 0,
            st_gid: u32 = 0,
            st_pad0: i32 = 0,
            st_rdev: u64 = 0,
            st_size: i64 = 0,
            st_blksize: i64 = 0,
            st_blocks: i64 = 0,
            st_atime_sec: i64 = 0,
            st_atime_nsec: i64 = 0,
            st_mtime_sec: i64 = 0,
            st_mtime_nsec: i64 = 0,
            st_ctime_sec: i64 = 0,
            st_ctime_nsec: i64 = 0,
            st_reserved_0: i64 = 0,
            st_reserved_1: i64 = 0,
            st_reserved_2: i64 = 0;
    }
}
