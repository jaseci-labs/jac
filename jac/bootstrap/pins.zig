//! The pinned toolchain inputs `bootstrap/pins.json` carries, read at configure
//! time. That file is the single source of truth shared with the Jac payload
//! tool (`jaclang.payload.pins`): a slice bump -- dirname, triple, hash, size
//! -- is one edit that `zig build` and `fetch-llvm` can never disagree on.

const std = @import("std");

pub const PINS_PATH = "bootstrap/pins.json";

/// One pinned LLVM slice. `dirname` is the release's top-level dir (also the
/// -Dllvm-dir basename under .llvm-build); `upstream` decides the macOS shim
/// link shape (ThinLTO bitcode + libLTO + external deps for a repackaged
/// official release, plain native archives for a from-source llvm-slice build).
pub const LlvmRelease = struct {
    dirname: []const u8,
    triple: []const u8,
    manifest_sha256: []const u8,
    zip_size: u64,
    upstream: bool,
};

fn root(b: *std.Build) ?std.json.Value {
    const raw = b.build_root.handle.readFileAlloc(b.graph.io, PINS_PATH, b.allocator, .unlimited) catch |err|
        std.debug.panic("{s}: cannot read: {s}", .{ PINS_PATH, @errorName(err) });
    return std.json.parseFromSliceLeaky(std.json.Value, b.allocator, raw, .{}) catch |err|
        std.debug.panic("{s}: invalid JSON: {s}", .{ PINS_PATH, @errorName(err) });
}

fn field(v: ?std.json.Value, key: []const u8) ?std.json.Value {
    const obj = v orelse return null;
    return switch (obj) {
        .object => |o| o.get(key),
        else => null,
    };
}

fn string(v: ?std.json.Value, key: []const u8) []const u8 {
    const f = field(v, key) orelse std.debug.panic("{s}: missing key {s}", .{ PINS_PATH, key });
    return switch (f) {
        .string => |s| s,
        else => std.debug.panic("{s}: {s} must be a string", .{ PINS_PATH, key }),
    };
}

/// The pinned slice for an os-arch token (`linux-x86_64`, ...), or null for
/// platforms we don't pin. Callers pass the resolved -Dtarget's token (the
/// distribution target); the Jac tool passes the build host's -- the two agree
/// in CI, where the runner arch matches the asset arch.
pub fn llvmRelease(b: *std.Build, osarch: ?[]const u8) ?LlvmRelease {
    const oa = osarch orelse return null;
    const slice = field(field(field(root(b), "llvm"), "slices"), oa) orelse return null;
    const size = field(slice, "zip_size") orelse std.debug.panic("{s}: llvm.slices.{s}.zip_size missing", .{ PINS_PATH, oa });
    const upstream = field(slice, "upstream") orelse std.debug.panic("{s}: llvm.slices.{s}.upstream missing", .{ PINS_PATH, oa });
    return .{
        .dirname = string(slice, "dirname"),
        .triple = string(slice, "triple"),
        .manifest_sha256 = string(slice, "manifest_sha256"),
        .zip_size = switch (size) {
            .integer => |i| @intCast(i),
            else => std.debug.panic("{s}: zip_size must be an integer", .{PINS_PATH}),
        },
        .upstream = switch (upstream) {
            .bool => |x| x,
            else => std.debug.panic("{s}: upstream must be a bool", .{PINS_PATH}),
        },
    };
}

/// True when the slice is a libc++ build (`*-libcxx`): its archives are
/// std::__1::* and glibc-floored by the zig pin they were built with, so the
/// shim must link them with `zig c++ -target <floor>` rather than the host
/// g++/libstdc++.
pub fn isLibcxx(rel: LlvmRelease) bool {
    return std.mem.endsWith(u8, rel.triple, "-libcxx");
}

/// The bundled CPython minor (`3.14`), derived from the pbs patch pin.
pub fn pyMinor(b: *std.Build) []const u8 {
    const patch = string(field(root(b), "pbs"), "python");
    const first = std.mem.indexOfScalar(u8, patch, '.') orelse return patch;
    const second = std.mem.indexOfScalarPos(u8, patch, first + 1, '.') orelse return patch;
    return patch[0..second];
}
