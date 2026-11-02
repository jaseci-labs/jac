"""libuv C FFI bindings for the Jac-native runtime.

Provides typed wrappers around the core libuv API:
  - Event loop lifecycle  (uvloop_create, run, stop, close)
  - Timer handles         (uvtimer_create, start, stop, close)
  - Async signal handles  (uvasync_create, send, close)
  - Handle ref/unref      (uvhandle_unref, uvhandle_ref)
  - High-resolution clock (uvhrtime)
  - File I/O primitives   (uv_fs_open, uv_fs_read, uv_fs_write, …)
  - UVBuf struct           (binary-compatible with uv_buf_t)

Bun reference:
  bun/src/bun.js/VirtualMachine.zig  — uv_loop, uv_run, uv_async_send
  bun/src/bun.js/node/time_like.zig  — uv_timer_*
  bun/src/bun.js/node/node_fs.zig    — uv_fs_*
"""

# ── C library imports ────────────────────────────────────────────────────────

import from "libjs_native.so" {
    # Event loop
    def uv_loop_size -> int;  def uv_loop_init(loop: int) -> int;  def uv_loop_close(
        loop: int
    ) -> int;  def uv_loop_alive(loop: int) -> int;  def uv_default_loop -> int;  def uv_run(
        loop: int, mode: int
    ) -> int;  def uv_stop(loop: int) -> None;  def uv_update_time(loop: int) -> None;
    # Handle utilities
    def uv_handle_size(handle_type: int) -> int;  def uv_close(
        handle: int, cb: int
    ) -> None;
    # Timer
    def uv_timer_init(loop: int, handle: int) -> int;  def uv_timer_start(
        handle: int, cb: int, timeout: int, repeat: int
    ) -> int;  def uv_timer_stop(handle: int) -> int;
    # Async signal
    def uv_async_init(loop: int, handle: int, cb: int) -> int;  def uv_async_send(
        handle: int
    ) -> int;
    # Handle ref/unref
    def uv_unref(handle: int) -> None;  def uv_ref(handle: int) -> None;
    # Poll (fd readability watching)
    def uv_poll_init(loop: int, handle: int, fd: int) -> int;  def uv_poll_start(
        handle: int, events: int, cb: int
    ) -> int;  def uv_poll_stop(handle: int) -> int;
    # FS event (inotify / kqueue directory watch)
    def uv_fs_event_init(loop: int, handle: int) -> int;  def uv_fs_event_start(
        handle: int, cb: int, path: str, flags: int
    ) -> int;  def uv_fs_event_stop(handle: int) -> int;  def uv_fs_event_getpath(
        handle: int, buf: int, size_ptr: int
    ) -> int;
    # High-resolution clock
    def uv_hrtime -> int;
    # File I/O
    def uv_fs_open(
        loop: int, req: int, path: str, flags: int, mode: int, cb: int
    ) -> int;  def uv_fs_close(loop: int, req: int, fd: int, cb: int) -> int;  def uv_fs_read(
        loop: int, req: int, fd: int, bufs: int, nbufs: int, offset: int, cb: int
    ) -> int;  def uv_fs_write(
        loop: int, req: int, fd: int, bufs: int, nbufs: int, offset: int, cb: int
    ) -> int;  def uv_fs_stat(loop: int, req: int, path: str, cb: int) -> int;  def uv_fs_unlink(
        loop: int, req: int, path: str, cb: int
    ) -> int;  def uv_fs_access(
        loop: int, req: int, path: str, mode: int, cb: int
    ) -> int;  def uv_fs_mkdir(
        loop: int, req: int, path: str, mode: int, cb: int
    ) -> int;  def uv_fs_rmdir(loop: int, req: int, path: str, cb: int) -> int;  def uv_fs_rename(
        loop: int, req: int, path: str, new_path: str, cb: int
    ) -> int;  def uv_fs_scandir(
        loop: int, req: int, path: str, flags: int, cb: int
    ) -> int;  def uv_fs_scandir_next(req: int, dirent: int) -> int;  def uv_fs_copyfile(
        loop: int, req: int, path: str, new_path: str, flags: int, cb: int
    ) -> int;  def uv_fs_chmod(
        loop: int, req: int, path: str, mode: int, cb: int
    ) -> int;  def uv_fs_chown(
        loop: int, req: int, path: str, uid: int, gid: int, cb: int
    ) -> int;  def uv_fs_symlink(
        loop: int, req: int, path: str, new_path: str, flags: int, cb: int
    ) -> int;  def uv_fs_readlink(loop: int, req: int, path: str, cb: int) -> int;  def uv_fs_realpath(
        loop: int, req: int, path: str, cb: int
    ) -> int;  def uv_fs_lstat(loop: int, req: int, path: str, cb: int) -> int;  def uv_fs_fstat(
        loop: int, req: int, fd: int, cb: int
    ) -> int;  def uv_fs_ftruncate(
        loop: int, req: int, fd: int, offset: int, cb: int
    ) -> int;
    # Note: libuv has no uv_fs_truncate — path truncate is open+ftruncate+close.
    def uv_fs_utime(
        loop: int, req: int, path: str, atime: float, mtime: float, cb: int
    ) -> int;  def uv_fs_futime(
        loop: int, req: int, fd: int, atime: float, mtime: float, cb: int
    ) -> int;  def uv_fs_lutime(
        loop: int, req: int, path: str, atime: float, mtime: float, cb: int
    ) -> int;  def uv_fs_link(
        loop: int, req: int, path: str, new_path: str, cb: int
    ) -> int;  def uv_fs_fsync(loop: int, req: int, fd: int, cb: int) -> int;  def uv_fs_fdatasync(
        loop: int, req: int, fd: int, cb: int
    ) -> int;  def uv_fs_fchmod(
        loop: int, req: int, fd: int, mode: int, cb: int
    ) -> int;  def uv_fs_fchown(
        loop: int, req: int, fd: int, uid: int, gid: int, cb: int
    ) -> int;  def uv_fs_lchown(
        loop: int, req: int, path: str, uid: int, gid: int, cb: int
    ) -> int;  def uv_fs_statfs(loop: int, req: int, path: str, cb: int) -> int;
    # Error helpers
    def uv_err_name(err: int) -> str;  def uv_strerror(err: int) -> str;
    # uv_fs_t accessors
    def uv_fs_get_result(req: int) -> int;  def uv_fs_get_statbuf(req: int) -> int;  def uv_fs_get_ptr(
        req: int
    ) -> int;  def uv_fs_req_cleanup(req: int) -> None;
    # Request size
    def uv_req_size(req_type: int) -> int;
    # TCP stream
    def uv_tcp_init(loop: int, handle: int) -> int;  def uv_tcp_connect(
        req: int, handle: int, addr: int, cb: int
    ) -> int;  def uv_tcp_bind(handle: int, addr: int, flags: int) -> int;
    # Generic handle fd extraction
    def uv_fileno(handle: int, fd_out: int) -> int;
    # Networking helpers
    def uv_ip4_addr(ip: str, port: int, addr: int) -> int;  def uv_ip6_addr(
        ip: str, port: int, addr: int
    ) -> int;
}

import from "libc.so.6" {
    def calloc(n: int, size: int) -> int;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;
}

# ── Constants ────────────────────────────────────────────────────────────────

glob UV_RUN_DEFAULT: int = 0,
     UV_RUN_ONCE: int = 1,
     UV_RUN_NOWAIT: int = 2,
     UV_HANDLE_ASYNC: int = 1,
     UV_HANDLE_TIMER: int = 13,
     UV_HANDLE_POLL: int = 8,
     UV_HANDLE_FS_EVENT: int = 3;

# uv_fs_event event/status flags (libuv)
glob:pub UV_FS_EVENT_RENAME: int = 1,
     UV_FS_EVENT_CHANGE: int = 2,
     UV_FS_EVENT_RECURSIVE_FLAG: int = 4,
     UV_READABLE: int = 1,
     UV_WRITABLE: int = 2,
     UV_DISCONNECT: int = 4;

# Poll event flags
# ── UVLoop ───────────────────────────────────────────────────────────────────

"""Thin wrapper around a heap-allocated uv_loop_t pointer."""
obj:pub UVLoop {
    has loop_ptr: int = 0;
}

"""Allocate and initialise a new uv_loop_t."""
def:pub uvloop_create -> UVLoop {
    sz: int = uv_loop_size();
    ptr: int = calloc(1, sz);
    uv_loop_init(ptr);
    lp: UVLoop = UVLoop();
    lp.loop_ptr = ptr;
    return lp;
}

"""Update the cached loop time.  Call before creating timers to ensure
deadlines are relative to *now*, not the stale time from uv_loop_init."""
def:pub uvloop_update_time(lp: UVLoop) {
    uv_update_time(lp.loop_ptr);
}

"""Run the loop until all handles are closed (UV_RUN_DEFAULT)."""
def:pub uvloop_run_default(lp: UVLoop) -> int {
    return uv_run(lp.loop_ptr, UV_RUN_DEFAULT);
}

"""Run a single loop iteration, may block briefly (UV_RUN_ONCE)."""
def:pub uvloop_run_once(lp: UVLoop) -> int {
    return uv_run(lp.loop_ptr, UV_RUN_ONCE);
}

"""Poll for pending callbacks without blocking (UV_RUN_NOWAIT)."""
def:pub uvloop_run_nowait(lp: UVLoop) -> int {
    return uv_run(lp.loop_ptr, UV_RUN_NOWAIT);
}

"""Stop the loop."""
def:pub uvloop_stop(lp: UVLoop) {
    uv_stop(lp.loop_ptr);
}

"""Close the loop. All handles must already be closed."""
def:pub uvloop_close(lp: UVLoop) -> int {
    return uv_loop_close(lp.loop_ptr);
}

"""Return non-zero if the loop has active handles or pending requests."""
def:pub uvloop_alive(lp: UVLoop) -> int {
    return uv_loop_alive(lp.loop_ptr);
}

"""Return the default event loop pointer."""
def:pub uvloop_default -> int {
    return uv_default_loop();
}

# ── UVHandle ─────────────────────────────────────────────────────────────────

"""Base wrapper for any libuv handle (timer, async, etc.)."""
obj:pub UVHandle {
    has handle_ptr: int = 0,
        handle_type: int = 0;
}

# ── Timer handles ────────────────────────────────────────────────────────────

"""Return the byte size of a uv_timer_t handle."""
def:pub uv_timer_size -> int {
    return uv_handle_size(UV_HANDLE_TIMER);
}

"""Allocate and initialise a uv_timer_t on the given loop."""
def:pub uvtimer_create(lp: UVLoop) -> UVHandle {
    sz: int = uv_handle_size(UV_HANDLE_TIMER);
    ptr: int = calloc(1, sz);
    uv_timer_init(lp.loop_ptr, ptr);
    h: UVHandle = UVHandle();
    h.handle_ptr = ptr;
    h.handle_type = UV_HANDLE_TIMER;
    return h;
}

"""Start the timer. cb is a raw function pointer; timeout/repeat in ms."""
def:pub uvtimer_start(h: UVHandle, cb: int, timeout: int, repeat: int) -> int {
    return uv_timer_start(h.handle_ptr, cb, timeout, repeat);
}

"""Stop a running timer (does not close the handle)."""
def:pub uvtimer_stop(h: UVHandle) -> int {
    return uv_timer_stop(h.handle_ptr);
}

"""Stop and close a timer handle."""
def:pub uvtimer_close(h: UVHandle) {
    uv_timer_stop(h.handle_ptr);
    uv_close(h.handle_ptr, 0);
}

# ── Async signal handles ─────────────────────────────────────────────────────

"""Return the byte size of a uv_async_t handle."""
def:pub uv_async_size -> int {
    return uv_handle_size(UV_HANDLE_ASYNC);
}

"""Allocate and initialise a uv_async_t on the given loop."""
def:pub uvasync_create(lp: UVLoop, cb: int) -> UVHandle {
    sz: int = uv_handle_size(UV_HANDLE_ASYNC);
    ptr: int = calloc(1, sz);
    uv_async_init(lp.loop_ptr, ptr, cb);
    h: UVHandle = UVHandle();
    h.handle_ptr = ptr;
    h.handle_type = UV_HANDLE_ASYNC;
    return h;
}

"""Send an async signal. Safe to call from any thread."""
def:pub uvasync_send(h: UVHandle) -> int {
    return uv_async_send(h.handle_ptr);
}

"""Close an async handle."""
def:pub uvasync_close(h: UVHandle) {
    uv_close(h.handle_ptr, 0);
}

# ── Handle ref / unref ────────────────────────────────────────────────────────

"""Unref a handle so it does not keep the loop alive."""
def:pub uvhandle_unref(h: UVHandle) {
    uv_unref(h.handle_ptr);
}

"""Re-reference a previously unref'd handle."""
def:pub uvhandle_ref(h: UVHandle) {
    uv_ref(h.handle_ptr);
}

# ── Poll handles ─────────────────────────────────────────────────────────────

"""Allocate and initialise a uv_poll_t watching the given file descriptor."""
def:pub uvpoll_create(lp: UVLoop, fd: int) -> UVHandle {
    sz: int = uv_handle_size(UV_HANDLE_POLL);
    ptr: int = calloc(1, sz);
    uv_poll_init(lp.loop_ptr, ptr, fd);
    h: UVHandle = UVHandle();
    h.handle_ptr = ptr;
    h.handle_type = UV_HANDLE_POLL;
    return h;
}

"""Start polling for the given events (UV_READABLE, UV_WRITABLE, etc.)."""
def:pub uvpoll_start(h: UVHandle, events: int, cb: int) -> int {
    return uv_poll_start(h.handle_ptr, events, cb);
}

"""Stop polling."""
def:pub uvpoll_stop(h: UVHandle) -> int {
    return uv_poll_stop(h.handle_ptr);
}

"""Close a poll handle."""
def:pub uvpoll_close(h: UVHandle) {
    uv_poll_stop(h.handle_ptr);
    uv_close(h.handle_ptr, 0);
}

# ── FS event handles (fs.watch backend) ──────────────────────────────────────

"""Allocate and initialise a uv_fs_event_t on the given loop."""
def:pub uv_fsevent_create(lp: UVLoop) -> UVHandle {
    sz: int = uv_handle_size(UV_HANDLE_FS_EVENT);
    ptr: int = calloc(1, sz);
    uv_fs_event_init(lp.loop_ptr, ptr);
    h: UVHandle = UVHandle();
    h.handle_ptr = ptr;
    h.handle_type = UV_HANDLE_FS_EVENT;
    return h;
}

"""Start watching `path`. flags may include UV_FS_EVENT_RECURSIVE_FLAG."""
def:pub uv_fsevent_start(h: UVHandle, cb: int, path: str, flags: int) -> int {
    return uv_fs_event_start(h.handle_ptr, cb, path, flags);
}

def:pub uv_fsevent_stop(h: UVHandle) -> int {
    return uv_fs_event_stop(h.handle_ptr);
}

def:pub uv_fsevent_close(h: UVHandle) {
    uv_fs_event_stop(h.handle_ptr);
    uv_close(h.handle_ptr, 0);
}

# ── High-resolution clock ─────────────────────────────────────────────────────

"""Return monotonic high-resolution time in nanoseconds."""
def:pub uvhrtime -> int {
    return uv_hrtime();
}

# ── UVBuf ─────────────────────────────────────────────────────────────────────

"""Binary-compatible with uv_buf_t: { char* base, size_t len }.
Jac str = i8* and int = i64, giving {i8*, i64} = uv_buf_t on x86_64."""
obj:pub UVBuf {
    has base: str = "",
        buf_len: int = 0;
}
