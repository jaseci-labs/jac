import from engine.src.ffi.zlib {
    zlib_inflate_gzip,
    zlib_inflate_deflate,
    zlib_inflate_auto
}
import from engine.src.ffi.libc { calloc, memcpy }
import from engine.src.runtime.mem { io_alloc, read_byte, write_byte }

"""Decode a hex string into a binary buffer. Returns (ptr, length)."""
def:priv hex_decode(hex: str) -> list[int] {
    n: int = len(hex) // 2;
    buf: int = io_alloc(n + 1);
    i: int = 0;
    while i < n {
        hi: int = _ut_hex_val(hex[i * 2]);
        lo: int = _ut_hex_val(hex[i * 2 + 1]);
        write_byte(buf, i, hi * 16 + lo);
        i = i + 1;
    }
    return [buf, n];
}

def:priv _ut_hex_val(c: str) -> int {
    if c == "0" {
        return 0;
    }
    if c == "1" {
        return 1;
    }
    if c == "2" {
        return 2;
    }
    if c == "3" {
        return 3;
    }
    if c == "4" {
        return 4;
    }
    if c == "5" {
        return 5;
    }
    if c == "6" {
        return 6;
    }
    if c == "7" {
        return 7;
    }
    if c == "8" {
        return 8;
    }
    if c == "9" {
        return 9;
    }
    if c == "a" {
        return 10;
    }
    if c == "b" {
        return 11;
    }
    if c == "c" {
        return 12;
    }
    if c == "d" {
        return 13;
    }
    if c == "e" {
        return 14;
    }
    if c == "f" {
        return 15;
    }
    return 0;
}

glob
     # Gzip compressed "Hello, World! This is a test of gzip decompression via Jac native FFI."
     gz_hex: str = "1f8b08000000000000030dc2310a80300c05d0ab7c77f118459d05e7d0c61aa84d6942074faf8fb772293ae3d45ed284e316c39fe06c0ebd905f69481cf5699dcd442b8610768aa8e43218216ccb0713e3bfdd46000000",
     # Raw deflate of same string
     df_hex: str = "0dc2310a80300c05d0ab7c77f118459d05e7d0c61aa84d6942074faf8fb772293ae3d45ed284e316c39fe06c0ebd905f69481cf5699dcd442b8610768aa8e43218216ccb07",
     expected: str = "Hello, World! This is a test of gzip decompression via Jac native FFI.";

with entry {
    # Test 1: gzip decompression
    info: list[int] = hex_decode(gz_hex);
    result: str = zlib_inflate_gzip(info[0], info[1]);
    if result == expected {
        print("OK: gzip decompression");
    } else {
        print("FAIL: gzip decompression");
        print("  got length: " + str(len(result)));
        print("  expected length: " + str(len(expected)));
    }

    # Test 2: deflate decompression
    info2: list[int] = hex_decode(df_hex);
    result2: str = zlib_inflate_deflate(info2[0], info2[1]);
    if result2 == expected {
        print("OK: deflate decompression");
    } else {
        print("FAIL: deflate decompression");
        print("  got length: " + str(len(result2)));
    }

    # Test 3: auto-detect (gzip)
    info3: list[int] = hex_decode(gz_hex);
    result3: str = zlib_inflate_auto(info3[0], info3[1]);
    if result3 == expected {
        print("OK: auto-detect gzip");
    } else {
        print("FAIL: auto-detect gzip, got len=" + str(len(result3)));
    }

    # Test 4: empty input
    r4: str = zlib_inflate_gzip(0, 0);
    if len(r4) == 0 {
        print("OK: empty input returns empty");
    } else {
        print("FAIL: empty input");
    }
}
