//! Bootstrap seed for the jac build: fetch the pinned python-build-standalone
//! CPython. This is the ONE build step that must run before any Python exists,
//! so it stays in Zig (std.http + std.crypto + std.compress.zstd + std.tar --
//! no host tools). Every later step is the Jac payload tool (`jaclang.payload`)
//! running on the interpreter this fetches.
//!
//!     fetch_pbs <os-arch> <dest-dir> <pins.json>
//!
//! Downloads + SHA256SUMS-verifies + extracts the pbs tree into <dest>/python.
//! Idempotent: a no-op when <dest>/python/PYTHON.json exists. The pins (release
//! tag, CPython patch version, flavor, base URL) are read from `pins.json`,
//! the single source of truth shared with the Jac tool's own `fetch-pbs`
//! (which produces the byte-identical tree for any other platform).

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const zstd = std.compress.zstd;

// The window pbs compresses its archives with (verified: `zstd -lv` reports
// 128 MiB); it is all the decode buffer we allocate.
const PBS_WINDOW = 1 << 27;

const Pins = struct { tag: []const u8, python: []const u8, flavor: []const u8, base: []const u8 };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    var args: [4][]const u8 = undefined;
    var n: usize = 0;
    var it = init.minimal.args.iterate();
    while (it.next()) |arg| : (n += 1) {
        if (n < args.len) args[n] = arg;
    }
    if (n < 4) die("usage: fetch_pbs <os-arch> <dest-dir> <pins.json>", .{});
    const osarch = args[1];
    const dest = args[2];
    const pins = try readPins(io, a, args[3]);

    const marker = try std.fmt.allocPrint(a, "{s}/python/PYTHON.json", .{dest});
    if (fileExists(io, marker)) {
        log("fetch-pbs: already present at {s}/python", .{dest});
        return;
    }

    const plat = pbsPlatform(osarch) orelse die("fetch-pbs: unsupported platform '{s}'", .{osarch});
    const asset = try std.fmt.allocPrint(a, "cpython-{s}+{s}-{s}-{s}.tar.zst", .{ pins.python, pins.tag, plat, pins.flavor });
    const url = try std.fmt.allocPrint(a, "{s}/{s}/{s}", .{ pins.base, pins.tag, asset });

    log("fetch-pbs: downloading {s}", .{asset});
    const tarzst = try httpGetAlloc(io, gpa, url);
    defer gpa.free(tarzst);

    // Verify against the release's SHA256SUMS -- this archive becomes the
    // libpython embedded in every distributed binary, so a swapped/MITM'd asset
    // must not slip through.
    const sums_url = try std.fmt.allocPrint(a, "{s}/{s}/SHA256SUMS", .{ pins.base, pins.tag });
    const sums = try httpGetAlloc(io, gpa, sums_url);
    defer gpa.free(sums);
    const expected = findSumLine(sums, asset) orelse die("fetch-pbs: no checksum for {s} in SHA256SUMS", .{asset});
    const actual = sha256Hex(tarzst);
    if (!std.mem.eql(u8, &actual, expected)) {
        die("fetch-pbs: checksum mismatch for {s}\n  expected {s}\n  actual   {s}", .{ asset, expected, &actual });
    }

    // zstd-decompress + untar straight into <dest> (entries start with python/).
    try Io.Dir.cwd().createDirPath(io, dest);
    var ddir = try Io.Dir.cwd().openDir(io, dest, .{});
    defer ddir.close(io);

    const window = try gpa.alloc(u8, PBS_WINDOW + zstd.block_size_max);
    defer gpa.free(window);
    var src = Io.Reader.fixed(tarzst);
    var dz = zstd.Decompress.init(&src, window, .{ .window_len = PBS_WINDOW, .verify_checksum = true });
    // executable_bit_only (not .ignore!) so the bundled `python3.14` keeps its
    // exec bit -- the payload tool spawns it for pip + precompile.
    std.tar.extract(io, ddir, &dz.reader, .{ .mode_mode = .executable_bit_only, .strip_components = 0 }) catch |err|
        die("fetch-pbs: extract failed: {s}", .{@errorName(err)});

    if (!fileExists(io, marker)) die("fetch-pbs: extract produced no PYTHON.json", .{});
    log("fetch-pbs: ready at {s}/python", .{dest});
}

/// `pins.json` -> the `pbs` table. Only the four keys the seed needs are read.
fn readPins(io: Io, a: Allocator, path: []const u8) !Pins {
    const raw = Io.Dir.cwd().readFileAlloc(io, path, a, .unlimited) catch |err|
        die("fetch-pbs: cannot read {s}: {s}", .{ path, @errorName(err) });
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, a, raw, .{}) catch |err|
        die("fetch-pbs: {s} is not valid JSON: {s}", .{ path, @errorName(err) });
    const pbs = switch (parsed) {
        .object => |o| o.get("pbs") orelse die("fetch-pbs: {s} has no \"pbs\" table", .{path}),
        else => die("fetch-pbs: {s} must be a JSON object", .{path}),
    };
    return .{
        .tag = jsonString(pbs, "tag", path),
        .python = jsonString(pbs, "python", path),
        .flavor = jsonString(pbs, "flavor", path),
        .base = jsonString(pbs, "base", path),
    };
}

fn jsonString(table: std.json.Value, key: []const u8, path: []const u8) []const u8 {
    const v = switch (table) {
        .object => |o| o.get(key) orelse die("fetch-pbs: {s}: pbs.{s} missing", .{ path, key }),
        else => die("fetch-pbs: {s}: \"pbs\" must be an object", .{path}),
    };
    return switch (v) {
        .string => |s| s,
        else => die("fetch-pbs: {s}: pbs.{s} must be a string", .{ path, key }),
    };
}

/// Map an os-arch token to the pbs platform triple.
fn pbsPlatform(osarch: []const u8) ?[]const u8 {
    const m = std.StaticStringMap([]const u8).initComptime(.{
        .{ "macos-aarch64", "aarch64-apple-darwin" },
        .{ "macos-x86_64", "x86_64-apple-darwin" },
        .{ "linux-x86_64", "x86_64-unknown-linux-gnu" },
        .{ "linux-aarch64", "aarch64-unknown-linux-gnu" },
    });
    return m.get(osarch);
}

/// SHA256SUMS lines are `<hex>  <filename>`; return the hex for `asset`.
fn findSumLine(sums: []const u8, asset: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, sums, '\n');
    while (lines.next()) |line| {
        var toks = std.mem.tokenizeAny(u8, line, " \t\r");
        const hex = toks.next() orelse continue;
        const name = toks.next() orelse continue;
        if (std.mem.eql(u8, name, asset)) return hex;
    }
    return null;
}

fn httpGetAlloc(io: Io, gpa: Allocator, url: []const u8) ![]u8 {
    var client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const res = client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &aw.writer,
        .redirect_behavior = @enumFromInt(10),
    }) catch |err| die("http fetch failed for {s}: {s}", .{ url, @errorName(err) });
    if (res.status != .ok) die("http {d} for {s}", .{ @intFromEnum(res.status), url });
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

fn sha256Hex(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    var hex: [64]u8 = undefined;
    const chars = "0123456789abcdef";
    for (digest, 0..) |b, i| {
        hex[i * 2] = chars[b >> 4];
        hex[i * 2 + 1] = chars[b & 0xf];
    }
    return hex;
}

fn fileExists(io: Io, path: []const u8) bool {
    const f = Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    f.close(io);
    return true;
}

fn die(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt ++ "\n", args);
    std.process.exit(1);
}

fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

test "findSumLine picks the matching asset" {
    const sums = "aaaa  x.tar.zst\nbbbb  cpython-3.14.6+1-x-y.tar.zst\n";
    try std.testing.expectEqualStrings("bbbb", findSumLine(sums, "cpython-3.14.6+1-x-y.tar.zst").?);
    try std.testing.expect(findSumLine(sums, "nope") == null);
}

test "pbsPlatform maps the four shipped legs" {
    try std.testing.expectEqualStrings("x86_64-unknown-linux-gnu", pbsPlatform("linux-x86_64").?);
    try std.testing.expect(pbsPlatform("plan9-mips") == null);
}
