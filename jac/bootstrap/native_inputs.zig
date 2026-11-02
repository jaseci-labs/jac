//! The inputs of the LLVMPY_* shim: the native C++ sources, the build
//! recipe, and the LLVM pin. The JacPython build key and the shim's artifact
//! record both hash exactly this; the artifact router recomputes it on the
//! Jac side (`shim_inputs_digest` in llvm/shim_path.jac) to decide whether a
//! placed shim is current.
const std = @import("std");
const Io = std.Io;

pub const toolchain_inputs = [_][]const u8{ "build.zig", "build.zig.zon", "bootstrap/pins.json" };

pub fn hashShimInputs(io: Io, a: std.mem.Allocator, root: []const u8, hash: *std.crypto.hash.sha2.Sha256) !void {
    for (toolchain_inputs) |path| {
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, path }), a, .unlimited));
    }
    try hashNativeSources(io, a, root, hash);
}

pub fn shimInputsHex(io: Io, a: std.mem.Allocator, root: []const u8) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    try hashShimInputs(io, a, root, &hash);
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

pub fn hashNativeSources(io: Io, a: std.mem.Allocator, root: []const u8, hash: *std.crypto.hash.sha2.Sha256) !void {
    var dir = try Io.Dir.cwd().openDir(io, try std.fs.path.join(a, &.{ root, "native" }), .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walkSelectively(a);
    defer walker.deinit();
    var paths: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory) {
            if (!std.mem.startsWith(u8, entry.basename, ".")) try walker.enter(io, entry);
        } else if (entry.kind == .file and (std.mem.endsWith(u8, entry.path, ".cpp") or
            std.mem.endsWith(u8, entry.path, ".h") or std.mem.endsWith(u8, entry.path, ".hpp")))
        {
            try paths.append(a, try a.dupe(u8, entry.path));
        }
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn less(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.less);
    for (paths.items) |path| {
        hash.update("native/");
        hash.update(path);
        hash.update(try dir.readFileAlloc(io, path, a, .unlimited));
    }
}

