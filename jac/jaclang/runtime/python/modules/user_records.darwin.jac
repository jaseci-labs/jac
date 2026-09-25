"""<pwd.h> and <grp.h> records as the macOS C library lays them out."""
import from c {
    obj passwd {
        has pw_name: ptr[u8] = ptr[u8](),
            pw_passwd: ptr[u8] = ptr[u8](),
            pw_uid: u32 = 0,
            pw_gid: u32 = 0,
            pw_change: i64 = 0,
            pw_class: ptr[u8] = ptr[u8](),
            pw_gecos: ptr[u8] = ptr[u8](),
            pw_dir: ptr[u8] = ptr[u8](),
            pw_shell: ptr[u8] = ptr[u8](),
            pw_expire: i64 = 0;
    }
}

glob:pub PLATFORM: str = "darwin";

glob:pub SC_GETPW_R_SIZE_MAX: i32 = 71,
     SC_GETGR_R_SIZE_MAX: i32 = 70;
