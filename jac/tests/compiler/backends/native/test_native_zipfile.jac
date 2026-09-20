"""Synthetic ZIPs compare the bundled native reader with CPython's zipfile."""
import ctypes;
import io;
import tempfile;
import warnings;
import zipfile;
import zlib;
import from pathlib { Path }
import from tests.support {
    compile_native,
    native_str_func,
    native_build,
    native_run,
    NATIVE_FIXTURES
}

glob _ENGINES: list[any] = [];

def engine -> any {
    if not _ENGINES {
        (eng, _) = compile_native("zipfile_read.jac");
        _ENGINES.append(eng);
    }
    return _ENGINES[0];
}

def probe(name: str, result: type = ctypes.c_int64, args: int = 1) -> any {
    if args == 2 {
        return native_str_func(
            engine(), name, result, ctypes.c_char_p, ctypes.c_char_p
        );
    }
    return native_str_func(engine(), name, result, ctypes.c_char_p);
}

def sample -> bytes {
    stream = io.BytesIO();
    with warnings.catch_warnings() {
        warnings.simplefilter("ignore", UserWarning);
        with zipfile.ZipFile(stream, "w") as archive {
            archive.comment = b"archive comment PK\x05\x06";
            archive.writestr("stored", b"\x00\xffstored\x00");
            archive.writestr("deflated", b"deflated\x00" * 1000, compress_type=8);
            archive.writestr("empty", b"", compress_type=8);
            archive.writestr("folder/", b"");
            archive.writestr("café.txt", b"unicode");
            archive.writestr("duplicate", b"first");
            archive.writestr("duplicate", b"last");
        }
    }
    return stream.getvalue();
}

def single(payload: bytes = b"payload", method: int = 0) -> bytes {
    stream = io.BytesIO();
    with zipfile.ZipFile(stream, "w") as archive {
        archive.writestr("member", payload, compress_type=method);
    }
    return stream.getvalue();
}

def replace_uint(data: bytes, offset: int, size: int, value: int) -> bytes {
    return data[:offset] + value.to_bytes(size, "little") + data[offset + size:];
}

class StreamingBuffer(io.BytesIO) {
    def seekable -> bool {
        return False;
    }

    def seek(offset: int, whence: int = 0) -> int {
        raise OSError("not seekable");
    }
}

test "native ZIP public reader and context manager agree with CPython" {
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "sample.pk3";
        path.write_bytes(sample());
        assert probe("archive_checks", ctypes.c_bool)(str(path));
        assert probe("exceptional_exit", ctypes.c_bool)(str(path));
        assert probe("wrong_mode", ctypes.c_bool)(str(path));
        assert probe("read_error", args=2)(str(path), "missing") == 3;
        # A prepended launcher or other prefix shifts the local-header offsets.
        path.write_bytes(b"prefix\x00" * 11 + sample());
        assert probe("archive_checks", ctypes.c_bool)(str(path));
        empty = io.BytesIO();
        with zipfile.ZipFile(empty, "w") {}
        path.write_bytes(empty.getvalue());
        assert probe("count_members")(str(path)) == 0;
    }
}

test "native ZIP reads descriptor members and all DEFLATE block kinds" {
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "data.zip";
        stream = StreamingBuffer();
        with zipfile.ZipFile(stream, "w", compression=8) as archive {
            archive.writestr("member", b"descriptor payload" * 1000);
        }
        path.write_bytes(stream.getvalue());
        read = probe("member_crc", args=2);
        assert read(str(path), "member") == zlib.crc32(b"descriptor payload" * 1000);
        for level in [0, 1, 6, 9] {
            for payload in [
                b"",
                b"\x00",
                bytes(range(256)) * 31,
                b"repeated" * 20000
            ] {
                buffer = io.BytesIO();
                with zipfile.ZipFile(
                    buffer, "w", compression=8, compresslevel=level
                ) as archive {
                    archive.writestr("member", payload);
                }
                path.write_bytes(buffer.getvalue());
                assert read(str(path), "member") == zlib.crc32(payload);
            }
        }
        # ZIP's unflagged names are CP437, not UTF-8 or Latin-1.
        data = single().replace(b"member", b"caf\x82!!");
        path.write_bytes(data);
        assert read(str(path), "café!!") == zlib.crc32(b"payload");
        for code in range(128, 256) {
            raw_name = b"caf" + bytes([code]) + b"!!";
            path.write_bytes(single().replace(b"member", raw_name));
            assert read(str(path), raw_name.decode("cp437")) == zlib.crc32(b"payload");
        }
        for name in ["日本語", "emoji-🌍", "a\u0080\u07ff\u0800\uffff\U0010ffff"] {
            buffer = io.BytesIO();
            with zipfile.ZipFile(buffer, "w") as archive {
                archive.writestr(name, b"unicode");
            }
            path.write_bytes(buffer.getvalue());
            assert read(str(path), name) == zlib.crc32(b"unicode");
        }
    }
}

test "native ZIP rejects corrupt headers ranges sizes and checksums" {
    data = single();
    central = data.index(b"PK\x01\x02");
    end = data.index(b"PK\x05\x06");
    invalid: list[bytes] = [
        b"",
        b"not a zip",
        data[:-1],
        b"FAIL" + data[4:],
        data[:central] + b"FAIL" + data[central + 4:],
        replace_uint(data, end + 10, 2, 2),
        replace_uint(data, end + 12, 4, 1),
        replace_uint(data, central + 42, 4, len(data)),
        replace_uint(data, central + 28, 2, 65535),
        replace_uint(data, 30, 1, 65),
        replace_uint(data, 36, 1, 0),
        replace_uint(data, 18, 4, 500),
        replace_uint(data, 8, 2, 8),
        replace_uint(data, end + 4, 2, 1),
        replace_uint(data, central + 34, 2, 1)
    ];
    invalid.append(replace_uint(replace_uint(data, 18, 4, 500), central + 20, 4, 500));
    duplicate_offsets = sample();
    first = duplicate_offsets.index(b"PK\x01\x02");
    second = duplicate_offsets.index(b"PK\x01\x02", first + 4);
    invalid.append(replace_uint(duplicate_offsets, second + 42, 4, 0));
    for size in [0, 6, 8, 2147483647] {
        bad = replace_uint(data, 22, 4, size);
        invalid.append(replace_uint(bad, central + 24, 4, size));
    }
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "bad.zip";
        error = probe("read_error", args=2);
        for (index, bad) in enumerate(invalid) {
            path.write_bytes(bad);
            assert error(str(path), "member") == 1 , str(index);
        }
        for method in [12, 99] {
            bad = replace_uint(data, 8, 2, method);
            path.write_bytes(replace_uint(bad, central + 10, 2, method));
            assert error(str(path), "member") == 2;
        }
        for flag in [1, 32, 64, 8192] {
            bad = replace_uint(data, 6, 2, flag);
            path.write_bytes(replace_uint(bad, central + 8, 2, flag));
            assert error(str(path), "member") == 2;
        }
        for raw in [
            b"\xffabcde",
            b"\xc0\xafabcd",
            b"\xed\xa0\x80abc",
            b"\xf4\x90\x80\x80ab",
            b"abcde\xc2"
        ] {
            bad = data.replace(b"member", raw);
            bad = replace_uint(bad, 6, 2, 2048);
            path.write_bytes(replace_uint(bad, central + 8, 2, 2048));
            assert error(str(path), "member") == 1;
        }
        path.write_bytes(replace_uint(data, central + 24, 4, 4294967295));
        assert error(str(path), "member") == 2;
    }
}

test "native ZIP requires a complete DEFLATE stream and exact compressed size" {
    data = single(b"repeated" * 100, 8);
    central = data.index(b"PK\x01\x02");
    end = data.index(b"PK\x05\x06");
    size = int.from_bytes(data[18:22], "little");
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "deflate.zip";
        error = probe("read_error", args=2);
        # Remove compressed bytes and repair all ZIP offsets, so the failure
        # must come from the DEFLATE decoder, not a broken directory.
        for cut in range(1, size + 1) {
            bad = data[:central - cut] + data[central:];
            bad = replace_uint(bad, 18, 4, size - cut);
            bad = replace_uint(bad, central - cut + 20, 4, size - cut);
            bad = replace_uint(bad, end - cut + 16, 4, central - cut);
            path.write_bytes(bad);
            assert error(str(path), "member") == 1 , str(cut);
        }
        # A reserved DEFLATE block type is invalid even with a valid ZIP header.
        path.write_bytes(replace_uint(data, 36, 1, 7));
        assert error(str(path), "member") == 1;
        # Junk after a valid stream is included in the declared compressed size.
        bad = data[:central] + b"junk" + data[central:];
        bad = replace_uint(bad, 18, 4, size + 4);
        bad = replace_uint(bad, central + 4 + 20, 4, size + 4);
        bad = replace_uint(bad, end + 4 + 16, 4, central + 4);
        path.write_bytes(bad);
        assert error(str(path), "member") == 1;
    }
}


test "native ZIP links and runs as a standalone binary" {
    with tempfile.TemporaryDirectory() as directory {
        archive_path = Path(directory) / "sample.pk3";
        archive_path.write_bytes(
            sample().replace(b"archive comment PK\x05\x06", b"archive comment safe")
        );
        total = 0;
        with zipfile.ZipFile(str(archive_path)) as archive {
            names = archive.namelist();
            for name in names {
                data = archive.read(name);
                total = (total + zlib.crc32(data) + len(data)) & 4294967295;
            }
        }
        binary = str(Path(directory) / "zip-reader");
        native_build(str(Path(NATIVE_FIXTURES) / "zipfile_main.jac"), binary);
        assert native_run(binary, [str(archive_path)]).strip() == "7 " + str(total);
    }
}
