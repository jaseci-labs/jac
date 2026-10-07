"""File System API (libuv-based).

Provides Node.js-compatible file system operations using libuv uv_fs_*
functions in synchronous mode (cb=0). Async variants perform the I/O
synchronously then defer the JS callback to the next event loop tick.

  Sync:  readFileSync, writeFileSync, appendFileSync, existsSync,
         unlinkSync, statSync
  Async: readFile, writeFile

Bun reference:
  bun/src/bun.js/node/node_fs.zig
  bun/src/bun.js/node/NodeFS.zig

Node.js spec:
  https://nodejs.org/api/fs.html

Import constraints:
  Must NOT import vm.event_loop, runtime.global, vm.vm, or builtins.dispatch
  to avoid circular dependencies. Uses the fired-queue accessor pattern.
"""

# ── Imports ──────────────────────────────────────────────────────────────────

import from engine.src.ffi.libuv {
    uv_default_loop,
    uvhandle_ref,
    uvhandle_unref,
    uv_fs_open,
    uv_fs_close,
    uv_fs_read,
    uv_fs_write,
    uv_fs_stat,
    uv_fs_unlink,
    uv_fs_access,
    uv_fs_mkdir,
    uv_fs_rmdir,
    uv_fs_rename,
    uv_fs_scandir,
    uv_fs_scandir_next,
    uv_fs_copyfile,
    uv_fs_chmod,
    uv_fs_chown,
    uv_fs_symlink,
    uv_fs_readlink,
    uv_fs_realpath,
    uv_fs_lstat,
    uv_fs_fstat,
    uv_fs_ftruncate,
    uv_fs_utime,
    uv_fs_futime,
    uv_fs_lutime,
    uv_fs_link,
    uv_fs_fsync,
    uv_fs_fdatasync,
    uv_fs_fchmod,
    uv_fs_fchown,
    uv_fs_lchown,
    uv_fs_statfs,
    uv_err_name,
    uv_strerror,
    uv_fs_get_result,
    uv_fs_get_statbuf,
    uv_fs_get_ptr,
    uv_fs_req_cleanup,
    uv_req_size,
    calloc,
    memcpy,
    UVBuf,
    UVHandle,
    uvasync_send
}

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_int,
    jsv_is_string_cell,
    jsv_is_undefined,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_to_table_id,
    jsv_to_int32,
    jsv_to_double,
    jsv_from_string_id,
    jsv_from_double
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_set,
    js_object_get
}
import from engine.src.runtime.jsstring {
    str_intern,
    str_heap,
    str_from_id,
    str_stamp_copy
}
import from engine.src.builtins.array { js_array_create }
import from engine.src.ffi.libc { calloc, free, mkdtemp }
import from engine.src.runtime.mem {
    read_byte,
    write_byte,
    write_i64,
    io_alloc,
    io_free,
    str_from_foreign_cstr
}
import from engine.src.runtime.jsstring {
    wire_utf8_needs_convert,
    wire_utf8_len,
    wire_utf8_write
}
import from engine.src.builtins.path_utils { path_split, path_normalize, path_dirname }
import from engine.src.runtime.error { vm_throw_native }
import from engine.src.runtime.gc_pin { gc_pin_live_list }

# ── Constants ────────────────────────────────────────────────────────────────

glob _O_RDONLY: int = 0,
     _O_WRONLY: int = 1,
     _O_RDWR: int = 2,
     _O_CREAT: int = 64,
     _O_EXCL: int = 128,
     _O_TRUNC: int = 512,
     _O_APPEND: int = 1024,
     _F_OK: int = 0,
     _UV_REQ_FS: int = 6,
     _FS_FIRED_FNS: list[JSValue] = [],
     _FS_FIRED_ARGS: list[list[JSValue]] = [],
     _FS_FIRED_ARG_ROOTS: list[JSValue] = [],
     _FS_FIRED_ROOTED: bool = False,
     _FS_ASYNC_PTR: int = 0,
     _FS_ASYNC_REFFED: bool = False,
     _FS_LOOP_PTR: int = 0;

# ── Deferred callback fired queue ────────────────────────────────────────────

# Flat mirror of every JSValue inside _FS_FIRED_ARGS — gc_pin_live_list only
# traces list[JSValue], so callback arg values (e.g. Buffers) are rooted here.

# True while fired callbacks are queued: the shared wake handle is unref'd at
# init, so pending fs completions must ref it or uv_run returns before they
# are delivered (they then ran in the post-loop flush, and anything they
# scheduled — timers, immediates, a child ref()+write, i.e. esbuild's >1MB
# temp-file request — was never run: vite render+write 'Unexpected early exit').
"""Initialise the fs subsystem (called once from el_run)."""
def:pub fs_init(async_ptr: int) {
    _FS_ASYNC_PTR = async_ptr;
}

"""Store event loop pointer for fs_event handles."""
def:pub fs_init_loop_ptr(loop_ptr: int) {
    _FS_LOOP_PTR = loop_ptr;
}

"""Alias for fs_watch — push bridge callback onto fs fired queue."""
def:pub fs_push_watch_callback(cb: JSValue, args: list[JSValue]) {
    _fs_push_callback(cb, args);
}

"""Return the number of pending fired fs callbacks."""
def:pub fs_fired_count -> int {
    return len(_FS_FIRED_FNS);
}

"""Return the i-th fired callback function."""
def:pub fs_fired_fn(idx: int) -> JSValue {
    return _FS_FIRED_FNS[idx];
}

"""Return the i-th fired callback args list."""
def:pub fs_fired_args(idx: int) -> list[JSValue] {
    return _FS_FIRED_ARGS[idx];
}

"""Remove the first n entries from the fired queues.

O(remaining) rebuild instead of repeated `del [0]` (O(n^2) batch drain)."""
def:pub fs_fired_clear(n: int) -> None {
    if n <= 0 {
        return;
    }
    fs_fn_kept: list[JSValue] = [];
    fs_arg_kept: list[list[JSValue]] = [];
    fs_i: int = n;
    fs_len: int = len(_FS_FIRED_FNS);
    while fs_i < fs_len {
        fs_fn_kept.append(_FS_FIRED_FNS[fs_i]);
        fs_arg_kept.append(_FS_FIRED_ARGS[fs_i]);
        fs_i = fs_i + 1;
    }
    # Rebuild IN PLACE — _FS_FIRED_FNS / _FS_FIRED_ARG_ROOTS identities are
    # GC-rooted via gc_pin_live_list; reassignment would orphan the root.
    while len(_FS_FIRED_FNS) > 0 {
        del _FS_FIRED_FNS[len(_FS_FIRED_FNS) - 1];
    }
    while len(_FS_FIRED_ARG_ROOTS) > 0 {
        del _FS_FIRED_ARG_ROOTS[len(_FS_FIRED_ARG_ROOTS) - 1];
    }
    fs_k: int = 0;
    while fs_k < len(fs_fn_kept) {
        _FS_FIRED_FNS.append(fs_fn_kept[fs_k]);
        fs_arg_l: list[JSValue] = fs_arg_kept[fs_k];
        fs_a: int = 0;
        while fs_a < len(fs_arg_l) {
            _FS_FIRED_ARG_ROOTS.append(fs_arg_l[fs_a]);
            fs_a = fs_a + 1;
        }
        fs_k = fs_k + 1;
    }
    _FS_FIRED_ARGS = fs_arg_kept;
    if len(_FS_FIRED_FNS) == 0 and _FS_ASYNC_REFFED and _FS_ASYNC_PTR != 0 {
        ah_u: UVHandle = UVHandle();
        ah_u.handle_ptr = _FS_ASYNC_PTR;
        uvhandle_unref(ah_u);
        _FS_ASYNC_REFFED = False;
    }
}

def _fs_push_callback(cb: JSValue, args: list[JSValue]) {
    if not _FS_FIRED_ROOTED {
        # glob queues — contents invisible to the GC root walk
        gc_pin_live_list(_FS_FIRED_FNS);
        gc_pin_live_list(_FS_FIRED_ARG_ROOTS);
        _FS_FIRED_ROOTED = True;
    }
    _FS_FIRED_FNS.append(cb);
    _FS_FIRED_ARGS.append(args);
    fs_q: int = 0;
    while fs_q < len(args) {
        _FS_FIRED_ARG_ROOTS.append(args[fs_q]);
        fs_q = fs_q + 1;
    }
    # Wake the event loop so el_tick picks up the new callback — same
    # pattern as _timer_fire_cb in vm/timers.na.jac — and keep the loop alive
    # (ref the wake handle) until the queue is drained (fs_fired_clear).
    if _FS_ASYNC_PTR != 0 {
        ah: UVHandle = UVHandle();
        ah.handle_ptr = _FS_ASYNC_PTR;
        if not _FS_ASYNC_REFFED {
            uvhandle_ref(ah);
            _FS_ASYNC_REFFED = True;
        }
        uvasync_send(ah);
    }
}

# ── Helpers ──────────────────────────────────────────────────────────────────

"""Allocate a zeroed I/O buffer that is safe to cast to Jac `str`.

The RC system (__rc_retain/__rc_release_simple) reads from ptr-32 (alloc_id /
magic check, HDR_ALLOC_ID_OFF = -32) and ptr-16 (refcount sentinel check,
HDR_RC_OFF = -16).  For large files (≥ ~128 KB) glibc satisfies calloc via
mmap, returning a page-aligned pointer.  With only 8 bytes of padding, ptr-32
falls in the preceding (unmapped) page → SIGSEGV.

Fix: reserve 32 bytes of zero-initialised padding (matching the full GC header
size) so that ptr-32 always lands within the calloc'd region.  The magic check
reads 0 (≠ 0xAC1D) and skips the retain/release — correct for a raw I/O buffer."""
def _io_alloc(size: int) -> int {
    raw: int = calloc(1, size + 32);
    return raw + 32;
}

"""Allocate a zeroed uv_fs_t request."""
def _fs_req_alloc -> int {
    return calloc(1, uv_req_size(_UV_REQ_FS));
}

"""Synchronously write the first `n` bytes of `s` to `fd` at `offset`
(-1: the current position / O_APPEND). Returns the uv result."""
def _fs_write_str(loop: int, fd: int, s: str, n: int, offset: int) -> int {
    wbuf: UVBuf = UVBuf(base=s, buf_len=n);
    req: int = _fs_req_alloc();
    uv_fs_write(loop, req, fd, wbuf, 1, offset, 0);
    written: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    return written;
}

"""_fs_write_str of the `n` bytes in io_alloc buffer `p` (which may hold 0x00
bytes). The str cast of `p` lives in this frame, so it and the UVBuf holding it
are released when this returns, before the caller frees `p`. Cast in the
caller's own frame, they were released after its io_free: a read of freed
memory that faults once `p` is large enough to be mmap'd."""
def _fs_write_wire(loop: int, fd: int, p: int, n: int, offset: int) -> int {
    s: str = p;  # jac:ignore[E1001] pointer reinterpreted as str (io_alloc header keeps the RC probe inert)
    return _fs_write_str(loop, fd, s, n, offset);
}

"""Read a uint64 from a raw memory address.
Copies 8 bytes into a UVBuf and reads the base field (str → ptrtoint → int)."""
def _read_u64(addr: int) -> int {
    tmp: int = calloc(1, 16);
    memcpy(tmp, addr, 8);
    reader: UVBuf = tmp;  # jac:ignore[E1001] pointer reinterpret
    return reader.base;  # jac:ignore[E1002] pointer reinterpret
}

# ── Internal sync I/O ────────────────────────────────────────────────────────

"""Return True if `path` exists (uv_fs_stat succeeds)."""
def:pub path_exists(path: str) -> bool {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_stat(loop, req, path, 0);
    stat_result: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    return stat_result >= 0;
}

"""Return True if `path` exists and is a directory."""
def:pub path_is_directory(path: str) -> bool {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_stat(loop, req, path, 0);
    stat_result: int = uv_fs_get_result(req);
    if stat_result < 0 {
        uv_fs_req_cleanup(req);
        return False;
    }
    statbuf: int = uv_fs_get_statbuf(req);
    # uv_stat_t: st_dev@0, st_mode@8 (uint64); S_IFMT=61440, S_IFDIR=16384
    mode: int = _read_u64(statbuf + 8);
    uv_fs_req_cleanup(req);
    return (mode & 61440) == 16384;
}

"""Read entire file as a JSValue string. Returns js_undefined() on error.
Handles virtual filesystems (e.g. /proc) where stat reports size 0 but
content is available — reads in chunks until EOF, like Node.js."""
def:pub _read_file_sync_str(path: str) -> JSValue {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();

    uv_fs_stat(loop, req, path, 0);
    stat_result: int = uv_fs_get_result(req);
    if stat_result < 0 {
        uv_fs_req_cleanup(req);
        return js_undefined();
    }

    # st_size is at offset 56 in uv_stat_t (x86_64 Linux)
    statbuf: int = uv_fs_get_statbuf(req);
    file_size: int = _read_u64(statbuf + 56);
    uv_fs_req_cleanup(req);

    # Open the file
    req = _fs_req_alloc();
    uv_fs_open(loop, req, path, _O_RDONLY, 0, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);

    if fd < 0 {
        return js_undefined();
    }

    if file_size > 0 {
        # ── Fast path: known size (regular files) ──
        buf_ptr: int = _io_alloc(file_size + 1);
        buf_str: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
        rbuf: UVBuf = UVBuf(base=buf_str, buf_len=file_size);

        req = _fs_req_alloc();
        uv_fs_read(loop, req, fd, rbuf, 1, 0, 0);
        bytes_read: int = uv_fs_get_result(req);
        uv_fs_req_cleanup(req);

        req = _fs_req_alloc();
        uv_fs_close(loop, req, fd, 0);
        uv_fs_req_cleanup(req);

        if bytes_read <= 0 {
            return js_undefined();
        }

        # The raw-pointer string has no stamped length header, so a length-stamped
        # copy is interned instead — otherwise every `s[i]` on the returned source
        # recomputes strlen (O(n²) to scan; froze the lexer on multi-MB modules).
        raw_str: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
        content: str = str_stamp_copy(raw_str);
        sid2: int = str_heap(content);  # G1.5: file contents are a large, distinct VALUE — collectible
        return jsv_from_string_id(sid2);
    }

    # ── Slow path: size unknown / 0 (virtual fs like /proc) ──
    # Read in 4 KB chunks until EOF, growing with calloc+memcpy.
    # NOTE: Do NOT call free() — calloc routes through Boehm GC;
    # calling libc free on GC-allocated memory crashes.
    chunk_size: int = 4096;
    accum_cap: int = chunk_size;
    accum_ptr: int = _io_alloc(accum_cap + 1);
    total_read: int = 0;

    chunk_ptr: int = _io_alloc(chunk_size);
    chunk_str: str = chunk_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    rbuf2: UVBuf = UVBuf(base=chunk_str, buf_len=chunk_size);

    keep_reading: int = 1;
    while keep_reading == 1 {
        req = _fs_req_alloc();
        uv_fs_read(loop, req, fd, rbuf2, 1, total_read, 0);
        n: int = uv_fs_get_result(req);
        uv_fs_req_cleanup(req);

        if n <= 0 {
            keep_reading = 0;
        } else {
            # Grow accumulator if needed (old buffer left for GC)
            if total_read + n >= accum_cap {
                new_cap: int = (total_read + n) * 2 + 1;
                new_ptr: int = _io_alloc(new_cap + 1);
                memcpy(new_ptr, accum_ptr, total_read);
                accum_ptr = new_ptr;
                accum_cap = new_cap;
            }
            memcpy(accum_ptr + total_read, chunk_ptr, n);
            total_read = total_read + n;
        }
    }

    req = _fs_req_alloc();
    uv_fs_close(loop, req, fd, 0);
    uv_fs_req_cleanup(req);

    if total_read <= 0 {
        sid_empty: int = str_intern("");
        return jsv_from_string_id(sid_empty);
    }

    # accum_ptr was calloc'd (zero-filled) with +1 extra byte,
    # so byte at accum_ptr[total_read] is already 0 → null-terminated.
    # Stamp a length header (see fast path) so `s[i]` on the source is O(1).
    accum_str: str = accum_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    result_str: str = str_stamp_copy(accum_str);
    sid3: int = str_heap(result_str);  # G1.5: file contents are a large, distinct VALUE — collectible
    return jsv_from_string_id(sid3);
}

# ── Raw-bytes sync read (binary-safe, no intern) ──────────────────────────────

"""Result of _read_file_bytes: a FIXED raw byte buffer + its size. `ok` is False
on any error. The buffer is a single io_alloc'd allocation (NO realloc/grow) and
is NUL-safe — it is never interned or cast to a whole Jac str, so embedded NUL
bytes survive. The caller keeps the FileBytes alive for as long as it reads `ptr`;
the calloc buffer has no refcount header and is never freed under it (refcounting
backend, no tracing GC)."""
obj FileBytes {
    has ptr: int = 0,
        size: int = 0,
        ok: bool = False;
}

"""Read an entire regular file into a single FIXED raw byte buffer.

Binary-safe replacement for _read_file_sync_str for callers that must preserve
embedded NUL bytes (e.g. the packed-binary .jsbc loader). Mirrors the fast path of
_read_file_sync_str: stat → open → single read into one io_alloc(file_size+1)
buffer, returned directly (NO list[int] copy — that per-byte boxing made .jsbc
decode the #1 startup cost). On ANY error returns ok=False. A .jsbc is always a
real, non-empty regular file, so a reported size of 0 is treated as an error (no
virtual-fs chunked slow path)."""
def:pub _read_file_bytes(path: str) -> FileBytes {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();

    uv_fs_stat(loop, req, path, 0);
    stat_result: int = uv_fs_get_result(req);
    if stat_result < 0 {
        uv_fs_req_cleanup(req);
        return FileBytes(ptr=0, size=0, ok=False);
    }

    # st_size is at offset 56 in uv_stat_t (x86_64 Linux)
    statbuf: int = uv_fs_get_statbuf(req);
    file_size: int = _read_u64(statbuf + 56);
    uv_fs_req_cleanup(req);

    if file_size <= 0 {
        # A real .jsbc is never empty; a 0 size means stat lied (virtual fs) or an
        # empty file — either way, treat as a miss rather than parse garbage.
        return FileBytes(ptr=0, size=0, ok=False);
    }

    req = _fs_req_alloc();
    uv_fs_open(loop, req, path, _O_RDONLY, 0, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if fd < 0 {
        return FileBytes(ptr=0, size=0, ok=False);
    }

    buf_ptr: int = _io_alloc(file_size + 1);
    buf_str: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    rbuf: UVBuf = UVBuf(base=buf_str, buf_len=file_size);

    req = _fs_req_alloc();
    uv_fs_read(loop, req, fd, rbuf, 1, 0, 0);
    bytes_read: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);

    req = _fs_req_alloc();
    uv_fs_close(loop, req, fd, 0);
    uv_fs_req_cleanup(req);

    if bytes_read <= 0 {
        return FileBytes(ptr=0, size=0, ok=False);
    }

    return FileBytes(ptr=buf_ptr, size=bytes_read, ok=True);
}

"""Write a string to a file. Returns 0 on success, -1 on error."""
def _write_file_sync_str(path: str, data: str) -> int {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();

    flags: int = _O_WRONLY + _O_CREAT + _O_TRUNC;
    uv_fs_open(loop, req, path, flags, 438, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);

    if fd < 0 {
        return -1;
    }

    data_len: int = len(data);
    # Strings are stored as CESU-8 + a 4-char NUL sentinel internally; files
    # must get real UTF-8 (surrogate pairs → 4-byte scalars, sentinel → 0x00).
    # esbuild's >1MB temp-file input and every emitted chunk with an emoji were
    # written as invalid UTF-8 otherwise.
    wire: int = 0;
    if wire_utf8_needs_convert(data) {
        data_len = wire_utf8_len(data);
        wire = io_alloc(data_len + 1);
        wire_utf8_write(data, wire, data_len);
    }
    written: int = 0;
    if wire != 0 {
        written = _fs_write_wire(loop, fd, wire, data_len, 0);
        io_free(wire);
    } else {
        written = _fs_write_str(loop, fd, data, data_len, 0);
    }

    req = _fs_req_alloc();
    uv_fs_close(loop, req, fd, 0);
    uv_fs_req_cleanup(req);

    if written < 0 {
        return -1;
    }
    return 0;
}

"""Append a string to a file. Returns 0 on success, -1 on error.
Uses offset -1 so libuv appends at EOF (O_APPEND + pwrite@0 is platform-fragile)."""
def _append_file_sync_str(path: str, data: str) -> int {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();

    flags: int = _O_WRONLY + _O_CREAT + _O_APPEND;
    uv_fs_open(loop, req, path, flags, 438, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);

    if fd < 0 {
        return -1;
    }

    data_len: int = len(data);
    # Strings are stored as CESU-8 + a 4-char NUL sentinel internally; files
    # must get real UTF-8 (surrogate pairs → 4-byte scalars, sentinel → 0x00).
    # esbuild's >1MB temp-file input and every emitted chunk with an emoji were
    # written as invalid UTF-8 otherwise.
    wire: int = 0;
    if wire_utf8_needs_convert(data) {
        data_len = wire_utf8_len(data);
        wire = io_alloc(data_len + 1);
        wire_utf8_write(data, wire, data_len);
    }
    written: int = 0;
    if wire != 0 {
        written = _fs_write_wire(loop, fd, wire, data_len, -1);
        io_free(wire);
    } else {
        written = _fs_write_str(loop, fd, data, data_len, -1);
    }

    req = _fs_req_alloc();
    uv_fs_close(loop, req, fd, 0);
    uv_fs_req_cleanup(req);

    if written < 0 {
        return -1;
    }
    return 0;
}

"""Create a JS error object { message, path, code, errno?, syscall? }."""
def _make_fs_error(msg: str, path: str) -> JSValue {
    err_obj: JSValue = js_object_create_null();
    js_object_set(err_obj, str_intern("message"), jsv_from_string_id(str_intern(msg)));
    js_object_set(err_obj, str_intern("path"), jsv_from_string_id(str_intern(path)));
    js_object_set(
        err_obj, str_intern("code"), jsv_from_string_id(str_intern("ENOENT"))
    );
    return err_obj;
}

"""Build a Node-shaped Error from a negative libuv result code."""
def _make_fs_uv_error(rc: int, syscall: str, path: str) -> JSValue {
    code: str = "UNKNOWN";
    msg: str = "fs error";
    if rc < 0 {
        code = uv_err_name(rc);
        msg = uv_strerror(rc);
        if code == "" {
            code = "UNKNOWN";
        }
        if msg == "" {
            msg = code;
        }
    }
    full: str = code + ": " + msg + ", " + syscall;
    if path != "" {
        full = full + " '" + path + "'";
    }
    err_obj: JSValue = js_object_create_null();
    js_object_set(err_obj, str_intern("message"), jsv_from_string_id(str_intern(full)));
    js_object_set(err_obj, str_intern("code"), jsv_from_string_id(str_intern(code)));
    js_object_set(err_obj, str_intern("errno"), js_int(rc));
    js_object_set(
        err_obj, str_intern("syscall"), jsv_from_string_id(str_intern(syscall))
    );
    if path != "" {
        js_object_set(
            err_obj, str_intern("path"), jsv_from_string_id(str_intern(path))
        );
    }
    return err_obj;
}

# ── Public API: Synchronous ──────────────────────────────────────────────────

"""Convert file:// URL href or URL object to a filesystem path."""
def _path_from_read_arg(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        p: str = str_from_id(jsv_to_table_id(v));
        if len(p) >= 7 and p[0:7] == "file://" {
            rest: str = p[7:];
            if len(rest) > 0 and rest[0] == "/" {
                return rest;
            }
            si: int = 0;
            while si < len(rest) {
                if rest[si] == "/" {
                    return rest[si:];
                }
                si = si + 1;
            }
            return rest;
        }
        return p;
    }
    if jsv_is_object_cell(v) {
        # Try href getter first (string "file://..." → recurse)
        href_v: JSValue = js_object_get(v, str_intern("href"));
        if jsv_is_string_cell(href_v) {
            return _path_from_read_arg(href_v);
        }
        # URL objects in js_engine store pathname as own property "_pathname"
        pn_v: JSValue = js_object_get(v, str_intern("_pathname"));
        if jsv_is_string_cell(pn_v) {
            return str_from_id(jsv_to_table_id(pn_v));
        }
    }
    return "";
}

"""fs.readFileSync(path, encoding?) → string | undefined."""
def:pub fs_read_file_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_undefined();
    }
    path: str = _path_from_read_arg(args[0]);
    if path == "" {
        return js_undefined();
    }
    return _read_file_sync_str(path);
}

"""fs.writeFileSync(path, data) → undefined."""
def:pub fs_write_file_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 2 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    data: str = "";
    if jsv_is_string_cell(args[1]) {
        data = str_from_id(jsv_to_table_id(args[1]));
    }
    _write_file_sync_str(path, data);
    return js_undefined();
}

"""fs.appendFileSync(path, data) → undefined."""
def:pub fs_append_file_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 2 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    data: str = "";
    if jsv_is_string_cell(args[1]) {
        data = str_from_id(jsv_to_table_id(args[1]));
    }
    _append_file_sync_str(path, data);
    return js_undefined();
}

"""Run a libuv access check. Returns the uv_fs_get_result value (0 = OK, <0 = error).
Shared between existsSync and accessSync."""
def _fs_access_check(path: str, mode: int) -> int {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_access(loop, req, path, mode, 0);
    result: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    return result;
}

"""fs.existsSync(path) → boolean."""
def:pub fs_exists_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_false();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    if _fs_access_check(path, _F_OK) == 0 {
        return js_true();
    }
    return js_false();
}

"""fs.unlinkSync(path) → undefined."""
def:pub fs_unlink_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_unlink(loop, req, path, 0);
    uv_fs_req_cleanup(req);
    return js_undefined();
}

"""fs.statSync(path) → { size, mode, isFile, isDirectory, isSymbolicLink }."""
def:pub fs_stat_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();

    uv_fs_stat(loop, req, path, 0);
    result: int = uv_fs_get_result(req);
    if result < 0 {
        uv_fs_req_cleanup(req);
        return js_undefined();
    }

    statbuf: int = uv_fs_get_statbuf(req);
    stat_obj: JSValue = _build_stat_object(statbuf);
    uv_fs_req_cleanup(req);
    return stat_obj;
}

# ── Public API: Async (deferred-sync) ────────────────────────────────────────

"""fs.readFile(path, encoding?, callback) → undefined.
Performs sync I/O then defers the callback to the next event loop tick."""
def:pub fs_read_file(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }

    path_val: JSValue = args[0];
    callback: JSValue = js_undefined();
    if len(args) == 2 {
        callback = args[1];
    } elif len(args) >= 3 {
        callback = args[2];
    }

    if not jsv_is_string_cell(path_val) {
        return js_undefined();
    }

    path: str = str_from_id(jsv_to_table_id(path_val));
    result: JSValue = _read_file_sync_str(path);

    cb_args: list[JSValue] = [];
    if jsv_is_undefined(result) {
        err: JSValue = _make_fs_error("ENOENT: no such file or directory", path);
        cb_args.append(err);
        cb_args.append(js_undefined());
    } else {
        cb_args.append(js_null());
        cb_args.append(result);
    }

    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.writeFile(path, data, callback) → undefined.
Performs sync I/O then defers the callback to the next event loop tick."""
def:pub fs_write_file(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }

    path_val: JSValue = args[0];
    data_val: JSValue = args[1];
    callback: JSValue = js_undefined();
    if len(args) == 3 {
        callback = args[2];
    } elif len(args) >= 4 {
        callback = args[3];
    }

    if not jsv_is_string_cell(path_val) {
        return js_undefined();
    }

    path: str = str_from_id(jsv_to_table_id(path_val));
    data: str = "";
    if jsv_is_string_cell(data_val) {
        data = str_from_id(jsv_to_table_id(data_val));
    }

    rc: int = _write_file_sync_str(path, data);

    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "write", path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }

    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

# ── Public API: Extended Sync Operations (Phase 5.10) ────────────────────────

"""Read a C string pointer from a memory address. The first 8 bytes at addr
are a pointer to a null-terminated C string."""
def _read_str_ptr(addr: int) -> str {
    tmp: int = calloc(1, 16);
    memcpy(tmp, addr, 8);
    reader: UVBuf = tmp;  # jac:ignore[E1001] pointer reinterpret
    raw_ptr: int = reader.base;  # jac:ignore[E1001] pointer reinterpret
    # libuv owns the string: copy it (never cast a foreign pointer to str).
    name: str = str_from_foreign_cstr(raw_ptr);
    free(tmp);
    return name;
}

"""fs.readdirSync(path) → array of filename strings."""
def:pub fs_readdir_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();

    uv_fs_scandir(loop, req, path, 0, 0);
    result: int = uv_fs_get_result(req);
    if result < 0 {
        uv_fs_req_cleanup(req);
        return js_undefined();
    }

    # uv_dirent_t = { const char* name; int d_type; } = 16 bytes on x86_64
    dirent_ptr: int = calloc(1, 16);
    entries: list[JSValue] = [];
    keep_going: int = 1;
    while keep_going == 1 {
        rc: int = uv_fs_scandir_next(req, dirent_ptr);
        if rc != 0 {
            keep_going = 0;
        } else {
            # dirent name points into the uv_fs_t scandir buffer; copy before
            # the next scandir_next / req_cleanup or str_intern keeps a dangling ptr.
            name_str: str = _read_str_ptr(dirent_ptr);
            name_owned: str = name_str + "";
            sid: int = str_intern(name_owned);
            entries.append(jsv_from_string_id(sid));
        }
    }

    uv_fs_req_cleanup(req);
    arr: JSValue = js_array_create(entries);
    return arr;
}

"""fs.mkdirSync(path, options?) → undefined.
options.recursive not yet supported. mode defaults to 0o777 (511)."""
def:pub fs_mkdir_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_mkdir(loop, req, path, 511, 0);
    uv_fs_req_cleanup(req);
    return js_undefined();
}

"""fs.rmdirSync(path) → undefined."""
def:pub fs_rmdir_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_rmdir(loop, req, path, 0);
    uv_fs_req_cleanup(req);
    return js_undefined();
}

"""fs.rmSync(path, options?) → undefined.
Simple: tries unlink first, then rmdir."""
def:pub fs_rm_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();

    req: int = _fs_req_alloc();
    uv_fs_unlink(loop, req, path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);

    if rc < 0 {
        req = _fs_req_alloc();
        uv_fs_rmdir(loop, req, path, 0);
        uv_fs_req_cleanup(req);
    }
    return js_undefined();
}

"""fs.renameSync(oldPath, newPath) → undefined."""
def:pub fs_rename_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 2
        or not jsv_is_string_cell(args[0])
        or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    old_path: str = str_from_id(jsv_to_table_id(args[0]));
    new_path: str = str_from_id(jsv_to_table_id(args[1]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_rename(loop, req, old_path, new_path, 0);
    uv_fs_req_cleanup(req);
    return js_undefined();
}

"""fs.copyFileSync(src, dest, mode?) → undefined."""
def:pub fs_copyfile_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 2
        or not jsv_is_string_cell(args[0])
        or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    src: str = str_from_id(jsv_to_table_id(args[0]));
    dest: str = str_from_id(jsv_to_table_id(args[1]));
    flags: int = 0;
    if len(args) >= 3 {
        if jsv_is_int32(args[2]) {
            flags = jsv_to_int32(args[2]);
        } elif jsv_is_double(args[2]) {
            flags = int(jsv_to_double(args[2]));
        }
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_copyfile(loop, req, src, dest, flags, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "copyfile", src);
        js_object_set(err, str_intern("dest"), jsv_from_string_id(str_intern(dest)));
        vm_throw_native(err);
        return js_undefined();
    }
    return js_undefined();
}

"""fs.chmodSync(path, mode) → undefined."""
def:pub fs_chmod_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 2 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    mode: int = 0;
    if jsv_is_int32(args[1]) {
        mode = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        mode = int(jsv_to_double(args[1]));
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_chmod(loop, req, path, mode, 0);
    uv_fs_req_cleanup(req);
    return js_undefined();
}

"""fs.chownSync(path, uid, gid) → undefined."""
def:pub fs_chown_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 3 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    uid: int = 0;
    gid: int = 0;
    if jsv_is_int32(args[1]) {
        uid = jsv_to_int32(args[1]);
    }
    if jsv_is_int32(args[2]) {
        gid = jsv_to_int32(args[2]);
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_chown(loop, req, path, uid, gid, 0);
    uv_fs_req_cleanup(req);
    return js_undefined();
}

"""fs.symlinkSync(target, path, type?) → undefined."""
def:pub fs_symlink_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 2
        or not jsv_is_string_cell(args[0])
        or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    target: str = str_from_id(jsv_to_table_id(args[0]));
    link_path: str = str_from_id(jsv_to_table_id(args[1]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_symlink(loop, req, target, link_path, 0, 0);
    uv_fs_req_cleanup(req);
    return js_undefined();
}

"""fs.readlinkSync(path) → string."""
def:pub fs_readlink_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_readlink(loop, req, path, 0);
    result: int = uv_fs_get_result(req);
    if result < 0 {
        uv_fs_req_cleanup(req);
        return js_undefined();
    }
    ptr: int = uv_fs_get_ptr(req);
    link_target: str = ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    # Copy before cleanup — ptr is into the libuv request buffer.
    link_owned: str = link_target + "";
    sid: int = str_intern(link_owned);
    uv_fs_req_cleanup(req);
    return jsv_from_string_id(sid);
}

def _fs_copy_str_to_buf(s: str) -> int {
    n: int = len(s);
    buf: int = calloc(1, n + 1);
    i: int = 0;
    while i < n {
        write_byte(buf, i, ord(s[i]));
        i = i + 1;
    }
    write_byte(buf, n, 0);
    return buf;
}

def _fs_buf_to_str(buf: int) -> str {
    n: int = 0;
    while read_byte(buf, n) != 0 {
        n = n + 1;
    }
    out: int = calloc(1, n + 1);
    i: int = 0;
    while i < n {
        write_byte(out, i, read_byte(buf, i));
        i = i + 1;
    }
    write_byte(out, n, 0);
    result: str = out;  # jac:ignore[E1001] pointer reinterpret
    return result;
}

"""fs.mkdtempSync(prefix) → string (created directory path)."""
def:pub fs_mkdtemp_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    tmpl: str = str_from_id(jsv_to_table_id(args[0]));
    # Node appends six random characters; libc mkdtemp requires a XXXXXX suffix.
    if len(tmpl) < 6 or tmpl[len(tmpl) - 6:len(tmpl)] != "XXXXXX" {
        tmpl = tmpl + "XXXXXX";
    }
    buf: int = _fs_copy_str_to_buf(tmpl);
    ptr: int = mkdtemp(buf);
    if ptr == 0 {
        free(buf);
        return js_undefined();
    }
    created: str = _fs_buf_to_str(buf);
    free(buf);
    return jsv_from_string_id(str_intern(created));
}

"""Read symlink target for path; returns -1 if not a symlink or error.
Returns the string table ID (int) to avoid RC lifetime issues with str returns."""
def _fs_readlink_sid(path: str) -> int {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_readlink(loop, req, path, 0);
    result: int = uv_fs_get_result(req);
    if result < 0 {
        uv_fs_req_cleanup(req);
        return -1;
    }
    ptr: int = uv_fs_get_ptr(req);
    link_target: str = ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    # IMPORTANT: link_target is a raw C pointer into the libuv request buffer.
    # We must make a GC-owned copy BEFORE calling str_intern and BEFORE
    # uv_fs_req_cleanup, otherwise the intern table stores a dangling pointer
    # (the libuv buffer is freed by cleanup, corrupting intern_by_str / intern_by_id).
    link_owned: str = link_target + "";
    sid: int = str_intern(link_owned);
    uv_fs_req_cleanup(req);
    return sid;
}

"""Inner recursive helper for path_realpath_str."""
def _realpath_walk(path: str, restarts: int) -> str {
    parts: list[str] = path_split(path);
    result: str = "";
    i: int = 0;
    while i < len(parts) {
        part: str = parts[i];
        if part == "" or part == "." {
            i = i + 1;
            continue;
        }
        if part == ".." {
            result = path_dirname(result);
            i = i + 1;
            continue;
        }
        candidate: str = result + "/" + part;
        link_sid: int = _fs_readlink_sid(candidate);
        if link_sid >= 0 and restarts > 0 {
            link: str = str_from_id(link_sid);
            # Build remaining suffix (parts after i)
            remaining: str = "";
            j: int = i + 1;
            while j < len(parts) {
                remaining = remaining + "/" + parts[j];
                j = j + 1;
            }
            # Resolve symlink: absolute replaces result; relative joins with parent
            new_path: str = "";
            if len(link) > 0 and link[0] == "/" {
                new_path = path_normalize(link + remaining);
            } else {
                new_path = path_normalize(result + "/" + link + remaining);
            }
            return _realpath_walk(new_path, restarts - 1);
        }
        result = candidate;
        i = i + 1;
    }
    if result == "" {
        return path;
    }
    return result;
}

"""Resolve all symlink components in path, returning the canonical path."""
def:pub path_realpath_str(path: str) -> str {
    return _realpath_walk(path, 40);
}

"""fs.realpathSync(path) → string."""
def:pub fs_realpath_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    real: str = path_realpath_str(path);
    # Return undefined for non-existent paths (Node.js throws ENOENT)
    if not path_exists(real) {
        return js_undefined();
    }
    return jsv_from_string_id(str_intern(real));
}

"""fs.accessSync(path, mode?) → undefined on success; THROWS on failure (Node).
Silently succeeding on a missing path made callers that gate on `access` (e.g.
vite/lilconfig's config search: `try { await access(p) } catch { continue }`)
believe absent files exist, then throw ENOENT from the following readFile as an
uncaught async rejection — which broke a plugin hook's promise chain and aborted
`vite build` with 'Unexpected early exit'. Throw the uv error so the catch fires."""
def:pub fs_access_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    mode: int = 0;
    if len(args) >= 2 and jsv_is_int32(args[1]) {
        mode = jsv_to_int32(args[1]);
    }
    rc: int = _fs_access_check(path, mode);
    if rc < 0 {
        vm_throw_native(_make_fs_uv_error(rc, "access", path));
        return js_undefined();
    }
    return js_undefined();
}

"""Build a stat result object from a uv_stat_t buffer.
Shared between statSync and lstatSync.
Field offsets for uv_stat_t on x86_64 Linux (uv.h):
  dev=0  mode=8  nlink=16  uid=24  gid=32  rdev=40  ino=48  size=56
  blksize=64  blocks=72
  atim: sec=96  nsec=104
  mtim: sec=112 nsec=120
  ctim: sec=128 nsec=136
  birthtim: sec=144 nsec=152"""
def _build_stat_object(statbuf: int) -> JSValue {
    dev_val: int = _read_u64(statbuf + 0);
    mode_val: int = _read_u64(statbuf + 8);
    nlink_val: int = _read_u64(statbuf + 16);
    uid_val: int = _read_u64(statbuf + 24);
    gid_val: int = _read_u64(statbuf + 32);
    rdev_val: int = _read_u64(statbuf + 40);
    ino_val: int = _read_u64(statbuf + 48);
    size_val: int = _read_u64(statbuf + 56);
    blksize_val: int = _read_u64(statbuf + 64);
    blocks_val: int = _read_u64(statbuf + 72);

    atime_sec: int = _read_u64(statbuf + 96);
    atime_nsec: int = _read_u64(statbuf + 104);
    mtime_sec: int = _read_u64(statbuf + 112);
    mtime_nsec: int = _read_u64(statbuf + 120);
    ctime_sec: int = _read_u64(statbuf + 128);
    ctime_nsec: int = _read_u64(statbuf + 136);
    btime_sec: int = _read_u64(statbuf + 144);
    btime_nsec: int = _read_u64(statbuf + 152);

    atime_ms: float = atime_sec * 1000.0 + atime_nsec / 1000000.0;
    mtime_ms: float = mtime_sec * 1000.0 + mtime_nsec / 1000000.0;
    ctime_ms: float = ctime_sec * 1000.0 + ctime_nsec / 1000000.0;
    btime_ms: float = btime_sec * 1000.0 + btime_nsec / 1000000.0;

    type_bits: int = (mode_val // 4096) * 4096;
    is_file: int = 0;
    is_dir: int = 0;
    is_symlink: int = 0;
    is_blk: int = 0;
    is_chr: int = 0;
    is_fifo: int = 0;
    is_sock: int = 0;
    if type_bits == 32768 {
        is_file = 1;
    } elif type_bits == 16384 {
        is_dir = 1;
    } elif type_bits == 40960 {
        is_symlink = 1;
    } elif type_bits == 24576 {
        is_blk = 1;
    } elif type_bits == 8192 {
        is_chr = 1;
    } elif type_bits == 4096 {
        is_fifo = 1;
    } elif type_bits == 49152 {
        is_sock = 1;
    }

    stat_obj: JSValue = js_object_create_null();
    js_object_set(stat_obj, str_intern("dev"), jsv_from_double(float(dev_val)));
    js_object_set(stat_obj, str_intern("mode"), js_int(mode_val));
    js_object_set(stat_obj, str_intern("nlink"), js_int(nlink_val));
    js_object_set(stat_obj, str_intern("uid"), js_int(uid_val));
    js_object_set(stat_obj, str_intern("gid"), js_int(gid_val));
    js_object_set(stat_obj, str_intern("rdev"), jsv_from_double(float(rdev_val)));
    js_object_set(stat_obj, str_intern("ino"), jsv_from_double(float(ino_val)));
    js_object_set(stat_obj, str_intern("size"), jsv_from_double(float(size_val)));
    js_object_set(stat_obj, str_intern("blksize"), js_int(blksize_val));
    js_object_set(stat_obj, str_intern("blocks"), jsv_from_double(float(blocks_val)));
    js_object_set(stat_obj, str_intern("atimeMs"), jsv_from_double(atime_ms));
    js_object_set(stat_obj, str_intern("mtimeMs"), jsv_from_double(mtime_ms));
    js_object_set(stat_obj, str_intern("ctimeMs"), jsv_from_double(ctime_ms));
    js_object_set(stat_obj, str_intern("birthtimeMs"), jsv_from_double(btime_ms));
    js_object_set(stat_obj, str_intern("atime"), jsv_from_double(atime_ms));
    js_object_set(stat_obj, str_intern("mtime"), jsv_from_double(mtime_ms));
    js_object_set(stat_obj, str_intern("ctime"), jsv_from_double(ctime_ms));
    js_object_set(stat_obj, str_intern("birthtime"), jsv_from_double(btime_ms));

    if is_file == 1 {
        js_object_set(stat_obj, str_intern("isFile"), js_true());
    } else {
        js_object_set(stat_obj, str_intern("isFile"), js_false());
    }
    if is_dir == 1 {
        js_object_set(stat_obj, str_intern("isDirectory"), js_true());
    } else {
        js_object_set(stat_obj, str_intern("isDirectory"), js_false());
    }
    if is_symlink == 1 {
        js_object_set(stat_obj, str_intern("isSymbolicLink"), js_true());
    } else {
        js_object_set(stat_obj, str_intern("isSymbolicLink"), js_false());
    }
    if is_blk == 1 {
        js_object_set(stat_obj, str_intern("isBlockDevice"), js_true());
    } else {
        js_object_set(stat_obj, str_intern("isBlockDevice"), js_false());
    }
    if is_chr == 1 {
        js_object_set(stat_obj, str_intern("isCharacterDevice"), js_true());
    } else {
        js_object_set(stat_obj, str_intern("isCharacterDevice"), js_false());
    }
    if is_fifo == 1 {
        js_object_set(stat_obj, str_intern("isFIFO"), js_true());
    } else {
        js_object_set(stat_obj, str_intern("isFIFO"), js_false());
    }
    if is_sock == 1 {
        js_object_set(stat_obj, str_intern("isSocket"), js_true());
    } else {
        js_object_set(stat_obj, str_intern("isSocket"), js_false());
    }

    return stat_obj;
}

"""fs.lstatSync(path) → stat object (does not follow symlinks)."""
def:pub fs_lstat_sync(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();

    uv_fs_lstat(loop, req, path, 0);
    result: int = uv_fs_get_result(req);
    if result < 0 {
        uv_fs_req_cleanup(req);
        return js_undefined();
    }

    statbuf: int = uv_fs_get_statbuf(req);
    stat_obj: JSValue = _build_stat_object(statbuf);
    uv_fs_req_cleanup(req);
    return stat_obj;
}

"""fs.createWriteStream(path, options?) → writable stream-like object.
Opens file, returns object with __wstream_fd for write/end methods."""
def:pub fs_create_write_stream(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();

    flags: int = _O_WRONLY + _O_CREAT + _O_TRUNC;
    uv_fs_open(loop, req, path, flags, 438, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);

    if fd < 0 {
        return js_undefined();
    }

    ws_obj: JSValue = js_object_create_null();
    js_object_set(ws_obj, str_intern("__wstream_fd"), js_int(fd));
    js_object_set(ws_obj, str_intern("path"), jsv_from_string_id(str_intern(path)));
    return ws_obj;
}

"""Write data to an open fd (used internally by createWriteStream)."""
def:pub fs_wstream_write(fd: int, data: str) -> int {
    loop: int = uv_default_loop();
    data_len: int = len(data);
    # Strings are stored as CESU-8 + a 4-char NUL sentinel internally; files
    # must get real UTF-8 (surrogate pairs → 4-byte scalars, sentinel → 0x00).
    # esbuild's >1MB temp-file input and every emitted chunk with an emoji were
    # written as invalid UTF-8 otherwise.
    wire: int = 0;
    if wire_utf8_needs_convert(data) {
        data_len = wire_utf8_len(data);
        wire = io_alloc(data_len + 1);
        wire_utf8_write(data, wire, data_len);
    }
    written: int = 0;
    if wire != 0 {
        written = _fs_write_wire(loop, fd, wire, data_len, -1);
        io_free(wire);
    } else {
        written = _fs_write_str(loop, fd, data, data_len, -1);
    }
    return written;
}

"""Close an open fd (used internally by createWriteStream)."""
def:pub fs_wstream_close(fd: int) {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_close(loop, req, fd, 0);
    uv_fs_req_cleanup(req);
}

# ── Callback (async-deferred) fs API ─────────────────────────────────────────
# All functions below do the I/O synchronously on the current thread, then
# defer the callback into the fired-callback queue so the event loop delivers
# it on the next tick — matching Node.js callback semantics.

"""fs.realpath(path, [options], callback) → undefined.  callback(err, resolvedPath)"""
def:pub fs_realpath(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    real: str = path_realpath_str(path);
    cb_args: list[JSValue] = [];
    cb_args.append(js_null());
    cb_args.append(jsv_from_string_id(str_intern(real)));
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.stat(path, [options], callback) → undefined.  callback(err, stats)"""
def:pub fs_stat(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_stat(loop, req, path, 0);
    rc: int = uv_fs_get_result(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        uv_fs_req_cleanup(req);
        err: JSValue = _make_fs_uv_error(rc, "stat", path);
        cb_args.append(err);
        cb_args.append(js_undefined());
    } else {
        statbuf: int = uv_fs_get_statbuf(req);
        stat_obj: JSValue = _build_stat_object(statbuf);
        uv_fs_req_cleanup(req);
        cb_args.append(js_null());
        cb_args.append(stat_obj);
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.lstat(path, [options], callback) → undefined.  callback(err, stats)"""
def:pub fs_lstat(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_lstat(loop, req, path, 0);
    rc: int = uv_fs_get_result(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        uv_fs_req_cleanup(req);
        err: JSValue = _make_fs_uv_error(rc, "lstat", path);
        cb_args.append(err);
        cb_args.append(js_undefined());
    } else {
        statbuf: int = uv_fs_get_statbuf(req);
        stat_obj: JSValue = _build_stat_object(statbuf);
        uv_fs_req_cleanup(req);
        cb_args.append(js_null());
        cb_args.append(stat_obj);
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.readdir(path, [options], callback) → undefined.  callback(err, files[])"""
def:pub fs_readdir(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_scandir(loop, req, path, 0, 0);
    rc: int = uv_fs_get_result(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        uv_fs_req_cleanup(req);
        err: JSValue = _make_fs_uv_error(rc, "scandir", path);
        cb_args.append(err);
        cb_args.append(js_undefined());
    } else {
        dirent_ptr: int = calloc(1, 16);
        entries: list[JSValue] = [];
        keep_going: int = 1;
        while keep_going == 1 {
            scan_rc: int = uv_fs_scandir_next(req, dirent_ptr);
            if scan_rc != 0 {
                keep_going = 0;
            } else {
                # Copy before next scandir_next / cleanup (dangling C pointer).
                name_str: str = _read_str_ptr(dirent_ptr);
                name_owned: str = name_str + "";
                sid: int = str_intern(name_owned);
                entries.append(jsv_from_string_id(sid));
            }
        }
        uv_fs_req_cleanup(req);
        arr: JSValue = js_array_create(entries);
        cb_args.append(js_null());
        cb_args.append(arr);
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.mkdir(path, [options], callback) → undefined.  callback(err)"""
def:pub fs_mkdir(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_mkdir(loop, req, path, 511, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "mkdir", path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.unlink(path, callback) → undefined.  callback(err)"""
def:pub fs_unlink(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_unlink(loop, req, path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "unlink", path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.rename(oldPath, newPath, callback) → undefined.  callback(err)"""
def:pub fs_rename(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    callback: JSValue = args[2];
    if not jsv_is_string_cell(args[0]) or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    old_path: str = str_from_id(jsv_to_table_id(args[0]));
    new_path: str = str_from_id(jsv_to_table_id(args[1]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_rename(loop, req, old_path, new_path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "rename", old_path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.access(path, [mode], callback) → undefined.  callback(err)"""
def:pub fs_access(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    mode: int = 0;
    if len(args) >= 3 and jsv_is_int32(args[1]) {
        mode = jsv_to_int32(args[1]);
    }
    rc: int = _fs_access_check(path, mode);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "access", path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.appendFile(path, data, [options], callback) → undefined.  callback(err)"""
def:pub fs_append_file(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    data: str = "";
    if jsv_is_string_cell(args[1]) {
        data = str_from_id(jsv_to_table_id(args[1]));
    }
    _append_file_sync_str(path, data);
    cb_args: list[JSValue] = [];
    cb_args.append(js_null());
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.mkdtemp(prefix, [options], callback) → undefined.  callback(err, folder)"""
def:pub fs_mkdtemp(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    tmpl: str = str_from_id(jsv_to_table_id(args[0]));
    if len(tmpl) < 6 or tmpl[len(tmpl) - 6:len(tmpl)] != "XXXXXX" {
        tmpl = tmpl + "XXXXXX";
    }
    buf: int = _fs_copy_str_to_buf(tmpl);
    ptr: int = mkdtemp(buf);
    cb_args: list[JSValue] = [];
    if ptr == 0 {
        free(buf);
        err: JSValue = _make_fs_error("EACCES: mkdtemp failed", tmpl);
        cb_args.append(err);
        cb_args.append(js_undefined());
    } else {
        created: str = _fs_buf_to_str(buf);
        free(buf);
        cb_args.append(js_null());
        cb_args.append(jsv_from_string_id(str_intern(created)));
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.copyFile(src, dest, [flags], callback) → undefined.  callback(err)"""
def:pub fs_copyfile(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    src: str = str_from_id(jsv_to_table_id(args[0]));
    dest: str = str_from_id(jsv_to_table_id(args[1]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    flags: int = 0;
    if len(args) >= 4 {
        if jsv_is_int32(args[2]) {
            flags = jsv_to_int32(args[2]);
        } elif jsv_is_double(args[2]) {
            flags = int(jsv_to_double(args[2]));
        }
    }
    uv_fs_copyfile(loop, req, src, dest, flags, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "copyfile", src);
        js_object_set(err, str_intern("dest"), jsv_from_string_id(str_intern(dest)));
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.chmod(path, mode, callback) → undefined.  callback(err)"""
def:pub fs_chmod(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    callback: JSValue = args[2];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    mode: int = 0;
    if jsv_is_int32(args[1]) {
        mode = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        mode = int(jsv_to_double(args[1]));
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_chmod(loop, req, path, mode, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "chmod", path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.chown(path, uid, gid, callback) → undefined.  callback(err)"""
def:pub fs_chown(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[3];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    uid: int = 0;
    gid: int = 0;
    if jsv_is_int32(args[1]) {
        uid = jsv_to_int32(args[1]);
    }
    if jsv_is_int32(args[2]) {
        gid = jsv_to_int32(args[2]);
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_chown(loop, req, path, uid, gid, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "chown", path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.symlink(target, path, [type], callback) → undefined.  callback(err)"""
def:pub fs_symlink(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    target: str = str_from_id(jsv_to_table_id(args[0]));
    link_path: str = str_from_id(jsv_to_table_id(args[1]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_symlink(loop, req, target, link_path, 0, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "symlink", target);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.readlink(path, [options], callback) → undefined.  callback(err, linkString)"""
def:pub fs_readlink(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    sid: int = _fs_readlink_sid(path);
    cb_args: list[JSValue] = [];
    if sid < 0 {
        err: JSValue = _make_fs_error("EINVAL: readlink failed", path);
        cb_args.append(err);
        cb_args.append(js_undefined());
    } else {
        cb_args.append(js_null());
        cb_args.append(jsv_from_string_id(sid));
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.rmdir(path, [options], callback) → undefined.  callback(err)"""
def:pub fs_rmdir(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_rmdir(loop, req, path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "rmdir", path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.rm(path, [options], callback) → undefined.  callback(err)"""
def:pub fs_rm(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_unlink(loop, req, path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        req = _fs_req_alloc();
        uv_fs_rmdir(loop, req, path, 0);
        rc = uv_fs_get_result(req);
        uv_fs_req_cleanup(req);
    }
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, "rm", path);
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""Parse Node.js open flags argument (string or integer) to POSIX O_* bitmask."""
def _parse_open_flags(flags: JSValue) -> int {
    if jsv_is_int32(flags) {
        return jsv_to_int32(flags);
    }
    if jsv_is_double(flags) {
        return int(jsv_to_double(flags));
    }
    if jsv_is_string_cell(flags) {
        s: str = str_from_id(jsv_to_table_id(flags));
        if s == "r" {
            return _O_RDONLY;
        }
        if s == "r+" {
            return _O_RDWR;
        }
        if s == "rs" {
            return _O_RDONLY;
        }
        if s == "sr" {
            return _O_RDONLY;
        }
        if s == "rs+" {
            return _O_RDWR;
        }
        if s == "sr+" {
            return _O_RDWR;
        }
        if s == "w" {
            return _O_WRONLY + _O_CREAT + _O_TRUNC;
        }
        if s == "wx" {
            return _O_WRONLY + _O_CREAT + _O_EXCL;
        }
        if s == "xw" {
            return _O_WRONLY + _O_CREAT + _O_EXCL;
        }
        if s == "w+" {
            return _O_RDWR + _O_CREAT + _O_TRUNC;
        }
        if s == "wx+" {
            return _O_RDWR + _O_CREAT + _O_EXCL;
        }
        if s == "xw+" {
            return _O_RDWR + _O_CREAT + _O_EXCL;
        }
        if s == "a" {
            return _O_WRONLY + _O_CREAT + _O_APPEND;
        }
        if s == "ax" {
            return _O_WRONLY + _O_CREAT + _O_APPEND + _O_EXCL;
        }
        if s == "xa" {
            return _O_WRONLY + _O_CREAT + _O_APPEND + _O_EXCL;
        }
        if s == "a+" {
            return _O_RDWR + _O_CREAT + _O_APPEND;
        }
        if s == "ax+" {
            return _O_RDWR + _O_CREAT + _O_APPEND + _O_EXCL;
        }
        if s == "xa+" {
            return _O_RDWR + _O_CREAT + _O_APPEND + _O_EXCL;
        }
    }
    return _O_RDONLY;
}

"""fs.openSync(path, flags, [mode]) -> fd. Throws UV exception on error (never returns negative fd)."""
def:pub fs_open_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 1 or not jsv_is_string_cell(args[0]) {
        _fs_throw("EINVAL", "open", "EINVAL: invalid argument, open", "");
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    flags: int = _O_RDONLY;
    if len(args) >= 2 {
        flags = _parse_open_flags(args[1]);
    }
    mode: int = 438;
    if len(args) >= 3 {
        if jsv_is_int32(args[2]) {
            mode = jsv_to_int32(args[2]);
        } elif jsv_is_double(args[2]) {
            mode = int(jsv_to_double(args[2]));
        }
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_open(loop, req, path, flags, mode, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if fd < 0 {
        _fs_throw_uv(fd, "open", path);
        return js_undefined();
    }
    return js_int(fd);
}

"""fs.open(path, flags, [mode], callback) -> undefined. callback(err, fd)."""
def:pub fs_open(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    flags: int = _parse_open_flags(args[1]);
    mode: int = 438;
    if len(args) >= 4 {
        if jsv_is_int32(args[2]) {
            mode = jsv_to_int32(args[2]);
        } elif jsv_is_double(args[2]) {
            mode = int(jsv_to_double(args[2]));
        }
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_open(loop, req, path, flags, mode, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if fd < 0 {
        err: JSValue = _make_fs_uv_error(fd, "open", path);
        cb_args.append(err);
        cb_args.append(js_undefined());
    } else {
        cb_args.append(js_null());
        cb_args.append(js_int(fd));
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.closeSync(fd) -> undefined."""
def:pub fs_close_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    fd: int = 0;
    if jsv_is_int32(args[0]) {
        fd = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        fd = int(jsv_to_double(args[0]));
    }
    if fd >= 0 {
        loop: int = uv_default_loop();
        req: int = _fs_req_alloc();
        uv_fs_close(loop, req, fd, 0);
        uv_fs_req_cleanup(req);
    }
    return js_undefined();
}

"""fs.close(fd, callback) -> undefined. callback(err)."""
def:pub fs_close(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    callback: JSValue = js_undefined();
    if len(args) >= 2 {
        callback = args[len(args) - 1];
    }
    fd: int = 0;
    if jsv_is_int32(args[0]) {
        fd = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        fd = int(jsv_to_double(args[0]));
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_close(loop, req, fd, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_error("EBADF: bad file descriptor, close", "");
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

# ── fd read / write (Buffer pointer bridge) ───────────────────────────────────

"""Parse a JS number (int32 or float64) to int — used for fd/ptr/length/position."""
def _js_to_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

"""uv_fs_read into a raw buffer pointer.
args: [fd, ptr, length, position]
  position < 0 → current file offset (libuv -1).
Returns bytes read (>= 0), or negative on error."""
def:pub fs_read_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_int(-1);
    }
    fd: int = _js_to_int(args[0]);
    ptr: int = _js_to_int(args[1]);
    length: int = _js_to_int(args[2]);
    position: int = -1;
    if len(args) >= 4 {
        position = _js_to_int(args[3]);
    }
    if fd < 0 or ptr == 0 or length < 0 {
        return js_int(-1);
    }
    if length == 0 {
        return js_int(0);
    }
    buf_str: str = ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    rbuf: UVBuf = UVBuf(base=buf_str, buf_len=length);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_read(loop, req, fd, rbuf, 1, position, 0);
    n: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    return js_int(n);
}

"""uv_fs_write from a raw buffer pointer.
args: [fd, ptr, length, position]
Returns bytes written (>= 0), or negative on error."""
def:pub fs_write_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_int(-1);
    }
    fd: int = _js_to_int(args[0]);
    ptr: int = _js_to_int(args[1]);
    length: int = _js_to_int(args[2]);
    position: int = -1;
    if len(args) >= 4 {
        position = _js_to_int(args[3]);
    }
    if fd < 0 or ptr == 0 or length < 0 {
        return js_int(-1);
    }
    if length == 0 {
        return js_int(0);
    }
    buf_str: str = ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    wbuf: UVBuf = UVBuf(base=buf_str, buf_len=length);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_write(loop, req, fd, wbuf, 1, position, 0);
    n: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    return js_int(n);
}

"""fs.read(fd, ptr, length, position, callback) — deferred callback(err, bytesRead).
JS layer supplies Buffer and rewrites callback to (err, bytesRead, buffer)."""
def:pub fs_read(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    fd: int = _js_to_int(args[0]);
    ptr: int = _js_to_int(args[1]);
    length: int = _js_to_int(args[2]);
    position: int = -1;
    if len(args) >= 5 {
        position = _js_to_int(args[3]);
    }
    n: int = -1;
    if fd >= 0 and ptr != 0 and length >= 0 {
        if length == 0 {
            n = 0;
        } else {
            buf_str: str = ptr;  # jac:ignore[E1001] pointer reinterpreted as str
            rbuf: UVBuf = UVBuf(base=buf_str, buf_len=length);
            loop: int = uv_default_loop();
            req: int = _fs_req_alloc();
            uv_fs_read(loop, req, fd, rbuf, 1, position, 0);
            n = uv_fs_get_result(req);
            uv_fs_req_cleanup(req);
        }
    }
    cb_args: list[JSValue] = [];
    if n < 0 {
        err: JSValue = _make_fs_error("EBADF: bad file descriptor, read", "");
        js_object_set(err, str_intern("code"), jsv_from_string_id(str_intern("EBADF")));
        js_object_set(
            err, str_intern("syscall"), jsv_from_string_id(str_intern("read"))
        );
        cb_args.append(err);
        cb_args.append(js_int(0));
    } else {
        cb_args.append(js_null());
        cb_args.append(js_int(n));
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.write(fd, ptr, length, position, callback) — deferred callback(err, bytesWritten)."""
def:pub fs_write(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    fd: int = _js_to_int(args[0]);
    ptr: int = _js_to_int(args[1]);
    length: int = _js_to_int(args[2]);
    position: int = -1;
    if len(args) >= 5 {
        position = _js_to_int(args[3]);
    }
    n: int = -1;
    if fd >= 0 and ptr != 0 and length >= 0 {
        if length == 0 {
            n = 0;
        } else {
            buf_str: str = ptr;  # jac:ignore[E1001] pointer reinterpreted as str
            wbuf: UVBuf = UVBuf(base=buf_str, buf_len=length);
            loop: int = uv_default_loop();
            req: int = _fs_req_alloc();
            uv_fs_write(loop, req, fd, wbuf, 1, position, 0);
            n = uv_fs_get_result(req);
            uv_fs_req_cleanup(req);
        }
    }
    cb_args: list[JSValue] = [];
    if n < 0 {
        err: JSValue = _make_fs_error("EBADF: bad file descriptor, write", "");
        js_object_set(err, str_intern("code"), jsv_from_string_id(str_intern("EBADF")));
        js_object_set(
            err, str_intern("syscall"), jsv_from_string_id(str_intern("write"))
        );
        cb_args.append(err);
        cb_args.append(js_int(0));
    } else {
        cb_args.append(js_null());
        cb_args.append(js_int(n));
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""Build a contiguous uv_buf_t[] from flat [ptr0,len0,ptr1,len1,...] args.
args layout for readv/writev sync: [fd, position, nbufs, ptr0, len0, ...]
Returns bytes transferred, or negative on error."""
def _fs_rwv_sync(args: list[JSValue], is_write: bool) -> JSValue {
    if len(args) < 3 {
        return js_int(-1);
    }
    fd: int = _js_to_int(args[0]);
    position: int = _js_to_int(args[1]);
    nbufs: int = _js_to_int(args[2]);
    if fd < 0 or nbufs <= 0 {
        return js_int(-1);
    }
    if len(args) < 3 + nbufs * 2 {
        return js_int(-1);
    }
    # uv_buf_t is {char* base; size_t len} = 16 bytes on x86_64
    bufs_mem: int = calloc(nbufs, 16);
    if bufs_mem == 0 {
        return js_int(-1);
    }
    bi: int = 0;
    while bi < nbufs {
        p: int = _js_to_int(args[3 + bi * 2]);
        ln: int = _js_to_int(args[3 + bi * 2 + 1]);
        write_i64(bufs_mem, bi * 16, p);
        write_i64(bufs_mem, bi * 16 + 8, ln);
        bi = bi + 1;
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    if is_write {
        uv_fs_write(loop, req, fd, bufs_mem, nbufs, position, 0);
    } else {
        uv_fs_read(loop, req, fd, bufs_mem, nbufs, position, 0);
    }
    n: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    return js_int(n);
}

"""fs.readvSync(fd, position, nbufs, ptr0, len0, ...) → bytesRead."""
def:pub fs_readv_sync(args: list[JSValue]) -> JSValue {
    return _fs_rwv_sync(args, False);
}

"""fs.writevSync(fd, position, nbufs, ptr0, len0, ...) → bytesWritten."""
def:pub fs_writev_sync(args: list[JSValue]) -> JSValue {
    return _fs_rwv_sync(args, True);
}

"""Async readv/writev: same arg layout as sync, last arg is callback.
callback(err, bytes)."""
def _fs_rwv_async(args: list[JSValue], is_write: bool) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    # Strip callback for sync helper
    sync_args: list[JSValue] = [];
    ai: int = 0;
    while ai < len(args) - 1 {
        sync_args.append(args[ai]);
        ai = ai + 1;
    }
    result: JSValue = _fs_rwv_sync(sync_args, is_write);
    n: int = _js_to_int(result);
    cb_args: list[JSValue] = [];
    if n < 0 {
        op: str = "readv";
        if is_write {
            op = "writev";
        }
        err: JSValue = _make_fs_error("EBADF: bad file descriptor, " + op, "");
        js_object_set(err, str_intern("code"), jsv_from_string_id(str_intern("EBADF")));
        js_object_set(err, str_intern("syscall"), jsv_from_string_id(str_intern(op)));
        cb_args.append(err);
        cb_args.append(js_int(0));
    } else {
        cb_args.append(js_null());
        cb_args.append(js_int(n));
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

def:pub fs_readv(args: list[JSValue]) -> JSValue {
    return _fs_rwv_async(args, False);
}

def:pub fs_writev(args: list[JSValue]) -> JSValue {
    return _fs_rwv_async(args, True);
}

# ── Long-tail fd / path ops (fstat, truncate, utime, link, fsync, …) ─────────

"""Parse a JS number (int32 or float64) to float."""
def _js_to_float(v: JSValue) -> float {
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    return 0.0;
}

"""Throw a structured fs error via vm_throw_native."""
def _fs_throw(code: str, syscall: str, msg: str, path: str) {
    err: JSValue = _make_fs_error(msg, path);
    js_object_set(err, str_intern("code"), jsv_from_string_id(str_intern(code)));
    js_object_set(err, str_intern("syscall"), jsv_from_string_id(str_intern(syscall)));
    vm_throw_native(err);
}

"""Throw from a negative uv_fs_get_result code."""
def _fs_throw_uv(rc: int, syscall: str, path: str) {
    err: JSValue = _make_fs_uv_error(rc, syscall, path);
    vm_throw_native(err);
}

"""Push callback(err) for void async ops."""
def _fs_cb_void(callback: JSValue, rc: int, code: str, syscall: str, path: str) {
    cb_args: list[JSValue] = [];
    if rc < 0 {
        err: JSValue = _make_fs_uv_error(rc, syscall, path);
        # Preserve legacy caller-supplied code when uv name is empty
        if code != "" {
            js_object_set(
                err, str_intern("code"), jsv_from_string_id(str_intern(code))
            );
        }
        cb_args.append(err);
    } else {
        cb_args.append(js_null());
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
}

"""fs.fstatSync(fd) → Stats | undefined."""
def:pub fs_fstat_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    fd: int = _js_to_int(args[0]);
    if fd < 0 {
        return js_undefined();
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fstat(loop, req, fd, 0);
    result: int = uv_fs_get_result(req);
    if result < 0 {
        uv_fs_req_cleanup(req);
        return js_undefined();
    }
    statbuf: int = uv_fs_get_statbuf(req);
    stat_obj: JSValue = _build_stat_object(statbuf);
    uv_fs_req_cleanup(req);
    return stat_obj;
}

"""fs.fstat(fd, callback) → undefined. callback(err, stats)."""
def:pub fs_fstat(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    fd: int = _js_to_int(args[0]);
    cb_args: list[JSValue] = [];
    if fd < 0 {
        err: JSValue = _make_fs_error("EBADF: bad file descriptor, fstat", "");
        js_object_set(err, str_intern("code"), jsv_from_string_id(str_intern("EBADF")));
        js_object_set(
            err, str_intern("syscall"), jsv_from_string_id(str_intern("fstat"))
        );
        cb_args.append(err);
        cb_args.append(js_undefined());
    } else {
        loop: int = uv_default_loop();
        req: int = _fs_req_alloc();
        uv_fs_fstat(loop, req, fd, 0);
        result: int = uv_fs_get_result(req);
        if result < 0 {
            uv_fs_req_cleanup(req);
            err2: JSValue = _make_fs_error("EBADF: bad file descriptor, fstat", "");
            js_object_set(
                err2, str_intern("code"), jsv_from_string_id(str_intern("EBADF"))
            );
            js_object_set(
                err2, str_intern("syscall"), jsv_from_string_id(str_intern("fstat"))
            );
            cb_args.append(err2);
            cb_args.append(js_undefined());
        } else {
            statbuf: int = uv_fs_get_statbuf(req);
            stat_obj: JSValue = _build_stat_object(statbuf);
            uv_fs_req_cleanup(req);
            cb_args.append(js_null());
            cb_args.append(stat_obj);
        }
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}

"""fs.ftruncateSync(fd, len?) → undefined."""
def:pub fs_ftruncate_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    fd: int = _js_to_int(args[0]);
    length: int = 0;
    if len(args) >= 2 {
        length = _js_to_int(args[1]);
    }
    if length < 0 {
        length = 0;
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_ftruncate(loop, req, fd, length, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw("EBADF", "ftruncate", "EBADF: bad file descriptor, ftruncate", "");
        return js_undefined();
    }
    return js_undefined();
}

"""fs.ftruncate(fd, [len], callback) → undefined. callback(err)."""
def:pub fs_ftruncate(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    fd: int = _js_to_int(args[0]);
    length: int = 0;
    if len(args) >= 3 {
        length = _js_to_int(args[1]);
    }
    if length < 0 {
        length = 0;
    }
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_ftruncate(loop, req, fd, length, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "EBADF", "ftruncate", "");
    return js_undefined();
}

"""Path truncate via open(O_WRONLY) + ftruncate + close. Returns uv result (<0 on error)."""
def _path_truncate(path: str, length: int) -> int {
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    # O_WRONLY = 1
    uv_fs_open(loop, req, path, _O_WRONLY, 0, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if fd < 0 {
        return fd;
    }
    req2: int = _fs_req_alloc();
    uv_fs_ftruncate(loop, req2, fd, length, 0);
    rc: int = uv_fs_get_result(req2);
    uv_fs_req_cleanup(req2);
    req3: int = _fs_req_alloc();
    uv_fs_close(loop, req3, fd, 0);
    uv_fs_req_cleanup(req3);
    return rc;
}

"""fs.truncateSync(path, len?) → undefined."""
def:pub fs_truncate_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 1 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    length: int = 0;
    if len(args) >= 2 {
        length = _js_to_int(args[1]);
    }
    if length < 0 {
        length = 0;
    }
    rc: int = _path_truncate(path, length);
    if rc < 0 {
        _fs_throw(
            "ENOENT",
            "truncate",
            "ENOENT: no such file or directory, truncate '" + path + "'",
            path
        );
        return js_undefined();
    }
    return js_undefined();
}

"""fs.truncate(path, [len], callback) → undefined. callback(err)."""
def:pub fs_truncate(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[len(args) - 1];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    length: int = 0;
    if len(args) >= 3 {
        length = _js_to_int(args[1]);
    }
    if length < 0 {
        length = 0;
    }
    rc: int = _path_truncate(path, length);
    _fs_cb_void(callback, rc, "ENOENT", "truncate", path);
    return js_undefined();
}

"""fs.utimesSync(path, atime, mtime) — times in seconds (float)."""
def:pub fs_utime_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 3 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    atime: float = _js_to_float(args[1]);
    mtime: float = _js_to_float(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_utime(loop, req, path, atime, mtime, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw(
            "ENOENT",
            "utime",
            "ENOENT: no such file or directory, utime '" + path + "'",
            path
        );
        return js_undefined();
    }
    return js_undefined();
}

"""fs.utimes(path, atime, mtime, callback) → undefined. callback(err)."""
def:pub fs_utime(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[3];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    atime: float = _js_to_float(args[1]);
    mtime: float = _js_to_float(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_utime(loop, req, path, atime, mtime, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "ENOENT", "utime", path);
    return js_undefined();
}

"""fs.futimesSync(fd, atime, mtime) — times in seconds."""
def:pub fs_futime_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    fd: int = _js_to_int(args[0]);
    atime: float = _js_to_float(args[1]);
    mtime: float = _js_to_float(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_futime(loop, req, fd, atime, mtime, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw("EBADF", "futime", "EBADF: bad file descriptor, futime", "");
        return js_undefined();
    }
    return js_undefined();
}

"""fs.futimes(fd, atime, mtime, callback) → undefined. callback(err)."""
def:pub fs_futime(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[3];
    fd: int = _js_to_int(args[0]);
    atime: float = _js_to_float(args[1]);
    mtime: float = _js_to_float(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_futime(loop, req, fd, atime, mtime, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "EBADF", "futime", "");
    return js_undefined();
}

"""fs.lutimesSync(path, atime, mtime) — times in seconds; does not follow symlinks."""
def:pub fs_lutime_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 3 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    atime: float = _js_to_float(args[1]);
    mtime: float = _js_to_float(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_lutime(loop, req, path, atime, mtime, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw(
            "ENOENT",
            "lutime",
            "ENOENT: no such file or directory, lutime '" + path + "'",
            path
        );
        return js_undefined();
    }
    return js_undefined();
}

"""fs.lutimes(path, atime, mtime, callback) → undefined. callback(err)."""
def:pub fs_lutime(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[3];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    atime: float = _js_to_float(args[1]);
    mtime: float = _js_to_float(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_lutime(loop, req, path, atime, mtime, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "ENOENT", "lutime", path);
    return js_undefined();
}

"""fs.linkSync(existingPath, newPath) → undefined."""
def:pub fs_link_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 2
        or not jsv_is_string_cell(args[0])
        or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    existing: str = str_from_id(jsv_to_table_id(args[0]));
    new_path: str = str_from_id(jsv_to_table_id(args[1]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_link(loop, req, existing, new_path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw(
            "ENOENT",
            "link",
            "ENOENT: no such file or directory, link '"
                + existing
                + "' -> '"
                + new_path
                + "'",
            existing
        );
        return js_undefined();
    }
    return js_undefined();
}

"""fs.link(existingPath, newPath, callback) → undefined. callback(err)."""
def:pub fs_link(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    callback: JSValue = args[2];
    if not jsv_is_string_cell(args[0]) or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    existing: str = str_from_id(jsv_to_table_id(args[0]));
    new_path: str = str_from_id(jsv_to_table_id(args[1]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_link(loop, req, existing, new_path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "ENOENT", "link", existing);
    return js_undefined();
}

"""fs.fsyncSync(fd) → undefined."""
def:pub fs_fsync_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    fd: int = _js_to_int(args[0]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fsync(loop, req, fd, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw("EBADF", "fsync", "EBADF: bad file descriptor, fsync", "");
        return js_undefined();
    }
    return js_undefined();
}

"""fs.fsync(fd, callback) → undefined. callback(err)."""
def:pub fs_fsync(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[1];
    fd: int = _js_to_int(args[0]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fsync(loop, req, fd, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "EBADF", "fsync", "");
    return js_undefined();
}

"""fs.fdatasyncSync(fd) → undefined."""
def:pub fs_fdatasync_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    fd: int = _js_to_int(args[0]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fdatasync(loop, req, fd, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw("EBADF", "fdatasync", "EBADF: bad file descriptor, fdatasync", "");
        return js_undefined();
    }
    return js_undefined();
}

"""fs.fdatasync(fd, callback) → undefined. callback(err)."""
def:pub fs_fdatasync(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    callback: JSValue = args[1];
    fd: int = _js_to_int(args[0]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fdatasync(loop, req, fd, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "EBADF", "fdatasync", "");
    return js_undefined();
}

"""fs.fchmodSync(fd, mode) → undefined."""
def:pub fs_fchmod_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    fd: int = _js_to_int(args[0]);
    mode: int = _js_to_int(args[1]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fchmod(loop, req, fd, mode, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw("EBADF", "fchmod", "EBADF: bad file descriptor, fchmod", "");
        return js_undefined();
    }
    return js_undefined();
}

"""fs.fchmod(fd, mode, callback) → undefined. callback(err)."""
def:pub fs_fchmod(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    callback: JSValue = args[2];
    fd: int = _js_to_int(args[0]);
    mode: int = _js_to_int(args[1]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fchmod(loop, req, fd, mode, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "EBADF", "fchmod", "");
    return js_undefined();
}

"""fs.fchownSync(fd, uid, gid) → undefined."""
def:pub fs_fchown_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    fd: int = _js_to_int(args[0]);
    uid: int = _js_to_int(args[1]);
    gid: int = _js_to_int(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fchown(loop, req, fd, uid, gid, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw("EBADF", "fchown", "EBADF: bad file descriptor, fchown", "");
        return js_undefined();
    }
    return js_undefined();
}

"""fs.fchown(fd, uid, gid, callback) → undefined. callback(err)."""
def:pub fs_fchown(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[3];
    fd: int = _js_to_int(args[0]);
    uid: int = _js_to_int(args[1]);
    gid: int = _js_to_int(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_fchown(loop, req, fd, uid, gid, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "EBADF", "fchown", "");
    return js_undefined();
}

"""fs.lchownSync(path, uid, gid) → undefined."""
def:pub fs_lchown_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 3 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    uid: int = _js_to_int(args[1]);
    gid: int = _js_to_int(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_lchown(loop, req, path, uid, gid, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    if rc < 0 {
        _fs_throw(
            "ENOENT",
            "lchown",
            "ENOENT: no such file or directory, lchown '" + path + "'",
            path
        );
        return js_undefined();
    }
    return js_undefined();
}

"""fs.lchown(path, uid, gid, callback) → undefined. callback(err)."""
def:pub fs_lchown(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    callback: JSValue = args[3];
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    uid: int = _js_to_int(args[1]);
    gid: int = _js_to_int(args[2]);
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_lchown(loop, req, path, uid, gid, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    _fs_cb_void(callback, rc, "ENOENT", "lchown", path);
    return js_undefined();
}

"""Build StatsFs-like object from uv_statfs_t.
Layout (libuv): type@0 bsize@8 blocks@16 bfree@24 bavail@32 files@40 ffree@48."""
def _build_statfs_object(buf_addr: int) -> JSValue {
    typ_val: int = _read_u64(buf_addr + 0);
    bsize_val: int = _read_u64(buf_addr + 8);
    blocks_val: int = _read_u64(buf_addr + 16);
    bfree_val: int = _read_u64(buf_addr + 24);
    bavail_val: int = _read_u64(buf_addr + 32);
    files_val: int = _read_u64(buf_addr + 40);
    ffree_val: int = _read_u64(buf_addr + 48);
    sf_obj: JSValue = js_object_create_null();
    js_object_set(sf_obj, str_intern("type"), jsv_from_double(float(typ_val)));
    js_object_set(sf_obj, str_intern("bsize"), jsv_from_double(float(bsize_val)));
    # libuv uv_statfs_t has no f_frsize; Node exposes frsize — mirror bsize.
    js_object_set(sf_obj, str_intern("frsize"), jsv_from_double(float(bsize_val)));
    js_object_set(sf_obj, str_intern("blocks"), jsv_from_double(float(blocks_val)));
    js_object_set(sf_obj, str_intern("bfree"), jsv_from_double(float(bfree_val)));
    js_object_set(sf_obj, str_intern("bavail"), jsv_from_double(float(bavail_val)));
    js_object_set(sf_obj, str_intern("files"), jsv_from_double(float(files_val)));
    js_object_set(sf_obj, str_intern("ffree"), jsv_from_double(float(ffree_val)));
    return sf_obj;
}

"""fs.statfsSync(path) -> StatsFs."""
def:pub fs_statfs_sync(args: list[JSValue]) -> JSValue {
    if len(args) < 1 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_statfs(loop, req, path, 0);
    rc: int = uv_fs_get_result(req);
    if rc < 0 {
        uv_fs_req_cleanup(req);
        _fs_throw_uv(rc, "statfs", path);
        return js_undefined();
    }
    sf_ptr: int = uv_fs_get_ptr(req);
    sf_obj: JSValue = _build_statfs_object(sf_ptr);
    uv_fs_req_cleanup(req);
    return sf_obj;
}

"""fs.statfs(path, callback) -> undefined. callback(err, stats)."""
def:pub fs_statfs(args: list[JSValue]) -> JSValue {
    if len(args) < 2 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    callback: JSValue = args[len(args) - 1];
    loop: int = uv_default_loop();
    req: int = _fs_req_alloc();
    uv_fs_statfs(loop, req, path, 0);
    rc: int = uv_fs_get_result(req);
    cb_args: list[JSValue] = [];
    if rc < 0 {
        uv_fs_req_cleanup(req);
        cb_args.append(_make_fs_uv_error(rc, "statfs", path));
        cb_args.append(js_undefined());
    } else {
        sf_ptr: int = uv_fs_get_ptr(req);
        sf_obj: JSValue = _build_statfs_object(sf_ptr);
        uv_fs_req_cleanup(req);
        cb_args.append(js_null());
        cb_args.append(sf_obj);
    }
    if not jsv_is_undefined(callback) {
        _fs_push_callback(callback, cb_args);
    }
    return js_undefined();
}
