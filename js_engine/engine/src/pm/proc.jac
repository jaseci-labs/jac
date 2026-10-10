"""Synchronous child processes for the package manager (lifecycle scripts,
`run`, `x`): posix_spawnp with optional cwd and captured output.

Output capture reads stdout and stderr through poll(2) so a chatty script
cannot deadlock on a full pipe. Environment is passed explicitly as
KEY=VALUE strings (proc_env_inherit reads the current one).
"""

import from engine.src.ffi.libc {
    posix_spawnp,
    posix_spawn_file_actions_init,
    posix_spawn_file_actions_destroy,
    posix_spawn_file_actions_adddup2,
    posix_spawn_file_actions_addclose,
    posix_spawn_file_actions_addchdir_np,
    waitpid,
    pipe,
    close,
    read,
    poll,
    fopen,
    fread,
    fclose,
    getenv
}
import from engine.src.runtime.mem {
    io_alloc,
    io_free,
    read_byte,
    write_i64,
    read_i32,
    write_i32,
    read_u16,
    write_byte
}
import from engine.src.pm.bytes {
    ByteBuf,
    bytebuf_new,
    bytebuf_append,
    bytebuf_to_str,
    bytebuf_free,
    str_to_cbuf,
    bytes_to_str
}

glob:priv _FILE_ACTIONS_SZ: int = 128;  # glibc posix_spawn_file_actions_t (80 bytes) with slack

obj:pub ProcResult {
    has ok: bool = False,
        exit_code: int = -1,
        signal: int = 0,
        stdout: str = "",
        stderr: str = "",
        error: str = "";  # the process was spawned and reaped
}

"""KEY=VALUE entries of the current environment."""
def:pub proc_env_inherit -> list[str] {
    out: list[str] = [];
    fp: int = fopen("/proc/self/environ", "rb");
    if fp == 0 {
        return out;
    }
    cap: int = 262144;
    buf: int = io_alloc(cap);
    n: int = fread(buf, 1, cap - 1, fp);
    fclose(fp);
    if n <= 0 {
        io_free(buf);
        return out;
    }
    start: int = 0;
    pos: int = 0;
    while pos <= n {
        if pos == n or read_byte(buf, pos) == 0 {
            if pos > start {
                out.append(bytes_to_str(buf, start, pos - start));
            }
            start = pos + 1;
        }
        pos = pos + 1;
    }
    io_free(buf);
    return out;
}

"""Value of KEY in an env list ("" when absent)."""
def:pub proc_env_get(env: list[str], key: str) -> str {
    prefix: str = key + "=";
    for e in env {
        if e.startswith(prefix) {
            return e[len(prefix):];
        }
    }
    return "";
}

"""Set KEY=value in an env list (replacing an existing entry)."""
def:pub proc_env_set(env: list[str], key: str, value: str) -> None {
    prefix: str = key + "=";
    i: int = 0;
    while i < len(env) {
        if env[i].startswith(prefix) {
            env[i] = prefix + value;
            return;
        }
        i = i + 1;
    }
    env.append(prefix + value);
}

def _cstr_array(items: list[str]) -> int {
    pp: int = io_alloc((len(items) + 1) * 8);
    i: int = 0;
    while i < len(items) {
        write_i64(pp, i * 8, str_to_cbuf(items[i]));
        i = i + 1;
    }
    write_i64(pp, len(items) * 8, 0);
    return pp;
}

def _free_cstr_array(pp: int, n: int) {
    i: int = 0;
    while i < n {
        p: int = read_i32(pp, i * 8);  # low half is enough to test for 0? no — read full pointer
        i = i + 1;
    }
    io_free(pp);
}

"""Read both pipes until EOF."""
def _drain(out_fd: int, err_fd: int, out_buf: ByteBuf, err_buf: ByteBuf) {
    chunk_sz: int = 65536;
    chunk: int = io_alloc(chunk_sz + 1);
    fds: int = io_alloc(16);  # two struct pollfd { int fd; short events; short revents; }
    open_out: bool = out_fd >= 0;
    open_err: bool = err_fd >= 0;
    while open_out or open_err {
        n: int = 0;
        if open_out {
            write_i32(fds, n * 8, out_fd);
            write_byte(fds, n * 8 + 4, 1);
            write_byte(fds, n * 8 + 5, 0);  # POLLIN
            write_byte(fds, n * 8 + 6, 0);
            write_byte(fds, n * 8 + 7, 0);
            n = n + 1;
        }
        if open_err {
            write_i32(fds, n * 8, err_fd);
            write_byte(fds, n * 8 + 4, 1);
            write_byte(fds, n * 8 + 5, 0);
            write_byte(fds, n * 8 + 6, 0);
            write_byte(fds, n * 8 + 7, 0);
            n = n + 1;
        }
        rc: int = poll(fds, n, -1);
        if rc < 0 or rc > 2147483647 {
            break;
        }
        i: int = 0;
        while i < n {
            fd: int = read_i32(fds, i * 8);
            revents: int = read_u16(fds, i * 8 + 6);
            i = i + 1;
            if revents == 0 {
                continue;
            }
            got: int = read(fd, chunk, chunk_sz);
            if got <= 0 or got > chunk_sz {
                if fd == out_fd {
                    open_out = False;
                } else {
                    open_err = False;
                }
                continue;
            }
            if fd == out_fd {
                bytebuf_append(out_buf, chunk, got);
            } else {
                bytebuf_append(err_buf, chunk, got);
            }
        }
    }
    io_free(chunk);
    io_free(fds);
}

"""Run `argv` (argv[0] looked up on PATH). `cwd` "" keeps the current one.
`capture` collects stdout/stderr into the result; otherwise the child inherits
our stdio."""
def:pub proc_run(
    argv: list[str], cwd: str, env: list[str], capture: bool
) -> ProcResult {
    r: ProcResult = ProcResult();
    if len(argv) == 0 {
        r.error = "empty argv";
        return r;
    }
    argv_pp: int = _cstr_array(argv);
    envp: int = _cstr_array(env);
    fa: int = io_alloc(_FILE_ACTIONS_SZ);
    rc: int = posix_spawn_file_actions_init(fa);
    if rc != 0 {
        r.error = "posix_spawn_file_actions_init failed";
        return r;
    }
    out_r: int = -1;
    out_w: int = -1;
    err_r: int = -1;
    err_w: int = -1;
    if capture {
        p1: int = io_alloc(8);
        p2: int = io_alloc(8);
        if pipe(p1) != 0 or pipe(p2) != 0 {
            r.error = "pipe failed";
            return r;
        }
        out_r = read_i32(p1, 0);
        out_w = read_i32(p1, 4);
        err_r = read_i32(p2, 0);
        err_w = read_i32(p2, 4);
        io_free(p1);
        io_free(p2);
        posix_spawn_file_actions_adddup2(fa, out_w, 1);
        posix_spawn_file_actions_adddup2(fa, err_w, 2);
        posix_spawn_file_actions_addclose(fa, out_r);
        posix_spawn_file_actions_addclose(fa, out_w);
        posix_spawn_file_actions_addclose(fa, err_r);
        posix_spawn_file_actions_addclose(fa, err_w);
    }
    if cwd != "" {
        rc = posix_spawn_file_actions_addchdir_np(fa, cwd);
        if rc != 0 {
            r.error = "cannot chdir to " + cwd;
            posix_spawn_file_actions_destroy(fa);
            return r;
        }
    }
    pid_ptr: int = io_alloc(8);
    rc = posix_spawnp(pid_ptr, argv[0], fa, 0, argv_pp, envp);
    posix_spawn_file_actions_destroy(fa);
    io_free(fa);
    if rc != 0 {
        r.error = "failed to spawn \"" + argv[0] + "\" (errno " + str(rc) + ")";
        if capture {
            close(out_r);
            close(out_w);
            close(err_r);
            close(err_w);
        }
        return r;
    }
    pid: int = read_i32(pid_ptr, 0);
    io_free(pid_ptr);
    if capture {
        close(out_w);
        close(err_w);
        ob: ByteBuf = bytebuf_new(4096);
        eb: ByteBuf = bytebuf_new(4096);
        _drain(out_r, err_r, ob, eb);
        close(out_r);
        close(err_r);
        r.stdout = bytebuf_to_str(ob);
        r.stderr = bytebuf_to_str(eb);
        bytebuf_free(ob);
        bytebuf_free(eb);
    }
    status_ptr: int = io_alloc(8);
    wrc: int = waitpid(pid, status_ptr, 0);
    status: int = read_i32(status_ptr, 0);
    io_free(status_ptr);
    if wrc < 0 or wrc > 2147483647 {
        r.error = "waitpid failed";
        return r;
    }
    r.ok = True;
    if (status & 127) == 0 {
        r.exit_code = (status >> 8) & 255;
    } else {
        r.signal = status & 127;
        r.exit_code = 128 + r.signal;
    }
    return r;
}

"""First executable named `name` on PATH ("" when none)."""
def:pub proc_which(name: str, path_env: str) -> str {
    if name.find("/") >= 0 {
        return name;
    }
    for dir in path_env.split(":") {
        if dir == "" {
            continue;
        }
        cand: str = dir + "/" + name;
        if _is_executable(cand) {
            return cand;
        }
    }
    return "";
}

def _is_executable(path: str) -> bool {
    # access(2) is not bound; use the existence of a regular file with any x bit
    st: int = _perm(path);
    return st >= 0 and (st & 73) != 0;  # 0o111
}

import from engine.src.pm.fsx { fsx_stat, FsxStat }

def _perm(path: str) -> int {
    st: FsxStat = fsx_stat(path);
    if st.rc < 0 {
        return -1;
    }
    if (st.mode & 61440) != 32768 {
        return -1;
    }  # regular files only
    return st.mode & 511;
}
