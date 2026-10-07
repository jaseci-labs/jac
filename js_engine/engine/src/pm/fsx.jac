"""Synchronous filesystem helpers for the package manager (libuv, no event loop).

Every call blocks and returns libuv's convention: >= 0 success, < 0 is -errno
(FSX_EEXIST = -17, FSX_ENOENT = -2, FSX_EXDEV = -18 …). File contents move as
raw (ptr, len) pairs — see pm/bytes.jac — because engine strings cannot hold
NUL bytes.

Modes are passed through to the kernel, so the process umask applies to
mkdir/open exactly as it does for bun (which matters: bun clears the umask
half-way through an install, see pm/install.jac).
"""

import from engine.src.ffi.libuv {
    uv_default_loop,
    uv_req_size,
    UVBuf,
    uv_fs_open,
    uv_fs_close,
    uv_fs_read,
    uv_fs_write,
    uv_fs_stat,
    uv_fs_lstat,
    uv_fs_unlink,
    uv_fs_mkdir,
    uv_fs_rmdir,
    uv_fs_rename,
    uv_fs_scandir,
    uv_fs_scandir_next,
    uv_fs_chmod,
    uv_fs_symlink,
    uv_fs_readlink,
    uv_fs_realpath,
    uv_fs_link,
    uv_fs_copyfile,
    uv_fs_get_result,
    uv_fs_get_statbuf,
    uv_fs_get_ptr,
    uv_fs_req_cleanup
}
import from engine.src.ffi.libc { calloc, free, memcpy, umask, getcwd, mkdtemp }
import from engine.src.runtime.mem {
    io_alloc,
    io_free,
    read_u64,
    read_u32,
    read_ptr,
    write_byte,
    str_from_foreign_cstr
}
import from engine.src.pm.bytes { ByteBuf, bytebuf_from, str_to_cbuf, bytes_to_str }

glob:pub FSX_ENOENT: int = -2,
     FSX_EEXIST: int = -17,
     FSX_EXDEV: int = -18,
     FSX_ENOTDIR: int = -20,
     FSX_EISDIR: int = -21,
     FSX_ENOTEMPTY: int = -39;

glob:priv _UV_REQ_FS: int = 6,
     _O_RDONLY: int = 0,
     _O_WRONLY: int = 1,
     _O_CREAT: int = 64,
     _O_EXCL: int = 128,
     _O_TRUNC: int = 512,
     _S_IFMT: int = 61440,
     _S_IFDIR: int = 16384,
     _S_IFREG: int = 32768,
     _S_IFLNK: int = 40960;

# 0o170000
# 0o040000
# 0o100000
# 0o120000
def _req -> int {
    return calloc(1, uv_req_size(_UV_REQ_FS));
}

"""uv_stat_t: st_dev, st_mode, st_nlink, st_uid, st_gid, st_rdev, st_ino,
st_size … (each 8 bytes)."""
def _stat_mode(statbuf: int) -> int {
    return read_u64(statbuf, 8);
}

def _stat_size(statbuf: int) -> int {
    return read_u64(statbuf, 56);
}

"""Result of a (l)stat: `rc` < 0 when the path does not exist."""
obj:pub FsxStat {
    has rc: int = -2,
        mode: int = 0,
        size: int = 0;
}

# full st_mode (type bits + permissions)
def:pub fsx_stat(path: str) -> FsxStat {
    req: int = _req();
    uv_fs_stat(uv_default_loop(), req, path, 0);
    return _stat_finish(req);
}

def:pub fsx_lstat(path: str) -> FsxStat {
    req: int = _req();
    uv_fs_lstat(uv_default_loop(), req, path, 0);
    return _stat_finish(req);
}

def _stat_finish(req: int) -> FsxStat {
    st: FsxStat = FsxStat();
    st.rc = uv_fs_get_result(req);
    if st.rc >= 0 {
        sb: int = uv_fs_get_statbuf(req);
        st.mode = _stat_mode(sb);
        st.size = _stat_size(sb);
    }
    uv_fs_req_cleanup(req);
    free(req);
    return st;
}

def:pub fsx_exists(path: str) -> bool {
    return fsx_lstat(path).rc >= 0;
}
def:pub fsx_is_dir(path: str) -> bool {
    st: FsxStat = fsx_stat(path);
    return st.rc >= 0 and (st.mode & _S_IFMT) == _S_IFDIR;
}

def:pub fsx_is_file(path: str) -> bool {
    st: FsxStat = fsx_stat(path);
    return st.rc >= 0 and (st.mode & _S_IFMT) == _S_IFREG;
}

def:pub fsx_is_symlink(path: str) -> bool {
    st: FsxStat = fsx_lstat(path);
    return st.rc >= 0 and (st.mode & _S_IFMT) == _S_IFLNK;
}

"""Permission bits (0..0o777) of `path`, or -1 when missing."""
def:pub fsx_perm(path: str) -> int {
    st: FsxStat = fsx_lstat(path);
    if st.rc < 0 {
        return -1;
    }
    return st.mode & 511;
}

# ── whole-file I/O ────────────────────────────────────────────────────────────

"""Read a whole file into a fresh ByteBuf. `ok` false (ptr 0, len -1) when the
file cannot be read; an empty file yields len 0."""
def:pub fsx_read_bytes(path: str) -> ByteBuf {
    bad: ByteBuf = ByteBuf(ptr=0, len=-1, cap=0);
    st: FsxStat = fsx_stat(path);
    if st.rc < 0 or (st.mode & _S_IFMT) == _S_IFDIR {
        return bad;
    }
    loop: int = uv_default_loop();
    req: int = _req();
    uv_fs_open(loop, req, path, _O_RDONLY, 0, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    if fd < 0 {
        return bad;
    }
    size: int = st.size;
    if size < 0 {
        size = 0;
    }
    cap: int = size + 1;
    buf: int = io_alloc(cap + 1);
    total: int = 0;
    ok: bool = True;
    while True {
        if total >= cap {
            # file grew since stat: extend
            ncap: int = cap * 2 + 4096;
            nbuf: int = io_alloc(ncap + 1);
            memcpy(nbuf, buf, total);
            io_free(buf);
            buf = nbuf;
            cap = ncap;
        }
        bstr: str = buf + total;  # jac:ignore[E1001] pointer reinterpreted as str
        rbuf: UVBuf = UVBuf(base=bstr, buf_len=cap - total);
        req2: int = _req();
        uv_fs_read(loop, req2, fd, rbuf, 1, -1, 0);
        got: int = uv_fs_get_result(req2);
        uv_fs_req_cleanup(req2);
        free(req2);
        if got < 0 {
            ok = False;
            break;
        }
        if got == 0 {
            break;
        }
        total = total + got;
    }
    _close(fd);
    if not ok {
        io_free(buf);
        return bad;
    }
    write_byte(buf, total, 0);
    return bytebuf_from(buf, total);
}

"""Read a text file; "" when missing/unreadable."""
def:pub fsx_read_text(path: str) -> str {
    b: ByteBuf = fsx_read_bytes(path);
    if b.len < 0 {
        return "";
    }
    if b.len == 0 {
        return "";
    }
    s: str = b.ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    return s;
}

def _close(fd: int) {
    req: int = _req();
    uv_fs_close(uv_default_loop(), req, fd, 0);
    uv_fs_req_cleanup(req);
    free(req);
}

"""Write all of ptr[0..n) to an open fd. Returns bytes written or < 0."""
def _write_all(fd: int, ptr: int, n: int) -> int {
    loop: int = uv_default_loop();
    done: int = 0;
    while done < n {
        s: str = ptr + done;  # jac:ignore[E1001] pointer reinterpreted as str
        wbuf: UVBuf = UVBuf(base=s, buf_len=n - done);
        req: int = _req();
        uv_fs_write(loop, req, fd, wbuf, 1, -1, 0);
        w: int = uv_fs_get_result(req);
        uv_fs_req_cleanup(req);
        free(req);
        if w < 0 {
            return w;
        }
        if w == 0 {
            return done;
        }
        done = done + w;
    }
    return done;
}

"""Create/truncate `path` with `mode` (subject to umask) and write ptr[0..n).
Returns 0 or a negative errno."""
def:pub fsx_write_bytes(path: str, ptr: int, n: int, mode: int) -> int {
    loop: int = uv_default_loop();
    req: int = _req();
    uv_fs_open(loop, req, path, _O_WRONLY + _O_CREAT + _O_TRUNC, mode, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    if fd < 0 {
        return fd;
    }
    rc: int = 0;
    if n > 0 {
        w: int = _write_all(fd, ptr, n);
        if w < 0 {
            rc = w;
        } elif w < n {
            rc = -5;
        }  # EIO
    }
    _close(fd);
    return rc;
}

"""fsx_write_bytes for a str."""
def:pub fsx_write_str(path: str, s: str, mode: int) -> int {
    n: int = len(s);
    if n == 0 {
        return fsx_write_bytes(path, 0, 0, mode);
    }
    p: int = str_to_cbuf(s);
    rc: int = fsx_write_bytes(path, p, n, mode);
    io_free(p);
    return rc;
}

"""Open for writing with explicit flags (used by the tar extractor, which
needs the fd to stream many blocks). Returns fd or negative errno."""
def:pub fsx_open_write(path: str, mode: int) -> int {
    req: int = _req();
    uv_fs_open(uv_default_loop(), req, path, _O_WRONLY + _O_CREAT + _O_TRUNC, mode, 0);
    fd: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    return fd;
}

def:pub fsx_fd_write(fd: int, ptr: int, n: int) -> int {
    return _write_all(fd, ptr, n);
}
def:pub fsx_close(fd: int) {
    _close(fd);
}

# ── directories ───────────────────────────────────────────────────────────────

def:pub fsx_mkdir(path: str, mode: int) -> int {
    req: int = _req();
    uv_fs_mkdir(uv_default_loop(), req, path, mode, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    return rc;
}

"""mkdir -p. Every created component gets `mode` (umask applies). True when
`path` is a directory afterwards."""
def:pub fsx_mkdir_p(path: str, mode: int) -> bool {
    if path == "" {
        return True;
    }
    if fsx_is_dir(path) {
        return True;
    }
    parts: list[str] = path.split("/");
    cur: str = "";
    i: int = 0;
    n: int = len(parts);
    while i < n {
        seg: str = parts[i];
        i = i + 1;
        if seg == "" {
            if cur == "" and i == 1 {
                cur = "/";
            }
            continue;
        }
        if cur == "" or cur == "/" {
            cur = cur + seg;
        } else {
            cur = cur + "/" + seg;
        }
        rc: int = fsx_mkdir(cur, mode);
        if rc < 0 and rc != FSX_EEXIST {
            return False;
        }
    }
    return fsx_is_dir(path);
}

def:pub fsx_rmdir(path: str) -> int {
    req: int = _req();
    uv_fs_rmdir(uv_default_loop(), req, path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    return rc;
}

def:pub fsx_unlink(path: str) -> int {
    req: int = _req();
    uv_fs_unlink(uv_default_loop(), req, path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    return rc;
}

def:pub fsx_rename(from_path: str, to_path: str) -> int {
    req: int = _req();
    uv_fs_rename(uv_default_loop(), req, from_path, to_path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    return rc;
}

"""Directory listing: parallel `names` / `kinds` (1 file, 2 dir, 3 symlink,
0 other/unknown), sorted by name. `rc` < 0 when the directory can't be read."""
obj:pub FsxDir {
    has rc: int = 0,
        names: list[str] = [],
        kinds: list[int] = [];
}

def:pub fsx_scandir(path: str) -> FsxDir {
    d: FsxDir = FsxDir();
    loop: int = uv_default_loop();
    req: int = _req();
    uv_fs_scandir(loop, req, path, 0, 0);
    d.rc = uv_fs_get_result(req);
    if d.rc < 0 {
        uv_fs_req_cleanup(req);
        free(req);
        return d;
    }
    dirent: int = calloc(1, 16);
    pairs: list[tuple[str, int]] = [];
    while True {
        rc: int = uv_fs_scandir_next(req, dirent);
        if rc != 0 {
            break;
        }
        name_ptr: int = read_ptr(dirent, 0);
        # libuv owns the name: copy it (never cast a foreign pointer to str).
        name: str = str_from_foreign_cstr(name_ptr);
        t: int = read_u32(dirent, 8);
        kind: int = 0;
        if t == 1 {
            kind = 1;
        } elif t == 2 {
            kind = 2;
        } elif t == 3 {
            kind = 3;
        }
        if kind == 0 {
            # UV_DIRENT_UNKNOWN: fall back to lstat
            st: FsxStat = fsx_lstat(path + "/" + name);
            if st.rc >= 0 {
                ft: int = st.mode & _S_IFMT;
                if ft == _S_IFREG {
                    kind = 1;
                } elif ft == _S_IFDIR {
                    kind = 2;
                } elif ft == _S_IFLNK {
                    kind = 3;
                }
            }
        }
        pairs.append((name, kind));
    }
    free(dirent);
    uv_fs_req_cleanup(req);
    free(req);
    names: list[str] = [];
    for p in pairs {
        names.append(p[0]);
    }
    names.sort();
    for nm in names {
        for p in pairs {
            if p[0] == nm {
                d.names.append(nm);
                d.kinds.append(p[1]);
                break;
            }
        }
    }
    return d;
}

"""rm -rf. Symlinks are unlinked, never followed."""
def:pub fsx_rm_rf(path: str) -> None {
    st: FsxStat = fsx_lstat(path);
    if st.rc < 0 {
        return;
    }
    if (st.mode & _S_IFMT) == _S_IFDIR {
        d: FsxDir = fsx_scandir(path);
        i: int = 0;
        while i < len(d.names) {
            fsx_rm_rf(path + "/" + d.names[i]);
            i = i + 1;
        }
        fsx_rmdir(path);
        return;
    }
    fsx_unlink(path);
}

# ── links / modes ─────────────────────────────────────────────────────────────

def:pub fsx_symlink(target: str, link_path: str) -> int {
    req: int = _req();
    uv_fs_symlink(uv_default_loop(), req, target, link_path, 0, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    return rc;
}

"""Hard link `existing` at `new_path`."""
def:pub fsx_link(existing: str, new_path: str) -> int {
    req: int = _req();
    uv_fs_link(uv_default_loop(), req, existing, new_path, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    return rc;
}

def:pub fsx_readlink(path: str) -> str {
    req: int = _req();
    uv_fs_readlink(uv_default_loop(), req, path, 0);
    rc: int = uv_fs_get_result(req);
    out: str = "";
    if rc >= 0 {
        p: int = uv_fs_get_ptr(req);
        raw: str = p;  # jac:ignore[E1001] pointer reinterpreted as str
        out = raw + "";
    }
    uv_fs_req_cleanup(req);
    free(req);
    return out;
}

def:pub fsx_realpath(path: str) -> str {
    req: int = _req();
    uv_fs_realpath(uv_default_loop(), req, path, 0);
    rc: int = uv_fs_get_result(req);
    out: str = "";
    if rc >= 0 {
        p: int = uv_fs_get_ptr(req);
        raw: str = p;  # jac:ignore[E1001] pointer reinterpreted as str
        out = raw + "";
    }
    uv_fs_req_cleanup(req);
    free(req);
    return out;
}

def:pub fsx_chmod(path: str, mode: int) -> int {
    req: int = _req();
    uv_fs_chmod(uv_default_loop(), req, path, mode, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    return rc;
}

"""Copy a regular file (fallback when hard-linking across filesystems fails).
The copy gets `mode` via chmod afterwards, umask-independent."""
def:pub fsx_copy_file(src: str, dst: str, mode: int) -> int {
    req: int = _req();
    uv_fs_copyfile(uv_default_loop(), req, src, dst, 0, 0);
    rc: int = uv_fs_get_result(req);
    uv_fs_req_cleanup(req);
    free(req);
    if rc < 0 {
        return rc;
    }
    return fsx_chmod(dst, mode);
}

# ── process ───────────────────────────────────────────────────────────────────

"""Current umask (read without changing it)."""
def:pub fsx_umask_get -> int {
    m: int = umask(0);
    umask(m);
    return m;
}

"""Set the process umask; returns the previous value."""
def:pub fsx_umask_set(m: int) -> int {
    return umask(m);
}

def:pub fsx_cwd -> str {
    c: str = getcwd(0, 0);
    if c == None {
        return ".";
    }
    return c;
}

"""mkdtemp(3): `template` must end in XXXXXX. Returns the created path or ""."""
def:pub fsx_mkdtemp(template: str) -> str {
    p: int = str_to_cbuf(template);
    r: int = mkdtemp(p);
    if r == 0 {
        io_free(p);
        return "";
    }
    s: str = bytes_to_str(p, 0, len(template));
    io_free(p);
    return s;
}
