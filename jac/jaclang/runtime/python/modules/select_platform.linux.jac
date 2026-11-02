"""The I/O multiplexing calls of Linux: select(), poll() and epoll; no kqueue.

struct epoll_event is packed on x86_64 only, so its size and the offset of
its data member come from epoll_layout.<arch>.jac and events are addressed
as bytes.
"""
import from jaclang.runtime.python.bindings.members { MemberField }
import from jaclang.runtime.python.modules.epoll_layout {
    EPOLL_EVENT_SIZE,
    EPOLL_DATA_OFFSET
}
import from c {
    obj pollfd {
        has fd: i32 = 0,
            events: i16 = 0,
            revents: i16 = 0;
    }  def select(
        nfds: i32, readfds: ptr, writefds: ptr, exceptfds: ptr, timeout: ptr
    ) -> i32;  def poll(fds: ptr[pollfd], nfds: u64, timeout: i32) -> i32;  def epoll_create1(
        flags: i32
    ) -> i32;  def epoll_ctl(epfd: i32, op: i32, fd: i32, event: ptr) -> i32;  def epoll_wait(
        epfd: i32, events: ptr, maxevents: i32, timeout: i32
    ) -> i32;
}

# Linux has no kqueue; this record keeps the portable module typed.
import from c {
    obj kevent_record {
        has ident: u64 = 0,
            filter: i16 = 0,
            flags: u16 = 0,
            fflags: u32 = 0,
            data: i64 = 0,
            udata: u64 = 0;
    }
}

glob HAS_EPOLL: bool = True,
     HAS_KQUEUE: bool = False,
     KEVENT_SIZE: int = 32,
     KEVENT_MEMBERS: list[MemberField] = [],
     PROBE_BROKEN_POLL: bool = False;

def poll_fds(fds: ptr[pollfd], count: int, timeout: i32) -> i32 {
    return poll(fds, u64(count), timeout);
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
