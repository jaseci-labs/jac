import from c { def poll(fds: bytes, nfds: u64, timeout: i32) -> i32;  }

glob _FD_SETSIZE: int = 1024,
     _POLLIN: int = 1,
     _POLLOUT: int = 4,
     _POLLERR: int = 8,
     _POLLNVAL: int = 32,
     _POLLHUP: int = 16;


def _add_entry(buf: bytes, slot: int, fd: int, events: int) {
    base: int = slot * 8;
    buf[base] = fd & 0xFF;
    buf[base + 1] = (fd >> 8) & 0xFF;
    buf[base + 2] = (fd >> 16) & 0xFF;
    buf[base + 3] = (fd >> 24) & 0xFF;

    buf[base + 4] = events & 0xFF;
    buf[base + 5] = (events >> 8) & 0xFF;
}


def _revents_at(buf: bytes, slot: int) -> int {
    return int.from_bytes(buf[slot * 8 + 6:slot * 8 + 8], "little");
}


def _fd_at(buf: bytes, slot: int) -> int {
    return int.from_bytes(buf[slot * 8:slot * 8 + 4], "little");
}


def _check_fd(fd: int) {
    if fd < 0 or fd >= _FD_SETSIZE {
        raise ValueError("filedescriptor out of range in select()");
    }
}


def _add_fds(lst: list[int], events: int, fds: list[int], masks: list[int]) {
    for fd in lst {
        _check_fd(fd);
        found: bool = False;
        k: int = 0;
        while k < len(fds) {
            if fds[k] == fd {
                masks[k] = masks[k] | events;
                found = True;
                break;
            }
            k += 1;
        }
        if not found {
            fds.append(fd);
            masks.append(events);
        }
    }
}


def:pub select(
    rlist: list[int], wlist: list[int], xlist: list[int], timeout: float = -1.0
) -> tuple[(list[int], list[int], list[int])] {
    fds: list[int] = [];
    masks: list[int] = [];

    _add_fds(rlist, _POLLIN | _POLLERR, fds, masks);
    _add_fds(wlist, _POLLOUT | _POLLERR, fds, masks);
    for fd in xlist {
        _check_fd(fd);
    }

    n: int = len(fds);
    buf: bytes = b"\x00" * ((n * 8) + 1);
    k: int = 0;
    while k < n {
        _add_entry(buf, k, fds[k], masks[k]);
        k += 1;
    }

    tmo: int = -1;
    if timeout >= 0.0 {
        tmo = int(timeout * 1000.0);
    } elif timeout < -1.0 {
        raise ValueError("select() timeout must be non-negative");
    }
    rc: int = poll(buf, u64(n), i32(tmo));
    if rc < 0 {
        raise ValueError("poll failed");
    }
    out_r: list[int] = [];
    out_w: list[int] = [];
    out_x: list[int] = [];
    k = 0;
    while k < n {
        rev: int = _revents_at(buf, k);
        if (rev & _POLLNVAL) != 0 {
            raise ValueError("invalid file descriptor in select()");
        }
        if rev != 0 {
            fd: int = _fd_at(buf, k);
            if (rev & (_POLLIN | _POLLERR | _POLLHUP)) != 0 {
                out_r.append(fd);
            }
            if (rev & (_POLLOUT | _POLLERR | _POLLHUP)) != 0 {
                out_w.append(fd);
            }
        }
        k += 1;
    }
    return (out_r, out_w, out_x);
}
