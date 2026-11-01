//! Write a target's pyconfig.h from the build's own probes (pyconfig.zig),
//! compiled and linked with the pinned Zig for that target. The JacPython
//! build probes its own target this way; scripts/jacpython/gen_layouts.jac
//! runs this for every platform it writes a layout table for, so each table
//! is read against that platform's configuration.
//!
//!   zig run bootstrap/pyconfig_tool.zig -- <zig> <deps> <out> <os> <arch> <zig target> <label>
//!
//! <deps> holds the vendored libraries' include/ and lib/ (a build's
//! python/build). The few probes that link a vendored archive only decide
//! library features, not layouts, so another platform's archives serve.
const std = @import("std");
const pyconfig = @import("pyconfig.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len != 8) {
        std.debug.print("usage: pyconfig_tool <zig> <deps> <out> <linux|macos> <x86_64|aarch64> <zig target> <label>\n", .{});
        std.process.exit(2);
    }
    const os = std.meta.stringToEnum(pyconfig.Os, args[4]) orelse return error.UnknownOs;
    const arch = std.meta.stringToEnum(pyconfig.Arch, args[5]) orelse return error.UnknownArch;
    var env = try init.environ_map.clone(a);
    const cache = try std.fs.path.join(a, &.{ args[3], "cc-cache" });
    try env.put("ZIG_LOCAL_CACHE_DIR", cache);
    try env.put("ZIG_GLOBAL_CACHE_DIR", cache);
    if (os == .macos) try env.put("MACOSX_DEPLOYMENT_TARGET", if (arch == .aarch64) "11.0" else "12.0");
    const cc = [_][]const u8{ args[1], "cc", "-target", args[6], "-Wno-unused-command-line-argument" };
    const results = try pyconfig.run(io, a, .{ .os = os, .arch = arch, .cc = &cc, .deps = args[2], .environ = &env }, try std.fs.path.join(a, &.{ args[3], "probes" }), 16);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ args[3], "pyconfig.h" }), .data = try pyconfig.render(a, results, args[7]) });
    try std.Io.Dir.cwd().deleteTree(io, cache);
}
