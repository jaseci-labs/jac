import from bz2 {
    def BZ2_bzBuffToBuffCompress(
        dst: bytes,
        dlen: bytes,
        src: bytes,
        slen: u32,
        block_size: i32,
        verbosity: i32,
        work_factor: i32
    ) -> i32;
}
import from bz2 {
    def BZ2_bzBuffToBuffDecompress(
        dst: bytes, dlen: bytes, src: bytes, slen: u32, small: i32, verbosity: i32
    ) -> i32;
}


def _signed32(status: int) -> int {
    if status >= 2147483648 {
        return status - 4294967296;
    }
    return status;
}


def:pub bz2_compress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int, block_size: int
) -> int {
    return _signed32(
        BZ2_bzBuffToBuffCompress(dest, dest_len, source, source_len, block_size, 0, 0)
    );
}


def:pub bz2_decompress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int
) -> int {
    return _signed32(
        BZ2_bzBuffToBuffDecompress(dest, dest_len, source, source_len, 0, 0)
    );
}
