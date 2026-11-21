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

    def is_dir -> bool;
}

def _range(data: bytes, start: int, size: int);

def _uint(data: bytes, start: int, size: int) -> int;

def _extra(data: bytes);

def _name(raw: bytes, flags: int) -> str;

def _inflate(data: bytes, size: int) -> bytes;

obj:pub ZipFile {
    has filename: str = "",
        mode: str = "r",
        comment: bytes = b"",
        _data: bytes = b"",
        _files: list[ZipInfo] = [],
        _index: dict[str, int] = {},
        _closed: bool = False;

    def init(file: str, mode: str = "r");
    def _parse;
    def namelist -> list[str];
    def infolist -> list[ZipInfo];
    def getinfo(name: str) -> ZipInfo;
    def read(name: str) -> bytes;
    def close;
    def __enter__ -> ZipFile;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}
