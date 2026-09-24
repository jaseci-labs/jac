import from c { def fopen(path: str, mode: str) -> int;  }
import from c { def fread(buffer: bytes, size: u64, count: u64, stream: int) -> u64;  }
import from c { def ferror(stream: int) -> i32;  }
import from c { def fclose(stream: int) -> i32;  }
import from c { def fseek(stream: int, off: i64, whence: i32) -> i32;  }
import from c { def ftell(stream: int) -> i64;  }
import from _errno_native { last_errno, raise_os_error }

glob _SEEK_SET: int = 0,
     _SEEK_END: int = 2,
     _PREALLOC_CAP: int = 67108864;

def:pub read_file_bytes(path: str) -> bytes {
    if "\x00" in path {
        raise ValueError("embedded null byte");
    }
    stream = fopen(path, "rb");
    if stream == 0 {
        raise_os_error("open", path, last_errno());
    }
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
