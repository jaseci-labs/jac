"""Child process bridge — Linux posix_spawn/fork + pipe I/O for node:child_process.

Exposed via globalThis.__cp (native fns in global.na.jac).
JS layer: src/builtins/js/child_process.js

Sync: posix_spawnp + waitpid + pipe read (spawnSync / execSync / execFileSync).
      fork+execvpe fallback when cwd is non-empty.
Async: posix_spawnp + uv_poll on stdout/stderr; events drained in el_tick.
"""

import from engine.src.ffi.libc {
    fork,
    execve,
    execvpe,
    waitpid,
    pipe,
    dup2,
    close,
    setsid,
    chdir,
    kill,
    get_errno,
    read,
    write,
    fcntl,
    calloc,
    free,
    _exit,
    fopen,
    fread,
    fclose,
    poll,
    posix_spawnp,
    posix_spawn_file_actions_init,
    posix_spawn_file_actions_destroy,
    posix_spawn_file_actions_adddup2,
    posix_spawn_file_actions_addclose,
    posix_spawn_file_actions_addchdir_np
}
import from engine.src.ffi.libuv {
    UVLoop,
    UVHandle,
    uvpoll_create,
    uvpoll_start,
    uvpoll_stop,
    uvasync_send,
    uvhandle_ref,
    uvhandle_unref
}
import from engine.src.runtime.mem {
    io_alloc,
    io_free,
    read_byte,
    write_byte,
    write_i32,
    read_u32,
    read_i32,
    read_u64,
    write_i64,
    str_from_raw
}
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_int,
    jsv_is_string_cell,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_to_int32,
    jsv_to_double,
    jsv_from_string_id
}
import from engine.src.runtime.jsobject { js_object_create_null, js_object_set }
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.builtins.array {
    js_array_create,
    js_array_len,
    js_array_get,
    js_is_array
}
import from engine.src.runtime.gc_pin { gc_pin_value, gc_unpin_value }

glob _WNOHANG: int = 1,
     _O_NONBLOCK: int = 2048,
     _F_GETFL: int = 3,
     _F_SETFL: int = 4,
     _SIGTERM: int = 15,
     _CP_SPAWN_FILE_ACTIONS_SZ: int = 128;

# glibc posix_spawn_file_actions_t ≈ 80 bytes
"""Copy n bytes from buf pointer into a new null-terminated str."""
# Runtime (non-constant) empty operand: `"" + x` would be constant-folded; a
# glob makes the concat allocate a real refcounted JacStr from the temp buffer.
glob _CP_EMPTY_RT: str = "";

"""Copy n raw bytes at `buf` into a refcounted Jac str.

The old code cast a bare io_alloc buffer to `str`. Every refcount touch on
such a str reads the 32-byte JacStr header BEFORE the data pointer; for a
large (mmap'd) allocation that lies before the start of the mapping →
SIGSEGV (the react-dom esbuild transform crashed exactly there). The temp
buffer now carries a zeroed 32-byte prefix (header reads stay in-bounds and
fail the magic check) and the result is a real refcounted copy."""
def _cp_buf_to_str(buf: int, n: int) -> str {
    if n <= 0 {
        return _CP_EMPTY_RT + "";
    }
    out: int = io_alloc(n + 33);
    data: int = out + 32;
    bi: int = 0;
    while bi < n {
        write_byte(data, bi, read_byte(buf, bi));
        bi = bi + 1;
    }
    write_byte(data, n, 0);
    result: str = str_from_raw(data);
    io_free(out);
    return result;
}

glob _CP_B64_ALPHABET: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

"""Base64 char → 6-bit value, or -1 for non-alphabet ('='/whitespace). Used by
the stdin decoder; child stdin (esbuild request packets) is BINARY, so JS sends
it base64 and it is decoded to raw bytes here before write()."""
def _cp_b64_val(c: int) -> int {
    if c >= 65 and c <= 90 {
        return c - 65;
    }  # A-Z
    if c >= 97 and c <= 122 {
        return c - 97 + 26;
    }  # a-z
    if c >= 48 and c <= 57 {
        return c - 48 + 52;
    }  # 0-9
    if c == 43 {
        return 62;
    }  # +
    if c == 47 {
        return 63;
    }  # /
    return -1;
}

"""Decode base64 str `b64` into a freshly io_alloc'd byte buffer. Returns the
buffer pointer; writes the decoded byte count into out_len[0]."""
def _cp_b64_to_buf(b64: str, out_len: list[int]) -> int {
    slen: int = len(b64);
    # Upper bound: 3 bytes per 4 chars. The decoded bytes start 32 bytes into
    # the block (a zeroed JacStr-header-sized prefix): _cp_write_all passes
    # `ptr + off` to write() as a `str`, and the refcount guards on that
    # argument read the 32 bytes before it — which for an mmap'd block would
    # be unmapped memory. Callers use `base + 32` and io_free(base).
    cap: int = (slen // 4) * 3 + 3;
    out: int = io_alloc(cap + 33) + 32;
    acc: int = 0;
    nbits: int = 0;
    di: int = 0;
    si: int = 0;
    while si < slen {
        v: int = _cp_b64_val(ord(b64[si]));
        si = si + 1;
        if v >= 0 {
            acc = (acc << 6) | v;
            nbits = nbits + 6;
            if nbits >= 8 {
                nbits = nbits - 8;
                write_byte(out, di, (acc >> nbits) & 255);
                di = di + 1;
            }
        }
    }
    out_len[0] = di;
    return out - 32;
}

"""Base64-encode n raw bytes at `buf` into an intern-safe ASCII string.

Child stdout/stderr is BINARY (esbuild's stdio protocol is full of NUL and
high bytes). A raw byte buffer cannot survive str_intern (truncates at NUL), so
the bytes are base64-encoded here and decoded back to a Buffer in JS
(child_process.js, `Buffer.from(chunk, 'base64')`). Base64 output is NUL-free
7-bit ASCII, so interning is lossless."""
def _cp_buf_to_b64(buf: int, n: int) -> str {
    if n <= 0 {
        return str_from_id(str_intern(""));
    }
    # 4 output chars per 3 input bytes, rounded up.
    out_len: int = ((n + 2) // 3) * 4;
    out: int = io_alloc(out_len + 33) + 32;  # zeroed 32-byte header prefix
    alpha: str = _CP_B64_ALPHABET;
    si: int = 0;
    di: int = 0;
    while si < n {
        b0: int = read_byte(buf, si);
        b1: int = 0;
        b2: int = 0;
        have1: bool = si + 1 < n;
        have2: bool = si + 2 < n;
        if have1 {
            b1 = read_byte(buf, si + 1);
        }
        if have2 {
            b2 = read_byte(buf, si + 2);
        }
        triple: int = (b0 << 16) | (b1 << 8) | b2;
        write_byte(out, di, ord(alpha[(triple >> 18) & 63]));
        write_byte(out, di + 1, ord(alpha[(triple >> 12) & 63]));
        if have1 {
            write_byte(out, di + 2, ord(alpha[(triple >> 6) & 63]));
        } else {
            write_byte(out, di + 2, ord("="));
        }
        if have2 {
            write_byte(out, di + 3, ord(alpha[triple & 63]));
        } else {
            write_byte(out, di + 3, ord("="));
        }
        si = si + 3;
        di = di + 4;
    }
    write_byte(out, out_len, 0);
    result: str = str_from_raw(out);
    io_free(out - 32);
    return result;
}

"""Drain all currently-available bytes from `fd` as a base64 string (binary-safe).
Mirrors _cp_drain_available_fd but base64-encodes each chunk so NUL/high bytes
survive the str path. Concatenating base64 of separate chunks is invalid, so a
single logical read is encoded whole: accumulate raw bytes, then encode once."""
def _cp_drain_available_fd_b64(fd: int) -> str {
    if fd < 0 {
        return "";
    }
    _cp_set_nonblock(fd);
    chunk_sz: int = 65536;
    # Accumulate raw bytes into a growable heap buffer, then base64 once.
    cap: int = chunk_sz;
    acc: int = io_alloc(cap);
    total: int = 0;
    keep: int = 1;
    while keep == 1 {
        # Ensure room for another chunk_sz read.
        if total + chunk_sz > cap {
            new_cap: int = cap * 2;
            while total + chunk_sz > new_cap {
                new_cap = new_cap * 2;
            }
            grown: int = io_alloc(new_cap);
            ci: int = 0;
            while ci < total {
                write_byte(grown, ci, read_byte(acc, ci));
                ci = ci + 1;
            }
            io_free(acc);
            acc = grown;
            cap = new_cap;
        }
        rd: int = read(fd, acc + total, chunk_sz);  # jac:ignore[E1001] ptr+offset
        if rd > 0 {
            total = total + rd;
        } else {
            keep = 0;
        }
    }
    if total <= 0 {
        io_free(acc);
        return "";
    }
    enc: str = _cp_buf_to_b64(acc, total);
    io_free(acc);
    return enc;
}

"""Copy string s to heap null-terminated buffer; returns pointer."""
def _cp_strdup(s: str) -> int {
    n: int = len(s);
    p: int = io_alloc(n + 1);
    i: int = 0;
    while i < n {
        write_byte(p, i, ord(s[i]));
        i = i + 1;
    }
    write_byte(p, n, 0);
    return p;
}

"""Build argv char** from JS array of argument strings (file is argv[0])."""
def _cp_build_argv_from_js(file: str, argv_arr: JSValue) -> int {
    argc: int = 1;
    extra: int = 0;
    if js_is_array(argv_arr) {
        extra = js_array_len(argv_arr);
        argc = 1 + extra;
    }
    argv_pp: int = io_alloc((argc + 1) * 8);
    write_i64(argv_pp, 0, _cp_strdup(file));
    ai: int = 0;
    while ai < extra {
        el: JSValue = js_array_get(argv_arr, ai);
        field: str = "";
        if jsv_is_string_cell(el) {
            field = str_from_id(jsv_to_table_id(el));
        }
        write_i64(argv_pp, (ai + 1) * 8, _cp_strdup(field));
        ai = ai + 1;
    }
    write_i64(argv_pp, argc * 8, 0);
    return argv_pp;
}

"""Build envp from newline-separated KEY=VALUE block."""
def _cp_build_envp(env_block: str) -> int {
    if env_block == "" {
        return 0;
    }
    lines: int = 1;
    n: int = len(env_block);
    li: int = 0;
    while li < n {
        if ord(env_block[li]) == 10 {
            lines = lines + 1;
        }
        li = li + 1;
    }
    envp: int = io_alloc((lines + 1) * 8);
    ei: int = 0;
    start: int = 0;
    li = 0;
    while li <= n {
        ch: int = 10;
        if li < n {
            ch = ord(env_block[li]);
        }
        if ch == 10 or li == n {
            if li > start {
                line: str = env_block[start:li];
                if len(line) > 0 {
                    ep: int = _cp_strdup(line);
                    write_i64(envp, ei * 8, ep);
                    ei = ei + 1;
                }
            }
            start = li + 1;
        }
        li = li + 1;
    }
    write_i64(envp, ei * 8, 0);
    return envp;
}

"""Build envp from /proc/self/environ (inherit parent environment)."""
def _cp_build_envp_inherit -> int {
    fp: int = fopen("/proc/self/environ", "rb");
    if fp == 0 {
        return 0;
    }
    BUF: int = 131072;
    buf: int = io_alloc(BUF);
    n: int = fread(buf, 1, BUF - 1, fp);
    fclose(fp);
    if n <= 0 {
        return 0;
    }
    cnt: int = 0;
    pos: int = 0;
    while pos < n {
        if read_byte(buf, pos) == 0 {
            cnt = cnt + 1;
        }
        pos = pos + 1;
    }
    if cnt == 0 {
        return 0;
    }
    envp: int = io_alloc((cnt + 1) * 8);
    ei: int = 0;
    start: int = 0;
    pos = 0;
    while pos <= n {
        if pos == n or read_byte(buf, pos) == 0 {
            if pos > start {
                line: str = _cp_buf_to_str(buf + start, pos - start);
                if len(line) > 0 {
                    ep: int = _cp_strdup(line);
                    write_i64(envp, ei * 8, ep);
                    ei = ei + 1;
                }
            }
            start = pos + 1;
        }
        pos = pos + 1;
    }
    write_i64(envp, ei * 8, 0);
    return envp;
}

"""Read fd until EOF into str; respect max_bytes."""
def _cp_read_fd_all(fd: int, max_bytes: int) -> str {
    if fd < 0 {
        return "";
    }
    chunk_sz: int = 65536;
    total: int = 0;
    out: str = "";
    keep: int = 1;
    while keep == 1 {
        buf: int = calloc(1, chunk_sz + 1);
        if buf == 0 {
            keep = 0;
        } else {
            n: int = read(fd, buf, chunk_sz);
            if n <= 0 {
                free(buf);
                keep = 0;
            } else {
                if max_bytes > 0 and total + n > max_bytes {
                    n = max_bytes - total;
                    keep = 0;
                }
                if n > 0 {
                    chunk: str = _cp_buf_to_str(buf, n);
                    free(buf);
                    out = out + chunk;
                    total = total + n;
                } else {
                    free(buf);
                }
            }
        }
    }
    return out;
}

def _cp_set_nonblock(fd: int) -> None {
    if fd < 0 {
        return;
    }
    fl: int = fcntl(fd, _F_GETFL, 0);
    fcntl(fd, _F_SETFL, fl | _O_NONBLOCK);
}

"""Non-blocking read of all currently available bytes from fd."""
def _cp_drain_available_fd(fd: int) -> str {
    if fd < 0 {
        return "";
    }
    _cp_set_nonblock(fd);
    chunk_sz: int = 65536;
    out: str = "";
    keep: int = 1;
    while keep == 1 {
        buf: int = calloc(1, chunk_sz + 1);
        if buf == 0 {
            keep = 0;
        } else {
            n: int = read(fd, buf, chunk_sz);
            if n > 0 {
                out = out + _cp_buf_to_str(buf, n);
                free(buf);
            } else {
                free(buf);
                keep = 0;
            }
        }
    }
    return out;
}

def _cp_wait_status_code(st: int) -> int {
    sig: int = st & 127;
    if sig != 0 {
        return -1;
    }
    return (st // 256) & 255;
}

def _cp_wait_signal(st: int) -> int {
    sig: int = st & 127;
    return sig;
}

def _signal_name(sig: int) -> str {
    if sig == 1 {
        return "SIGHUP";
    }
    if sig == 2 {
        return "SIGINT";
    }
    if sig == 3 {
        return "SIGQUIT";
    }
    if sig == 4 {
        return "SIGILL";
    }
    if sig == 6 {
        return "SIGABRT";
    }
    if sig == 8 {
        return "SIGFPE";
    }
    if sig == 9 {
        return "SIGKILL";
    }
    if sig == 11 {
        return "SIGSEGV";
    }
    if sig == 13 {
        return "SIGPIPE";
    }
    if sig == 14 {
        return "SIGALRM";
    }
    if sig == 15 {
        return "SIGTERM";
    }
    if sig == 17 {
        return "SIGCHLD";
    }
    if sig == 19 {
        return "SIGSTOP";
    }
    return "SIG" + str(sig);
}

"""Configure posix_spawn file actions for stdio pipe wiring."""
def _cp_spawn_file_actions_setup(
    fa: int, in_r: int, in_w: int, out_r: int, out_w: int, err_r: int, err_w: int
) -> int {
    rc: int = posix_spawn_file_actions_init(fa);
    if rc != 0 {
        return rc;
    }
    rc = posix_spawn_file_actions_adddup2(fa, in_r, 0);
    if rc != 0 {
        return rc;
    }
    rc = posix_spawn_file_actions_adddup2(fa, out_w, 1);
    if rc != 0 {
        return rc;
    }
    rc = posix_spawn_file_actions_adddup2(fa, err_w, 2);
    if rc != 0 {
        return rc;
    }
    if in_r > 2 {
        rc = posix_spawn_file_actions_addclose(fa, in_r);
        if rc != 0 {
            return rc;
        }
    }
    if in_w > 2 {
        rc = posix_spawn_file_actions_addclose(fa, in_w);
        if rc != 0 {
            return rc;
        }
    }
    if out_r > 2 {
        rc = posix_spawn_file_actions_addclose(fa, out_r);
        if rc != 0 {
            return rc;
        }
    }
    if out_w > 2 {
        rc = posix_spawn_file_actions_addclose(fa, out_w);
        if rc != 0 {
            return rc;
        }
    }
    if err_r > 2 {
        rc = posix_spawn_file_actions_addclose(fa, err_r);
        if rc != 0 {
            return rc;
        }
    }
    if err_w > 2 {
        rc = posix_spawn_file_actions_addclose(fa, err_w);
        if rc != 0 {
            return rc;
        }
    }
    return 0;
}

"""Spawn via posix_spawnp (no fork — avoids COW address-space duplication under load).
Optional `cwd` is applied with glibc's addchdir_np so we never need fork just to
change directory (fork under a tight RLIMIT_AS was a top source of SIGSEGV in
es-module spawn-heavy tests)."""
def _cp_posix_spawn(
    file: str,
    argv_pp: int,
    envp: int,
    in_r: int,
    in_w: int,
    out_r: int,
    out_w: int,
    err_r: int,
    err_w: int,
    cwd: str
) -> int {
    fa: int = io_alloc(_CP_SPAWN_FILE_ACTIONS_SZ);
    rc: int = _cp_spawn_file_actions_setup(fa, in_r, in_w, out_r, out_w, err_r, err_w);
    if rc != 0 {
        posix_spawn_file_actions_destroy(fa);
        return -1;
    }
    if cwd != "" {
        rc = posix_spawn_file_actions_addchdir_np(fa, cwd);
        if rc != 0 {
            posix_spawn_file_actions_destroy(fa);
            return -1;
        }
    }
    pid_ptr: int = io_alloc(4);
    env_use: int = envp;
    sp_rc: int = posix_spawnp(pid_ptr, file, fa, 0, argv_pp, env_use);
    posix_spawn_file_actions_destroy(fa);
    if sp_rc != 0 {
        return -1;
    }
    return read_i32(pid_ptr, 0);
}

"""Fallback spawn when detached:true (needs setsid in the child)."""
def _cp_fork_exec_spawn(
    file: str,
    argv_pp: int,
    envp: int,
    cwd: str,
    in_r: int,
    in_w: int,
    out_r: int,
    out_w: int,
    err_r: int,
    err_w: int,
    detached: int
) -> int {
    pid: int = fork();
    if pid == 0 {
        # Node's options.detached === true → new session (setsid).
        # Default spawn must NOT setsid — children stay in the parent's
        # process group so killpg of the parent reaps them.
        if detached != 0 {
            setsid();
        }
        if cwd != "" {
            chdir(cwd);
        }
        dup2(in_r, 0);
        dup2(out_w, 1);
        dup2(err_w, 2);
        if in_r > 2 {
            close(in_r);
        }
        if in_w > 2 {
            close(in_w);
        }
        if out_r > 2 {
            close(out_r);
        }
        if out_w > 2 {
            close(out_w);
        }
        if err_r > 2 {
            close(err_r);
        }
        if err_w > 2 {
            close(err_w);
        }
        env_use: int = envp;
        execvpe(file, argv_pp, env_use);
        _exit(127);
    }
    return pid;
}

"""Spawn child process; returns pid or -1 on failure."""
def _cp_spawn_process(
    file: str,
    argv_pp: int,
    envp: int,
    cwd: str,
    in_r: int,
    in_w: int,
    out_r: int,
    out_w: int,
    err_r: int,
    err_w: int,
    detached: int
) -> int {
    # detached requires setsid in the child → fork/exec path.
    # cwd alone uses posix_spawn + addchdir_np (no address-space duplication).
    if detached != 0 {
        return _cp_fork_exec_spawn(
            file, argv_pp, envp, cwd, in_r, in_w, out_r, out_w, err_r, err_w, detached
        );
    }
    return _cp_posix_spawn(
        file, argv_pp, envp, in_r, in_w, out_r, out_w, err_r, err_w, cwd
    );
}

"""spawnSync(file, argv_blob, cwd, env_block, input, max_buffer) -> result object."""
def:pub cp_spawn_sync(args: list[JSValue]) -> JSValue {
    file: str = "";
    argv_blob: str = "";
    cwd: str = "";
    env_block: str = "";
    inp: str = "";
    max_buf: int = 1048576;
    if len(args) >= 1 and jsv_is_string_cell(args[0]) {
        file = str_from_id(jsv_to_table_id(args[0]));
    }
    argv_arr: JSValue = js_undefined();
    if len(args) >= 2 {
        argv_arr = args[1];
    }
    if len(args) >= 3 and jsv_is_string_cell(args[2]) {
        cwd = str_from_id(jsv_to_table_id(args[2]));
    }
    if len(args) >= 4 and jsv_is_string_cell(args[3]) {
        env_block = str_from_id(jsv_to_table_id(args[3]));
    }
    if len(args) >= 5 and jsv_is_string_cell(args[4]) {
        inp = str_from_id(jsv_to_table_id(args[4]));
    }
    if len(args) >= 6 {
        if jsv_is_int32(args[5]) {
            max_buf = jsv_to_int32(args[5]);
        } elif jsv_is_double(args[5]) {
            max_buf = int(jsv_to_double(args[5]));
        }
    }

    out_pipe: int = io_alloc(8);
    err_pipe: int = io_alloc(8);
    in_pipe: int = io_alloc(8);
    pipe(out_pipe);
    pipe(err_pipe);
    pipe(in_pipe);
    out_r: int = read_u32(out_pipe, 0);
    out_w: int = read_u32(out_pipe, 4);
    err_r: int = read_u32(err_pipe, 0);
    err_w: int = read_u32(err_pipe, 4);
    in_r: int = read_u32(in_pipe, 0);
    in_w: int = read_u32(in_pipe, 4);

    argv_pp: int = _cp_build_argv_from_js(file, argv_arr);
    envp: int = _cp_build_envp(env_block);
    # Build inherited env in parent — never malloc/fopen in child after fork (async-signal-unsafe).
    if envp == 0 {
        envp = _cp_build_envp_inherit();
    }

    pid: int = _cp_spawn_process(
        file, argv_pp, envp, cwd, in_r, in_w, out_r, out_w, err_r, err_w, 0
    );

    if pid < 0 {
        close(in_r);
        close(in_w);
        close(out_r);
        close(out_w);
        close(err_r);
        close(err_w);
        res: JSValue = js_object_create_null();
        js_object_set(res, str_intern("pid"), js_int(-1));
        js_object_set(res, str_intern("stdout"), jsv_from_string_id(str_intern("")));
        js_object_set(res, str_intern("stderr"), jsv_from_string_id(str_intern("")));
        js_object_set(res, str_intern("status"), js_null());
        js_object_set(res, str_intern("signal"), js_null());
        return res;
    }

    close(in_r);
    close(out_w);
    close(err_w);

    if len(inp) > 0 and in_w >= 0 {
        write(in_w, inp, len(inp));
    }
    close(in_w);

    stdout_s: str = _cp_read_fd_all(out_r, max_buf);
    close(out_r);
    stderr_s: str = _cp_read_fd_all(err_r, max_buf);
    close(err_r);

    status_ptr: int = io_alloc(4);
    waitpid(pid, status_ptr, 0);
    st: int = read_i32(status_ptr, 0);

    code: int = _cp_wait_status_code(st);
    sig: int = _cp_wait_signal(st);

    res: JSValue = js_object_create_null();
    js_object_set(res, str_intern("pid"), js_int(pid));
    js_object_set(res, str_intern("stdout"), jsv_from_string_id(str_intern(stdout_s)));
    js_object_set(res, str_intern("stderr"), jsv_from_string_id(str_intern(stderr_s)));
    if code >= 0 {
        js_object_set(res, str_intern("status"), js_int(code));
        js_object_set(res, str_intern("signal"), js_null());
    } else {
        js_object_set(res, str_intern("status"), js_null());
        js_object_set(
            res, str_intern("signal"), jsv_from_string_id(str_intern(_signal_name(sig)))
        );
    }
    if sig != 0 {
        js_object_set(res, str_intern("status"), js_null());
    }
    return res;
}

# ── Async spawn handles ───────────────────────────────────────────────────────

glob _CP_HANDLES_PID: list[int] = [0],
     _CP_HANDLES_OUT_R: list[int] = [0],
     _CP_HANDLES_ERR_R: list[int] = [0],
     _CP_HANDLES_IN_W: list[int] = [-1],
     _CP_HANDLES_OUT_ACC: list[str] = [""],
     _CP_HANDLES_ERR_ACC: list[str] = [""],
     _CP_HANDLES_EXITED: list[int] = [0],
     _CP_HANDLES_EXIT_CODE: list[int] = [0],
     _CP_HANDLES_SIGNAL: list[int] = [0],
     _CP_HANDLES_POLL_OUT: list[UVHandle] = [UVHandle()],
     _CP_HANDLES_POLL_ERR: list[UVHandle] = [UVHandle()],
     _CP_ASYNC_PTR: int = 0,
     _CP_LOOP_PTR: int = 0,
     _CP_DRAIN_FN: JSValue = js_undefined(),
     _CP_EVT_HANDLE: list[int] = [],
     _CP_EVT_NAME: list[str] = [],
     _CP_EVT_ARG0: list[str] = [],
     _CP_EVT_ARG1: list[str] = [];

def:pub cp_init(loop_ptr: int, async_ptr: int) {
    _CP_LOOP_PTR = loop_ptr;
    _CP_ASYNC_PTR = async_ptr;
}

def _cp_wake {
    if _CP_ASYNC_PTR != 0 {
        ah: UVHandle = UVHandle();
        ah.handle_ptr = _CP_ASYNC_PTR;
        uvasync_send(ah);
    }
}

def _cp_queue_event(hid: int, ev: str, a0: str, a1: str) {
    _CP_EVT_HANDLE.append(hid);
    _CP_EVT_NAME.append(ev);
    _CP_EVT_ARG0.append(a0);
    _CP_EVT_ARG1.append(a1);
    _cp_wake();
}

def:pub cp_event_count -> int {
    return len(_CP_EVT_HANDLE);
}
def:pub cp_event_handle(i: int) -> int {
    return _CP_EVT_HANDLE[i];
}
def:pub cp_event_name(i: int) -> str {
    return _CP_EVT_NAME[i];
}
def:pub cp_event_arg0(i: int) -> str {
    return _CP_EVT_ARG0[i];
}
def:pub cp_event_arg1(i: int) -> str {
    return _CP_EVT_ARG1[i];
}
def:pub cp_event_pending -> int {
    return len(_CP_EVT_HANDLE);
}

def:pub cp_get_drain_fn -> JSValue {
    return _CP_DRAIN_FN;
}

"""Register JS callback (child_process _globalDrain) for el_tick delivery."""
def:pub cp_register_drain(args: list[JSValue]) -> JSValue {
    if len(args) >= 1 {
        # glob-held root — invisible to the GC root walk; unpin old on re-register
        gc_unpin_value(_CP_DRAIN_FN);
        _CP_DRAIN_FN = args[0];
        gc_pin_value(_CP_DRAIN_FN);
    }
    return js_undefined();
}

def:pub cp_event_clear(n: int) -> None {
    # O(remaining) rebuild — repeated `del [0]` is O(n^2) for a batch of n.
    if n <= 0 {
        return;
    }
    cp_h: list[int] = [];
    cp_n: list[str] = [];
    cp_a0: list[str] = [];
    cp_a1: list[str] = [];
    cp_i: int = n;
    cp_len: int = len(_CP_EVT_HANDLE);
    while cp_i < cp_len {
        cp_h.append(_CP_EVT_HANDLE[cp_i]);
        cp_n.append(_CP_EVT_NAME[cp_i]);
        cp_a0.append(_CP_EVT_ARG0[cp_i]);
        cp_a1.append(_CP_EVT_ARG1[cp_i]);
        cp_i = cp_i + 1;
    }
    _CP_EVT_HANDLE = cp_h;
    _CP_EVT_NAME = cp_n;
    _CP_EVT_ARG0 = cp_a0;
    _CP_EVT_ARG1 = cp_a1;
}

def _cp_alloc_handle -> int {
    _CP_HANDLES_PID.append(0);
    _CP_HANDLES_OUT_R.append(-1);
    _CP_HANDLES_ERR_R.append(-1);
    _CP_HANDLES_IN_W.append(-1);
    _CP_HANDLES_OUT_ACC.append("");
    _CP_HANDLES_ERR_ACC.append("");
    _CP_HANDLES_EXITED.append(0);
    _CP_HANDLES_EXIT_CODE.append(0);
    _CP_HANDLES_SIGNAL.append(0);
    _CP_HANDLES_POLL_OUT.append(UVHandle());
    _CP_HANDLES_POLL_ERR.append(UVHandle());
    return len(_CP_HANDLES_PID) - 1;
}

def _cp_poll_out_cb(handle: int, status: int, events: int) {
    _cp_poll_read_fd(handle, 0);
}

def _cp_poll_err_cb(handle: int, status: int, events: int) {
    _cp_poll_read_fd(handle, 1);
}

def _cp_poll_read_fd(poll_handle: int, is_err: int) -> None {
    hi: int = 1;
    while hi < len(_CP_HANDLES_PID) {
        ph: UVHandle = _CP_HANDLES_POLL_OUT[hi];
        if is_err == 1 {
            ph = _CP_HANDLES_POLL_ERR[hi];
        }
        if ph.handle_ptr == poll_handle {
            fd: int = _CP_HANDLES_OUT_R[hi];
            if is_err == 1 {
                fd = _CP_HANDLES_ERR_R[hi];
            }
            if fd < 0 {
                return;
            }
            buf: int = calloc(1, 65537);
            if buf == 0 {
                return;
            }
            n: int = read(fd, buf, 65536);
            if n > 0 {
                # Streaming events carry base64 (binary-safe). The per-handle
                # _CP_HANDLES_*_ACC str accumulators are no longer fed here:
                # nothing reads them (spawnSync/exec collect their output through
                # _cp_read_fd_all / the JS stream events), and appending every
                # chunk was O(total²) copying plus unbounded memory over the life
                # of a long-lived service child such as esbuild's.
                chunk_b64: str = _cp_buf_to_b64(buf, n);
                free(buf);
                if is_err == 1 {
                    _cp_queue_event(hi, "stderr_b64", chunk_b64, "");
                } else {
                    _cp_queue_event(hi, "stdout_b64", chunk_b64, "");
                }
            } else {
                free(buf);
            }
            # Reap after every read (not only pipe EOF): child may exit while data
            # was buffered and libuv may not deliver another poll before nextTick stops.
            _cp_try_finish_handle(hi);
            return;
        }
        hi = hi + 1;
    }
}

def _cp_try_finish_handle(hi: int) -> None {
    if _CP_HANDLES_EXITED[hi] != 0 {
        return;
    }
    pid: int = _CP_HANDLES_PID[hi];
    status_ptr: int = io_alloc(4);
    w: int = waitpid(pid, status_ptr, _WNOHANG);
    if w == 0 {
        return;
    }
    if w < 0 {
        _CP_HANDLES_EXITED[hi] = 1;
        _cp_queue_event(hi, "error", "waitpid failed", "");
        return;
    }
    st: int = read_i32(status_ptr, 0);
    _CP_HANDLES_EXITED[hi] = 1;
    _CP_HANDLES_EXIT_CODE[hi] = _cp_wait_status_code(st);
    _CP_HANDLES_SIGNAL[hi] = _cp_wait_signal(st);
    code_s: str = "";
    if _CP_HANDLES_EXIT_CODE[hi] >= 0 {
        code_s = str(_CP_HANDLES_EXIT_CODE[hi]);
    }
    sig_s: str = "";
    if _CP_HANDLES_SIGNAL[hi] != 0 {
        sig_s = _signal_name(_CP_HANDLES_SIGNAL[hi]);
    }
    fd_out: int = _CP_HANDLES_OUT_R[hi];
    fd_err: int = _CP_HANDLES_ERR_R[hi];
    # The child has exited, so whatever it wrote is already sitting in the pipes:
    # read it out (non-blocking) BEFORE reporting close and closing the fds.
    # Without this, output a fast child wrote after the last poll callback was
    # dropped — `cat` echoing stdin returned 0 bytes when the exit was reaped
    # first (test_cp_binary_ipc_smoke under parallel load).
    if fd_out >= 0 {
        rest_out: str = _cp_drain_available_fd_b64(fd_out);
        if len(rest_out) > 0 {
            _cp_queue_event(hi, "stdout_b64", rest_out, "");
        }
    }
    if fd_err >= 0 {
        rest_err: str = _cp_drain_available_fd_b64(fd_err);
        if len(rest_err) > 0 {
            _cp_queue_event(hi, "stderr_b64", rest_err, "");
        }
    }
    _cp_queue_event(hi, "exit", code_s, sig_s);
    _cp_queue_event(hi, "close", code_s, sig_s);
    poh: UVHandle = _CP_HANDLES_POLL_OUT[hi];
    peh: UVHandle = _CP_HANDLES_POLL_ERR[hi];
    if poh.handle_ptr != 0 {
        uvpoll_stop(poh);
        poh.handle_ptr = 0;
    }
    if peh.handle_ptr != 0 {
        uvpoll_stop(peh);
        peh.handle_ptr = 0;
    }
    if fd_out >= 0 {
        close(fd_out);
        _CP_HANDLES_OUT_R[hi] = -1;
    }
    if fd_err >= 0 {
        close(fd_err);
        _CP_HANDLES_ERR_R[hi] = -1;
    }
}

"""Non-blocking read of stdout/stderr and waitpid(WNOHANG) for all live handles.

CRITICAL: only drain an fd here when there is NO active uv_poll handle for it.
The uv_poll callback (_cp_poll_read_fd) is the real-time reader; if cp_reap ALSO
reads the same fd, the two paths split the pipe stream into separate base64
events that can be queued out of order → the consumer (esbuild's binary protocol)
sees mis-ordered bytes → "Invalid packet". This tick-based reap is only a
fallback for handles whose poll is not (or no longer) active, plus the waitpid
finish check."""
def:pub cp_reap_active_handles {
    hi: int = 1;
    while hi < len(_CP_HANDLES_PID) {
        if _CP_HANDLES_PID[hi] != 0 and _CP_HANDLES_EXITED[hi] == 0 {
            fd_out: int = _CP_HANDLES_OUT_R[hi];
            if fd_out >= 0 {
                bout: str = _cp_drain_available_fd_b64(fd_out);  # binary-safe
                if len(bout) > 0 {
                    _cp_queue_event(hi, "stdout_b64", bout, "");
                }
            }
            fd_err: int = _CP_HANDLES_ERR_R[hi];
            if fd_err >= 0 {
                berr: str = _cp_drain_available_fd_b64(fd_err);  # binary-safe
                if len(berr) > 0 {
                    _cp_queue_event(hi, "stderr_b64", berr, "");
                }
            }
            _cp_try_finish_handle(hi);
        }
        hi = hi + 1;
    }
}

def:pub cp_any_active -> int {
    hi: int = 1;
    while hi < len(_CP_HANDLES_PID) {
        if _CP_HANDLES_PID[hi] != 0 and _CP_HANDLES_EXITED[hi] == 0 {
            return 1;
        }
        hi = hi + 1;
    }
    return 0;
}

"""spawn(file, argv, cwd, env_block[, detached]) -> handle id (int).
detached (optional 5th arg): truthy → setsid() in the child (Node options.detached)."""
def:pub cp_spawn_async(args: list[JSValue]) -> JSValue {
    file: str = "";
    argv_blob: str = "";
    cwd: str = "";
    env_block: str = "";
    detached: int = 0;
    if len(args) >= 1 and jsv_is_string_cell(args[0]) {
        file = str_from_id(jsv_to_table_id(args[0]));
    }
    argv_arr: JSValue = js_undefined();
    if len(args) >= 2 {
        argv_arr = args[1];
    }
    if len(args) >= 3 and jsv_is_string_cell(args[2]) {
        cwd = str_from_id(jsv_to_table_id(args[2]));
    }
    if len(args) >= 4 and jsv_is_string_cell(args[3]) {
        env_block = str_from_id(jsv_to_table_id(args[3]));
    }
    if len(args) >= 5 {
        if jsv_is_bool(args[4]) {
            if jsv_to_bool(args[4]) {
                detached = 1;
            }
        } elif jsv_is_int32(args[4]) {
            if jsv_to_int32(args[4]) != 0 {
                detached = 1;
            }
        } elif jsv_is_double(args[4]) {
            if int(jsv_to_double(args[4])) != 0 {
                detached = 1;
            }
        } elif not jsv_is_undefined(args[4]) and not jsv_is_null(args[4]) {
            detached = 1;
        }
    }

    out_pipe: int = io_alloc(8);
    err_pipe: int = io_alloc(8);
    in_pipe: int = io_alloc(8);
    pipe(out_pipe);
    pipe(err_pipe);
    pipe(in_pipe);
    out_r: int = read_u32(out_pipe, 0);
    out_w: int = read_u32(out_pipe, 4);
    err_r: int = read_u32(err_pipe, 0);
    err_w: int = read_u32(err_pipe, 4);
    in_r: int = read_u32(in_pipe, 0);
    in_w: int = read_u32(in_pipe, 4);

    argv_pp: int = _cp_build_argv_from_js(file, argv_arr);
    envp: int = _cp_build_envp(env_block);
    # Build inherited env in parent — never malloc/fopen in child after fork (async-signal-unsafe).
    if envp == 0 {
        envp = _cp_build_envp_inherit();
    }

    pid: int = _cp_spawn_process(
        file, argv_pp, envp, cwd, in_r, in_w, out_r, out_w, err_r, err_w, detached
    );

    if pid < 0 {
        close(in_r);
        close(in_w);
        close(out_r);
        close(out_w);
        close(err_r);
        close(err_w);
        return js_int(-1);
    }

    close(in_r);
    close(out_w);
    close(err_w);

    hi: int = _cp_alloc_handle();
    _CP_HANDLES_PID[hi] = pid;
    _CP_HANDLES_OUT_R[hi] = out_r;
    _CP_HANDLES_ERR_R[hi] = err_r;
    _CP_HANDLES_IN_W[hi] = in_w;
    _cp_set_nonblock(in_w);  # writes must never block: see _cp_write_all

    if _CP_LOOP_PTR != 0 {
        lp: UVLoop = UVLoop();
        lp.loop_ptr = _CP_LOOP_PTR;
        poh: UVHandle = uvpoll_create(lp, out_r);
        peh: UVHandle = uvpoll_create(lp, err_r);
        _CP_HANDLES_POLL_OUT[hi] = poh;
        _CP_HANDLES_POLL_ERR[hi] = peh;
        uvpoll_start(poh, 1, _cp_poll_out_cb);
        uvpoll_start(peh, 1, _cp_poll_err_cb);
    }

    _cp_queue_event(hi, "spawn", "", "");

    # NO initial stdout/stderr drain here: the uv_poll started above is the sole
    # reader. An initial drain here races the poll for the same pipe bytes and
    # can deliver the child's first chunk TWICE (e.g. esbuild's handshake read
    # once here and once by the poll → esbuild processes the version packet twice,
    # the 2nd time as a data packet → "Invalid packet"). If no loop is attached
    # (_CP_LOOP_PTR == 0, no poll), cp_reap_active_handles drains as the fallback.
    _cp_try_finish_handle(hi);

    return js_int(hi);
}

def:pub cp_spawn_kill(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_false();
    }
    hi: int = 0;
    if jsv_is_int32(args[0]) {
        hi = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        hi = int(jsv_to_double(args[0]));
    }
    if hi <= 0 or hi >= len(_CP_HANDLES_PID) {
        return js_false();
    }
    pid: int = _CP_HANDLES_PID[hi];
    rc: int = kill(pid, _SIGTERM);
    if rc == 0 {
        return js_true();
    }
    return js_false();
}

def:pub cp_spawn_write_stdin(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_false();
    }
    hi: int = 0;
    if jsv_is_int32(args[0]) {
        hi = jsv_to_int32(args[0]);
    }
    data: str = "";
    if jsv_is_string_cell(args[1]) {
        data = str_from_id(jsv_to_table_id(args[1]));
    }
    if hi <= 0 or hi >= len(_CP_HANDLES_PID) {
        return js_false();
    }
    fd: int = _CP_HANDLES_IN_W[hi];
    if fd < 0 {
        return js_false();
    }
    if len(data) == 0 {
        return js_true();
    }
    write(fd, data, len(data));
    return js_true();
}

"""Write base64-encoded binary to child stdin (binary-safe). JS base64-encodes a
Buffer and calls this; the bytes are decoded here and written raw. esbuild's
request packets are binary (length headers, NUL) and MUST NOT go through the
utf8-string write path (cp_spawn_write_stdin), which corrupts them."""
def:pub cp_spawn_write_stdin_b64(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_false();
    }
    hi: int = 0;
    if jsv_is_int32(args[0]) {
        hi = jsv_to_int32(args[0]);
    }
    b64: str = "";
    if jsv_is_string_cell(args[1]) {
        b64 = str_from_id(jsv_to_table_id(args[1]));
    }
    if hi <= 0 or hi >= len(_CP_HANDLES_PID) {
        return js_false();
    }
    fd: int = _CP_HANDLES_IN_W[hi];
    if fd < 0 {
        return js_false();
    }
    if len(b64) == 0 {
        return js_true();
    }
    dec_len: list[int] = [0];
    base: int = _cp_b64_to_buf(b64, dec_len);
    n: int = dec_len[0];
    if n > 0 {
        _cp_write_all(hi, fd, base + 32, n);
    }
    io_free(base);
    return js_true();
}

"""Drain whatever the child has written on `rfd` right now into the event
queue (base64, binary-safe); an empty drain queues nothing."""
def _cp_queue_drained(hi: int, ev: str, b64: str) -> None {
    if len(b64) == 0 {
        return;
    }
    _cp_queue_event(hi, ev, b64, "");
}

def _cp_drain_into_events(hi: int, rfd: int, is_err: int) {
    if is_err == 1 {
        _cp_queue_drained(hi, "stderr_b64", _cp_drain_available_fd_b64(rfd));
    } else {
        _cp_queue_drained(hi, "stdout_b64", _cp_drain_available_fd_b64(rfd));
    }
}

"""write() all n bytes at `buf` to the child's stdin, looping over partial
writes. Uses the pointer directly (not a Jac str, which would strlen-truncate at
NUL). The fd is non-blocking (set at spawn): a full pipe returns EAGAIN and we
poll for writability AND for the child's stdout/stderr becoming readable,
draining those into the event queue while we wait. Without that drain a child
that answers request N while we are still writing request N+1 blocks on its own
64KB stdout pipe, stops reading stdin, and both sides wait forever — rollup
renders chunks in parallel, so vite's esbuild-transpile renderChunk had several
MB-size transform requests in flight and never settled (build:render+write
"Unexpected early exit"). The old code blocked in write() (fd was blocking) and,
in its poll variant, silently DROPPED the tail of the packet after 60s. Gives up
only when the child exited / closed its stdin or nothing moved for ~10 min."""
def _cp_write_all(hi: int, fd: int, buf: int, n: int) {
    off: int = 0;
    idle: int = 0;
    fo_hup: bool = False;
    fe_hup: bool = False;
    pfd: int = io_alloc(24);  # up to 3 × struct pollfd { int fd; short events; short revents }
    while off < n {
        s_view: str = buf + off;  # jac:ignore[E1001] ptr+offset reinterpret
        wr: int = write(fd, s_view, n - off);
        if wr > 0 {
            off = off + wr;
            idle = 0;
            continue;
        }
        # wr <= 0: EAGAIN (pipe full) or a closed pipe — poll tells them apart.
        write_i32(pfd, 0, fd);
        write_byte(pfd, 4, 4);
        write_byte(pfd, 5, 0);  # events = POLLOUT
        write_byte(pfd, 6, 0);
        write_byte(pfd, 7, 0);  # revents
        nf: int = 1;
        fo: int = -1;
        fe: int = -1;
        pos_o: int = -1;
        pos_e: int = -1;
        if not fo_hup {
            fo = _CP_HANDLES_OUT_R[hi];
        }
        if not fe_hup {
            fe = _CP_HANDLES_ERR_R[hi];
        }
        if fo >= 0 {
            pos_o = nf * 8;
            write_i32(pfd, pos_o, fo);
            write_byte(pfd, pos_o + 4, 1);
            write_byte(pfd, pos_o + 5, 0);  # POLLIN
            write_byte(pfd, pos_o + 6, 0);
            write_byte(pfd, pos_o + 7, 0);
            nf = nf + 1;
        }
        if fe >= 0 {
            pos_e = nf * 8;
            write_i32(pfd, pos_e, fe);
            write_byte(pfd, pos_e + 4, 1);
            write_byte(pfd, pos_e + 5, 0);
            write_byte(pfd, pos_e + 6, 0);
            write_byte(pfd, pos_e + 7, 0);
            nf = nf + 1;
        }
        pr: int = poll(pfd, nf, 100);
        if pr > 0 {
            rev0: int = read_byte(pfd, 6);
            if (rev0 & 8) != 0 or (rev0 & 32) != 0 {
                break;
            }  # POLLERR / POLLNVAL: stdin closed
            if pos_o >= 0 {
                revo: int = read_byte(pfd, pos_o + 6);
                if (revo & 17) != 0 {
                    _cp_drain_into_events(hi, fo, 0);
                }  # POLLIN | POLLHUP
                if (revo & 16) != 0 {
                    fo_hup = True;
                }
            }
            if pos_e >= 0 {
                reve: int = read_byte(pfd, pos_e + 6);
                if (reve & 17) != 0 {
                    _cp_drain_into_events(hi, fe, 1);
                }
                if (reve & 16) != 0 {
                    fe_hup = True;
                }
            }
            idle = 0;
        } else {
            idle = idle + 1;
            _cp_try_finish_handle(hi);
            if _CP_HANDLES_EXITED[hi] != 0 {
                break;
            }
            if idle > 6000 {
                break;
            }  # ~10 min with zero progress
        }
    }
    io_free(pfd);
}

def:pub cp_spawn_stdin_end(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    hi: int = 0;
    if jsv_is_int32(args[0]) {
        hi = jsv_to_int32(args[0]);
    }
    if hi <= 0 or hi >= len(_CP_HANDLES_PID) {
        return js_undefined();
    }
    fd: int = _CP_HANDLES_IN_W[hi];
    if fd >= 0 {
        close(fd);
        _CP_HANDLES_IN_W[hi] = -1;
    }
    return js_undefined();
}

def:pub cp_get_pid(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(-1);
    }
    hi: int = 0;
    if jsv_is_int32(args[0]) {
        hi = jsv_to_int32(args[0]);
    }
    if hi <= 0 or hi >= len(_CP_HANDLES_PID) {
        return js_int(-1);
    }
    return js_int(_CP_HANDLES_PID[hi]);
}

"""child.unref(): drop the child's stdout/stderr poll handles from the loop's
keep-alive set, so a persistent child (e.g. esbuild's service, which unref's
itself and only ref's during an active build) does NOT keep the process alive
after all work is done. Without this, esbuild's binary keeps pinging forever and
the process never exits (Node relies on child.unref() here)."""
def:pub cp_unref(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    hi: int = 0;
    if jsv_is_int32(args[0]) {
        hi = jsv_to_int32(args[0]);
    }
    if hi <= 0 or hi >= len(_CP_HANDLES_POLL_OUT) {
        return js_undefined();
    }
    poh: UVHandle = _CP_HANDLES_POLL_OUT[hi];
    if poh.handle_ptr != 0 {
        uvhandle_unref(poh);
    }
    peh: UVHandle = _CP_HANDLES_POLL_ERR[hi];
    if peh.handle_ptr != 0 {
        uvhandle_unref(peh);
    }
    return js_undefined();
}

"""child.ref(): re-reference the poll handles so the child keeps the loop alive
again (esbuild ref's on each active build)."""
def:pub cp_ref(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    hi: int = 0;
    if jsv_is_int32(args[0]) {
        hi = jsv_to_int32(args[0]);
    }
    if hi <= 0 or hi >= len(_CP_HANDLES_POLL_OUT) {
        return js_undefined();
    }
    poh: UVHandle = _CP_HANDLES_POLL_OUT[hi];
    if poh.handle_ptr != 0 {
        uvhandle_ref(poh);
    }
    peh: UVHandle = _CP_HANDLES_POLL_ERR[hi];
    if peh.handle_ptr != 0 {
        uvhandle_ref(peh);
    }
    return js_undefined();
}

"""Drain queued child-process events into array of {handle, event, arg0, arg1}."""
def:pub cp_poll_events(args: list[JSValue]) -> JSValue {
    n: int = cp_event_count();
    elems: list[JSValue] = [];
    i: int = 0;
    while i < n {
        ev_obj: JSValue = js_object_create_null();
        js_object_set(ev_obj, str_intern("handle"), js_int(cp_event_handle(i)));
        js_object_set(
            ev_obj,
            str_intern("event"),
            jsv_from_string_id(str_intern(cp_event_name(i)))
        );
        js_object_set(
            ev_obj, str_intern("arg0"), jsv_from_string_id(str_intern(cp_event_arg0(i)))
        );
        js_object_set(
            ev_obj, str_intern("arg1"), jsv_from_string_id(str_intern(cp_event_arg1(i)))
        );
        elems.append(ev_obj);
        i = i + 1;
    }
    cp_event_clear(n);
    return js_array_create(elems);
}
