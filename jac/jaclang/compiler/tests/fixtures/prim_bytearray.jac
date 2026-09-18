"""bytearray native lowering (#7626 C7: the linker-tree blocker).

The growable byte buffer every object-file linker and the JIR marshaller are
built on. Pins the operations the compiler tree actually uses: constructors
(empty, zero-filled size, copy-from-bytes), append (LEB128 loops), extend
(bytes and bytearray), index read/write, slice read, same-length slice
assignment, `+=`, len, `bytes()` freeze, and `struct.pack_into`.
"""
import struct;

def bytearray_core_py -> dict[any, any] {
    empty = bytearray();
    sized = bytearray(4);
    copied = bytearray(b"seed");
    empty.append(65);
    empty.append(66);
    copied.extend(b"-tail");
    copied.extend(empty);
    sized[0] = 255;
    sized[3] = 7;
    head = copied[0];
    frozen = bytes(copied);
    return {
        "empty_len": len(empty),
        "sized_len": len(sized),
        "sized_zero": sized[1],
        "sized_first": sized[0],
        "sized_last": sized[3],
        "copied_len": len(copied),
        "head": head,
        "frozen_ok": frozen == b"seed-tailAB",

    };
}

def bytearray_slices_py -> dict[any, any] {
    buf = bytearray(8);
    buf[0:4] = b"\x01\x02\x03\x04";
    buf[4:8] = b"\xff\x06\x07\x08";
    mid = bytes(buf[2:6]);
    total = 0;
    for b in buf {
        total += b;
    }
    grown = bytearray(b"ab");
    grown += b"cd";
    return {
        "b0": buf[0],
        "b7": buf[7],
        "mid_ok": mid == b"\x03\x04\xff\x06",
        "total": total,
        "grown_ok": bytes(grown) == b"abcd",
        "grown_len": len(grown),

    };
}

def bytearray_pack_py -> dict[any, any] {
    buf = bytearray(16);
    struct.pack_into("<I", buf, 0, 305419896);
    struct.pack_into("<Q", buf, 4, 1311768467463790320);
    struct.pack_into("<H", buf, 12, 43981);
    struct.pack_into("<B", buf, 14, 171);
    return {
        "p0": buf[0],
        "p3": buf[3],
        "p4": buf[4],
        "p11": buf[11],
        "p12": buf[12],
        "p14": buf[14],
        "packed_ok": bytes(buf[0:4]) == b"\x78\x56\x34\x12",

    };
}


def bytearray_unpack_py -> dict[any, any] {
    buf = bytearray(b"\x01\x02\x03\x04");
    word_buf = bytearray(b"\x01\x02");
    (w, ) = struct.unpack("H", word_buf);
    (neg_mid, ) = struct.unpack_from("H", word_buf, -2);
    blob = b"\x78\x56\x34\x12";
    (v, ) = struct.unpack("<I", blob);
    (hi, lo) = struct.unpack(">hh", b"\xff\xfe\x00\x01");
    (mid, ) = struct.unpack_from("H", buf, 2);
    (head, ) = struct.unpack_from("<I", blob);
    (big, ) = struct.unpack("<q", struct.pack("<q", -5));
    scratch = bytearray(4);
    struct.pack_into("<H", scratch, 1, 4660);
    (pi_mid, ) = struct.unpack_from("<H", scratch, 1);
    return {
        "word": w,
        "word_ok": w == 0x0201,
        "negative_ok": neg_mid == 0x0201,
        "dword": v,
        "be_hi": hi,
        "be_lo": lo,
        "uf_mid": mid,
        "uf_head": head,
        "q_round": big,
        "pi_uf_ok": pi_mid == 4660,

    };
}

def bytearray_core_cl -> dict[any, any] {
    return {};
}

def bytearray_slices_cl -> dict[any, any] {
    return {};
}

def bytearray_pack_cl -> dict[any, any] {
    return {};
}


def bytearray_unpack_cl -> dict[any, any] {
    return {};
}

def bytearray_core_na -> dict[str, any] {
    empty = bytearray();
    sized = bytearray(4);
    copied = bytearray(b"seed");
    empty.append(65);
    empty.append(66);
    copied.extend(b"-tail");
    copied.extend(empty);
    sized[0] = 255;
    sized[3] = 7;
    head = copied[0];
    frozen = bytes(copied);
    return {
        "empty_len": len(empty),
        "sized_len": len(sized),
        "sized_zero": sized[1],
        "sized_first": sized[0],
        "sized_last": sized[3],
        "copied_len": len(copied),
        "head": head,
        "frozen_ok": frozen == b"seed-tailAB",

    };
}

def bytearray_slices_na -> dict[str, any] {
    buf = bytearray(8);
    buf[0:4] = b"\x01\x02\x03\x04";
    buf[4:8] = b"\xff\x06\x07\x08";
    mid = bytes(buf[2:6]);
    total = 0;
    for b in buf {
        total += b;
    }
    grown = bytearray(b"ab");
    grown += b"cd";
    return {
        "b0": buf[0],
        "b7": buf[7],
        "mid_ok": mid == b"\x03\x04\xff\x06",
        "total": total,
        "grown_ok": bytes(grown) == b"abcd",
        "grown_len": len(grown),

    };
}

def bytearray_pack_na -> dict[str, any] {
    buf = bytearray(16);
    struct.pack_into("<I", buf, 0, 305419896);
    struct.pack_into("<Q", buf, 4, 1311768467463790320);
    struct.pack_into("<H", buf, 12, 43981);
    struct.pack_into("<B", buf, 14, 171);
    return {
        "p0": buf[0],
        "p3": buf[3],
        "p4": buf[4],
        "p11": buf[11],
        "p12": buf[12],
        "p14": buf[14],
        "packed_ok": bytes(buf[0:4]) == b"\x78\x56\x34\x12",

    };
}

def bytearray_unpack_na -> dict[str, any] {
    buf = bytearray(b"\x01\x02\x03\x04");
    word_buf = bytearray(b"\x01\x02");
    (w, ) = struct.unpack("H", word_buf);
    (neg_mid, ) = struct.unpack_from("H", word_buf, -2);
    blob = b"\x78\x56\x34\x12";
    (v, ) = struct.unpack("<I", blob);
    (hi, lo) = struct.unpack(">hh", b"\xff\xfe\x00\x01");
    (mid, ) = struct.unpack_from("H", buf, 2);
    (head, ) = struct.unpack_from("<I", blob);
    (big, ) = struct.unpack("<q", struct.pack("<q", -5));
    scratch = bytearray(4);
    struct.pack_into("<H", scratch, 1, 4660);
    (pi_mid, ) = struct.unpack_from("<H", scratch, 1);
    return {
        "word": w,
        "word_ok": w == 0x0201,
        "negative_ok": neg_mid == 0x0201,
        "dword": v,
        "be_hi": hi,
        "be_lo": lo,
        "uf_mid": mid,
        "uf_head": head,
        "q_round": big,
        "pi_uf_ok": pi_mid == 4660,

    };
}
