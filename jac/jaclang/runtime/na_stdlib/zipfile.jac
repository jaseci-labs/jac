import from _zlib_native { z_uncompress2, z_crc32, z_adler32 }

glob:pub ZIP_STORED: int = 0,
     ZIP_DEFLATED: int = 8;

obj:pub BadZipFile(Exception) {}

obj:pub ZipInfo {
    has filename: str = "",
        compress_type: int = 0,
        flag_bits: int = 0,
        CRC: int = 0,
        compress_size: int = 0,
        file_size: int = 0,
        header_offset: int = 0,
        extra: bytes = b"",
        comment: bytes = b"",
        _raw_name: bytes = b"",
        _end_offset: int = 0;

    def is_dir -> bool {
        return self.filename.endswith("/");
    }
}

def _range(data: bytes, start: int, size: int) {
    if start < 0 or size < 0 or start > len(data) or size > len(data) - start {
        raise BadZipFile("Truncated ZIP record");
    }
}

def _uint(data: bytes, start: int, size: int) -> int {
    _range(data, start, size);
    return int.from_bytes(data[start:start + size], "little");
}

def _extra(data: bytes) {
    pos = 0;
    while pos < len(data) {
        kind = _uint(data, pos, 2);
        size = _uint(data, pos + 2, 2);
        _range(data, pos + 4, size);
        if kind == 1 {
            raise NotImplementedError("ZIP64 is not supported on the native pathway");
        }
        pos += 4 + size;
    }
}

def _name(raw: bytes, flags: int) -> str {
    if flags & 2048 != 0 {
        i = 0;
        while i < len(raw) {
            lead = int(raw[i]);
            i += 1;
            if lead < 128 {
                continue;
            }
            count = 0;
            low = 128;
            high = 191;
            if lead >= 194 and lead <= 223 {
                count = 1;
            } elif lead >= 224 and lead <= 239 {
                count = 2;
                if lead == 224 {
                    low = 160;
                }
                if lead == 237 {
                    high = 159;
                }
            } elif lead >= 240 and lead <= 244 {
                count = 3;
                if lead == 240 {
                    low = 144;
                }
                if lead == 244 {
                    high = 143;
                }
            } else {
                raise BadZipFile("Invalid UTF-8 ZIP filename");
            }
            if i + count > len(raw) or int(raw[i]) < low or int(raw[i]) > high {
                raise BadZipFile("Invalid UTF-8 ZIP filename");
            }
            for j in range(1, count) {
                if int(raw[i + j]) < 128 or int(raw[i + j]) > 191 {
                    raise BadZipFile("Invalid UTF-8 ZIP filename");
                }
            }
            i += count;
        }
        return raw.decode("utf-8");
    }
    cp437: list[int] = [
        199,
        252,
        233,
        226,
        228,
        224,
        229,
        231,
        234,
        235,
        232,
        239,
        238,
        236,
        196,
        197,
        201,
        230,
        198,
        244,
        246,
        242,
        251,
        249,
        255,
        214,
        220,
        162,
        163,
        165,
        8359,
        402,
        225,
        237,
        243,
        250,
        241,
        209,
        170,
        186,
        191,
        8976,
        172,
        189,
        188,
        161,
        171,
        187,
        9617,
        9618,
        9619,
        9474,
        9508,
        9569,
        9570,
        9558,
        9557,
        9571,
        9553,
        9559,
        9565,
        9564,
        9563,
        9488,
        9492,
        9524,
        9516,
        9500,
        9472,
        9532,
        9566,
        9567,
        9562,
        9556,
        9577,
        9574,
        9568,
        9552,
        9580,
        9575,
        9576,
        9572,
        9573,
        9561,
        9560,
        9554,
        9555,
        9579,
        9578,
        9496,
        9484,
        9608,
        9604,
        9612,
        9616,
        9600,
        945,
        223,
        915,
        960,
        931,
        963,
        181,
        964,
        934,
        920,
        937,
        948,
        8734,
        966,
        949,
        8745,
        8801,
        177,
        8805,
        8804,
        8992,
        8993,
        247,
        8776,
        176,
        8729,
        183,
        8730,
        8319,
        178,
        9632,
        160
    ];
    result = "";
    for byte in raw {
        result += chr(byte) if byte < 128 else chr(cp437[byte - 128]);
    }
    return result;
}

def _inflate(data: bytes, size: int) -> bytes {
    if size < 0 or size > len(data) * 1032 + 1024 {
        raise BadZipFile("Invalid DEFLATE output size");
    }
    framed = b"\x78\x9c" + data + b"\x00\x00\x00\x00";
    dest = b"\x00" * (size + 1);
    dest_len = (size + 1).to_bytes(8, "little");
    src_len = len(framed).to_bytes(8, "little");
    rc = z_uncompress2(dest, dest_len, framed, src_len);
    if (rc != 0 and rc != -3)
        or int.from_bytes(dest_len, "little") != size
        or int.from_bytes(src_len, "little") != len(framed) {
        raise BadZipFile("Invalid or truncated DEFLATE stream");
    }
    result = dest[:size];
    checksum = z_adler32(1, result, size);
    verified = b"\x78\x9c" + data + checksum.to_bytes(4, "big");
    dest_len = (size + 1).to_bytes(8, "little");
    src_len = len(verified).to_bytes(8, "little");
    rc = z_uncompress2(dest, dest_len, verified, src_len);
    if rc != 0
        or int.from_bytes(dest_len, "little") != size
        or int.from_bytes(src_len, "little") != len(verified) {
        raise BadZipFile("Invalid or truncated DEFLATE stream");
    }
    return result;
}

obj:pub ZipFile {
    has filename: str = "",
        mode: str = "r",
        comment: bytes = b"",
        _data: bytes = b"",
        _files: list[ZipInfo] = [],
        _index: dict[str, int] = {},
        _closed: bool = False;

    def init(file: str, mode: str = "r") {
        if mode != "r" {
            raise NotImplementedError("Native ZipFile supports mode 'r' only");
        }
        self.filename = file;
        self.mode = mode;
        with open(file, "rb") as stream {
            self._data = stream.read();
        }
        self._parse();
    }

    def _parse {
        data = self._data;
        end = len(data) - 22;
        lower = max(0, len(data) - 65557);
        while end >= lower {
            if data[end:end + 4] == b"PK\x05\x06"
                and end + 22 + _uint(data, end + 20, 2) == len(data) {
                break;
            }
            end -= 1;
        }
        if end < lower {
            raise BadZipFile("File is not a zip file");
        }
        if end >= 20 and data[end - 20:end - 16] == b"PK\x06\x07" {
            raise NotImplementedError("ZIP64 is not supported on the native pathway");
        }
        count = _uint(data, end + 10, 2);
        size = _uint(data, end + 12, 4);
        offset = _uint(data, end + 16, 4);
        if count == 65535 or size == 4294967295 or offset == 4294967295 {
            raise NotImplementedError("ZIP64 is not supported on the native pathway");
        }
        if _uint(data, end + 4, 2) != 0
            or _uint(data, end + 6, 2) != 0
            or _uint(data, end + 8, 2) != count {
            raise BadZipFile("Multi-disk ZIP archives are not supported");
        }
        start = end - size;
        prefix = start - offset;
        if prefix < 0 or start < 0 or count > size // 46 {
            raise BadZipFile("Invalid central directory bounds");
        }
        self.comment = data[end + 22:];
        pos = start;
        for i in range(count) {
            _range(data, pos, 46);
            if pos + 46 > end or data[pos:pos + 4] != b"PK\x01\x02" {
                raise BadZipFile("Bad central directory signature");
            }
            flags = _uint(data, pos + 8, 2);
            compressed = _uint(data, pos + 20, 4);
            original = _uint(data, pos + 24, 4);
            local = _uint(data, pos + 42, 4);
            if compressed == 4294967295
                or original == 4294967295
                or local == 4294967295 {
                raise NotImplementedError(
                    "ZIP64 is not supported on the native pathway"
                );
            }
            if _uint(data, pos + 34, 2) != 0 {
                raise BadZipFile("Multi-disk ZIP archives are not supported");
            }
            nlen = _uint(data, pos + 28, 2);
            elen = _uint(data, pos + 30, 2);
            clen = _uint(data, pos + 32, 2);
            next_pos = pos + 46 + nlen + elen + clen;
            if next_pos > end {
                raise BadZipFile("Truncated central directory entry");
            }
            raw = data[pos + 46:pos + 46 + nlen];
            name = _name(raw, flags).split("\x00")[0];
            extra = data[pos + 46 + nlen:pos + 46 + nlen + elen];
            _extra(extra);
            info = ZipInfo(
                filename=name,
                compress_type=_uint(data, pos + 10, 2),
                flag_bits=flags,
                CRC=_uint(data, pos + 16, 4),
                compress_size=compressed,
                file_size=original,
                header_offset=local + prefix,
                extra=extra,
                comment=data[pos + 46 + nlen + elen:next_pos],
                _raw_name=raw,
                _end_offset=start
            );
            if info.header_offset < prefix or info.header_offset + 30 > start {
                raise BadZipFile("Invalid local header offset");
            }
            self._index[name] = len(self._files);
            self._files.append(info);
            pos = next_pos;
        }
        if pos != end {
            raise BadZipFile("Invalid central directory size");
        }
        offsets: list[int] = [];
        for info in self._files {
            offsets.append(info.header_offset);
        }
        ordered = sorted(offsets);
        boundaries: dict[int, int] = {};
        for i in range(len(ordered)) {
            if i > 0 and ordered[i] == ordered[i - 1] {
                raise BadZipFile("Overlapping ZIP entries");
            }
            boundaries[ordered[i]] = ordered[i + 1] if i + 1 < len(ordered) else start;
        }
        for info in self._files {
            info._end_offset = boundaries[info.header_offset];
        }
    }

    def namelist -> list[str] {
        names: list[str] = [];
        for info in self._files {
            names.append(info.filename);
        }
        return names;
    }

    def infolist -> list[ZipInfo] {
        return self._files[:];
    }

    def getinfo(name: str) -> ZipInfo {
        if name not in self._index {
            raise KeyError("There is no item named '" + name + "' in the archive");
        }
        return self._files[self._index[name]];
    }

    def read(name: str) -> bytes {
        if self._closed {
            raise ValueError("Attempt to use ZIP archive that was already closed");
        }
        info = self.getinfo(name);
        data = self._data;
        pos = info.header_offset;
        _range(data, pos, 30);
        if data[pos:pos + 4] != b"PK\x03\x04" {
            raise BadZipFile("Bad local file header signature");
        }
        flags = _uint(data, pos + 6, 2);
        method = _uint(data, pos + 8, 2);
        if flags != info.flag_bits or method != info.compress_type {
            raise BadZipFile("Local and central ZIP headers disagree");
        }
        if flags & 1 != 0 {
            raise NotImplementedError("Encrypted ZIP members are not supported");
        }
        if flags & 8288 != 0 {
            raise NotImplementedError("Unsupported ZIP member flags");
        }
        if method != ZIP_STORED and method != ZIP_DEFLATED {
            raise NotImplementedError("Unsupported ZIP compression method");
        }
        nlen = _uint(data, pos + 26, 2);
        elen = _uint(data, pos + 28, 2);
        payload = pos + 30 + nlen + elen;
        if payload > info._end_offset
            or info.compress_size > info._end_offset - payload {
            raise BadZipFile("Overlapping or truncated ZIP member");
        }
        if data[pos + 30:pos + 30 + nlen] != info._raw_name {
            raise BadZipFile("Local and central ZIP filenames disagree");
        }
        _extra(data[pos + 30 + nlen:payload]);
        if flags & 8 == 0 {
            if _uint(data, pos + 14, 4) != info.CRC
                or _uint(data, pos + 18, 4) != info.compress_size
                or _uint(data, pos + 22, 4) != info.file_size {
                raise BadZipFile("Local and central ZIP sizes or CRC disagree");
            }
        }
        compressed = data[payload:payload + info.compress_size];
        result = compressed
            if method == ZIP_STORED
            else _inflate(compressed, info.file_size);
        if len(result) != info.file_size {
            raise BadZipFile("Bad uncompressed size for file '" + name + "'");
        }
        if z_crc32(0, result, len(result)) != info.CRC {
            raise BadZipFile("Bad CRC-32 for file '" + name + "'");
        }
        return result;
    }

    def close {
        self._data = b"";
        self._closed = True;
    }

    def __enter__ -> ZipFile {
        if self._closed {
            raise ValueError("Attempt to use ZIP archive that was already closed");
        }
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }
}
