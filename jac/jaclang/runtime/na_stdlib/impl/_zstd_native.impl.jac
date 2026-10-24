impl zstd_version_number -> int {
    return ZSTD_versionNumber();
}

impl zstd_is_error(code: int) -> bool {
    return ZSTD_isError(u64(code)) != 0;
}

impl zstd_error_name(code: int) -> str {
    return ZSTD_getErrorName(u64(code));
}

impl zstd_compress_bound(src_size: int) -> int {
    return int(ZSTD_compressBound(u64(src_size)));
}

impl zstd_cctx_new -> int {
    return ZSTD_createCCtx();
}

impl zstd_cctx_free(cctx: int) {
    if cctx != 0 {
        ZSTD_freeCCtx(cctx);
    }
}

impl zstd_cctx_set(cctx: int, param: int, value: int) -> int {
    return int(ZSTD_CCtx_setParameter(cctx, i32(param), i32(value)));
}

impl zstd_compress2(
    cctx: int, dst: bytes, dst_capacity: int, src: bytes, src_size: int
) -> int {
    return int(ZSTD_compress2(cctx, dst, u64(dst_capacity), src, u64(src_size)));
}

impl zstd_dctx_new -> int {
    return ZSTD_createDCtx();
}

impl zstd_dctx_free(dctx: int) {
    if dctx != 0 {
        ZSTD_freeDCtx(dctx);
    }
}

impl zstd_dctx_set(dctx: int, param: int, value: int) -> int {
    return int(ZSTD_DCtx_setParameter(dctx, i32(param), i32(value)));
}

impl zstd_decompress_stream(
    dctx: int,
    dst: bytes,
    dst_capacity: int,
    dst_pos: bytes,
    src: bytes,
    src_size: int,
    src_pos: bytes
) -> int {
    return int(
        ZSTD_decompressStream_simpleArgs(
            dctx, dst, u64(dst_capacity), dst_pos, src, u64(src_size), src_pos
        )
    );
}

impl zstd_frame_content_size(src: bytes) -> int {
    return int(ZSTD_getFrameContentSize(src, u64(len(src))));
}

impl zstd_frame_dict_id(src: bytes) -> int {
    return ZSTD_getDictID_fromFrame(src, u64(len(src)));
}

impl zstd_dstream_out_size -> int {
    return int(ZSTD_DStreamOutSize());
}

impl ZSTD_trace_compress_begin(cctx: int) -> u64 {
    return 0;
}

impl ZSTD_trace_compress_end(ctx: u64, trace: int) -> None {
    return;
}

impl ZSTD_trace_decompress_begin(dctx: int) -> u64 {
    return 0;
}

impl ZSTD_trace_decompress_end(ctx: u64, trace: int) -> None {
    return;
}

impl _trace_anchor -> int {
    return int(ZSTD_trace_compress_begin(0) + ZSTD_trace_decompress_begin(0));
}
