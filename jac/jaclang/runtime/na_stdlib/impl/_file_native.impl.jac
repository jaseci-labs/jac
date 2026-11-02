impl open_stream(path: str, mode: str) -> int {
    if "\x00" in path {
        raise ValueError("embedded null byte");
    }
    stream = fopen(path, mode);
    if stream == 0 {
        raise_os_error("open", path, last_errno());
    }
    return stream;
}

impl close_stream(stream: int) {
    fclose(stream);
}

impl read_stream(stream: int, size: int, path: str) -> bytes {
    if size <= 0 {
        return b"";
    }
    buffer = b"\x00" * size;
    count = int(fread(buffer, u64(1), u64(size), stream));
    if ferror(stream) != i32(0) {
        raise_os_error("read", path, last_errno());
    }
    if count == size {
        return buffer;
    }
    return buffer[:count];
}

impl read_stream_all(stream: int, path: str) -> bytes {
    buffer = b"\x00" * 65536;
    result = bytearray();
    while True {
        count = int(fread(buffer, u64(1), u64(len(buffer)), stream));
        if ferror(stream) != i32(0) {
            raise_os_error("read", path, last_errno());
        }
        result.extend(buffer[:count]);
        if count < len(buffer) {
            break;
        }
    }
    return bytes(result);
}

impl seek_stream(stream: int, offset: int, whence: int, path: str) -> int {
    if fseek(stream, i64(offset), i32(whence)) != i32(0) {
        raise_os_error("seek", path, last_errno());
    }
    return int(ftell(stream));
}

impl read_file_bytes(path: str) -> bytes {
    stream = open_stream(path, "rb");
    try {
        hint = -1;
        if fseek(stream, i64(0), i32(_SEEK_END)) == i32(0) {
            end = int(ftell(stream));
            if fseek(stream, i64(0), i32(_SEEK_SET)) != i32(0) {
                raise_os_error("seek", path, last_errno());
            }
            if end > 0 {
                hint = end;
                if hint > _PREALLOC_CAP {
                    hint = _PREALLOC_CAP;
                }
            }
        }
        result = bytearray();
        if hint > 0 {
            out = b"\x00" * hint;
            got = int(fread(out, u64(1), u64(hint), stream));
            if ferror(stream) != i32(0) {
                raise_os_error("read", path, last_errno());
            }
            if got < hint {
                return out[:got];
            }
            tail = b"\x00" * 1;
            if int(fread(tail, u64(1), u64(1), stream)) == 0 {
                if ferror(stream) != i32(0) {
                    raise_os_error("read", path, last_errno());
                }
                return out;
            }
            result.extend(out);
            result.extend(tail);
        }
        buffer = b"\x00" * 65536;
        while True {
            count = int(fread(buffer, u64(1), u64(len(buffer)), stream));
            if ferror(stream) != i32(0) {
                raise_os_error("read", path, last_errno());
            }
            result.extend(buffer[:count]);
            if count < len(buffer) {
                break;
            }
        }
        return bytes(result);
    } finally {
        fclose(stream);
    }
}
