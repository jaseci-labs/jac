import from io { BytesIO }
import from _zstd_native {
    zstd_version_number,
    zstd_is_error,
    zstd_error_name,
    zstd_compress_bound,
    zstd_cctx_new,
    zstd_cctx_free,
    zstd_cctx_set,
    zstd_compress2,
    zstd_dctx_new,
    zstd_dctx_free,
    zstd_dctx_set,
    zstd_decompress_stream,
    zstd_frame_content_size,
    zstd_frame_dict_id,
    ZSTD_C_COMPRESSION_LEVEL,
    ZSTD_D_WINDOW_LOG_MAX
}

glob:pub COMPRESSION_LEVEL_DEFAULT: int = 3;

glob _BUFFER_SIZE: int = 131072,
     _MAX_CHUNK: int = 8388608,
     _WINDOW_LOG_MAX: int = 27,
     _INT_MAX: int = 9223372036854775807;


def _version_string -> str {
    v: int = zstd_version_number();
    return str(v // 10000) + "." + str((v // 100) % 100) + "." + str(v % 100);
}

glob:pub zstd_version: str = _version_string();


obj:pub ZstdError(Exception) {}


obj:pub FrameInfo {
    has decompressed_size: (int | None) = None,
        dictionary_id: int = 0;
}


def _zero_cell -> bytes {
    zero: int = 0;
    return zero.to_bytes(8, "little");
}


obj:pub ZstdDecompressor {
    has eof: bool = False,
        needs_input: bool = True,
        unused_data: bytes = b"",
        _dctx: int = 0,
        _in: bytes = b"",
        _in_pos: int = 0;

    def init {
        self._dctx = zstd_dctx_new();
        if self._dctx == 0 {
            raise MemoryError("ZSTD_createDCtx failed (out of memory)");
        }
        rc: int = zstd_dctx_set(self._dctx, ZSTD_D_WINDOW_LOG_MAX, _WINDOW_LOG_MAX);
        if zstd_is_error(rc) {
            zstd_dctx_free(self._dctx);
            self._dctx = 0;
            raise ZstdError(
                "Error when setting a Zstandard decompression parameter: "
                    + zstd_error_name(rc)
            );
        }
        self.eof = False;
        self.needs_input = True;
        self.unused_data = b"";
        self._in = b"";
        self._in_pos = 0;
    }

    def drop {
        if self._dctx != 0 {
            zstd_dctx_free(self._dctx);
            self._dctx = 0;
        }
    }

    def decompress(data: bytes, max_length: int = -1) -> bytes {
        if self.eof {
            raise EOFError("Already at the end of a Zstandard frame.");
        }
        src = data;
        if self._in_pos < len(self._in) {
            src = self._in[self._in_pos:] + data;
        }
        src_len: int = len(src);
        src_pos = _zero_cell();
        out = b"";
        total: int = 0;
        cap: int = _BUFFER_SIZE;
        if max_length >= 0 and max_length < cap {
            cap = max_length;
        }
        frame_done: bool = False;
        while True {
            if max_length >= 0 and total >= max_length {
                break;
            }
            buf = b"\x00" * cap;
            dst_pos = _zero_cell();
            rc: int = zstd_decompress_stream(
                self._dctx, buf, cap, dst_pos, src, src_len, src_pos
            );
            if zstd_is_error(rc) {
                raise ZstdError(
                    "Unable to decompress Zstandard data: " + zstd_error_name(rc)
                );
            }
            produced: int = int.from_bytes(dst_pos, "little");
            if produced > 0 {
                out = out + buf[0:produced];
                total += produced;
            }
            if rc == 0 {
                frame_done = True;
                break;
            }
            if produced < cap {
                break;
            }
            if cap < _MAX_CHUNK {
                cap = cap * 2;
            }
            if max_length >= 0 and total + cap > max_length {
                cap = max_length - total;
            }
        }
        consumed: int = int.from_bytes(src_pos, "little");
        if frame_done {
            self.eof = True;
            self.needs_input = False;
            self.unused_data = src[consumed:src_len];
            self._in = b"";
            self._in_pos = 0;
        } elif consumed < src_len {
            self.needs_input = False;
            self._in = src;
            self._in_pos = consumed;
        } else {
            self._in = b"";
            self._in_pos = 0;
            if max_length >= 0 and total >= max_length {
                self.needs_input = False;
            } else {
                self.needs_input = True;
            }
        }
        return out;
    }
}


obj:pub ZstdFile {
    has _fp: BytesIO,
        _decompressor: ZstdDecompressor,
        mode: str = "rb",
        closed: bool = False,
        _pos: int = 0,
        _eof: bool = False,
        _size: int = -1;

    def init(file: BytesIO, mode: str = "rb") {
        if mode == "r" or mode == "rb" {
            self.mode = "rb";
        } elif mode == "w"
            or mode == "wb"
            or mode == "a"
            or mode == "ab"
            or mode == "x"
            or mode == "xb" {
            raise ValueError(
                "ZstdFile: write modes are not supported on the native pathway"
            );
        } else {
            raise ValueError("Invalid mode: '" + mode + "'");
        }
        self._fp = file;
        self._decompressor = ZstdDecompressor();
        self._pos = 0;
        self._eof = False;
        self._size = -1;
        self.closed = False;
    }

    def _check_can_read {
        if self.closed {
            raise ValueError("I/O operation on closed file");
        }
    }

    def _read_block(size: int) -> bytes {
        if size == 0 or self._eof {
            return b"";
        }
        data = b"";
        while True {
            if self._decompressor.eof {
                rawblock = self._decompressor.unused_data;
                if len(rawblock) == 0 {
                    rawblock = self._fp.read(_BUFFER_SIZE);
                }
                if len(rawblock) == 0 {
                    break;
                }
                self._decompressor = ZstdDecompressor();
                data = self._decompressor.decompress(rawblock, size);
            } else {
                rawblock = b"";
                if self._decompressor.needs_input {
                    rawblock = self._fp.read(_BUFFER_SIZE);
                    if len(rawblock) == 0 {
                        raise EOFError(
                            "Compressed file ended before the end-of-stream marker was reached"
                        );
                    }
                }
                data = self._decompressor.decompress(rawblock, size);
            }
            if len(data) > 0 {
                break;
            }
        }
        if len(data) == 0 {
            self._eof = True;
            self._size = self._pos;
            return b"";
        }
        self._pos += len(data);
        return data;
    }

    def _readall -> bytes {
        out = b"";
        chunk = self._read_block(_INT_MAX);
        while len(chunk) > 0 {
            out = out + chunk;
            chunk = self._read_block(_INT_MAX);
        }
        return out;
    }

    def readable -> bool {
        self._check_can_read();
        return True;
    }

    def writable -> bool {
        return False;
    }

    def seekable -> bool {
        self._check_can_read();
        return self._fp.seekable();
    }

    def read(size: int = -1) -> bytes {
        self._check_can_read();
        if size < 0 {
            return self._readall();
        }
        out = b"";
        while len(out) < size {
            chunk = self._read_block(size - len(out));
            if len(chunk) == 0 {
                break;
            }
            out = out + chunk;
        }
        return out;
    }

    def read1(size: int = -1) -> bytes {
        self._check_can_read();
        if size < 0 {
            return self._read_block(_BUFFER_SIZE);
        }
        return self._read_block(size);
    }

    def tell -> int {
        self._check_can_read();
        return self._pos;
    }

    def seek(pos: int, whence: int = 0) -> int {
        self._check_can_read();
        target: int = pos;
        if whence == 0 {
            target = pos;
        } elif whence == 1 {
            target = self._pos + pos;
        } elif whence == 2 {
            if self._size < 0 {
                while len(self._read_block(_BUFFER_SIZE)) > 0 {
                    continue;
                }
            }
            target = self._size + pos;
        } else {
            raise ValueError("Invalid value for whence: " + str(whence));
        }
        remaining: int = 0;
        if target < self._pos {
            self._fp.seek(0, 0);
            self._eof = False;
            self._pos = 0;
            self._decompressor = ZstdDecompressor();
            remaining = target;
        } else {
            remaining = target - self._pos;
        }
        while remaining > 0 {
            step: int = _BUFFER_SIZE;
            if remaining < step {
                step = remaining;
            }
            data = self._read_block(step);
            if len(data) == 0 {
                break;
            }
            remaining -= len(data);
        }
        return self._pos;
    }

    def close {
        if self.closed {
            return;
        }
        self._decompressor = ZstdDecompressor();
        self._eof = True;
        self.closed = True;
    }

    def __enter__ -> ZstdFile {
        self._check_can_read();
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }
}


def:pub compress(data: bytes, level: int = 3) -> bytes {
    cctx: int = zstd_cctx_new();
    if cctx == 0 {
        raise MemoryError("ZSTD_createCCtx failed (out of memory)");
    }
    rc: int = zstd_cctx_set(cctx, ZSTD_C_COMPRESSION_LEVEL, level);
    if zstd_is_error(rc) {
        zstd_cctx_free(cctx);
        raise ValueError(
            "compression level "
                + str(level)
                + " not in valid range: "
                + zstd_error_name(rc)
        );
    }
    src_len: int = len(data);
    bound: int = zstd_compress_bound(src_len);
    dst = b"\x00" * bound;
    written: int = zstd_compress2(cctx, dst, bound, data, src_len);
    zstd_cctx_free(cctx);
    if zstd_is_error(written) {
        raise ZstdError(
            "Unable to compress Zstandard data: " + zstd_error_name(written)
        );
    }
    return dst[0:written];
}


def:pub decompress(data: bytes) -> bytes {
    out = b"";
    rest = data;
    while True {
        decomp = ZstdDecompressor();
        out = out + decomp.decompress(rest);
        if not decomp.eof {
            raise ZstdError(
                "Compressed data ended before the end-of-stream marker was reached"
            );
        }
        rest = decomp.unused_data;
        if len(rest) == 0 {
            break;
        }
    }
    return out;
}


def:pub get_frame_info(frame_buffer: bytes) -> FrameInfo {
    content: int = zstd_frame_content_size(frame_buffer);
    if content == -2 {
        raise ZstdError(
            "Error when getting information from the header of a Zstandard frame. "
                + "Ensure the frame_buffer argument starts from the beginning of a "
                + "frame, and its length is not less than the frame header (6~18 bytes)."
        );
    }
    info = FrameInfo();
    if content != -1 {
        info.decompressed_size = content;
    }
    info.dictionary_id = zstd_frame_dict_id(frame_buffer);
    return info;
}
