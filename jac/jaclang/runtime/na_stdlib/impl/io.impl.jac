impl BufferedIOBase.readable -> bool {
    return False;
}

impl BufferedIOBase.writable -> bool {
    return False;
}

impl BufferedIOBase.seekable -> bool {
    return False;
}

impl BufferedIOBase.read(size: int = -1) -> bytes {
    raise UnsupportedOperation("read");
}

impl BufferedIOBase.read1(size: int = -1) -> bytes {
    raise UnsupportedOperation("read1");
}

impl BufferedIOBase.write(b: bytes) -> int {
    raise UnsupportedOperation("write");
}

impl BufferedIOBase.seek(pos: int, whence: int = 0) -> int {
    raise UnsupportedOperation("seek");
}

impl BufferedIOBase.tell -> int {
    raise UnsupportedOperation("tell");
}

impl BufferedIOBase.flush {
    return;
}

impl BufferedIOBase.close {
    self.closed = True;
}

impl BufferedIOBase.__enter__ -> BufferedIOBase {
    return self;
}

impl BufferedIOBase.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    self.close();
    return False;
}

impl BytesIO.init(initial_bytes: bytes = b"") {
    self._buf = initial_bytes;
    self._pos = 0;
    self.closed = False;
}

impl BytesIO._check_closed {
    if self.closed {
        raise ValueError("I/O operation on closed file.");
    }
}

impl BytesIO.readable -> bool {
    self._check_closed();
    return True;
}

impl BytesIO.writable -> bool {
    self._check_closed();
    return True;
}

impl BytesIO.seekable -> bool {
    self._check_closed();
    return True;
}

impl BytesIO.read(size: int = -1) -> bytes {
    self._check_closed();
    total: int = len(self._buf);
    if self._pos >= total {
        return b"";
    }
    end: int = total;
    if size >= 0 and self._pos + size < total {
        end = self._pos + size;
    }
    out = self._buf[self._pos:end];
    self._pos = end;
    return out;
}

impl BytesIO.read1(size: int = -1) -> bytes {
    return self.read(size);
}

impl BytesIO.write(b: bytes) -> int {
    self._check_closed();
    n: int = len(b);
    if n == 0 {
        return 0;
    }
    cur: int = len(self._buf);
    if self._pos > cur {
        self._buf = self._buf + b"\x00" * (self._pos - cur);
        cur = self._pos;
    }
    end: int = self._pos + n;
    if end >= cur {
        self._buf = self._buf[0:self._pos] + b;
    } else {
        self._buf = self._buf[0:self._pos] + b + self._buf[end:cur];
    }
    self._pos = end;
    return n;
}

impl BytesIO.seek(pos: int, whence: int = 0) -> int {
    self._check_closed();
    if whence == 0 {
        if pos < 0 {
            raise ValueError("negative seek value " + str(pos));
        }
        self._pos = pos;
    } elif whence == 1 {
        self._pos = max(0, self._pos + pos);
    } elif whence == 2 {
        self._pos = max(0, len(self._buf) + pos);
    } else {
        raise ValueError("invalid whence (" + str(whence) + ", should be 0, 1 or 2)");
    }
    return self._pos;
}

impl BytesIO.tell -> int {
    self._check_closed();
    return self._pos;
}

impl BytesIO.getvalue -> bytes {
    self._check_closed();
    return self._buf;
}

impl BytesIO.flush {
    self._check_closed();
}

impl BytesIO.close {
    self._buf = b"";
    self._pos = 0;
    self.closed = True;
}

impl BytesIO.__enter__ -> BytesIO {
    self._check_closed();
    return self;
}

impl BytesIO.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    self.close();
    return False;
}

impl FileIO.init(file: str, mode: str = "r") {
    if mode.replace("b", "") != "r" {
        raise ValueError("FileIO mode " + mode + " is not supported natively");
    }
    self.name = file;
    self.mode = "rb";
    self.closed = False;
    self._stream = open_stream(file, "rb");
}

impl FileIO._check_closed {
    if self.closed {
        raise ValueError("I/O operation on closed file");
    }
}

impl FileIO.readable -> bool {
    self._check_closed();
    return True;
}

impl FileIO.writable -> bool {
    self._check_closed();
    return False;
}

impl FileIO.seekable -> bool {
    self._check_closed();
    return True;
}

impl FileIO.read(size: int = -1) -> bytes {
    self._check_closed();
    if size < 0 {
        return read_stream_all(self._stream, self.name);
    }
    return read_stream(self._stream, size, self.name);
}

impl FileIO.readall -> bytes {
    self._check_closed();
    return read_stream_all(self._stream, self.name);
}

impl FileIO.write(b: bytes) -> int {
    self._check_closed();
    raise UnsupportedOperation("File not open for writing");
}

impl FileIO.seek(pos: int, whence: int = 0) -> int {
    self._check_closed();
    if whence < 0 or whence > 2 {
        raise ValueError("invalid whence (" + str(whence) + ", should be 0, 1 or 2)");
    }
    return seek_stream(self._stream, pos, whence, self.name);
}

impl FileIO.tell -> int {
    self._check_closed();
    return seek_stream(self._stream, 0, SEEK_CUR, self.name);
}

impl FileIO.flush {
    self._check_closed();
}

impl FileIO.close {
    if not self.closed {
        close_stream(self._stream);
        self._stream = 0;
        self.closed = True;
    }
}

impl FileIO.__enter__ -> FileIO {
    self._check_closed();
    return self;
}

impl FileIO.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    self.close();
    return False;
}

impl StringIO.init(initial_value: str = "") {
    self._buf = initial_value;
    self._pos = 0;
    self.closed = False;
}

impl StringIO._check_closed {
    if self.closed {
        raise ValueError("I/O operation on closed file");
    }
}

impl StringIO.readable -> bool {
    self._check_closed();
    return True;
}

impl StringIO.writable -> bool {
    self._check_closed();
    return True;
}

impl StringIO.seekable -> bool {
    self._check_closed();
    return True;
}

impl StringIO.read(size: int = -1) -> str {
    self._check_closed();
    total: int = len(self._buf);
    if self._pos >= total {
        return "";
    }
    end: int = total;
    if size >= 0 and self._pos + size < total {
        end = self._pos + size;
    }
    out = self._buf[self._pos:end];
    self._pos = end;
    return out;
}

impl StringIO.readline(size: int = -1) -> str {
    self._check_closed();
    total: int = len(self._buf);
    if self._pos >= total {
        return "";
    }
    end: int = total;
    i: int = self._pos;
    while i < total {
        if self._buf[i] == "\n" {
            end = i + 1;
            break;
        }
        i += 1;
    }
    if size >= 0 and self._pos + size < end {
        end = self._pos + size;
    }
    out = self._buf[self._pos:end];
    self._pos = end;
    return out;
}

impl StringIO.write(s: str) -> int {
    self._check_closed();
    n: int = len(s);
    total: int = len(self._buf);
    if self._pos > total {
        self._buf = self._buf + (" " * (self._pos - total));
        total = self._pos;
    }
    head = self._buf[0:self._pos];
    tail_start: int = self._pos + n;
    tail = self._buf[tail_start:] if tail_start < total else "";
    self._buf = head + s + tail;
    self._pos = self._pos + n;
    return n;
}

impl StringIO.getvalue -> str {
    self._check_closed();
    return self._buf;
}

impl StringIO.tell -> int {
    self._check_closed();
    return self._pos;
}

impl StringIO.seek(pos: int, whence: int = 0) -> int {
    self._check_closed();
    if whence == 0 {
        if pos < 0 {
            raise ValueError("negative seek position");
        }
        self._pos = pos;
    } elif whence == 1 {
        if pos != 0 {
            raise OSError("Can't do nonzero cur-relative seeks");
        }
    } elif whence == 2 {
        if pos != 0 {
            raise OSError("Can't do nonzero end-relative seeks");
        }
        self._pos = len(self._buf);
    } else {
        raise ValueError("invalid whence");
    }
    return self._pos;
}

impl StringIO.close {
    self.closed = True;
}

impl StringIO.__enter__ -> StringIO {
    self._check_closed();
    return self;
}

impl StringIO.__exit__(exc_type: object, exc: object, tb: object) {
    self.close();
}
