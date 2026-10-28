import from io { BytesIO }

glob:pub COMPRESSION_LEVEL_DEFAULT: int = 3;

glob _BUFFER_SIZE: int = 131072,
     _MAX_CHUNK: int = 8388608,
     _WINDOW_LOG_MAX: int = 27,
     _INT_MAX: int = 9223372036854775807;


def _version_string -> str;

glob:pub zstd_version: str = _version_string();


obj:pub ZstdError(Exception) {}


obj:pub FrameInfo {
    has decompressed_size: (int | None) = None,
        dictionary_id: int = 0;
}


def _zero_cell -> bytes;


obj:pub ZstdDecompressor {
    has eof: bool = False,
        needs_input: bool = True,
        unused_data: bytes = b"",
        _dctx: int = 0,
        _in: bytes = b"",
        _in_pos: int = 0;

    def init;
    def drop;
    def decompress(data: bytes, max_length: int = -1) -> bytes;
}


obj:pub ZstdFile {
    has _fp: BytesIO,
        _decompressor: ZstdDecompressor,
        mode: str = "rb",
        closed: bool = False,
        _pos: int = 0,
        _eof: bool = False,
        _size: int = -1;

    def init(file: BytesIO, mode: str = "rb");
    def _check_can_read;
    def _read_block(size: int) -> bytes;
    def _readall -> bytes;
    def readable -> bool;
    def writable -> bool;
    def seekable -> bool;
    def read(size: int = -1) -> bytes;
    def read1(size: int = -1) -> bytes;
    def tell -> int;
    def seek(pos: int, whence: int = 0) -> int;
    def close;
    def __enter__ -> ZstdFile;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}


def:pub compress(data: bytes, level: int = 3) -> bytes;


def:pub decompress(data: bytes) -> bytes;


def:pub get_frame_info(frame_buffer: bytes) -> FrameInfo;
