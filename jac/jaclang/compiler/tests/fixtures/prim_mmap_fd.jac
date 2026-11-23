"""Native-only probe for fd-backed ``mmap`` on device and regular files.

Compiled and run on the na lane only: obtaining a real descriptor needs
``_fd_native``, which has no Python binding, so there is no sv/cl
counterpart. ``mm_isreg`` must classify ``/dev/zero`` (character device) as
non-regular so the regular-file size/lseek validation is skipped, while
``/etc/hosts`` (regular file) keeps it.
"""

import from mmap { mmap, ACCESS_READ }
import from _fd_native { open_readonly }
import from _mmap_native { mm_isreg, mm_close_fd }


def _try_map(fd: int, length: int) -> str {
    try {
        m = mmap(fd, length, access=ACCESS_READ);
        m.close();
        return "ok";
    } except OSError {
        return "oserror";
    } except ValueError {
        return "valueerror";
    }
}


def mmap_fd_probe -> dict[str, any] {
    r: dict[str, any] = {};
    zfd = open_readonly("/dev/zero");
    r["zero_fd"] = zfd;
    r["zero_isreg"] = 1 if mm_isreg(zfd) else 0;
    r["zero_map"] = _try_map(zfd, 4096);
    mm_close_fd(zfd);
    hfd = open_readonly("/etc/hosts");
    r["hosts_fd"] = hfd;
    r["hosts_isreg"] = 1 if mm_isreg(hfd) else 0;
    r["hosts_huge"] = _try_map(hfd, 1099511627776);
    r["hosts_small"] = _try_map(hfd, 16);
    mm_close_fd(hfd);
    return r;
}
