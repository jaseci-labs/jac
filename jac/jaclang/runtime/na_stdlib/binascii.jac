import from _zlib_native { z_crc32 }
import from base64 { b64decode, b64encode }


obj:pub Error(ValueError) {}
obj:pub Incomplete(Exception) {}


glob _CRCTAB: list[int] = [];


def _hexval(c: int) -> int {
    if c >= 48 and c <= 57 {
        return c - 48;
    }
    if c >= 97 and c <= 102 {
        return c - 87;
    }
    if c >= 65 and c <= 70 {
        return c - 55;
    }
    return -1;
}


def _hexdig(v: int) -> int {
    return (48 + v) if v < 10 else (55 + v);
}


def _hqx_tab -> list[int] {
    if len(_CRCTAB) == 0 {
        b: int = 0;
        while b < 256 {
            crc: int = b << 8;
            k: int = 0;
            while k < 8 {
                crc = ((crc << 1) ^ 4129) if (crc & 32768) else (crc << 1);
                crc = crc & 65535;
                k += 1;
            }
            _CRCTAB.append(crc);
            b += 1;
        }
    }
    return _CRCTAB;
}


def:pub hexlify(data: bytes, sep: bytes = b"", bytes_per_sep: int = 1) -> bytes {
    n: int = len(data);
    use_sep: bool = len(sep) > 0;
    if use_sep and len(sep) != 1 {
        raise ValueError("sep must be length 1.");
    }
    sep_byte: int = sep[0] if use_sep else 0;
    abs_bps: int = -bytes_per_sep if bytes_per_sep < 0 else bytes_per_sep;
    nseps: int = 0;
    if use_sep and abs_bps > 0 and n > 1 {
        nseps = (n - 1) // abs_bps;
    }
    out: bytes = b"\x00" * (n * 2 + nseps);
    if n == 0 {
        return out;
    }

    sp: int = __bytes_data(data);
    dp: int = __bytes_data(out);
    j: int = 0;
    i: int = 0;
    while i < n {
        if use_sep and i > 0 and abs_bps > 0 {
            put: bool = ((n - i) % abs_bps == 0)
                if bytes_per_sep > 0
                else (i % abs_bps == 0);
            if put {
                __mem_store_i8(dp + j, sep_byte);
                j += 1;
            }
        }
        c: int = __mem_load_i8(sp + i);
        hi: int = c >> 4;
        lo: int = c & 15;
        __mem_store_i8(dp + j, (48 + hi) if hi < 10 else (87 + hi));
        __mem_store_i8(dp + j + 1, (48 + lo) if lo < 10 else (87 + lo));
        j += 2;
        i += 1;
    }
    return out;
}


def:pub b2a_hex(data: bytes, sep: bytes = b"", bytes_per_sep: int = 1) -> bytes {
    return hexlify(data, sep, bytes_per_sep);
}


def:pub unhexlify(hexstr: bytes) -> bytes {
    n: int = len(hexstr);
    if n % 2 != 0 {
        raise Error("Odd-length string");
    }
    out: bytes = b"\x00" * (n // 2);
    if n == 0 {
        return out;
    }
    sp: int = __bytes_data(hexstr);
    dp: int = __bytes_data(out);
    i: int = 0;
    j: int = 0;
    while i < n {
        top: int = _hexval(__mem_load_i8(sp + i));
        bot: int = _hexval(__mem_load_i8(sp + i + 1));
        if top < 0 or bot < 0 {
            raise Error("Non-hexadecimal digit found");
        }
        __mem_store_i8(dp + j, (top << 4) + bot);
        j += 1;
        i += 2;
    }
    return out;
}


def:pub a2b_hex(hexstr: bytes) -> bytes {
    return unhexlify(hexstr);
}


def:pub b2a_base64(data: bytes, newline: bool = True) -> bytes {
    enc: bytes = b64encode(data);
    if newline {
        return enc + b"\n";
    }
    return enc;
}


def:pub a2b_base64(data: bytes, strict_mode: bool = False) -> bytes {
    return b64decode(data, b"", strict_mode);
}


def:pub crc32(data: bytes, value: int = 0) -> int {
    return z_crc32(value & 4294967295, data, len(data));
}


def:pub crc_hqx(data: bytes, crc: int) -> int {
    tab: list[int] = _hqx_tab();
    c: int = crc & 65535;
    n: int = len(data);
    if n == 0 {
        return c;
    }
    sp: int = __bytes_data(data);
    i: int = 0;
    while i < n {
        c = ((c << 8) & 65280) ^ tab[((c >> 8) ^ __mem_load_i8(sp + i)) & 255];
        i += 1;
    }
    return c;
}


def:pub b2a_uu(data: bytes, backtick: bool = False) -> bytes {
    bin_len: int = len(data);
    if bin_len > 45 {
        raise Error("At most 45 bytes at once");
    }

    out: bytearray = bytearray(((bin_len + 2) // 3) * 4 + 2);
    dp: int = __bytearray_data(out);
    j: int = 0;
    if backtick and bin_len == 0 {
        __mem_store_i8(dp, 96);
        j = 1;
    } else {
        __mem_store_i8(dp, 32 + bin_len);
        j = 1;
    }
    sp: int = __bytes_data(data) if bin_len > 0 else 0;
    leftbits: int = 0;
    leftchar: int = 0;
    i: int = 0;
    while bin_len > 0 or leftbits != 0 {
        if bin_len > 0 {
            leftchar = (leftchar << 8) | __mem_load_i8(sp + i);
            bin_len -= 1;
            i += 1;
        } else {
            leftchar = leftchar << 8;
        }
        leftbits += 8;
        while leftbits >= 6 {
            this_ch: int = (leftchar >> (leftbits - 6)) & 63;
            leftbits -= 6;
            if backtick and this_ch == 0 {
                __mem_store_i8(dp + j, 96);
            } else {
                __mem_store_i8(dp + j, this_ch + 32);
            }
            j += 1;
        }
    }
    __mem_store_i8(dp + j, 10);
    j += 1;
    return bytes(out[0:j]);
}


def:pub a2b_uu(data: bytes) -> bytes {
    ascii_len: int = len(data);
    if ascii_len == 0 {
        raise Error("Missing length byte");
    }
    sp: int = __bytes_data(data);
    bin_len: int = (__mem_load_i8(sp) - 32) & 63;
    pos: int = 1;
    ascii_len -= 1;
    out: bytearray = bytearray(bin_len);
    dp: int = __bytearray_data(out) if bin_len > 0 else 0;
    j: int = 0;
    leftbits: int = 0;
    leftchar: int = 0;
    while bin_len > 0 {
        this_ch: int = __mem_load_i8(sp + pos) if ascii_len > 0 else 0;
        if this_ch == 10 or this_ch == 13 or ascii_len <= 0 {
            this_ch = 0;
        } else {
            if this_ch < 32 or this_ch > 96 {
                raise Error("Illegal char");
            }
            this_ch = (this_ch - 32) & 63;
        }
        leftchar = (leftchar << 6) | this_ch;
        leftbits += 6;
        if leftbits >= 8 {
            leftbits -= 8;
            __mem_store_i8(dp + j, (leftchar >> leftbits) & 255);
            j += 1;
            leftchar = leftchar & ((1 << leftbits) - 1);
            bin_len -= 1;
        }
        ascii_len -= 1;
        pos += 1;
    }
    while ascii_len > 0 {
        this_ch = __mem_load_i8(sp + pos);
        if this_ch != 32 and this_ch != 96 and this_ch != 10 and this_ch != 13 {
            raise Error("Trailing garbage");
        }
        ascii_len -= 1;
        pos += 1;
    }
    return bytes(out);
}


def:pub a2b_qp(data: bytes, header: bool = False) -> bytes {
    datalen: int = len(data);
    out: bytearray = bytearray(datalen);
    sp: int = __bytes_data(data) if datalen > 0 else 0;
    dp: int = __bytearray_data(out) if datalen > 0 else 0;
    out_j: int = 0;
    in_i: int = 0;
    while in_i < datalen {
        c: int = __mem_load_i8(sp + in_i);
        if c == 61 {
            in_i += 1;
            if in_i >= datalen {
                break;
            }
            c = __mem_load_i8(sp + in_i);
            if c == 10 or c == 13 {
                if c != 10 {
                    while in_i < datalen and __mem_load_i8(sp + in_i) != 10 {
                        in_i += 1;
                    }
                }
                if in_i < datalen {
                    in_i += 1;
                }
            } elif c == 61 {
                __mem_store_i8(dp + out_j, 61);
                out_j += 1;
                in_i += 1;
            } elif (
                in_i + 1 < datalen
                and _hexval(c) >= 0
                and _hexval(__mem_load_i8(sp + in_i + 1)) >= 0
            ) {
                __mem_store_i8(
                    dp + out_j,
                    (_hexval(c) << 4) | _hexval(__mem_load_i8(sp + in_i + 1))
                );
                out_j += 1;
                in_i += 2;
            } else {
                __mem_store_i8(dp + out_j, 61);
                out_j += 1;
            }
        } elif header and c == 95 {
            __mem_store_i8(dp + out_j, 32);
            out_j += 1;
            in_i += 1;
        } else {
            __mem_store_i8(dp + out_j, c);
            out_j += 1;
            in_i += 1;
        }
    }
    return bytes(out[0:out_j]);
}


def:pub b2a_qp(
    data: bytes, quotetabs: bool = False, istext: bool = True, header: bool = False
) -> bytes {
    datalen: int = len(data);
    sp: int = __bytes_data(data) if datalen > 0 else 0;
    crlf: bool = False;
    p: int = 0;
    while p < datalen {
        if __mem_load_i8(sp + p) == 10 {
            if p > 0 and __mem_load_i8(sp + p - 1) == 13 {
                crlf = True;
            }
            break;
        }
        p += 1;
    }
    out: bytearray = bytearray(6 * datalen + 8);
    dp: int = __bytearray_data(out);
    out_j: int = 0;
    linelen: int = 0;
    in_i: int = 0;
    while in_i < datalen {
        c: int = __mem_load_i8(sp + in_i);
        nxt: int = __mem_load_i8(sp + in_i + 1) if in_i + 1 < datalen else -1;
        needs_enc: bool = c > 126
            or c == 61
            or (header and c == 95)
            or (
                c == 46
                and linelen == 0
                and (in_i + 1 == datalen or nxt == 10 or nxt == 13 or nxt == 0)
            )
            or (not istext and (c == 13 or c == 10))
            or ((c == 9 or c == 32) and in_i + 1 == datalen)
            or (c < 33 and c != 13 and c != 10 and (quotetabs or (c != 9 and c != 32)));
        if needs_enc {
            if linelen + 3 >= 76 {
                __mem_store_i8(dp + out_j, 61);
                out_j += 1;
                if crlf {
                    __mem_store_i8(dp + out_j, 13);
                    out_j += 1;
                }
                __mem_store_i8(dp + out_j, 10);
                out_j += 1;
                linelen = 0;
            }
            __mem_store_i8(dp + out_j, 61);
            __mem_store_i8(dp + out_j + 1, _hexdig((c >> 4) & 15));
            __mem_store_i8(dp + out_j + 2, _hexdig(c & 15));
            out_j += 3;
            in_i += 1;
            linelen += 3;
        } else {
            at_lf: bool = c == 10 or (c == 13 and nxt == 10);
            if istext and at_lf {
                linelen = 0;
                if out_j > 0 {
                    prev: int = __mem_load_i8(dp + out_j - 1);
                    if prev == 32 or prev == 9 {
                        __mem_store_i8(dp + out_j - 1, 61);
                        __mem_store_i8(dp + out_j, _hexdig((prev >> 4) & 15));
                        __mem_store_i8(dp + out_j + 1, _hexdig(prev & 15));
                        out_j += 2;
                    }
                }
                if crlf {
                    __mem_store_i8(dp + out_j, 13);
                    out_j += 1;
                }
                __mem_store_i8(dp + out_j, 10);
                out_j += 1;
                if c == 13 {
                    in_i += 2;
                } else {
                    in_i += 1;
                }
            } else {
                if in_i + 1 != datalen and nxt != 10 and linelen + 1 >= 76 {
                    __mem_store_i8(dp + out_j, 61);
                    out_j += 1;
                    if crlf {
                        __mem_store_i8(dp + out_j, 13);
                        out_j += 1;
                    }
                    __mem_store_i8(dp + out_j, 10);
                    out_j += 1;
                    linelen = 0;
                }
                linelen += 1;
                if header and c == 32 {
                    __mem_store_i8(dp + out_j, 95);
                    out_j += 1;
                    in_i += 1;
                } else {
                    __mem_store_i8(dp + out_j, c);
                    out_j += 1;
                    in_i += 1;
                }
            }
        }
    }
    return bytes(out[0:out_j]);
}
