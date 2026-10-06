"""I/O multiplexing for a target with no select_platform.<os>.jac; the module rejects it."""

import from jaclang.runtime.python.bindings.members { MemberField }
import from c {
    obj pollfd {
        has fd: i32 = 0,
            events: i16 = 0,
            revents: i16 = 0;
    }  obj kevent_record {
        has ident: u64 = 0,
            filter: i16 = 0,
            flags: u16 = 0,
            fflags: u32 = 0,
            data: i64 = 0,
            udata: u64 = 0;
    }
}

glob HAS_EPOLL: bool = False,
     HAS_KQUEUE: bool = False,
     KEVENT_SIZE: int = 32,
     KEVENT_MEMBERS: list[MemberField] = [],
     EPOLL_EVENT_SIZE: int = 16,
     EPOLL_DATA_OFFSET: int = 8,
     PROBE_BROKEN_POLL: bool = False;

def select(
    nfds: i32, readfds: ptr, writefds: ptr, exceptfds: ptr, timeout: ptr
) -> i32 {
    return i32(-1);
}

def poll_fds(fds: ptr[pollfd], count: int, timeout: i32) -> i32 {
    return i32(-1);
}

def kqueue -> i32 {
    return i32(-1);
}

def kevent(
    kq: i32,
    changelist: ptr[kevent_record],
    nchanges: i32,
    eventlist: ptr[kevent_record],
    nevents: i32,
    timeout: ptr
) -> i32 {
    return i32(-1);
}

def epoll_create1(flags: i32) -> i32 {
    return i32(-1);
}

def epoll_ctl(epfd: i32, op: i32, fd: i32, event: ptr) -> i32 {
    return i32(-1);
}

def epoll_wait(epfd: i32, events: ptr, maxevents: i32, timeout: i32) -> i32 {
    return i32(-1);
}
