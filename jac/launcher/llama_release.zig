//! Single source of truth for the pinned `llama-server` runner assets.
//!
//! Consumed by BOTH launcher/payload.zig (`fetch-llama` downloads + verifies +
//! stages the runner for a build target) and build.zig (the fetch-llama step +
//! the mkpayload `--llama` staging). Keeping the pin here means a version bump
//! -- tag, asset names, sha256s -- is one edit that build and fetch can never
//! disagree on.
//!
//! llama.cpp publishes no SHASUMS file, so unlike bun (which verifies against a
//! fetched SHASUMS256.txt) the sha256 here IS the trust anchor -- exactly like
//! llvm_release.zig's manifest_sha256. On a version bump, re-pin every sha256
//! from the GitHub releases API `digest` field and verify against a download.
//!
//! Two variants are bundled per Linux platform: `cpu` (the always-works
//! baseline) and `vulkan` (NVIDIA/AMD/Intel GPU). macOS arm64 ships a single
//! binary with Metal compiled in (named `cpu`). Heavy accelerators (ROCm,
//! Linux CUDA) are fetched on demand at runtime (see byllm/llama_sums.lock),
//! never bundled.

const std = @import("std");

/// The pinned llama.cpp build tag (also embedded in every asset filename).
pub const LLAMA_VER = "b10019";
pub const LLAMA_BASE = "https://github.com/ggml-org/llama.cpp/releases/download";

const P = "llama-" ++ LLAMA_VER ++ "-bin-";

/// One bundled runner variant: the daemon resolves `_llama/<variant>/llama-server`.
pub const LlamaAsset = struct {
    variant: []const u8,
    asset: []const u8,
    sha256: []const u8,
};

const linux_x86_64 = [_]LlamaAsset{
    .{ .variant = "cpu", .asset = P ++ "ubuntu-x64.tar.gz", .sha256 = "dca9238166b038ca9144d20952247edacaadc531cd4555e07242185342da3e30" },
    .{ .variant = "vulkan", .asset = P ++ "ubuntu-vulkan-x64.tar.gz", .sha256 = "63b1999cdfdcf6acd979f28db9b8c4276b2328d512f431dd99a00d2399ef98cb" },
};

const linux_aarch64 = [_]LlamaAsset{
    .{ .variant = "cpu", .asset = P ++ "ubuntu-arm64.tar.gz", .sha256 = "3969ece56aa0a5c8daa550b15ca3a9eabc063a2a9c0516a50fe307dc2f3101f6" },
    .{ .variant = "vulkan", .asset = P ++ "ubuntu-vulkan-arm64.tar.gz", .sha256 = "718ea841edb5af22904e11746c95b73c36e2118df4d84e3db94ff9a3284bb719" },
};

// macOS arm64: single binary with Metal compiled in (no separate GPU variant).
const macos_aarch64 = [_]LlamaAsset{
    .{ .variant = "cpu", .asset = P ++ "macos-arm64.tar.gz", .sha256 = "059ba8f859edeb321d45d51caca3adb67571fd5c1a6c1d7d9b42254b68dd943b" },
};

/// Bundled runner variants for `osarch` (the osArchString token), or an empty
/// slice for platforms we do not ship a bundled runner for. macos-x86_64 is
/// intentionally unpinned: it is not in the released target set.
pub fn llamaVariants(osarch: []const u8) []const LlamaAsset {
    if (std.mem.eql(u8, osarch, "linux-x86_64")) return &linux_x86_64;
    if (std.mem.eql(u8, osarch, "linux-aarch64")) return &linux_aarch64;
    if (std.mem.eql(u8, osarch, "macos-aarch64")) return &macos_aarch64;
    return &.{};
}
