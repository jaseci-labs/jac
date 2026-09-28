"""<uuid/uuid.h> for a target whose C library provides none.

Zig's glibc sysroot, which the Linux builds link against, has no libuuid, so
configure leaves HAVE_UUID_H and HAVE_UUID_UUID_H undefined there: _uuid then
offers no generator and uuid.py falls back to its own. generate_time() is
never called on such a target; the binding does not register the function.
"""

glob HAVE_UUID_HEADER: bool = False,
     HAVE_GENERATE_TIME_SAFE: bool = False,
     HAVE_GENERATE_TIME_SAFE_STABLE_MAC: bool = False;

def generate_time(out: ptr[u8]) -> i32 {
    return i32(-1);
}
