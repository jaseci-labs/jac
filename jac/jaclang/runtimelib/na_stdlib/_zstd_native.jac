import from zstd { def ZSTD_versionNumber -> u32;  }
import from zstd { def ZSTD_isError(code: u64) -> u32;  }
import from zstd { def ZSTD_getErrorName(code: u64) -> str;  }
import from zstd { def ZSTD_compressBound(src_size: u64) -> u64;  }
import from zstd { def ZSTD_createCCtx -> int;  }
import from zstd { def ZSTD_freeCCtx(cctx: int) -> u64;  }
import from zstd {
    def ZSTD_CCtx_setParameter(cctx: int, param: i32, value: i32) -> u64;
}
import from zstd {
    def ZSTD_compress2(
        cctx: int, dst: bytes, dst_capacity: u64, src: bytes, src_size: u64
    ) -> u64;
}
import from zstd { def ZSTD_createDCtx -> int;  }
import from zstd { def ZSTD_freeDCtx(dctx: int) -> u64;  }
import from zstd {
    def ZSTD_DCtx_setParameter(dctx: int, param: i32, value: i32) -> u64;
}
import from zstd {
    def ZSTD_decompressStream_simpleArgs(
        dctx: int,
        dst: bytes,
        dst_capacity: u64,
        dst_pos: bytes,
        src: bytes,
        src_size: u64,
        src_pos: bytes
    ) -> u64;
}
import from zstd { def ZSTD_getFrameContentSize(src: bytes, src_size: u64) -> u64;  }
import from zstd { def ZSTD_getDictID_fromFrame(src: bytes, src_size: u64) -> u32;  }
import from zstd { def ZSTD_DStreamOutSize -> u64;  }

glob:pub ZSTD_C_COMPRESSION_LEVEL: int = 100,
     ZSTD_C_WINDOW_LOG: int = 101,
     ZSTD_C_CHECKSUM_FLAG: int = 201,
     ZSTD_D_WINDOW_LOG_MAX: int = 100;


def:pub zstd_version_number -> int {
    return ZSTD_versionNumber();
}


def:pub zstd_is_error(code: int) -> bool {
    return ZSTD_isError(code) != 0;
}


def:pub zstd_error_name(code: int) -> str {
    return ZSTD_getErrorName(code);
}


def:pub zstd_compress_bound(src_size: int) -> int {
    return ZSTD_compressBound(src_size);
}


def:pub zstd_cctx_new -> int {
    return ZSTD_createCCtx();
}


def:pub zstd_cctx_free(cctx: int) {
    if cctx != 0 {
        ZSTD_freeCCtx(cctx);
    }
}


def:pub zstd_cctx_set(cctx: int, param: int, value: int) -> int {
    return ZSTD_CCtx_setParameter(cctx, param, value);
}


def:pub zstd_compress2(
    cctx: int, dst: bytes, dst_capacity: int, src: bytes, src_size: int
) -> int {
    return ZSTD_compress2(cctx, dst, dst_capacity, src, src_size);
}


def:pub zstd_dctx_new -> int {
    return ZSTD_createDCtx();
}


def:pub zstd_dctx_free(dctx: int) {
    if dctx != 0 {
        ZSTD_freeDCtx(dctx);
    }
}


def:pub zstd_dctx_set(dctx: int, param: int, value: int) -> int {
    return ZSTD_DCtx_setParameter(dctx, param, value);
}


def:pub zstd_decompress_stream(
    dctx: int,
    dst: bytes,
    dst_capacity: int,
    dst_pos: bytes,
    src: bytes,
    src_size: int,
    src_pos: bytes
) -> int {
    return ZSTD_decompressStream_simpleArgs(
        dctx, dst, dst_capacity, dst_pos, src, src_size, src_pos
    );
}


def:pub zstd_frame_content_size(src: bytes) -> int {
    return ZSTD_getFrameContentSize(src, len(src));
}


def:pub zstd_frame_dict_id(src: bytes) -> int {
    return ZSTD_getDictID_fromFrame(src, len(src));
}


def:pub zstd_dstream_out_size -> int {
    return ZSTD_DStreamOutSize();
}


def:pub ZSTD_trace_compress_begin(cctx: int) -> u64 {
    return 0;
}


def:pub ZSTD_trace_compress_end(ctx: u64, trace: int) -> None {
    return;
}


def:pub ZSTD_trace_decompress_begin(dctx: int) -> u64 {
    return 0;
}


def:pub ZSTD_trace_decompress_end(ctx: u64, trace: int) -> None {
    return;
}


def _trace_anchor -> int {
    return ZSTD_trace_compress_begin(0) + ZSTD_trace_decompress_begin(0);
}

glob _zstd_trace_anchor: int = _trace_anchor();
