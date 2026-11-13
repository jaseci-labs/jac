impl _signed32(status: int) -> int {
    if status >= 2147483648 {
        return status - 4294967296;
    }
    return status;
}

impl bz2_compress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int, block_size: int
) -> int {
    return _signed32(
        BZ2_bzBuffToBuffCompress(
            dest, dest_len, source, u32(source_len), i32(block_size), 0, 0
        )
    );
}

impl bz2_decompress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int
) -> int {
    return _signed32(
        BZ2_bzBuffToBuffDecompress(dest, dest_len, source, u32(source_len), 0, 0)
    );
}
