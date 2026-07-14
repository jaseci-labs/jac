//! Test fixture: a tiny `python/`+`site/` runtime tree, tarred and
//! zstd-compressed, base64-encoded as source (the repo disallows committed
//! binary files). Decoded by runtime.zig's end-to-end materialize test.
//!
//! Regenerate: untar/re-tar the tree, then `zstd -19 --no-check` +
//! `base64 -w0` (any conformant frame whose window fits
//! runtime.PAYLOAD_WINDOW_LOG works; --no-check matches the packer, which
//! skips the frame checksum because the trailer sha256 already covers the
//! compressed bytes).

const std = @import("std");

pub const payload_tar_zst_b64 =
    "KLUv/WAAJzUFAKIGFhiQOweoKIPvf1WsOfp/7tLIl6JJ/f57TgHKE1YxVYfZEU2T447cqDb2J+4kHhDYvYM7MjJ4rtxdpVhDPUBWYMEoIlOTkSzPPCw6Pl/BGduWX6vlU/OQjpwdIEAzKCM5BTjYesC+/1bjHwNjKhk5NlMQQIU4MAZ1IExGC8ZCJYwBRBl1FY4dMdXsMHuACbmp+nApDcjAvNQBR8pXCQ8waIDlJOI=";

/// Decode the fixture payload into freshly allocated bytes (caller frees).
pub fn payloadAlloc(a: std.mem.Allocator) ![]u8 {
    const dec = std.base64.standard.Decoder;
    const n = try dec.calcSizeForSlice(payload_tar_zst_b64);
    const out = try a.alloc(u8, n);
    try dec.decode(out, payload_tar_zst_b64);
    return out;
}
