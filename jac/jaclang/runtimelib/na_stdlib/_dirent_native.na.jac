"""Mechanism-F floor: dirent access at the glibc/musl layout (#7626 C3).

`readdir` returns `struct dirent*`; `d_name` sits at byte offset 19 on
glibc and musl (d_ino 8 + d_off 8 + d_reclen 2 + d_type 1). The darwin
variant of this floor (`_dirent_native.darwin.na.jac`) uses offset 21
(d_ino 8 + d_seekoff 8 + d_reclen 2 + d_namlen 2 + d_type 1); the
resolver picks the `<name>.<os>.na.jac` file matching the native target.
"""

import from c { def strdup(s: int) -> str;  }

def:pub dirent_name(ent: int) -> str {
    return strdup(ent + 19);
}
