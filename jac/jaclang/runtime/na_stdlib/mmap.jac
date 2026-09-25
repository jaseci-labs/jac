import from _mmap_native {
    mm_map,
    mm_unmap,
    mm_sync,
    mm_filesize,
    mm_read,
    mm_write,
    mm_copy,
    mm_errno,
    mm_errstr
}
import from _mmap_platform { mm_anon_flag, mm_sync_flag }


glob:pub PROT_READ: int = 1,
     PROT_WRITE: int = 2,
     PROT_EXEC: int = 4,
     MAP_SHARED: int = 1,
     MAP_PRIVATE: int = 2,
     ACCESS_READ: int = 1,
     ACCESS_WRITE: int = 2,
     ACCESS_COPY: int = 3,
     ACCESS_DEFAULT: int = 0,
     SEEK_SET: int = 0,
     SEEK_CUR: int = 1,
     SEEK_END: int = 2;

glob:pub MAP_ANONYMOUS: int = mm_anon_flag();
glob MAP_ANON: int = mm_anon_flag(),
     _NO_POS: int = -9223372036854775807;


def _os_err -> str {
    return "[Errno " + str(mm_errno()) + "] " + mm_errstr();
}


obj:pub mmap {
    has _addr: int = 0,
        _len: int = 0,
        _pos: int = 0,
        closed: bool = False,
        _access: int = 0,
        _flags: int = 0,
        _fd: int = -1;

    def init(
        fileno: int,
        length: int,
        flags: int = 1,
        prot: int = 3,
        access: int = 0,
        offset: int = 0
    ) {
        use_flags: int = flags;
        use_prot: int = prot;
        if access != ACCESS_DEFAULT
            and (flags != MAP_SHARED or prot != (PROT_READ | PROT_WRITE)) {
            raise ValueError("mmap can't specify both access and flags, prot.");
        }
        if access == ACCESS_READ {
            use_prot = PROT_READ;
            use_flags = MAP_SHARED;
        } elif access == ACCESS_WRITE {
            use_prot = PROT_READ | PROT_WRITE;
            use_flags = MAP_SHARED;
        } elif access == ACCESS_COPY {
            use_prot = PROT_READ | PROT_WRITE;
            use_flags = MAP_PRIVATE;
        } elif access != ACCESS_DEFAULT {
            raise ValueError("mmap invalid access parameter.");
        }
        self._access = access;
        self._flags = use_flags;
        map_len: int = length;
        if map_len < 0 {
            raise OverflowError("memory mapped length must be positive");
        }
        if offset < 0 {
            raise OverflowError("memory mapped offset must be positive");
        }
        if fileno == -1 {
            use_flags = use_flags | MAP_ANON;
        } else {
            fsize: int = mm_filesize(fileno);
            if fsize < 0 {
                raise OSError(_os_err());
            }
            if map_len == 0 {
                if fsize == 0 {
                    raise ValueError("cannot mmap an empty file");
                }
                if offset > fsize {
                    raise ValueError("mmap offset is greater than file size");
                }
                map_len = fsize - offset;
            } else {
                if offset > fsize or map_len > fsize - offset {
                    raise ValueError("mmap length is greater than file size");
                }
            }
        }
        addr: int = mm_map(map_len, use_prot, use_flags, fileno, offset);
        if addr == -1 or addr == 0 {
            raise OSError(_os_err());
        }
        self._addr = addr;
        self._len = map_len;
        self._pos = 0;
        self._fd = fileno;
        self.closed = False;
    }

    def _check_open {
        if self.closed {
            raise ValueError("mmap closed or invalid");
        }
    }

    def close {
        if not self.closed and self._addr != 0 {
            mm_unmap(self._addr, self._len);
            self._addr = 0;
        }
        self.closed = True;
    }

    def __enter__ -> mmap {
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }

    def __len__ -> int {
        return self._len;
    }

    def size -> int {
        self._check_open();
        if self._fd == -1 {
            raise OSError("[Errno 9] Bad file descriptor");
        }
        return mm_filesize(self._fd);
    }

    def tell -> int {
        self._check_open();
        return self._pos;
    }

    def seek(pos: int, whence: int = 0) {
        self._check_open();
        at: int = pos;
        if whence == SEEK_SET {
            at = pos;
        } elif whence == SEEK_CUR {
            at = self._pos + pos;
        } elif whence == SEEK_END {
            at = self._len + pos;
        } else {
            raise ValueError("unknown seek type");
        }
        if at < 0 or at > self._len {
            raise ValueError("seek out of range");
        }
        self._pos = at;
    }

    def read(n: int = -1) -> bytes {
        self._check_open();
        cnt: int = n;
        if cnt < 0 or self._pos + cnt > self._len {
            cnt = self._len - self._pos;
        }
        if cnt <= 0 {
            return b"";
        }
        data: bytes = mm_read(self._addr + self._pos, cnt);
        self._pos += cnt;
        return data;
    }

    def read_byte -> int {
        self._check_open();
        if self._pos >= self._len {
            raise ValueError("read byte out of range");
        }
        v: int = __mem_load_i8(self._addr + self._pos);
        self._pos += 1;
        return v;
    }

    def readline -> bytes {
        self._check_open();
        if self._pos >= self._len {
            return b"";
        }
        base: int = self._addr + self._pos;
        i: int = 0;
        n: int = self._len - self._pos;
        while i < n {
            if __mem_load_i8(base + i) == 10 {
                i += 1;
                line: bytes = mm_read(base, i);
                self._pos += i;
                return line;
            }
            i += 1;
        }
        rest: bytes = mm_read(base, n);
        self._pos += n;
        return rest;
    }

    def _check_writable {
        if self._access == ACCESS_READ {
            raise TypeError("mmap can't modify a readonly memory map.");
        }
    }

    def write(data: bytes) -> int {
        self._check_open();
        self._check_writable();
        n: int = len(data);
        if self._pos + n > self._len {
            raise ValueError("data out of range");
        }
        if n == 0 {
            return 0;
        }
        mm_write(self._addr + self._pos, data);
        self._pos += n;
        return n;
    }

    def write_byte(v: int) {
        self._check_open();
        self._check_writable();
        if self._pos >= self._len {
            raise ValueError("write byte out of range");
        }
        if v < 0 {
            raise OverflowError("unsigned byte integer is less than minimum");
        }
        if v > 255 {
            raise OverflowError("unsigned byte integer is greater than maximum");
        }
        __mem_store_i8(self._addr + self._pos, v);
        self._pos += 1;
    }

    def __getitem__(i: int) -> int {
        self._check_open();
        at: int = i;
        if at < 0 {
            at += self._len;
        }
        if at < 0 or at >= self._len {
            raise IndexError("mmap index out of range");
        }
        return __mem_load_i8(self._addr + at);
    }

    def __setitem__(i: int, v: int) {
        self._check_open();
        self._check_writable();
        at: int = i;
        if at < 0 {
            at += self._len;
        }
        if at < 0 or at >= self._len {
            raise IndexError("mmap index out of range");
        }
        if v < 0 or v > 255 {
            raise ValueError("mmap item value must be in range(0, 256)");
        }
        __mem_store_i8(self._addr + at, v);
    }

    def _find_bounds(start: int, end: int) -> tuple[int, int] {
        lo: int = start;
        if lo == _NO_POS {
            lo = self._pos;
        } elif lo < 0 {
            lo += self._len;
            if lo < 0 {
                lo = 0;
            }
        }
        if lo > self._len {
            lo = self._len;
        }
        hi: int = end;
        if hi == _NO_POS {
            hi = self._len;
        } elif hi < 0 {
            hi += self._len;
            if hi < 0 {
                hi = 0;
            }
        }
        if hi > self._len {
            hi = self._len;
        }
        if lo >= hi {
            return (-1, -1);
        }
        return (lo, hi);
    }

    def _scan(sub: bytes, lo: int, hi: int, last: bool) -> int {
        n: int = len(sub);
        span: int = hi - lo;
        if n == 0 {
            if last {
                return hi;
            }
            return lo;
        }
        if n > span {
            return -1;
        }
        base: int = self._addr + lo;
        sp: int = __bytes_data(sub);
        i: int = 0;
        step: int = 1;
        if last {
            i = span - n;
            step = -1;
        }
        while i >= 0 and i <= span - n {
            j: int = 0;
            matched: bool = True;
            while j < n {
                if __mem_load_i8(base + i + j) != __mem_load_i8(sp + j) {
                    matched = False;
                    break;
                }
                j += 1;
            }
            if matched {
                return lo + i;
            }
            i += step;
        }
        return -1;
    }

    def find(sub: bytes, start: int = _NO_POS, end: int = _NO_POS) -> int {
        self._check_open();
        w: tuple[int, int] = self._find_bounds(start, end);
        if w[0] < 0 {
            return -1;
        }
        return self._scan(sub, w[0], w[1], False);
    }

    def rfind(sub: bytes, start: int = _NO_POS, end: int = _NO_POS) -> int {
        self._check_open();
        w: tuple[int, int] = self._find_bounds(start, end);
        if w[0] < 0 {
            return -1;
        }
        return self._scan(sub, w[0], w[1], True);
    }

    def flush(offset: int = 0, size: int = 0) {
        self._check_open();
        if offset < 0 or size < 0 or offset > self._len or offset + size > self._len {
            raise ValueError("flush values out of range");
        }
        cnt: int = size;
        if cnt == 0 {
            cnt = self._len - offset;
        }
        rc: int = mm_sync(self._addr + offset, cnt);
        if rc != 0 {
            raise OSError(_os_err());
        }
    }

    def move(dest: int, src: int, count: int) {
        self._check_open();
        self._check_writable();
        if dest < 0 or src < 0 or count < 0 {
            raise ValueError("source, destination, or count out of range");
        }
        if dest + count > self._len or src + count > self._len {
            raise ValueError("source, destination, or count out of range");
        }
        mm_copy(self._addr + dest, self._addr + src, count);
    }

    def resize(newsize: int) {
        self._check_open();

        if self._access == ACCESS_READ or self._access == ACCESS_COPY {
            raise TypeError(
                "mmap can't resize a readonly or copy-on-write memory map."
            );
        }
        if newsize < 0 {
            raise ValueError("new size out of range");
        }
        if (self._flags & MAP_PRIVATE) == 0 {
            if self._fd == -1 {
                if newsize > self._len {
                    raise ValueError("mmap: can't expand a shared anonymous mapping");
                }
            } else {
                raise ValueError("mmap: can't resize a file-backed shared mapping");
            }
        }
        new_addr: int = mm_map(
            newsize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0
        );
        if new_addr == -1 or new_addr == 0 {
            raise OSError(_os_err());
        }
        keep: int = newsize;
        if self._len < keep {
            keep = self._len;
        }
        mm_copy(new_addr, self._addr, keep);
        mm_unmap(self._addr, self._len);
        self._addr = new_addr;
        self._len = newsize;
        if self._pos > newsize {
            self._pos = newsize;
        }
    }

    def read_slice(start: int, n: int) -> bytes {
        self._check_open();
        if start < 0 or start + n > self._len {
            raise IndexError("mmap slice out of range");
        }
        return mm_read(self._addr + start, n);
    }
}
