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


def _signed32(status: int) -> int;


def:pub bz2_compress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int, block_size: int
) -> int;


def:pub bz2_decompress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int
) -> int;
