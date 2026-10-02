"""struct stat in the asm-generic layout of Linux on aarch64 and the other newer architectures.

x86_64 Linux and macOS have their own stat_records variants; a target of
another system is rejected by the modules reading the record.
"""
import from c {
    obj _Py_stat_struct {
        has st_dev: u64 = 0,
            st_ino: u64 = 0,
            st_mode: u32 = 0,
            st_nlink: u32 = 0,
            st_uid: u32 = 0,
            st_gid: u32 = 0,
            st_rdev: u64 = 0,
            st_pad1: u64 = 0,
            st_size: i64 = 0,
            st_blksize: i32 = 0,
            st_pad2: i32 = 0,
            st_blocks: i64 = 0,
            st_atime_sec: i64 = 0,
            st_atime_nsec: i64 = 0,
            st_mtime_sec: i64 = 0,
            st_mtime_nsec: i64 = 0,
            st_ctime_sec: i64 = 0,
            st_ctime_nsec: i64 = 0,
            st_reserved_0: i32 = 0,
            st_reserved_1: i32 = 0;
    }
}
