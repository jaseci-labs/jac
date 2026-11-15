impl _check_fd(fd: int) {
    if fd < 0 or fd >= _FD_SETSIZE {
        raise ValueError("filedescriptor out of range in select()");
    }
}

impl _add_fds(lst: list[int], events: int, fds: list[int], masks: list[int]) {
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

impl select(
    rlist: list[int], wlist: list[int], xlist: list[int], timeout: (float | None) = -1.0
) -> tuple[(list[int], list[int], list[int])] {
    fds: list[int] = [];
    masks: list[int] = [];

    _add_fds(rlist, _POLLIN | _POLLERR, fds, masks);
    _add_fds(wlist, _POLLOUT | _POLLERR, fds, masks);
    for fd in xlist {
        _check_fd(fd);
    }

    tmo: int = -1;
    deadline_ns: int = -1;
    if timeout is None {
        tmo = -1;
    } elif timeout >= 0.0 {
        tmo = int(timeout * 1000.0);
        deadline_ns = time.monotonic_ns() + int(timeout * 1000000000.0);
    } elif timeout != -1.0 {
        raise ValueError("timeout must be None, -1.0 (block), or non-negative");
    }
    res: list[int] = do_poll(fds, masks, tmo);
    while res[0] < 0 and last_errno() == EINTR {
        if deadline_ns >= 0 {
            left_ns: int = deadline_ns - time.monotonic_ns();
            if left_ns < 0 {
                return ([], [], []);
            }
            tmo = (left_ns + 999999) // 1000000;
        }
        res = do_poll(fds, masks, tmo);
    }
    if res[0] < 0 {
        raise ValueError(
            "poll failed: [Errno " + str(last_errno()) + "] " + errno_message()
        );
    }
    n: int = len(fds);
    k: int = 0;
    while k < n {
        if (res[k + 1] & _POLLNVAL) != 0 {
            raise ValueError("invalid file descriptor in select()");
        }
        k += 1;
    }
    out_r: list[int] = _ready(rlist, fds, res, _POLLIN | _POLLERR | _POLLHUP);
    out_w: list[int] = _ready(wlist, fds, res, _POLLOUT | _POLLERR | _POLLHUP);
    out_x: list[int] = [];
    return (out_r, out_w, out_x);
}

impl _ready(lst: list[int], fds: list[int], res: list[int], ready: int) -> list[int] {
    out: list[int] = [];
    for fd in lst {
        k: int = 0;
        while k < len(fds) {
            if fds[k] == fd {
                if (res[k + 1] & ready) != 0 {
                    out.append(fd);
                }
                break;
            }
            k += 1;
        }
    }
    return out;
}
