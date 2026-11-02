"""The I/O multiplexing calls of macOS: select(), poll() and kqueue(); no epoll.

struct kevent is laid out as <sys/event.h> declares it; KEVENT_MEMBERS gives
the offsets and structmember types CPython publishes its fields with.
"""
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
    }  def select(
        nfds: i32, readfds: ptr, writefds: ptr, errorfds: ptr, timeout: ptr
    ) -> i32;  def poll(fds: ptr[pollfd], nfds: u32, timeout: i32) -> i32;  def kqueue -> i32;  def kevent(
        kq: i32,
        changelist: ptr[kevent_record],
        nchanges: i32,
        eventlist: ptr[kevent_record],
        nevents: i32,
        timeout: ptr
    ) -> i32;
}

glob HAS_EPOLL: bool = False,
     HAS_KQUEUE: bool = True,
     KEVENT_SIZE: int = 32,
     # ident and udata are uintptr_t (Py_T_ULONGLONG), filter a short,
     # flags an unsigned short, fflags an unsigned int, data an intptr_t.
     KEVENT_MEMBERS: list[MemberField] = [
         MemberField(name="ident", kind=18, offset=0),
         MemberField(name="filter", kind=0, offset=8),
         MemberField(name="flags", kind=10, offset=10),
         MemberField(name="fflags", kind=11, offset=12),
         MemberField(name="data", kind=17, offset=16),
         MemberField(name="udata", kind=18, offset=24)
     ],
     EPOLL_EVENT_SIZE: int = 16,
     EPOLL_DATA_OFFSET: int = 8,
     # poll() may flag invalid descriptors with an error instead of POLLNVAL
     # on some releases, so the module probes it before publishing poll.
     PROBE_BROKEN_POLL: bool = True;

def poll_fds(fds: ptr[pollfd], count: int, timeout: i32) -> i32 {
    return poll(fds, u32(count), timeout);
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
