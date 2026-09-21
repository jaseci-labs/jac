import struct;
import from _passwd_layout { PASSWD_SIZE, PASSWD_DIR }
import from c { def getuid -> u32;  }
import from c {
    def getpwuid_r(
        uid: u32, record: bytes, buffer: bytes, size: u64, result: bytes
    ) -> i32;
}
import from c {
    def getpwnam_r(
        name: str, record: bytes, buffer: bytes, size: u64, result: bytes
    ) -> i32;
}
import from c { def strlen(pointer: int) -> u64;  }
import from c { def memcpy(target: bytes, source: int, length: u64) -> int;  }

def:pub user_home(name: str) -> str | None {
    if "\x00" in name {
        raise ValueError("embedded null byte");
    }
    size = 1024;
    while True {
        record = b"\x00" * PASSWD_SIZE;
        buffer = b"\x00" * size;
        result = b"\x00" * 8;
        code = int(getpwuid_r(getuid(), record, buffer, u64(size), result))
            if name == ""
            else int(getpwnam_r(name, record, buffer, u64(size), result));
        if code == 34 {
            size *= 2;
            continue;
        }
        if code != 0 {
            return None;
        }
        if int(struct.unpack("=Q", result)[0]) == 0 {
            return None;
        }
        address = int(struct.unpack("=Q", record[PASSWD_DIR:PASSWD_DIR + 8])[0]);
        if address == 0 {
            return "";
        }
        length = strlen(address);
        copied = b"\x00" * int(length);
        memcpy(copied, address, length);
        return copied.decode("utf-8");
    }
}
