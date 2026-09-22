import from c { def fopen(path: str, mode: str) -> int;  }
import from c { def fread(buffer: bytes, size: u64, count: u64, stream: int) -> u64;  }
import from c { def ferror(stream: int) -> i32;  }
import from c { def fclose(stream: int) -> i32;  }
import from _errno_native { last_errno, raise_os_error }

def:pub read_file_bytes(path: str) -> bytes {
    if "\x00" in path {
        raise ValueError("embedded null byte");
    }
    stream = fopen(path, "rb");
    if stream == 0 {
        raise_os_error("open", path, last_errno());
    }
    try {
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
    } finally {
        fclose(stream);
    }
}
