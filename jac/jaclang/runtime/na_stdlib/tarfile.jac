import os;
import from os.path { abspath, normpath }
import from io { BytesIO }
import from compression.zstd { ZstdFile }

glob:pub BLOCKSIZE: int = 512,
     RECORDSIZE: int = 10240;

glob:pub USTAR_FORMAT: int = 0,
     GNU_FORMAT: int = 1,
     PAX_FORMAT: int = 2,
     DEFAULT_FORMAT: int = 2;

glob:pub REGTYPE: bytes = b"0",
     AREGTYPE: bytes = b"\x00",
     LNKTYPE: bytes = b"1",
     SYMTYPE: bytes = b"2",
     CHRTYPE: bytes = b"3",
     BLKTYPE: bytes = b"4",
     DIRTYPE: bytes = b"5",
     FIFOTYPE: bytes = b"6",
     CONTTYPE: bytes = b"7",
     GNUTYPE_LONGNAME: bytes = b"L",
     GNUTYPE_LONGLINK: bytes = b"K",
     GNUTYPE_SPARSE: bytes = b"S",
     XHDTYPE: bytes = b"x",
     XGLTYPE: bytes = b"g",
     SOLARIS_XHDTYPE: bytes = b"X";

glob _COPY_BUFSIZE: int = 65536,
     _STREAM_CHUNK: int = 1048576,
     _MODE_NONE: int = -1;


obj:pub TarError(Exception) {}


obj:pub ReadError(TarError) {}


obj:pub CompressionError(TarError) {}


obj:pub StreamError(TarError) {}


obj:pub ExtractError(TarError) {}


obj:pub HeaderError(TarError) {}


obj InvalidHeaderError(HeaderError) {}


obj:pub FilterError(TarError) {}


obj:pub AbsolutePathError(FilterError) {}


obj:pub OutsideDestinationError(FilterError) {}


obj:pub SpecialFileError(FilterError) {}


obj:pub AbsoluteLinkError(FilterError) {}


obj:pub LinkOutsideDestinationError(FilterError) {}


def _is_supported_type(t: bytes) -> bool;


def _is_gnu_type(t: bytes) -> bool;


def _nts(s: bytes) -> str;


def _nti(s: bytes) -> int;


def _blocks(size: int) -> int;


def _all_zero(buf: bytes) -> bool;


def _checksums(buf: bytes) -> tuple[(int, int)];


def _parse_int_field(value: str) -> int;


obj:pub TarInfo {
    has name: str = "",
        mode: int = 0o644,
        uid: int = 0,
        gid: int = 0,
        size: int = 0,
        mtime: int = 0,
        chksum: int = 0,
        `type: bytes = b"0",
        linkname: str = "",
        uname: str = "",
        gname: str = "",
        devmajor: int = 0,
        devminor: int = 0,
        offset: int = 0,
        offset_data: int = 0,
        pax_headers: dict[str, str] = {};

    def isreg -> bool;
    def isfile -> bool;
    def isdir -> bool;
    def issym -> bool;
    def islnk -> bool;
    def ischr -> bool;
    def isblk -> bool;
    def isfifo -> bool;
    def issparse -> bool;
    def isdev -> bool;
    def _clone -> TarInfo;
    def _apply_pax_info(pax_headers: dict[str, str]);
}


def frombuf(buf: bytes, dircheck: bool = True) -> TarInfo;


def _frombuf_checked(buf: bytes, dircheck: bool, at_start: bool) -> TarInfo;


def _parse_pax_records(buf: bytes, into: dict[str, str]);


obj:pub TarFile {
    has _data: bytes = b"",
        name: (str | None) = None,
        mode: str = "r",
        stream: bool = False,
        offset: int = 0,
        _closed: bool = False,
        _members: list[TarInfo] = [],
        pax_headers: dict[str, str] = {},
        _firstmember: (TarInfo | None) = None,
        _loaded: bool = False,
        _src: (ZstdFile | None) = None,
        _window: bytes = b"",
        _window_start: int = 0,
        _src_eof: bool = False;

    def init(
        data: bytes = b"",
        name: (str | None) = None,
        mode: str = "r",
        stream: bool = False,
        src: (ZstdFile | None) = None
    );

    def _check;
    def _read_at(pos: int, n: int) -> bytes;
    def _discard(count: int, src: ZstdFile);
    def _read_header(at_start: bool, dircheck: bool) -> (TarInfo | None);
    def _proc_builtin(info: TarInfo) -> TarInfo;
    def _proc_gnulong(info: TarInfo) -> (TarInfo | None);
    def _proc_pax(info: TarInfo) -> (TarInfo | None);
    def _proc_member(info: TarInfo) -> (TarInfo | None);
    def next -> (TarInfo | None);
    def __iter__ -> TarFile;
    def __next__ -> TarInfo;
    def getmembers -> list[TarInfo];
    def getnames -> list[str];
    def extractfile(member: TarInfo) -> (BytesIO | None);
    def _within(target: str, dest: str) -> bool;
    def _filter_member(member: TarInfo, dest_path: str, kind: str) -> TarInfo;
    def _makefile(info: TarInfo, targetpath: str);
    def _makedir(info: TarInfo, targetpath: str);
    def _makelink(info: TarInfo, targetpath: str, extraction_root: str);
    def _chmod(info: TarInfo, targetpath: str);
    def _utime(info: TarInfo, targetpath: str);
    def _extract_member(
        info: TarInfo, targetpath: str, set_attrs: bool, extraction_root: str
    );

    def extract(member: TarInfo, path: str = "", filter: str = "data");
    def extractall(path: str = ".", filter: str = "data");
    def close;
    def __enter__ -> TarFile;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}


def _as_str(value: (str | None)) -> str;


def _open_tar(
    name: (str | None) = None,
    mode: str = "r",
    fileobj: (ZstdFile | None) = None,
    bufsize: int = 10240
) -> TarFile;


def:pub open(
    name: (str | None) = None,
    mode: str = "r",
    fileobj: (ZstdFile | None) = None,
    bufsize: int = 10240
) -> TarFile;


def:pub is_tarfile(name: str) -> bool;
