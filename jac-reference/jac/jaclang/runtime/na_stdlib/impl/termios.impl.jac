impl _fail(op: str) {
    raise ValueError(
        op + " failed: [Errno " + str(last_errno()) + "] " + errno_message()
    );
}

impl tcgetattr(fd: int) -> list[any] {
    (blob, rc) = get_attrs(fd);
    if rc != 0 {
        _fail("tcgetattr");
    }
    out: list[any] = [];
    out.append(word_at(blob, _OFF_IFLAG));
    out.append(word_at(blob, _OFF_OFLAG));
    out.append(word_at(blob, _OFF_CFLAG));
    out.append(word_at(blob, _OFF_LFLAG));
    out.append(in_speed(blob));
    out.append(out_speed(blob));
    cc: list[any] = [];
    k: int = 0;
    while k < _NCCS {
        cc.append(blob[_OFF_CC + k]);
        k += 1;
    }
    out.append(cc);
    return out;
}

impl _cc_byte(e: any) -> int {
    if isinstance(e, int) {
        return e & 0xFF;
    }
    if isinstance(e, bytes) and len(e) == 1 {
        return e[0];
    }
    raise TypeError(
        "tcsetattr: elements of attributes must be bytes objects of length 1 or integers"
    );
}

impl _pack_attrs(base: bytes, attrs: list[any]) -> bytes {
    ccv = attrs[6];
    if not isinstance(ccv, list) or len(ccv) != _NCCS {
        raise TypeError(
            "tcsetattr: attributes[6] must be " + str(_NCCS) + " element list"
        );
    }
    cc_bytes: list[int] = [];
    for e in ccv {
        cc_bytes.append(_cc_byte(e));
    }
    blob: bytes = base;
    k: int = 0;
    while k < 6 {
        v = attrs[k];
        if isinstance(v, int) {
            if k == 0 {
                blob = put_word(blob, _OFF_IFLAG, v);
            } elif k == 1 {
                blob = put_word(blob, _OFF_OFLAG, v);
            } elif k == 2 {
                blob = put_word(blob, _OFF_CFLAG, v);
            } elif k == 3 {
                blob = put_word(blob, _OFF_LFLAG, v);
            }
        } else {
            raise TypeError("tcsetattr: attributes elements must be integers");
        }
        k += 1;
    }
    speed_rc: int = set_speeds(blob, int(attrs[4]), int(attrs[5]));
    if speed_rc != 0 {
        _fail("tcsetattr");
    }
    j: int = 0;
    while j < _NCCS {
        blob = _put_byte(blob, _OFF_CC + j, cc_bytes[j]);
        j += 1;
    }
    return blob;
}

impl tcsetattr(fd: int, when: int, attrs: list[any]) {
    if len(attrs) != 7 {
        raise TypeError("tcsetattr, arg 3: must be 7 element list");
    }
    if when != TCSANOW and when != TCSADRAIN and when != TCSAFLUSH {
        raise ValueError("invalid 'when' argument");
    }
    (current, get_rc) = get_attrs(fd);
    if get_rc != 0 {
        _fail("tcsetattr");
    }
    rc: int = set_attrs(fd, when, _pack_attrs(current, attrs));
    if rc != 0 {
        _fail("tcsetattr");
    }
}

impl _put_byte(buf: bytes, off: int, value: int) -> bytes {
    return buf[:off] + value.to_bytes(1, "little") + buf[off + 1:];
}
