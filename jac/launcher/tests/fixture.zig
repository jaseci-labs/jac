//! Test fixture: a tiny `python/`+`site/` runtime tree, tarred and
//! zstd-compressed, base64-encoded as source (the repo disallows committed
//! binary files). Decoded by runtime.zig's end-to-end materialize test.

const std = @import("std");

pub const payload_tar_zst_b64 =
    "KLUv/WQAT+0VAKYaWCtgWQcwDMMjQSSAMJrQHW633a9KpkZjkgGAR8B67iallFKaWu0khWMh/G0KSQBQAE0AAMPNO59PxHHuLnev7k7wGZoezSyBGPeADxACn87aGyVzUBWmwhcJtv6dBMsXzH96zdnSn5dS/BrTium0t+aJsf5/D0VUSRtHXhZOBOKRZQnOPArIUpl0IhLLZWpc0PXWh/1LvX/oW78+NIXsVqpszbez6U8vfuogtwnclRm4cRtW1GK7nM4DAN+lEAx3TCRHb7PGEfRaYukQ1neZeo28xjaJpV3SSLTxba717Ue/iuvXp7fifG8uZ6VH7hUJtkZezvU67qWP1xnT/PZeUoo18nDF9t8dBdHFM79bKIkyqohoGmMXWSQrsaE/V/rpfJ/acW/TyGMkZkskTzOxKMMUOdJ/TO1javH3VY21flsrFlmsjcL1Oj77ur7F1OqMTbt87XDk2Uvdob9qXa19/AGAg6ChnYNoZiRJUVIYxqBKApFApIobe+j9h13hofgfbGQDNPXS4QArQX6kNSROwFbNN2BS/QEWKS4QsgK5DYAZ0g6YrLwBFpRggZAcMB2E9HeVp6DC1i4wgY8NIPXtHACQk5/TWwQuIKvAV2NW+8jzqQXCRIdjXeF+AvxPoAGRcQzqIZrKvzkAVwOvch5W5wAIKguEFEFcA9BibCrxwPSALcaoOpMuH/KXRcIHbNV5q2ylF6hzW1XVAEiSBJ6YSdk1nroGDAayAZaa2T2AIJxf9FZBH6BVyd6AUAty5+kC6B3IawAtVLuKwcTbeABrq1VVBFPyB/I5qtE79QNiFBbAVEHekOFYVxyQEGhPA8gIlkqAAgkDDAU+529AZllVzo+BM0wcgBLZ0hVsNe4aIA5hC2jqlbUrXXDofoHakbWQfj3iHtth5iWdgqXTLqZKKiC98G7GShMinK4UpMUOZg==";

/// Decode the fixture payload into freshly allocated bytes (caller frees).
pub fn payloadAlloc(a: std.mem.Allocator) ![]u8 {
    const dec = std.base64.standard.Decoder;
    const n = try dec.calcSizeForSlice(payload_tar_zst_b64);
    const out = try a.alloc(u8, n);
    try dec.decode(out, payload_tar_zst_b64);
    return out;
}
