import from c {
    def crc32(crc: u64, buf: ptr, length: u32) -> u64;  def memchr(
        source: ptr, value: i32, n: u64
    ) -> ptr;  def _Py_strhex_bytes_with_sep(
        argbuf: ptr[u8], arglen: i64, sep: ptr[PyObject], bytes_per_group: i32
    ) -> ptr[PyObject];  glob:priv table_a2b_base64: list[u8] = [
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(62),
             u8(255),
             u8(255),
             u8(255),
             u8(63),
             u8(52),
             u8(53),
             u8(54),
             u8(55),
             u8(56),
             u8(57),
             u8(58),
             u8(59),
             u8(60),
             u8(61),
             u8(255),
             u8(255),
             u8(255),
             u8(0),
             u8(255),
             u8(255),
             u8(255),
             u8(0),
             u8(1),
             u8(2),
             u8(3),
             u8(4),
             u8(5),
             u8(6),
             u8(7),
             u8(8),
             u8(9),
             u8(10),
             u8(11),
             u8(12),
             u8(13),
             u8(14),
             u8(15),
             u8(16),
             u8(17),
             u8(18),
             u8(19),
             u8(20),
             u8(21),
             u8(22),
             u8(23),
             u8(24),
             u8(25),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(26),
             u8(27),
             u8(28),
             u8(29),
             u8(30),
             u8(31),
             u8(32),
             u8(33),
             u8(34),
             u8(35),
             u8(36),
             u8(37),
             u8(38),
             u8(39),
             u8(40),
             u8(41),
             u8(42),
             u8(43),
             u8(44),
             u8(45),
             u8(46),
             u8(47),
             u8(48),
             u8(49),
             u8(50),
             u8(51),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255),
             u8(255)
         ]; glob:priv digit_values: list[u8] = [
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(0),
             u8(1),
             u8(2),
             u8(3),
             u8(4),
             u8(5),
             u8(6),
             u8(7),
             u8(8),
             u8(9),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(10),
             u8(11),
             u8(12),
             u8(13),
             u8(14),
             u8(15),
             u8(16),
             u8(17),
             u8(18),
             u8(19),
             u8(20),
             u8(21),
             u8(22),
             u8(23),
             u8(24),
             u8(25),
             u8(26),
             u8(27),
             u8(28),
             u8(29),
             u8(30),
             u8(31),
             u8(32),
             u8(33),
             u8(34),
             u8(35),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(10),
             u8(11),
             u8(12),
             u8(13),
             u8(14),
             u8(15),
             u8(16),
             u8(17),
             u8(18),
             u8(19),
             u8(20),
             u8(21),
             u8(22),
             u8(23),
             u8(24),
             u8(25),
             u8(26),
             u8(27),
             u8(28),
             u8(29),
             u8(30),
             u8(31),
             u8(32),
             u8(33),
             u8(34),
             u8(35),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37)
         ]; glob:priv crctab_hqx: list[u16] = [
             u16(0x0000),
             u16(0x1021),
             u16(0x2042),
             u16(0x3063),
             u16(0x4084),
             u16(0x50A5),
             u16(0x60C6),
             u16(0x70E7),
             u16(0x8108),
             u16(0x9129),
             u16(0xA14A),
             u16(0xB16B),
             u16(0xC18C),
             u16(0xD1AD),
             u16(0xE1CE),
             u16(0xF1EF),
             u16(0x1231),
             u16(0x0210),
             u16(0x3273),
             u16(0x2252),
             u16(0x52B5),
             u16(0x4294),
             u16(0x72F7),
             u16(0x62D6),
             u16(0x9339),
             u16(0x8318),
             u16(0xB37B),
             u16(0xA35A),
             u16(0xD3BD),
             u16(0xC39C),
             u16(0xF3FF),
             u16(0xE3DE),
             u16(0x2462),
             u16(0x3443),
             u16(0x0420),
             u16(0x1401),
             u16(0x64E6),
             u16(0x74C7),
             u16(0x44A4),
             u16(0x5485),
             u16(0xA56A),
             u16(0xB54B),
             u16(0x8528),
             u16(0x9509),
             u16(0xE5EE),
             u16(0xF5CF),
             u16(0xC5AC),
             u16(0xD58D),
             u16(0x3653),
             u16(0x2672),
             u16(0x1611),
             u16(0x0630),
             u16(0x76D7),
             u16(0x66F6),
             u16(0x5695),
             u16(0x46B4),
             u16(0xB75B),
             u16(0xA77A),
             u16(0x9719),
             u16(0x8738),
             u16(0xF7DF),
             u16(0xE7FE),
             u16(0xD79D),
             u16(0xC7BC),
             u16(0x48C4),
             u16(0x58E5),
             u16(0x6886),
             u16(0x78A7),
             u16(0x0840),
             u16(0x1861),
             u16(0x2802),
             u16(0x3823),
             u16(0xC9CC),
             u16(0xD9ED),
             u16(0xE98E),
             u16(0xF9AF),
             u16(0x8948),
             u16(0x9969),
             u16(0xA90A),
             u16(0xB92B),
             u16(0x5AF5),
             u16(0x4AD4),
             u16(0x7AB7),
             u16(0x6A96),
             u16(0x1A71),
             u16(0x0A50),
             u16(0x3A33),
             u16(0x2A12),
             u16(0xDBFD),
             u16(0xCBDC),
             u16(0xFBBF),
             u16(0xEB9E),
             u16(0x9B79),
             u16(0x8B58),
             u16(0xBB3B),
             u16(0xAB1A),
             u16(0x6CA6),
             u16(0x7C87),
             u16(0x4CE4),
             u16(0x5CC5),
             u16(0x2C22),
             u16(0x3C03),
             u16(0x0C60),
             u16(0x1C41),
             u16(0xEDAE),
             u16(0xFD8F),
             u16(0xCDEC),
             u16(0xDDCD),
             u16(0xAD2A),
             u16(0xBD0B),
             u16(0x8D68),
             u16(0x9D49),
             u16(0x7E97),
             u16(0x6EB6),
             u16(0x5ED5),
             u16(0x4EF4),
             u16(0x3E13),
             u16(0x2E32),
             u16(0x1E51),
             u16(0x0E70),
             u16(0xFF9F),
             u16(0xEFBE),
             u16(0xDFDD),
             u16(0xCFFC),
             u16(0xBF1B),
             u16(0xAF3A),
             u16(0x9F59),
             u16(0x8F78),
             u16(0x9188),
             u16(0x81A9),
             u16(0xB1CA),
             u16(0xA1EB),
             u16(0xD10C),
             u16(0xC12D),
             u16(0xF14E),
             u16(0xE16F),
             u16(0x1080),
             u16(0x00A1),
             u16(0x30C2),
             u16(0x20E3),
             u16(0x5004),
             u16(0x4025),
             u16(0x7046),
             u16(0x6067),
             u16(0x83B9),
             u16(0x9398),
             u16(0xA3FB),
             u16(0xB3DA),
             u16(0xC33D),
             u16(0xD31C),
             u16(0xE37F),
             u16(0xF35E),
             u16(0x02B1),
             u16(0x1290),
             u16(0x22F3),
             u16(0x32D2),
             u16(0x4235),
             u16(0x5214),
             u16(0x6277),
             u16(0x7256),
             u16(0xB5EA),
             u16(0xA5CB),
             u16(0x95A8),
             u16(0x8589),
             u16(0xF56E),
             u16(0xE54F),
             u16(0xD52C),
             u16(0xC50D),
             u16(0x34E2),
             u16(0x24C3),
             u16(0x14A0),
             u16(0x0481),
             u16(0x7466),
             u16(0x6447),
             u16(0x5424),
             u16(0x4405),
             u16(0xA7DB),
             u16(0xB7FA),
             u16(0x8799),
             u16(0x97B8),
             u16(0xE75F),
             u16(0xF77E),
             u16(0xC71D),
             u16(0xD73C),
             u16(0x26D3),
             u16(0x36F2),
             u16(0x0691),
             u16(0x16B0),
             u16(0x6657),
             u16(0x7676),
             u16(0x4615),
             u16(0x5634),
             u16(0xD94C),
             u16(0xC96D),
             u16(0xF90E),
             u16(0xE92F),
             u16(0x99C8),
             u16(0x89E9),
             u16(0xB98A),
             u16(0xA9AB),
             u16(0x5844),
             u16(0x4865),
             u16(0x7806),
             u16(0x6827),
             u16(0x18C0),
             u16(0x08E1),
             u16(0x3882),
             u16(0x28A3),
             u16(0xCB7D),
             u16(0xDB5C),
             u16(0xEB3F),
             u16(0xFB1E),
             u16(0x8BF9),
             u16(0x9BD8),
             u16(0xABBB),
             u16(0xBB9A),
             u16(0x4A75),
             u16(0x5A54),
             u16(0x6A37),
             u16(0x7A16),
             u16(0x0AF1),
             u16(0x1AD0),
             u16(0x2AB3),
             u16(0x3A92),
             u16(0xFD2E),
             u16(0xED0F),
             u16(0xDD6C),
             u16(0xCD4D),
             u16(0xBDAA),
             u16(0xAD8B),
             u16(0x9DE8),
             u16(0x8DC9),
             u16(0x7C26),
             u16(0x6C07),
             u16(0x5C64),
             u16(0x4C45),
             u16(0x3CA2),
             u16(0x2C83),
             u16(0x1CE0),
             u16(0x0CC1),
             u16(0xEF1F),
             u16(0xFF3E),
             u16(0xCF5D),
             u16(0xDF7C),
             u16(0xAF9B),
             u16(0xBFBA),
             u16(0x8FD9),
             u16(0x9FF8),
             u16(0x6E17),
             u16(0x7E36),
             u16(0x4E55),
             u16(0x5E74),
             u16(0x2E93),
             u16(0x3EB2),
             u16(0x0ED1),
             u16(0x1EF0)
         ];
}

glob:priv BYTES_SVAL: Final[i64] = 32,
     PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     BASE64_MAXBIN: Final[i64] = (9223372036854775807 - 3) // 2,
     MAXLINESIZE: Final[i64] = 76,
     CRC_CHUNK: Final[i64] = 0x40000000;

def:priv binascii_error(module: ptr[PyObject]) -> ptr[PyObject];

def:priv bytes_buffer(op: ptr[PyObject]) -> ptr[u8];

def:priv finish_bytes(rv: ptr[PyObject], allocated: i64, used: i64) -> ptr[PyObject];

def convert_ascii_buffer_converter(
    value: ptr[PyObject], fname: str, label: str
) -> BufferArgument;

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

def binascii_crc_hqx_impl(
    module: ptr[PyObject], data: BufferArgument, crc: u32
) -> ptr[PyObject];

def binascii_crc32_impl(module: ptr[PyObject], data: BufferArgument, crc: u32) -> u32;

def binascii_b2a_hex_impl(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject];

def binascii_hexlify_impl(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject];

def binascii_a2b_hex_impl(
    module: ptr[PyObject], hexstr: BufferArgument
) -> ptr[PyObject];

def binascii_unhexlify_impl(
    module: ptr[PyObject], hexstr: BufferArgument
) -> ptr[PyObject];

def:priv is_hex_char(c: u8) -> bool;

def binascii_a2b_qp_impl(
    module: ptr[PyObject], data: BufferArgument, header: bool
) -> ptr[PyObject];

def:priv to_hex(ch: u8, s: ptr[u8]);

def:priv qp_needs_quoting(
    databuf: ptr[u8],
    datalen: i64,
    inpos: i64,
    linelen: i64,
    quotetabs: bool,
    istext: bool,
    header: bool
) -> bool;

def binascii_b2a_qp_impl(
    module: ptr[PyObject],
    data: BufferArgument,
    quotetabs: bool,
    istext: bool,
    header: bool
) -> ptr[PyObject];

impl binascii_error(module: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, 0);
}

impl bytes_buffer(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + BYTES_SVAL;
}

impl finish_bytes(rv: ptr[PyObject], allocated: i64, used: i64) -> ptr[PyObject] {
    if used == allocated {
        return rv;
    }
    result = rv;
    if _PyBytes_Resize(&mut result, used) < 0 {
        return NULL;
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

impl binascii_a2b_uu_impl(
    module: ptr[PyObject], data: BufferArgument
) -> ptr[PyObject] {
    ascii_data = ptr[u8](data.address());
    ascii_len = data.size();
    leftbits: i64 = 0;
    leftchar: i64 = 0;

    if ascii_len == 0 {
        PyErr_SetString(binascii_error(module), ptr[u8]("Missing length byte"));
        return NULL;
    }
    bin_len = (i64(ascii_data.view(1)[0]) - 32) & 0x3F;
    ascii_data += 1;
    ascii_len -= 1;

    rv = PyBytes_FromStringAndSize(ptr[u8](), bin_len);
    if not rv {
        return NULL;
    }
    bin_data = bytes_buffer(rv);

    while bin_len > 0 {
        this_ch: i64 = 0;
        if ascii_len > 0 {
            this_ch = i64(ascii_data.view(1)[0]);
        }
        if this_ch == 10 or this_ch == 13 or ascii_len <= 0 {
            this_ch = 0;
        } else {
            if this_ch < 32 or this_ch > 96 {
                PyErr_SetString(binascii_error(module), ptr[u8]("Illegal char"));
                jacpy_release(rv);
                return NULL;
            }
            this_ch = (this_ch - 32) & 0x3F;
        }

        leftchar = (leftchar << 6) | this_ch;
        leftbits += 6;
        if leftbits >= 8 {
            leftbits -= 8;
            bin_data.view(1)[0] = u8((leftchar >> leftbits) & 0xFF);
            bin_data += 1;
            leftchar &= (i64(1) << leftbits) - 1;
            bin_len -= 1;
        }
        ascii_len -= 1;
        ascii_data += 1;
    }

    while ascii_len > 0 {
        ascii_len -= 1;
        trailing = ascii_data.view(1)[0];
        ascii_data += 1;

        if trailing != u8(32)
            and trailing != u8(96)
            and trailing != u8(10)
            and trailing != u8(13) {
            PyErr_SetString(binascii_error(module), ptr[u8]("Trailing garbage"));
            jacpy_release(rv);
            return NULL;
        }
    }
    return rv;
}

impl binascii_b2a_uu_impl(
    module: ptr[PyObject], data: BufferArgument, backtick: bool
) -> ptr[PyObject] {
    bin_data = ptr[u8](data.address());
    bin_len = data.size();
    leftbits: i64 = 0;
    leftchar: i64 = 0;
    if bin_len > 45 {
        PyErr_SetString(binascii_error(module), ptr[u8]("At most 45 bytes at once"));
        return NULL;
    }

    out_len = 2 + (bin_len + 2) // 3 * 4;
    rv = PyBytes_FromStringAndSize(ptr[u8](), out_len);
    if not rv {
        return NULL;
    }
    start = bytes_buffer(rv);
    ascii_data = start;

    if backtick and bin_len == 0 {
        ascii_data.view(1)[0] = u8(96);
    } else {
        ascii_data.view(1)[0] = u8(32 + bin_len);
    }
    ascii_data += 1;

    while bin_len > 0 or leftbits != 0 {
        if bin_len > 0 {
            leftchar = ((leftchar << 8) | i64(bin_data.view(1)[0])) & 0xFFFFFF;
        } else {
            leftchar = (leftchar << 8) & 0xFFFFFF;
        }
        leftbits += 8;

        while leftbits >= 6 {
            this_ch = (leftchar >> (leftbits - 6)) & 0x3F;
            leftbits -= 6;
            if backtick and this_ch == 0 {
                ascii_data.view(1)[0] = u8(96);
            } else {
                ascii_data.view(1)[0] = u8(this_ch + 32);
            }
            ascii_data += 1;
        }
        bin_len -= 1;
        bin_data += 1;
    }

    ascii_data.view(1)[0] = u8(10);
    ascii_data += 1;
    return finish_bytes(rv, out_len, i64(int(ascii_data) - int(start)));
}

impl binascii_a2b_base64_impl(
    module: ptr[PyObject], data: BufferArgument, strict_mode: bool
) -> ptr[PyObject] {
    ascii_data = ptr[u8](data.address());
    ascii_len = data.size();

    bin_len = ((ascii_len + 3) // 4) * 3;
    rv = PyBytes_FromStringAndSize(ptr[u8](), bin_len);
    if not rv {
        return NULL;
    }
    bin_data_start = bytes_buffer(rv);
    bin_data = bin_data_start;
    table = ptr[u8](addressof(table_a2b_base64));

    quad_pos: i64 = 0;
    leftchar: i64 = 0;
    pads: i64 = 0;
    i: i64 = 0;
    while i < ascii_len {
        if quad_pos == 0 and (pads == 0 or not strict_mode) and i + 4 <= ascii_len {
            c0 = (ascii_data + i).view(1)[0];
            c1 = (ascii_data + i + 1).view(1)[0];
            c2 = (ascii_data + i + 2).view(1)[0];
            c3 = (ascii_data + i + 3).view(1)[0];
            if c0 != u8(61) and c1 != u8(61) and c2 != u8(61) and c3 != u8(61) {
                v0 = (table + i64(c0)).view(1)[0];
                v1 = (table + i64(c1)).view(1)[0];
                v2 = (table + i64(c2)).view(1)[0];
                v3 = (table + i64(c3)).view(1)[0];
                if (v0 | v1 | v2 | v3) < u8(64) {
                    bin_data.view(3)[0] = (v0 << u8(2)) | (v1 >> u8(4));
                    bin_data.view(3)[1] = ((v1 & u8(0x0F)) << u8(4)) | (v2 >> u8(2));
                    bin_data.view(3)[2] = ((v2 & u8(0x03)) << u8(6)) | v3;
                    bin_data += 3;
                    i += 4;
                    pads = 0;
                    continue;
                }
            }
        }
        this_ch = (ascii_data + i).view(1)[0];
        i += 1;

        if this_ch == u8(61) {
            pads += 1;
            if quad_pos >= 2 and quad_pos + pads <= 4 {
                continue;
            }

            if not strict_mode {
                continue;
            }
            if quad_pos == 1 {
                break;
            }
            if quad_pos == 0 and i == 1 {
                PyErr_SetString(
                    binascii_error(module), ptr[u8]("Leading padding not allowed")
                );
            } else {
                PyErr_SetString(
                    binascii_error(module), ptr[u8]("Excess padding not allowed")
                );
            }
            jacpy_release(rv);
            return NULL;
        }

        value = (table + i64(this_ch)).view(1)[0];
        if value >= u8(64) {
            if strict_mode {
                PyErr_SetString(
                    binascii_error(module), ptr[u8]("Only base64 data is allowed")
                );
                jacpy_release(rv);
                return NULL;
            }
            continue;
        }

        if pads != 0 and strict_mode {
            if quad_pos + pads == 4 {
                PyErr_SetString(
                    binascii_error(module), ptr[u8]("Excess data after padding")
                );
            } else {
                PyErr_SetString(
                    binascii_error(module), ptr[u8]("Discontinuous padding not allowed")
                );
            }
            jacpy_release(rv);
            return NULL;
        }
        pads = 0;

        sextet = i64(value);
        if quad_pos == 0 {
            quad_pos = 1;
            leftchar = sextet;
        } elif quad_pos == 1 {
            quad_pos = 2;
            bin_data.view(1)[0] = u8(((leftchar << 2) | (sextet >> 4)) & 0xFF);
            bin_data += 1;
            leftchar = sextet & 0x0F;
        } elif quad_pos == 2 {
            quad_pos = 3;
            bin_data.view(1)[0] = u8(((leftchar << 4) | (sextet >> 2)) & 0xFF);
            bin_data += 1;
            leftchar = sextet & 0x03;
        } else {
            quad_pos = 0;
            bin_data.view(1)[0] = u8(((leftchar << 6) | sextet) & 0xFF);
            bin_data += 1;
            leftchar = 0;
        }
    }

    written = i64(int(bin_data) - int(bin_data_start));
    if quad_pos == 1 {
        characters: i64 = written // 3 * 4 + 1;
        PyErr_Format(
            binascii_error(module),
            ptr[u8](
                "Invalid base64-encoded string: number of data characters (%zd) cannot be 1 more than a multiple of 4"
            ),
            characters
        );
        jacpy_release(rv);
        return NULL;
    }

    if quad_pos != 0 and quad_pos + pads < 4 {
        PyErr_SetString(binascii_error(module), ptr[u8]("Incorrect padding"));
        jacpy_release(rv);
        return NULL;
    }

    return finish_bytes(rv, bin_len, written);
}

impl binascii_b2a_base64_impl(
    module: ptr[PyObject], data: BufferArgument, newline: bool
) -> ptr[PyObject] {
    bin_data = ptr[u8](data.address());
    bin_len = data.size();
    if bin_len > BASE64_MAXBIN {
        PyErr_SetString(
            binascii_error(module), ptr[u8]("Too much data for base64 line")
        );
        return NULL;
    }

    out_len = ((bin_len + 2) // 3) * 4;
    if newline {
        out_len += 1;
    }
    rv = PyBytes_FromStringAndSize(ptr[u8](), out_len);
    if not rv {
        return NULL;
    }
    ascii_data = bytes_buffer(rv);
    table = ptr[u8]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
    i: i64 = 0;
    o: i64 = 0;
    while i + 2 < bin_len {
        b0 = i64((bin_data + i).view(1)[0]);
        b1 = i64((bin_data + i + 1).view(1)[0]);
        b2 = i64((bin_data + i + 2).view(1)[0]);
        (ascii_data + o).view(1)[0] = (table + (b0 >> 2)).view(1)[0];
        (ascii_data + o + 1).view(1)[0] = (table + (((b0 & 3) << 4) | (b1 >> 4))).view(
            1
        )[0];
        (ascii_data + o + 2).view(1)[0] = (table + (((b1 & 15) << 2) | (b2 >> 6))).view(
            1
        )[0];
        (ascii_data + o + 3).view(1)[0] = (table + (b2 & 63)).view(1)[0];
        i += 3;
        o += 4;
    }
    left = bin_len - i;
    if left == 1 {
        b0 = i64((bin_data + i).view(1)[0]);
        (ascii_data + o).view(1)[0] = (table + (b0 >> 2)).view(1)[0];
        (ascii_data + o + 1).view(1)[0] = (table + ((b0 & 3) << 4)).view(1)[0];
        (ascii_data + o + 2).view(1)[0] = u8(61);
        (ascii_data + o + 3).view(1)[0] = u8(61);
        o += 4;
    } elif left == 2 {
        b0 = i64((bin_data + i).view(1)[0]);
        b1 = i64((bin_data + i + 1).view(1)[0]);
        (ascii_data + o).view(1)[0] = (table + (b0 >> 2)).view(1)[0];
        (ascii_data + o + 1).view(1)[0] = (table + (((b0 & 3) << 4) | (b1 >> 4))).view(
            1
        )[0];
        (ascii_data + o + 2).view(1)[0] = (table + ((b1 & 15) << 2)).view(1)[0];
        (ascii_data + o + 3).view(1)[0] = u8(61);
        o += 4;
    }
    if newline {
        (ascii_data + o).view(1)[0] = u8(10);
    }
    return rv;
}

impl binascii_crc_hqx_impl(
    module: ptr[PyObject], data: BufferArgument, crc: u32
) -> ptr[PyObject] {
    value = i64(crc) & 0xFFFF;
    bin_data = ptr[u8](data.address());
    length = data.size();
    table = ptr[u16](addressof(crctab_hqx));
    i: i64 = 0;
    while i < length {
        value = ((value << 8) & 0xFF00)
            ^ i64((table + ((value >> 8) ^ i64((bin_data + i).view(1)[0]))).view(1)[0]);
        i += 1;
    }
    return PyLong_FromUnsignedLong(u64(value));
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

impl binascii_b2a_hex_impl(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject] {
    return _Py_strhex_bytes_with_sep(
        ptr[u8](data.address()), data.size(), sep, bytes_per_sep
    );
}

impl binascii_hexlify_impl(
    module: ptr[PyObject], data: BufferArgument, sep: ptr[PyObject], bytes_per_sep: i32
) -> ptr[PyObject] {
    return _Py_strhex_bytes_with_sep(
        ptr[u8](data.address()), data.size(), sep, bytes_per_sep
    );
}

impl binascii_a2b_hex_impl(
    module: ptr[PyObject], hexstr: BufferArgument
) -> ptr[PyObject] {
    argbuf = ptr[u8](hexstr.address());
    arglen = hexstr.size();

    if arglen % 2 != 0 {
        PyErr_SetString(binascii_error(module), ptr[u8]("Odd-length string"));
        return NULL;
    }

    retval = PyBytes_FromStringAndSize(ptr[u8](), arglen // 2);
    if not retval {
        return NULL;
    }
    retbuf = bytes_buffer(retval);
    digits = ptr[u8](addressof(digit_values));

    i: i64 = 0;
    j: i64 = 0;
    while i < arglen {
        top = (digits + i64((argbuf + i).view(1)[0])).view(1)[0];
        bot = (digits + i64((argbuf + i + 1).view(1)[0])).view(1)[0];
        if top >= u8(16) or bot >= u8(16) {
            PyErr_SetString(
                binascii_error(module), ptr[u8]("Non-hexadecimal digit found")
            );
            jacpy_release(retval);
            return NULL;
        }
        (retbuf + j).view(1)[0] = (top << u8(4)) | bot;
        j += 1;
        i += 2;
    }
    return retval;
}

impl binascii_unhexlify_impl(
    module: ptr[PyObject], hexstr: BufferArgument
) -> ptr[PyObject] {
    return binascii_a2b_hex_impl(module, hexstr);
}

impl is_hex_char(c: u8) -> bool {
    return (c >= u8(65) and c <= u8(70))
        or (c >= u8(97) and c <= u8(102))
        or (c >= u8(48) and c <= u8(57));
}

impl binascii_a2b_qp_impl(
    module: ptr[PyObject], data: BufferArgument, header: bool
) -> ptr[PyObject] {
    ascii_data = ptr[u8](data.address());
    datalen = data.size();
    digits = ptr[u8](addressof(digit_values));

    odata = ptr[u8](PyMem_Calloc(u64(1), u64(datalen)));
    if not odata {
        PyErr_NoMemory();
        return NULL;
    }
    inpos: i64 = 0;
    out: i64 = 0;
    while inpos < datalen {
        if (ascii_data + inpos).view(1)[0] == u8(61) {
            inpos += 1;
            if inpos >= datalen {
                break;
            }
            ch = (ascii_data + inpos).view(1)[0];

            if ch == u8(10) or ch == u8(13) {
                if ch != u8(10) {
                    while inpos < datalen
                        and (ascii_data + inpos).view(1)[0] != u8(10) {
                        inpos += 1;
                    }
                }
                if inpos < datalen {
                    inpos += 1;
                }
            } elif ch == u8(61) {
                (odata + out).view(1)[0] = u8(61);
                out += 1;
                inpos += 1;
            } elif inpos + 1 < datalen
                and is_hex_char(ch)
                and is_hex_char((ascii_data + inpos + 1).view(1)[0]) {
                high = (digits + i64(ch)).view(1)[0];
                low = (digits + i64((ascii_data + inpos + 1).view(1)[0])).view(1)[0];
                inpos += 2;
                (odata + out).view(1)[0] = (high << u8(4)) | low;
                out += 1;
            } else {
                (odata + out).view(1)[0] = u8(61);
                out += 1;
            }
        } elif header and (ascii_data + inpos).view(1)[0] == u8(95) {
            (odata + out).view(1)[0] = u8(32);
            out += 1;
            inpos += 1;
        } else {
            (odata + out).view(1)[0] = (ascii_data + inpos).view(1)[0];
            inpos += 1;
            out += 1;
        }
    }
    rv = PyBytes_FromStringAndSize(odata, out);
    PyMem_Free(odata);
    return rv;
}

impl to_hex(ch: u8, s: ptr[u8]) {
    hexdigits = ptr[u8]("0123456789ABCDEF");
    s.view(2)[1] = (hexdigits + i64(ch & u8(15))).view(1)[0];
    s.view(2)[0] = (hexdigits + i64(ch >> u8(4))).view(1)[0];
}

impl qp_needs_quoting(
    databuf: ptr[u8],
    datalen: i64,
    inpos: i64,
    linelen: i64,
    quotetabs: bool,
    istext: bool,
    header: bool
) -> bool {
    c = (databuf + inpos).view(1)[0];
    if c > u8(126) or c == u8(61) or (header and c == u8(95)) {
        return True;
    }
    if c == u8(46) and linelen == 0 {
        if inpos + 1 == datalen {
            return True;
        }
        following = (databuf + inpos + 1).view(1)[0];
        if following == u8(10) or following == u8(13) or following == u8(0) {
            return True;
        }
    }
    if not istext and (c == u8(13) or c == u8(10)) {
        return True;
    }
    if (c == u8(9) or c == u8(32)) and inpos + 1 == datalen {
        return True;
    }
    return c < u8(33)
        and c != u8(13)
        and c != u8(10)
        and (quotetabs or (c != u8(9) and c != u8(32)));
}

impl binascii_b2a_qp_impl(
    module: ptr[PyObject],
    data: BufferArgument,
    quotetabs: bool,
    istext: bool,
    header: bool
) -> ptr[PyObject] {
    databuf = ptr[u8](data.address());
    datalen = data.size();
    crlf = False;

    p = ptr[u8](memchr(databuf, i32(10), u64(datalen)));
    if p {
        newline_at = i64(int(p) - int(databuf));
        if newline_at > 0 and (databuf + newline_at - 1).view(1)[0] == u8(13) {
            crlf = True;
        }
    }

    inpos: i64 = 0;
    linelen: i64 = 0;
    odatalen: i64 = 0;
    while inpos < datalen {
        delta: i64 = 0;
        if qp_needs_quoting(
            databuf, datalen, inpos, linelen, quotetabs, istext, header
        ) {
            if linelen + 3 >= MAXLINESIZE {
                linelen = 0;
                if crlf {
                    delta += 3;
                } else {
                    delta += 2;
                }
            }
            linelen += 3;
            delta += 3;
            inpos += 1;
        } else {
            c = (databuf + inpos).view(1)[0];
            if istext
                and (
                    c == u8(10)
                    or (
                        inpos + 1 < datalen
                        and c == u8(13)
                        and (databuf + inpos + 1).view(1)[0] == u8(10)
                    )
                ) {
                linelen = 0;

                if inpos != 0 {
                    previous = (databuf + inpos - 1).view(1)[0];
                    if previous == u8(32) or previous == u8(9) {
                        delta += 2;
                    }
                }
                if crlf {
                    delta += 2;
                } else {
                    delta += 1;
                }
                if c == u8(13) {
                    inpos += 2;
                } else {
                    inpos += 1;
                }
            } else {
                if inpos + 1 != datalen
                    and (databuf + inpos + 1).view(1)[0] != u8(10)
                    and linelen + 1 >= MAXLINESIZE {
                    linelen = 0;
                    if crlf {
                        delta += 3;
                    } else {
                        delta += 2;
                    }
                }
                linelen += 1;
                delta += 1;
                inpos += 1;
            }
        }
        if PY_SSIZE_T_MAX - delta < odatalen {
            PyErr_NoMemory();
            return NULL;
        }
        odatalen += delta;
    }

    odata = ptr[u8](PyMem_Calloc(u64(1), u64(odatalen)));
    if not odata {
        PyErr_NoMemory();
        return NULL;
    }
    inpos = 0;
    out: i64 = 0;
    linelen = 0;
    while inpos < datalen {
        if qp_needs_quoting(
            databuf, datalen, inpos, linelen, quotetabs, istext, header
        ) {
            if linelen + 3 >= MAXLINESIZE {
                (odata + out).view(1)[0] = u8(61);
                out += 1;
                if crlf {
                    (odata + out).view(1)[0] = u8(13);
                    out += 1;
                }
                (odata + out).view(1)[0] = u8(10);
                out += 1;
                linelen = 0;
            }
            (odata + out).view(1)[0] = u8(61);
            out += 1;
            to_hex((databuf + inpos).view(1)[0], odata + out);
            out += 2;
            inpos += 1;
            linelen += 3;
        } else {
            c = (databuf + inpos).view(1)[0];
            if istext
                and (
                    c == u8(10)
                    or (
                        inpos + 1 < datalen
                        and c == u8(13)
                        and (databuf + inpos + 1).view(1)[0] == u8(10)
                    )
                ) {
                linelen = 0;

                if out != 0 {
                    last = (odata + out - 1).view(1)[0];
                    if last == u8(32) or last == u8(9) {
                        (odata + out - 1).view(1)[0] = u8(61);
                        to_hex(last, odata + out);
                        out += 2;
                    }
                }
                if crlf {
                    (odata + out).view(1)[0] = u8(13);
                    out += 1;
                }
                (odata + out).view(1)[0] = u8(10);
                out += 1;
                if c == u8(13) {
                    inpos += 2;
                } else {
                    inpos += 1;
                }
            } else {
                if inpos + 1 != datalen
                    and (databuf + inpos + 1).view(1)[0] != u8(10)
                    and linelen + 1 >= MAXLINESIZE {
                    (odata + out).view(1)[0] = u8(61);
                    out += 1;
                    if crlf {
                        (odata + out).view(1)[0] = u8(13);
                        out += 1;
                    }
                    (odata + out).view(1)[0] = u8(10);
                    out += 1;
                    linelen = 0;
                }
                linelen += 1;
                if header and c == u8(32) {
                    (odata + out).view(1)[0] = u8(95);
                } else {
                    (odata + out).view(1)[0] = c;
                }
                out += 1;
                inpos += 1;
            }
        }
    }
    rv = PyBytes_FromStringAndSize(odata, out);
    PyMem_Free(odata);
    return rv;
}
