//! Test fixture: a tiny `python/`+`site/` runtime tree, tarred and
//! gzip-compressed, base64-encoded as source (the repo disallows committed
//! binary files). Decoded by runtime.zig's end-to-end materialize test.

const std = @import("std");

pub const payload_tar_gz_b64 =
    "H4sIAAAAAAACA+3VSw6CMBSF4Y5dhRvAPuhjPSA3kaBA4JrI7iUyIxrjoA2R803aWQd/0tNPfOlaKWJSs+Dc65ytzzf3YLwXRycSuI9cDPOTYp/6pf+1LuV2+mulcov+ifvfiqGh4cQPjtDfW/u5vzGr/kY5JY4K/RP0Lyemc1dRtvQ/CNiRsWaSkd/4ff990Br/f7L+LY1MldxMf610yNE/df+KqI8w/9/3X6/3X3trsP8pLOmzrsHuAwAAAAAAAAAAAAAA/IUnlAy0nAAoAAA=";

/// Decode the fixture payload into freshly allocated bytes (caller frees).
pub fn payloadAlloc(a: std.mem.Allocator) ![]u8 {
    const dec = std.base64.standard.Decoder;
    const n = try dec.calcSizeForSlice(payload_tar_gz_b64);
    const out = try a.alloc(u8, n);
    try dec.decode(out, payload_tar_gz_b64);
    return out;
}
