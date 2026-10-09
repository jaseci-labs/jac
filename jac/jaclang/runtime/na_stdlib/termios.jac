import from _termios_native {
    get_attrs,
    set_attrs,
    _put_u32,
    _new_buf,
    _NCCS,
    _OFF_CC,
    _OFF_IFLAG,
    _OFF_OFLAG,
    _OFF_CFLAG,
    _OFF_LFLAG,
    _OFF_ISPEED,
    _OFF_OSPEED
}

glob TCSANOW: int = 0,
     TCSADRAIN: int = 1,
     TCSAFLUSH: int = 2;

glob TIOCGWINSZ: int = 21523;

glob VINTR: int = 0,
     VQUIT: int = 1,
     VERASE: int = 2,
     VKILL: int = 3,
     VEOF: int = 4,
     VTIME: int = 5,
     VMIN: int = 6,
     VSWTC: int = 7,
     VSTART: int = 8,
     VSTOP: int = 9,
     VSUSP: int = 10,
     VEOL: int = 11,
     VREPRINT: int = 12,
     VDISCARD: int = 13,
     VWERASE: int = 14,
     VLNEXT: int = 15,
     VEOL2: int = 16;

glob BRKINT: int = 2,
     ICRNL: int = 256,
     INPCK: int = 16,
     ISTRIP: int = 32,
     IXON: int = 1024,
     IGNBRK: int = 1,
     IGNCR: int = 128,
     IGNPAR: int = 4,
     INLCR: int = 64,
     IXANY: int = 2048,
     IXOFF: int = 4096,
     PARMRK: int = 8;

glob OPOST: int = 1,
     ONLCR: int = 4;

glob CSIZE: int = 48,
     CSTOPB: int = 64,
     CREAD: int = 128,
     PARENB: int = 256,
     PARODD: int = 512,
     CS7: int = 32,
     CS8: int = 48,
     HUPCL: int = 1024;

glob ECHO: int = 8,
     ECHOE: int = 16,
     ECHOK: int = 32,
     ECHONL: int = 64,
     ICANON: int = 2,
     IEXTEN: int = 32768,
     ISIG: int = 1,
     NOFLSH: int = 128,
     TOSTOP: int = 256;


def:pub tcgetattr(fd: int) -> list[any] {
    (blob, flags) = get_attrs(fd);
    if len(flags) == 0 {
        raise ValueError("tcgetattr failed");
    }
    out: list[any] = [flags[0], flags[1], flags[2], flags[3], flags[4], flags[5]];
    cc: list[any] = [];
    k: int = 0;
    while k < _NCCS {
        cc.append(blob[_OFF_CC + k:_OFF_CC + k + 1]);
        k += 1;
    }
    out.append(cc);
    return out;
}


def _cc_byte(e: any) -> int {
    if isinstance(e, int) {
        return e & 0xFF;
    }
    if isinstance(e, bytes) and len(e) >= 1 {
        return e[0];
    }
    raise TypeError("tcsetattr: cc entries must be int or one-byte bytes");
}


def _pack_attrs(attrs: list[any]) -> bytes {
    blob: bytes = _new_buf();
    vals: list[int] = [0, 0, 0, 0, 0, 0];
    k: int = 0;
    while k < 6 {
        v = attrs[k];
        if isinstance(v, int) {
            vals[k] = v;
        } else {
            raise TypeError("tcsetattr: attrs flag elements must be int");
        }
        k += 1;
    }
    _put_u32(blob, _OFF_IFLAG, vals[0]);
    _put_u32(blob, _OFF_OFLAG, vals[1]);
    _put_u32(blob, _OFF_CFLAG, vals[2]);
    _put_u32(blob, _OFF_LFLAG, vals[3]);
    _put_u32(blob, _OFF_ISPEED, vals[4]);
    _put_u32(blob, _OFF_OSPEED, vals[5]);
    ccv = attrs[6];
    if isinstance(ccv, list) {
        j: int = 0;
        while j < _NCCS and j < len(ccv) {
            blob[_OFF_CC + j] = _cc_byte(ccv[j]);
            j += 1;
        }
    }
    return blob;
}


def:pub tcsetattr(fd: int, when: int, attrs: any) -> None {
    if isinstance(attrs, list) {
        if len(attrs) < 7 {
            raise ValueError("tcsetattr: attrs must have 7 elements");
        }
        rc: int = set_attrs(fd, when, _pack_attrs(attrs));
        if rc != 0 {
            raise ValueError("tcsetattr failed");
        }
        return;
    }

    if isinstance(attrs, bytes) {
        rc2: int = set_attrs(fd, when, attrs);
        if rc2 != 0 {
            raise ValueError("tcsetattr failed");
        }
        return;
    }
    raise ValueError("tcsetattr: attrs must be a list or a bytes blob");
}
