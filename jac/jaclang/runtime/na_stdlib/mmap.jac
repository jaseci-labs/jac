import from _mmap_native {
    mm_map,
    mm_unmap,
    mm_sync,
    mm_filesize,
    mm_read,
    mm_write,
    mm_copy,
    mm_errno,
    mm_errstr,
    mm_dup_fd,
    mm_close_fd,
    mm_isreg
}
import from _mmap_platform { mm_anon_flag, mm_sync_flag, mm_resize_requires_mremap }


glob:pub PROT_READ: int = 1,
     PROT_WRITE: int = 2,
     PROT_EXEC: int = 4,
     MAP_SHARED: int = 1,
     MAP_PRIVATE: int = 2,
     ACCESS_READ: int = 1,
     ACCESS_WRITE: int = 2,
     ACCESS_COPY: int = 3,
     ACCESS_DEFAULT: int = 0,
     SEEK_SET: int = 0,
     SEEK_CUR: int = 1,
     SEEK_END: int = 2;

glob:pub MAP_ANONYMOUS: int = mm_anon_flag();
glob MAP_ANON: int = mm_anon_flag(),
     _NO_POS: int = -9223372036854775807;


def _os_err -> str;


obj:pub mmap {
    has _addr: int = 0,
        _len: int = 0,
        _pos: int = 0,
        closed: bool = False,
        _access: int = 0,
        _flags: int = 0,
        _fd: int = -1,
        _writable: bool = False;

    def init(
        fileno: int,
        length: int,
        flags: int = 1,
        prot: int = 3,
        access: int = 0,
        offset: int = 0
    );

    def _check_open;
    def close;
    def drop;
    def __enter__ -> mmap;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
    def __len__ -> int;
    def size -> int;
    def tell -> int;
    def seek(pos: int, whence: int = 0);
    def read(n: int = -1) -> bytes;
    def read_byte -> int;
    def readline -> bytes;
    def _check_writable;
    def write(data: bytes) -> int;
    def write_byte(v: int);
    def __getitem__(i: int) -> int;
    def __setitem__(i: int, v: int);
    def _find_bounds(start: int, end: int) -> tuple[int, int];
    def _scan(sub: bytes, lo: int, hi: int, last: bool) -> int;
    def find(sub: bytes, start: int = _NO_POS, end: int = _NO_POS) -> int;
    def rfind(sub: bytes, start: int = _NO_POS, end: int = _NO_POS) -> int;
    def flush(offset: int = 0, size: int = 0);
    def move(dest: int, src: int, count: int);
    def resize(newsize: int);
}
