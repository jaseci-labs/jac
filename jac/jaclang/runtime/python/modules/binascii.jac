"""Native binary/text codecs and checksums derived from CPython 3.14.6.

The algorithm kernels use typed native buffers. Python buffer validation,
argument binding, and module exception identities remain at the object ABI.
See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    read_buffer,
    write_buffer,
    jacpy_set_exception,
    jacpy_int,
    module_failure,
    jacpy_buffer_size,
    jacpy_buffer_byte,
    object_error
}

def _binascii_error(message: str) {
    raise module_failure(message=message);
}

def _hex_digits -> str {
    return "0123456789abcdef";
}

# Digit valuation mirroring _PyLong_DigitValue: 0..15 for hex digits,
# >= 16 otherwise.
def _digit_value(c: int) -> int {
    if c >= 48 and c <= 57 {  # '0'..'9'
        return c - 48;
    }
    if c >= 97 and c <= 102 {  # 'a'..'f'
        return c - 87;
    }
    if c >= 65 and c <= 70 {  # 'A'..'F'
        return c - 55;
    }
    return 16;
}

def _append_hex_pair(out: list[int], digits: str, b: int) {
    out.append(ord(digits[b >> 4]));
    out.append(ord(digits[b & 0x0F]));
}

# Shared body of b2a_hex/hexlify (_Py_strhex_bytes_with_sep).
def _strhex_impl(data: list[int], sep: int, bytes_per_sep: int) -> list[int] {
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
        # C disables grouping when abs(bytes_per_sep) >= arglen.
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
        # Separators count from the left.
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
        # Separators count from the right: fill the output backwards.
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


# ---------------------------------------------------------------------------
# base64: a2b_base64/b2a_base64
#
# Decode mirrors the RFC 3548/4648 strict-mode state machine of
# binascii_a2b_base64_impl verbatim; encode mirrors b2a_base64_impl's
# 6-bit drain plus partial-group tail.
#

def _b64_alphabet -> str {
    return "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
}

# table_a2b_base64 semantics: value 0..63 for alphabet characters, 255
# (unsigned-char wrap of -1) for anything else.
def _b64_value(raw: int) -> int {
    o = raw;
    if o >= 65 and o <= 90 {  # 'A'..'Z' -> 0..25
        return o - 65;
    }
    if o >= 97 and o <= 122 {  # 'a'..'z' -> 26..51
        return o - 71;
    }
    if o >= 48 and o <= 57 {  # '0'..'9' -> 52..61
        return o + 4;
    }
    if o == 43 {  # '+' -> 62
        return 62;
    }
    if o == 47 {  # '/' -> 63
        return 63;
    }
    return 255;
}

# ---------------------------------------------------------------------------
# uuencode: a2b_uu/b2a_uu
#

def _b64_len1_error(nbytes_emitted: int) {
    _binascii_error(
        "Invalid base64-encoded string: number of data characters ("
            + str(nbytes_emitted // 3 * 4 + 1)
            + ") cannot be 1 more than a multiple of 4"
    );
}

def a2b_base64(data: list[int], strict_mode: bool = False) -> list[int] {
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
        if raw == 61 {  # '=' (BASE64_PAD)
            pads += 1;
            if quad_pos >= 2 and quad_pos + pads <= 4 {
                i += 1;
                continue;  # valid trailing pad
            }
            # RFC 4648 section 3.3: excess pad MAY be ignored.
            if not strict_mode {
                i += 1;
                continue;
            }
            if quad_pos == 1 {
                # C breaks here; the final validation reports the error.
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
                continue;  # ignore non-alphabet byte
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

# BASE64_MAXBIN: ((PY_SSIZE_T_MAX - 3) / 2) on LP64.
glob _BASE64_MAXBIN: int = (9223372036854775807 - 3) // 2;

def b2a_base64(data: list[int], newline: bool = True) -> list[int] {
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
        out.append(61);  # '='
        out.append(61);
    } elif leftbits == 4 {
        out.append(ord(table[(leftchar & 0x0F) << 2]));
        out.append(61);
    }
    if newline {
        out.append(10);  # courtesy newline
    }
    return out;
}


def hexlify(data: list[int], sep: int = -1, bytes_per_sep: int = 1) -> list[int] {
    return _strhex_impl(data, sep, bytes_per_sep);
}

def b2a_hex(data: list[int], sep: int = -1, bytes_per_sep: int = 1) -> list[int] {
    return _strhex_impl(data, sep, bytes_per_sep);
}

def a2b_hex(hexstr: list[int]) -> list[int] {
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

def unhexlify(hexstr: list[int]) -> list[int] {
    return a2b_hex(hexstr);
}


# ---------------------------------------------------------------------------
# uuencode: a2b_uu/b2a_uu
#

def a2b_uu(data: list[int]) -> list[int] {
    buf = data;
    ascii_len = len(buf);
    if ascii_len == 0 {
        _binascii_error("Missing length byte");
    }
    # First byte: binary data length (in bytes). C's unsigned-char
    # arithmetic makes negative differences wrap within & 077.
    bin_len = (buf[0] - 32) % 64;
    if bin_len < 0 {
        bin_len += 64;
    }
    out: list[int] = [];
    leftchar = 0;
    leftbits = 0;
    i = 1;  # ascii_data cursor (after length byte)
    while bin_len > 0 {
        this_ch = buf[i] if i < ascii_len else 0;
        if this_ch == 10 or this_ch == 13 or i >= ascii_len {
            # Whitespace: some spaces got eaten at end-of-line.
            this_ch = 0;
        } elif this_ch < 32 or this_ch > 96 {  # ' ' .. ' '+64
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
    # Trailing bytes must be whitespace-only (' ' or '`' padding, CR/LF).
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

def b2a_uu(data: list[int], backtick: bool = False) -> list[int] {
    buf = data;
    bin_len = len(buf);
    if bin_len > 45 {
        # The 45 is a limit that appears in all uuencodes.
        _binascii_error("At most 45 bytes at once");
    }
    out: list[int] = [];
    # Length byte ('`' encodes empty data in backtick mode).
    if backtick and not bin_len {
        out.append(96);  # '`'
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
            leftchar <<= 8;  # padding
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
    out.append(10);  # courtesy newline
    return out;
}


# ---------------------------------------------------------------------------
# quoted-printable: a2b_qp/b2a_qp
#

glob _QP_MAXLINESIZE: int = 76;

def _qp_hexdigit(v: int) -> int {
    digits = "0123456789ABCDEF";
    return ord(digits[v]);
}

def a2b_qp(data: list[int], header: bool = False) -> list[int] {
    buf = data;
    datalen = len(buf);
    out: list[int] = [];
    i = 0;
    while i < datalen {
        if buf[i] == 61 {  # '='
            i += 1;
            if i >= datalen {
                break;
            }
            if buf[i] == 10 or buf[i] == 13 {  # soft line break
                if buf[i] != 10 {
                    while i < datalen and buf[i] != 10 {
                        i += 1;
                    }
                }
                if i < datalen {
                    i += 1;
                }
            } elif buf[i] == 61 {  # broken case from broken python qp
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
        } elif header and buf[i] == 95 {  # '_' -> ' '
            out.append(32);
            i += 1;
        } else {
            out.append(buf[i]);
            i += 1;
        }
    }
    return out;
}

def _is_hex_digit(c: int) -> bool {
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102);
}

def _hex_val(c: int) -> int {
    if c <= 57 {
        return c - 48;
    }
    if c <= 70 {
        return c - 55;
    }
    return c - 87;
}

def b2a_qp(
    data: list[int], quotetabs: bool = False, istext: bool = True, header: bool = False
) -> list[int] {
    buf = data;
    datalen = len(buf);

    # CRLF detection: a '\n' whose predecessor is '\r'.
    crlf = False;
    nl = _memchr(buf, 10);
    if nl > 0 and buf[nl - 1] == 13 {
        crlf = True;
    }

    # Sizing pass (verbatim predicates/order from binascii_b2a_qp_impl).
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
            # Protect against whitespace on end of line.
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
                out[o] = 95;  # '_' encodes space in header mode
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

# First index of byte `v` in buf, or -1. (memchr stand-in)
def _memchr(buf: list[int], v: int) -> int {
    for k in range(len(buf)) {
        if buf[k] == v {
            return k;
        }
    }
    return -1;
}

# Shared need-encode predicate of both b2a_qp passes; order matches the C
# disjunction exactly so boundary behavior stays identical.
def _qp_needs_encode(
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
    if c == 61 {  # '='
        return True;
    }
    if header and c == 95 {  # '_'
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


# ---------------------------------------------------------------------------
# CRC: crc_hqx/crc32
#

# CRC-CCITT table (crctab_hqx in Modules/binascii.c).
def _crctab_hqx(i: int) -> int {
    # Generated per-entry to avoid a 256-literal glob; polynomial 0x1021,
    # MSB-first -- identical values to the C table.
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

glob _CRC_HQX_TABLE: list[int] = [_crctab_hqx(i) for i in range(256)];

def crc_hqx(data: u64, crc: int) -> int {
    c = crc & 0xFFFF;
    for k in range(int(jacpy_buffer_size(data))) {
        byte = int(jacpy_buffer_byte(data, i64(k)));
        c = ((c << 8) & 0xFF00) ^ _CRC_HQX_TABLE[(c >> 8) ^ byte];
    }
    return c;
}

# CRC-32 table walk (internal_crc32 / crc_32_tab). Entry i is the CRC of
# byte i starting from ~0; generated per-entry with polynomial 0xEDB88320.
def _crctab32(i: int) -> int {
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

glob _CRC32_TABLE: list[int] = [_crctab32(i) for i in range(256)];

def crc32(data: u64, crc: int = 0) -> int {
    # unsigned_int(bitwise=True) converter: mask like the C unsigned int.
    c = (~crc) & 0xFFFFFFFF;
    for k in range(int(jacpy_buffer_size(data))) {
        byte = int(jacpy_buffer_byte(data, i64(k)));
        c = (_CRC32_TABLE[(c ^ byte) & 0xFF] ^ (c >> 8)) & 0xFFFFFFFF;
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}


def:pub jacpy_binascii_convert(
    source: u64, error_type: u64, operation: i64, option: i64, second: i64, third: i64
) -> u64 {
    try {
        if operation == 8 {
            return jacpy_int(i64(crc_hqx(source, int(option))));
        }
        if operation == 9 {
            return jacpy_int(i64(crc32(source, int(option))));
        }
        data = read_buffer(source);
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
            object_error("SystemError", "unknown binary codec operation");
            return 0;
        }
        return write_buffer(result);
    } except module_failure as error {
        message = error.message;
        jacpy_set_exception(error_type, message, i64(len(message.encode("utf-8"))));
        return 0;
    }
}
