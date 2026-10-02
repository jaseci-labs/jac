"""struct stat as the macOS C library lays it out (64-bit inodes, every architecture)."""
import from c {
    obj _Py_stat_struct {
        has st_dev: i32 = 0,
            st_mode: u16 = 0,
            st_nlink: u16 = 0,
            st_ino: u64 = 0,
            st_uid: u32 = 0,
            st_gid: u32 = 0,
            st_rdev: i32 = 0,
            st_atime_sec: i64 = 0,
            st_atime_nsec: i64 = 0,
            st_mtime_sec: i64 = 0,
            st_mtime_nsec: i64 = 0,
            st_ctime_sec: i64 = 0,
            st_ctime_nsec: i64 = 0,
            st_birthtime_sec: i64 = 0,
            st_birthtime_nsec: i64 = 0,
            st_size: i64 = 0,
            st_blocks: i64 = 0,
            st_blksize: i32 = 0,
            st_flags: u32 = 0,
            st_gen: u32 = 0,
            st_lspare: i32 = 0,
            st_qspare_0: i64 = 0,
            st_qspare_1: i64 = 0;
    }
}
