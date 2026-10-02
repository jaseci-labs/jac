import from c { def tcgetattr(fd: i32, buf: bytes) -> i32;  }
import from c { def tcsetattr(fd: i32, act: i32, buf: bytes) -> i32;  }
import from c { def cfgetispeed(buf: bytes) -> u32;  }
import from c { def cfgetospeed(buf: bytes) -> u32;  }

glob _T_SIZE: int = 60,
     _OFF_IFLAG: int = 0,
     _OFF_OFLAG: int = 4,
     _OFF_CFLAG: int = 8,
     _OFF_LFLAG: int = 12,
     _OFF_LINE: int = 16,
     _OFF_CC: int = 17,
     _NCCS: int = 32,
     _OFF_ISPEED: int = 52,
     _OFF_OSPEED: int = 56;


def _u32_at(buf: bytes, off: int) -> int {
    return int.from_bytes(buf[off:off + 4], "little");
}


def _put_u32(buf: bytes, off: int, v: int) {
    buf[off] = v & 0xFF;
    buf[off + 1] = (v >> 8) & 0xFF;
    buf[off + 2] = (v >> 16) & 0xFF;
    buf[off + 3] = (v >> 24) & 0xFF;
}


def _new_buf -> bytes {
    return b"\x00" * _T_SIZE;
}


def:pub get_attrs(fd: int) -> tuple[(bytes, list[int])] {
    buf: bytes = _new_buf();
    rc: int = tcgetattr(i32(fd), buf);
    if rc != 0 {
        return (buf, []);
    }
    return (
        buf,
        [
            _u32_at(buf, _OFF_IFLAG),
            _u32_at(buf, _OFF_OFLAG),
            _u32_at(buf, _OFF_CFLAG),
            _u32_at(buf, _OFF_LFLAG),
            int(cfgetispeed(buf)),
            int(cfgetospeed(buf)),

        ],

    );
}


def:pub set_attrs(fd: int, when: int, blob: bytes) -> int {
    return tcsetattr(i32(fd), i32(when), blob);
}
