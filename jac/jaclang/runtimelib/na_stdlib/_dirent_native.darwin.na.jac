"""Mechanism-F floor: dirent access at the darwin layout (#7626 C3).

macOS `struct dirent` (64-bit inode ABI) places `d_name` at byte offset
21: d_ino 8 + d_seekoff 8 + d_reclen 2 + d_namlen 2 + d_type 1. The
glibc/musl variant lives in `_dirent_native.na.jac` (offset 19); the
resolver picks this file when the native target OS is darwin.
"""

import from c { def strdup(s: int) -> str;  }

def:pub dirent_name(ent: int) -> str {
    return strdup(ent + 21);
}
