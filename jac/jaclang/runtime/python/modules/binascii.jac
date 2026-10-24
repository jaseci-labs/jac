def _binascii_error(message: str);

def _hex_digits -> str;

def _digit_value(c: int) -> int;

def _append_hex_pair(out: list[int], digits: str, b: int);

def _strhex_impl(data: list[int], sep: int, bytes_per_sep: int) -> list[int];

def _b64_alphabet -> str;

def _b64_value(raw: int) -> int;

def _b64_len1_error(nbytes_emitted: int);

def a2b_base64(data: list[int], strict_mode: bool = False) -> list[int];

glob _BASE64_MAXBIN: int = (9223372036854775807 - 3) // 2;

def b2a_base64(data: list[int], newline: bool = True) -> list[int];

def hexlify(data: list[int], sep: int = -1, bytes_per_sep: int = 1) -> list[int];

def b2a_hex(data: list[int], sep: int = -1, bytes_per_sep: int = 1) -> list[int];

def a2b_hex(hexstr: list[int]) -> list[int];

def unhexlify(hexstr: list[int]) -> list[int];

def a2b_uu(data: list[int]) -> list[int];

def b2a_uu(data: list[int], backtick: bool = False) -> list[int];

glob _QP_MAXLINESIZE: int = 76;

def _qp_hexdigit(v: int) -> int;

def a2b_qp(data: list[int], header: bool = False) -> list[int];

def _is_hex_digit(c: int) -> bool;

def _hex_val(c: int) -> int;

def b2a_qp(
    data: list[int], quotetabs: bool = False, istext: bool = True, header: bool = False
) -> list[int];

def _memchr(buf: list[int], v: int) -> int;

def _qp_needs_encode(
    buf: list[int],
    datalen: int,
    i: int,
    linelen: int,
    quotetabs: bool,
    istext: bool,
    header: bool
) -> bool;

def _crctab_hqx(i: int) -> int;

glob _CRC_HQX_TABLE: list[int] = [_crctab_hqx(i) for i in range(256)];

def crc_hqx(data: ptr[PyObject], crc: int) -> int;

def _crctab32(i: int) -> int;

glob _CRC32_TABLE: list[int] = [_crctab32(i) for i in range(256)];

def crc32_table(data: ptr[PyObject], crc: int = 0) -> int;

def:pub jacpy_binascii_convert(
    source: ptr[PyObject],
    error_type: ptr[PyObject],
    operation: i64,
    option: i64,
    second: i64,
    third: i64
) -> ptr[PyObject];

import from c { def crc32(crc: u64, buf: ptr, length: u32) -> u64;  }

glob:priv CRC_CHUNK: i64 = 0x40000000;

def:priv hex_buffer(source: ptr, length: i64) -> ptr[PyObject];

def:priv base64_buffer(source: ptr, length: i64, newline: bool) -> ptr[PyObject];

def convert_ascii_buffer_converter(
    value: ptr[PyObject], fname: str, label: str
) -> BufferArgument;

def:priv convert(
    module: ptr[PyObject],
    data: BufferArgument,
    operation: int,
    option: i64 = 0,
    second: i64 = 0,
    third: i64 = 0
) -> ptr[PyObject];

def binascii_a2b_uu_impl(module: ptr[PyObject], data: BufferArgument) -> ptr[PyObject];

def binascii_b2a_uu_impl(
    module: ptr[PyObject], data: BufferArgument, backtick: bool
) -> ptr[PyObject];

def binascii_a2b_base64_impl(
    module: ptr[PyObject], data: BufferArgument, strict_mode: bool
) -> ptr[PyObject];

def binascii_b2a_base64_impl(
    module: ptr[PyObject], data: BufferArgument, newline: bool
) -> ptr[PyObject];

def binascii_a2b_hex_impl(
    module: ptr[PyObject], hexstr: BufferArgument
) -> ptr[PyObject];

def binascii_unhexlify_impl(
    module: ptr[PyObject], hexstr: BufferArgument
) -> ptr[PyObject];

def:priv hex_with_separator(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject];

def binascii_b2a_hex_impl(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject];

def binascii_hexlify_impl(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject];

def binascii_a2b_qp_impl(
    module: ptr[PyObject], data: BufferArgument, header: bool
) -> ptr[PyObject];

def binascii_b2a_qp_impl(
    module: ptr[PyObject],
    data: BufferArgument,
    quotetabs: bool,
    istext: bool,
    header: bool
) -> ptr[PyObject];

def binascii_crc_hqx_impl(
    module: ptr[PyObject], data: BufferArgument, crc: u32
) -> ptr[PyObject];

def binascii_crc32_impl(module: ptr[PyObject], data: BufferArgument, crc: u32) -> u32;

impl _binascii_error(message: str) {
    raise module_failure(message=message);
}

impl _hex_digits -> str {
    return "0123456789abcdef";
}

impl _digit_value(c: int) -> int {
    if c >= 48 and c <= 57 {
        return c - 48;
    }
    if c >= 97 and c <= 102 {
        return c - 87;
    }
    if c >= 65 and c <= 70 {
        return c - 55;
    }
    return 16;
}

impl _append_hex_pair(out: list[int], digits: str, b: int) {
    out.append(ord(digits[b >> 4]));
    out.append(ord(digits[b & 0x0F]));
}

impl _strhex_impl(data: list[int], sep: int, bytes_per_sep: int) -> list[int] {
    buf = data;
    arglen = len(buf);
    digits = _hex_digits();
    sc = sep;
    bps = bytes_per_sep;
    if sc < 0 {
        bps = 0;
    }
    abps = bps if bps > 0 else -bps;
    if abps >= arglen {
        bps = 0;
        abps = 0;
    }
    out: list[int] = [];

    if bps == 0 {
        for i in range(arglen) {
            _append_hex_pair(out, digits, buf[i]);
        }
        return out;
    }
    chunks = 0 if arglen == 0 else (arglen - 1) // abps;
    if bps < 0 {
        i = 0;
        for _ in range(chunks) {
            for _ in range(abps) {
                _append_hex_pair(out, digits, buf[i]);
                i += 1;
            }
            out.append(sc);
        }
        while i < arglen {
            _append_hex_pair(out, digits, buf[i]);
            i += 1;
        }
    } else {
        total = arglen * 2 + chunks;
        j = total - 1;
        i = arglen - 1;
        while j >= 0 {
            out.append(0);
            j -= 1;
        }
        j = total - 1;
        for _ in range(chunks) {
            for _ in range(abps) {
                b = buf[i];
                out[j] = ord(digits[b & 0x0F]);
                out[j - 1] = ord(digits[b >> 4]);
                j -= 2;
                i -= 1;
            }
            out[j] = sc;
            j -= 1;
        }
        while i >= 0 {
            b = buf[i];
            out[j] = ord(digits[b & 0x0F]);
            out[j - 1] = ord(digits[b >> 4]);
            j -= 2;
            i -= 1;
        }
    }
    return out;
}

impl _b64_alphabet -> str {
    return "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
}

impl _b64_value(raw: int) -> int {
    o = raw;
    if o >= 65 and o <= 90 {
        return o - 65;
    }
    if o >= 97 and o <= 122 {
        return o - 71;
    }
    if o >= 48 and o <= 57 {
        return o + 4;
    }
    if o == 43 {
        return 62;
    }
    if o == 47 {
        return 63;
    }
    return 255;
}

impl _b64_len1_error(nbytes_emitted: int) {
    _binascii_error(
        "Invalid base64-encoded string: number of data characters ("
            + str(nbytes_emitted // 3 * 4 + 1)
            + ") cannot be 1 more than a multiple of 4"
    );
}

impl a2b_base64(data: list[int], strict_mode: bool = False) -> list[int] {
    buf = data;
    ascii_len = len(buf);
    out: list[int] = [];
    quad_pos = 0;
    leftchar = 0;
    pads = 0;

    i = 0;
    while i < ascii_len {
        raw = buf[i];
        stop = False;
        if raw == 61 {
            pads += 1;
            if quad_pos >= 2 and quad_pos + pads <= 4 {
                i += 1;
                continue;
            }

            if not strict_mode {
                i += 1;
                continue;
            }
            if quad_pos == 1 {
                stop = True;
            } else {
                _binascii_error(
                    "Leading padding not allowed"
                        if (quad_pos == 0 and i == 0)
                        else "Excess padding not allowed"
                );
            }
        } else {
            this_ch = _b64_value(raw);
            if this_ch >= 64 {
                if strict_mode {
                    _binascii_error("Only base64 data is allowed");
                }
                i += 1;
                continue;
            }
            if pads > 0 and strict_mode {
                _binascii_error(
                    "Excess data after padding"
                        if quad_pos + pads == 4
                        else "Discontinuous padding not allowed"
                );
            }
            pads = 0;
            if quad_pos == 0 {
                quad_pos = 1;
                leftchar = this_ch;
            } elif quad_pos == 1 {
                quad_pos = 2;
                out.append(((leftchar << 2) | (this_ch >> 4)) & 0xFF);
                leftchar = this_ch & 0x0F;
            } elif quad_pos == 2 {
                quad_pos = 3;
                out.append(((leftchar << 4) | (this_ch >> 2)) & 0xFF);
                leftchar = this_ch & 0x03;
            } else {
                quad_pos = 0;
                out.append(((leftchar << 6) | this_ch) & 0xFF);
                leftchar = 0;
            }
        }
        if stop {
            break;
        }
        i += 1;
    }

    if quad_pos == 1 {
        _b64_len1_error(len(out));
    }
    if quad_pos != 0 and quad_pos + pads < 4 {
        _binascii_error("Incorrect padding");
    }
    return out;
}

impl b2a_base64(data: list[int], newline: bool = True) -> list[int] {
    buf = data;
    bin_len = len(buf);
    if bin_len > _BASE64_MAXBIN {
        _binascii_error("Too much data for base64 line");
    }
    table = _b64_alphabet();
    out: list[int] = [];
    leftchar = 0;
    leftbits = 0;
    for k in range(bin_len) {
        leftchar = ((leftchar << 8) | buf[k]) & 0xFFFFFFFF;
        leftbits += 8;
        while leftbits >= 6 {
            this_ch = (leftchar >> (leftbits - 6)) & 0x3F;
            leftbits -= 6;
            out.append(ord(table[this_ch]));
        }
    }
    if leftbits == 2 {
        out.append(ord(table[(leftchar & 3) << 4]));
        out.append(61);
        out.append(61);
    } elif leftbits == 4 {
        out.append(ord(table[(leftchar & 0x0F) << 2]));
        out.append(61);
    }
    if newline {
        out.append(10);
    }
    return out;
}

impl hexlify(data: list[int], sep: int = -1, bytes_per_sep: int = 1) -> list[int] {
    return _strhex_impl(data, sep, bytes_per_sep);
}

impl b2a_hex(data: list[int], sep: int = -1, bytes_per_sep: int = 1) -> list[int] {
    return _strhex_impl(data, sep, bytes_per_sep);
}

impl a2b_hex(hexstr: list[int]) -> list[int] {
    buf = hexstr;
    arglen = len(buf);
    if arglen % 2 {
        _binascii_error("Odd-length string");
    }
    out: list[int] = [];
    i = 0;
    while i < arglen {
        top = _digit_value(buf[i]);
        bot = _digit_value(buf[i + 1]);
        if top >= 16 or bot >= 16 {
            _binascii_error("Non-hexadecimal digit found");
        }
        out.append(((top << 4) + bot) & 0xFF);
        i += 2;
    }
    return out;
}

impl unhexlify(hexstr: list[int]) -> list[int] {
    return a2b_hex(hexstr);
}

impl a2b_uu(data: list[int]) -> list[int] {
    buf = data;
    ascii_len = len(buf);
    if ascii_len == 0 {
        _binascii_error("Missing length byte");
    }

    bin_len = (buf[0] - 32) % 64;
    if bin_len < 0 {
        bin_len += 64;
    }
    out: list[int] = [];
    leftchar = 0;
    leftbits = 0;
    i = 1;
    while bin_len > 0 {
        this_ch = buf[i] if i < ascii_len else 0;
        if this_ch == 10 or this_ch == 13 or i >= ascii_len {
            this_ch = 0;
        } elif this_ch < 32 or this_ch > 96 {
            _binascii_error("Illegal char");
        } else {
            this_ch = (this_ch - 32) % 64;
        }
        leftchar = ((leftchar << 6) | this_ch) & 0xFFFF;
        leftbits += 6;
        if leftbits >= 8 {
            leftbits -= 8;
            out.append((leftchar >> leftbits) & 0xFF);
            leftchar &= (1 << leftbits) - 1;
            bin_len -= 1;
        }
        i += 1;
    }

    j = i;
    while j < ascii_len {
        ch = buf[j];
        if ch != 32 and ch != 96 and ch != 10 and ch != 13 {
            _binascii_error("Trailing garbage");
        }
        j += 1;
    }
    return out;
}

impl b2a_uu(data: list[int], backtick: bool = False) -> list[int] {
    buf = data;
    bin_len = len(buf);
    if bin_len > 45 {
        _binascii_error("At most 45 bytes at once");
    }
    out: list[int] = [];

    if backtick and not bin_len {
        out.append(96);
    } else {
        out.append(32 + bin_len);
    }
    leftchar = 0;
    leftbits = 0;
    k = 0;
    while bin_len > 0 or leftbits != 0 {
        if bin_len > 0 {
            leftchar = (leftchar << 8) | buf[k];
        } else {
            leftchar <<= 8;
        }
        leftbits += 8;
        while leftbits >= 6 {
            this_ch = (leftchar >> (leftbits - 6)) & 0x3F;
            leftbits -= 6;
            if backtick and not this_ch {
                out.append(96);
            } else {
                out.append(this_ch + 32);
            }
        }
        bin_len -= 1;
        k += 1;
    }
    out.append(10);
    return out;
}

impl _qp_hexdigit(v: int) -> int {
    digits = "0123456789ABCDEF";
    return ord(digits[v]);
}

impl a2b_qp(data: list[int], header: bool = False) -> list[int] {
    buf = data;
    datalen = len(buf);
    out: list[int] = [];
    i = 0;
    while i < datalen {
        if buf[i] == 61 {
            i += 1;
            if i >= datalen {
                break;
            }
            if buf[i] == 10 or buf[i] == 13 {
                if buf[i] != 10 {
                    while i < datalen and buf[i] != 10 {
                        i += 1;
                    }
                }
                if i < datalen {
                    i += 1;
                }
            } elif buf[i] == 61 {
                out.append(61);
                i += 1;
            } elif (
                i + 1 < datalen and _is_hex_digit(buf[i]) and _is_hex_digit(buf[i + 1])
            ) {
                out.append(((_hex_val(buf[i]) << 4) + _hex_val(buf[i + 1])) & 0xFF);
                i += 2;
            } else {
                out.append(61);
            }
        } elif header and buf[i] == 95 {
            out.append(32);
            i += 1;
        } else {
            out.append(buf[i]);
            i += 1;
        }
    }
    return out;
}

impl _is_hex_digit(c: int) -> bool {
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102);
}

impl _hex_val(c: int) -> int {
    if c <= 57 {
        return c - 48;
    }
    if c <= 70 {
        return c - 55;
    }
    return c - 87;
}

impl b2a_qp(
    data: list[int], quotetabs: bool = False, istext: bool = True, header: bool = False
) -> list[int] {
    buf = data;
    datalen = len(buf);

    crlf = False;
    nl = _memchr(buf, 10);
    if nl > 0 and buf[nl - 1] == 13 {
        crlf = True;
    }

    odatalen = 0;
    linelen = 0;
    i = 0;
    while i < datalen {
        delta = 0;
        if _qp_needs_encode(buf, datalen, i, linelen, quotetabs, istext, header) {
            if linelen + 3 >= _QP_MAXLINESIZE {
                linelen = 0;
                delta += 3 if crlf else 2;
            }
            linelen += 3;
            delta += 3;
            i += 1;
        } elif istext
            and (
                buf[i] == 10 or (i + 1 < datalen and buf[i] == 13 and buf[i + 1] == 10)
            ) {
            linelen = 0;
            if i > 0 and (buf[i - 1] == 32 or buf[i - 1] == 9) {
                delta += 2;
            }
            delta += 2 if crlf else 1;
            if buf[i] == 13 {
                i += 2;
            } else {
                i += 1;
            }
        } else {
            if i + 1 != datalen
                and buf[i + 1] != 10
                and linelen + 1 >= _QP_MAXLINESIZE {
                linelen = 0;
                delta += 3 if crlf else 2;
            }
            linelen += 1;
            delta += 1;
            i += 1;
        }
        odatalen += delta;
    }

    out: list[int] = [0] * odatalen;
    o = 0;
    linelen = 0;
    i = 0;
    while i < datalen {
        ch = buf[i];
        if _qp_needs_encode(buf, datalen, i, linelen, quotetabs, istext, header) {
            if linelen + 3 >= _QP_MAXLINESIZE {
                out[o] = 61;
                o += 1;
                if crlf {
                    out[o] = 13;
                    o += 1;
                }
                out[o] = 10;
                o += 1;
                linelen = 0;
            }
            out[o] = 61;
            out[o + 1] = _qp_hexdigit(ch // 16);
            out[o + 2] = _qp_hexdigit(ch % 16);
            o += 3;
            i += 1;
            linelen += 3;
        } elif istext
            and (ch == 10 or (i + 1 < datalen and ch == 13 and buf[i + 1] == 10)) {
            linelen = 0;
            if o > 0 and (out[o - 1] == 32 or out[o - 1] == 9) {
                prev = out[o - 1];
                out[o - 1] = 61;
                out[o] = _qp_hexdigit(prev // 16);
                out[o + 1] = _qp_hexdigit(prev % 16);
                o += 2;
            }
            if crlf {
                out[o] = 13;
                o += 1;
            }
            out[o] = 10;
            o += 1;
            if ch == 13 {
                i += 2;
            } else {
                i += 1;
            }
        } else {
            if i + 1 != datalen
                and buf[i + 1] != 10
                and linelen + 1 >= _QP_MAXLINESIZE {
                out[o] = 61;
                o += 1;
                if crlf {
                    out[o] = 13;
                    o += 1;
                }
                out[o] = 10;
                o += 1;
                linelen = 0;
            }
            linelen += 1;
            if header and ch == 32 {
                out[o] = 95;
                o += 1;
            } else {
                out[o] = ch;
                o += 1;
            }
            i += 1;
        }
    }
    return out[:o];
}

impl _memchr(buf: list[int], v: int) -> int {
    for k in range(len(buf)) {
        if buf[k] == v {
            return k;
        }
    }
    return -1;
}

impl _qp_needs_encode(
    buf: list[int],
    datalen: int,
    i: int,
    linelen: int,
    quotetabs: bool,
    istext: bool,
    header: bool
) -> bool {
    c = buf[i];
    if c > 126 {
        return True;
    }
    if c == 61 {
        return True;
    }
    if header and c == 95 {
        return True;
    }
    if c == 46
        and linelen == 0
        and (
            i + 1 == datalen or buf[i + 1] == 10 or buf[i + 1] == 13 or buf[i + 1] == 0
        ) {
        return True;
    }
    if not istext and (c == 13 or c == 10) {
        return True;
    }
    if (c == 9 or c == 32) and i + 1 == datalen {
        return True;
    }
    if c < 33 and c != 13 and c != 10 and (quotetabs or (c != 9 and c != 32)) {
        return True;
    }
    return False;
}

impl _crctab_hqx(i: int) -> int {
    v = i << 8;
    for _ in range(8) {
        if v & 0x8000 {
            v = ((v << 1) ^ 0x1021) & 0xFFFF;
        } else {
            v = (v << 1) & 0xFFFF;
        }
    }
    return v;
}

impl crc_hqx(data: ptr[PyObject], crc: int) -> int {
    c = crc & 0xFFFF;
    for k in range(int(jacpy_buffer_size(data))) {
        byte = int(jacpy_buffer_byte(data, i64(k)));
        c = ((c << 8) & 0xFF00) ^ _CRC_HQX_TABLE[(c >> 8) ^ byte];
    }
    return c;
}

impl _crctab32(i: int) -> int {
    v = i;
    for _ in range(8) {
        if v & 1 {
            v = (v >> 1) ^ 0xEDB88320;
        } else {
            v >>= 1;
        }
    }
    return v & 0xFFFFFFFF;
}

impl crc32_table(data: ptr[PyObject], crc: int = 0) -> int {
    c = (~crc) & 0xFFFFFFFF;
    for k in range(int(jacpy_buffer_size(data))) {
        byte = int(jacpy_buffer_byte(data, i64(k)));
        c = (_CRC32_TABLE[(c ^ byte) & 0xFF] ^ (c >> 8)) & 0xFFFFFFFF;
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

impl jacpy_binascii_convert(
    source: ptr[PyObject],
    error_type: ptr[PyObject],
    operation: i64,
    option: i64,
    second: i64,
    third: i64
) -> ptr[PyObject] {
    try {
        if operation == 8 {
            return PyLong_FromLongLong(i64(crc_hqx(source, int(option))));
        }
        if operation == 9 {
            return PyLong_FromLongLong(i64(crc32_table(source, int(option))));
        }
        data = list(read_buffer(source));
        result: list[int] = [];
        if operation == 0 {
            result = a2b_uu(data);
        } elif operation == 1 {
            result = b2a_uu(data, option != 0);
        } elif operation == 2 {
            result = a2b_base64(data, option != 0);
        } elif operation == 3 {
            result = b2a_base64(data, option != 0);
        } elif operation == 4 {
            result = a2b_hex(data);
        } elif operation == 5 {
            result = hexlify(data, int(option), int(second));
        } elif operation == 6 {
            result = a2b_qp(data, option != 0);
        } elif operation == 7 {
            result = b2a_qp(data, option != 0, second != 0, third != 0);
        } else {
            object_error(PyExc_SystemError, "unknown binary codec operation");
            return NULL;
        }
        return write_buffer(bytes(result));
    } except module_failure as error {
        message = error.message;
        jacpy_set_exception(error_type, message, i64(len(message.encode("utf-8"))));
        return NULL;
    }
}

impl hex_buffer(source: ptr, length: i64) -> ptr[PyObject] {
    if length > 0x3FFFFFFFFFFFFFFF {
        return PyErr_NoMemory();
    }
    result = PyBytes_FromStringAndSize(ptr[u8](), length * 2);
    if not result {
        return NULL;
    }
    src = ptr[u8](int(source));
    dst = PyBytes_AsString(result);
    digits = ptr[u8]("0123456789abcdef");
    i: i64 = 0;
    while i < length {
        byte = (src + i).view(1)[0];
        (dst + 2 * i).view(1)[0] = (digits + i64(byte >> 4)).view(1)[0];
        (dst + 2 * i + 1).view(1)[0] = (digits + i64(byte & u8(0x0F))).view(1)[0];
        i += 1;
    }
    return result;
}

impl base64_buffer(source: ptr, length: i64, newline: bool) -> ptr[PyObject] {
    size = ((length + 2) // 3) * 4 + (1 if newline else 0);
    result = PyBytes_FromStringAndSize(ptr[u8](), size);
    if not result {
        return NULL;
    }
    src = ptr[u8](int(source));
    dst = PyBytes_AsString(result);
    table = ptr[u8]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
    i: i64 = 0;
    o: i64 = 0;
    while i + 2 < length {
        b0 = i64((src + i).view(1)[0]);
        b1 = i64((src + i + 1).view(1)[0]);
        b2 = i64((src + i + 2).view(1)[0]);
        (dst + o).view(1)[0] = (table + (b0 >> 2)).view(1)[0];
        (dst + o + 1).view(1)[0] = (table + (((b0 & 3) << 4) | (b1 >> 4))).view(1)[0];
        (dst + o + 2).view(1)[0] = (table + (((b1 & 15) << 2) | (b2 >> 6))).view(1)[0];
        (dst + o + 3).view(1)[0] = (table + (b2 & 63)).view(1)[0];
        i += 3;
        o += 4;
    }
    left = length - i;
    if left > 0 {
        b0 = i64((src + i).view(1)[0]);
        b1 = i64((src + i + 1).view(1)[0]) if left == 2 else i64(0);
        (dst + o).view(1)[0] = (table + (b0 >> 2)).view(1)[0];
        (dst + o + 1).view(1)[0] = (table + (((b0 & 3) << 4) | (b1 >> 4))).view(1)[0];
        (dst + o + 2).view(1)[0] = (table + ((b1 & 15) << 2)).view(1)[0]
            if left == 2
            else u8(61);
        (dst + o + 3).view(1)[0] = u8(61);
        o += 4;
    }
    if newline {
        (dst + o).view(1)[0] = u8(10);
    }
    return result;
}

impl convert_ascii_buffer_converter(
    value: ptr[PyObject], fname: str, label: str
) -> BufferArgument {
    view = BufferArgument();
    if not view.acquire(value, True) {
        raise boundary_failure();
    }
    return view;
}

impl convert(
    module: ptr[PyObject],
    data: BufferArgument,
    operation: int,
    option: i64 = 0,
    second: i64 = 0,
    third: i64 = 0
) -> ptr[PyObject] {
    source = data.bytes();
    if source == 0 {
        return NULL;
    }
    result = jacpy_binascii_convert(
        source,
        jacpy_binding_state_get(module, 0),
        i64(operation),
        option,
        second,
        third
    );
    jacpy_release(source);
    return result;
}

impl binascii_a2b_uu_impl(
    module: ptr[PyObject], data: BufferArgument
) -> ptr[PyObject] {
    return convert(module, data, 0);
}

impl binascii_b2a_uu_impl(
    module: ptr[PyObject], data: BufferArgument, backtick: bool
) -> ptr[PyObject] {
    return convert(module, data, 1, i64(backtick));
}

impl binascii_a2b_base64_impl(
    module: ptr[PyObject], data: BufferArgument, strict_mode: bool
) -> ptr[PyObject] {
    return convert(module, data, 2, i64(strict_mode));
}

impl binascii_b2a_base64_impl(
    module: ptr[PyObject], data: BufferArgument, newline: bool
) -> ptr[PyObject] {
    if data.size() > _BASE64_MAXBIN {
        return convert(module, data, 3, i64(newline));
    }
    return base64_buffer(data.address(), data.size(), newline);
}

impl binascii_a2b_hex_impl(
    module: ptr[PyObject], hexstr: BufferArgument
) -> ptr[PyObject] {
    return convert(module, hexstr, 4);
}

impl binascii_unhexlify_impl(
    module: ptr[PyObject], hexstr: BufferArgument
) -> ptr[PyObject] {
    return convert(module, hexstr, 4);
}

impl hex_with_separator(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject] {
    option: i64 = -1;
    if sep != 0 {
        size = PySequence_Size(sep);
        if size < 0 {
            return NULL;
        }
        if size != 1 {
            object_error(PyExc_ValueError, "sep must be length 1.");
            return NULL;
        }
        if jacpy_is_unicode(sep) != 0 {
            option = PyUnicode_ReadChar(sep, 0);
            if option > 255 {
                object_error(PyExc_ValueError, "sep must be ASCII.");
                return NULL;
            }
        } elif jacpy_is_bytes(sep) != 0 {
            option = jacpy_buffer_byte(sep, 0);
        } else {
            object_error(PyExc_TypeError, "sep must be str or bytes.");
            return NULL;
        }
    }
    if option < 0 {
        return hex_buffer(data.address(), data.size());
    }
    return convert(module, data, 5, option, i64(bytes_per_sep));
}

impl binascii_b2a_hex_impl(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject] {
    return hex_with_separator(module, data, sep, bytes_per_sep);
}

impl binascii_hexlify_impl(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject] {
    return hex_with_separator(module, data, sep, bytes_per_sep);
}

impl binascii_a2b_qp_impl(
    module: ptr[PyObject], data: BufferArgument, header: bool
) -> ptr[PyObject] {
    return convert(module, data, 6, i64(header));
}

impl binascii_b2a_qp_impl(
    module: ptr[PyObject],
    data: BufferArgument,
    quotetabs: bool,
    istext: bool,
    header: bool
) -> ptr[PyObject] {
    return convert(module, data, 7, i64(quotetabs), i64(istext), i64(header));
}

impl binascii_crc_hqx_impl(
    module: ptr[PyObject], data: BufferArgument, crc: u32
) -> ptr[PyObject] {
    return convert(module, data, 8, i64(crc));
}

impl binascii_crc32_impl(module: ptr[PyObject], data: BufferArgument, crc: u32) -> u32 {
    checksum = u64(crc);
    position = data.address();
    remains = data.size();
    while remains > CRC_CHUNK {
        checksum = crc32(checksum, position, u32(CRC_CHUNK));
        position += CRC_CHUNK;
        remains -= CRC_CHUNK;
    }
    checksum = crc32(checksum, position, u32(remains));
    return u32(checksum & u64(0xFFFFFFFF));
}
