import from c { def fopen(path: str, mode: str) -> int;  }
import from c { def fread(buffer: bytes, size: u64, count: u64, stream: int) -> u64;  }
import from c { def ferror(stream: int) -> i32;  }
import from c { def fclose(stream: int) -> i32;  }
import from c { def fseek(stream: int, offset: int, whence: i32) -> i32;  }
import from c { def ftell(stream: int) -> int;  }
import from _errno_native { last_errno, raise_os_error }

def:pub open_stream(path: str, mode: str) -> int {
    if "\x00" in path {
        raise ValueError("embedded null byte");
    }
    stream = fopen(path, mode);
    if stream == 0 {
        raise_os_error("open", path, last_errno());
    }
    return stream;
}

def:pub close_stream(stream: int) {
    fclose(stream);
}

def:pub read_stream(stream: int, size: int, path: str) -> bytes {
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

def:pub read_stream_all(stream: int, path: str) -> bytes {
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

def:pub seek_stream(stream: int, offset: int, whence: int, path: str) -> int {
    if fseek(stream, offset, i32(whence)) != i32(0) {
        raise_os_error("seek", path, last_errno());
    }
    return ftell(stream);
}

def:pub read_file_bytes(path: str) -> bytes {
    stream = open_stream(path, "rb");
    try {
        return read_stream_all(stream, path);
    } finally {
        fclose(stream);
    }
}
