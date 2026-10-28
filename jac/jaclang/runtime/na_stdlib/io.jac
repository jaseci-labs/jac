glob:pub SEEK_SET: int = 0,
     SEEK_CUR: int = 1,
     SEEK_END: int = 2,
     DEFAULT_BUFFER_SIZE: int = 131072;


obj:pub UnsupportedOperation(OSError) {}


obj:pub BufferedIOBase {
    has closed: bool = False;

    def readable -> bool;
    def writable -> bool;
    def seekable -> bool;
    def read(size: int = -1) -> bytes;
    def read1(size: int = -1) -> bytes;
    def write(b: bytes) -> int;
    def seek(pos: int, whence: int = 0) -> int;
    def tell -> int;
    def flush;
    def close;
    def __enter__ -> BufferedIOBase;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}


obj:pub BytesIO {
    has _buf: bytes = b"",
        _pos: int = 0,
        closed: bool = False;

    def init(initial_bytes: bytes = b"");
    def _check_closed;
    def readable -> bool;
    def writable -> bool;
    def seekable -> bool;
    def read(size: int = -1) -> bytes;
    def read1(size: int = -1) -> bytes;
    def write(b: bytes) -> int;
    def seek(pos: int, whence: int = 0) -> int;
    def tell -> int;
    def getvalue -> bytes;
    def flush;
    def close;
    def __enter__ -> BytesIO;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}

obj:pub FileIO {
    has name: str = "",
        mode: str = "rb",
        closed: bool = False,
        _stream: int = 0;

    def init(file: str, mode: str = "r");
    def _check_closed;
    def readable -> bool;
    def writable -> bool;
    def seekable -> bool;
    def read(size: int = -1) -> bytes;
    def readall -> bytes;
    def write(b: bytes) -> int;
    def seek(pos: int, whence: int = 0) -> int;
    def tell -> int;
    def flush;
    def close;
    def __enter__ -> FileIO;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}

obj:pub StringIO {
    has _buf: str = "",
        _pos: int = 0,
        closed: bool = False;

    def init(initial_value: str = "");
    def _check_closed;
    def readable -> bool;
    def writable -> bool;
    def seekable -> bool;
    def read(size: int = -1) -> str;
    def readline(size: int = -1) -> str;
    def write(s: str) -> int;
    def getvalue -> str;
    def tell -> int;
    def seek(pos: int, whence: int = 0) -> int;
    def close;
    def __enter__ -> StringIO;
    def __exit__(exc_type: object, exc: object, tb: object);
}
