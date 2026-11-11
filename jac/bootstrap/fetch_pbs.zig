//! Bootstrap seed for the jac build: fetch the pinned python-build-standalone
//! CPython. One of the two steps that must run before any Python exists (the
//! other is `fetch_typeshed.zig`), so it stays in Zig (std.http + std.crypto +
//! std.compress.zstd + std.tar -- no host tools). Every later step is the Jac
//! payload tool (`jaclang.dist.payload`) running on the interpreter this fetches.
//!
//!     fetch_pbs <os-arch> <dest-dir> <pins.json>
//!
//! Downloads, checks against the sha256 pinned in pins.json, and extracts the pbs tree into <dest>/python.
//! Idempotent: a no-op when <dest>/python/PBS_ASSET names the pinned archive.
//! The archive is extracted beside the tree and swapped in only once complete,
//! so an interrupted fetch or a pin change never leaves a tree that passes for
//! current. The pins (release tag, CPython patch version, flavor, base URL)
//! are read from `pins.json`.
//! The tree has the layout every consumer of a Python build reads:
//! python/install (the interpreter and libpython), python/build/lib (the C
//! floor archives `jac build --native` links) and python/licenses.

const std = @import("std");
const seed = @import("seed.zig");
const die = seed.die;
const log = seed.log;
const fileExists = seed.fileExists;
const httpGetAlloc = seed.httpGetAlloc;
const sha256Hex = seed.sha256Hex;
const Io = std.Io;
const Allocator = std.mem.Allocator;
const zstd = std.compress.zstd;

// The window pbs compresses its archives with (verified: `zstd -lv` reports
// 128 MiB); it is all the decode buffer we allocate.
const PBS_WINDOW = 1 << 27;

// Written into the tree only after a complete extract: the archive it came from.
const STAMP = "PBS_ASSET";

const Pins = struct { tag: []const u8, python: []const u8, flavor: []const u8, base: []const u8, sha256: []const u8 };

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
    const pins = try readPins(io, a, args[3], osarch);

    const plat = pbsPlatform(osarch) orelse die("fetch-pbs: unsupported platform '{s}'", .{osarch});
    const asset = try std.fmt.allocPrint(a, "cpython-{s}+{s}-{s}-{s}.tar.zst", .{ pins.python, pins.tag, plat, pins.flavor });

    const tree = try std.fmt.allocPrint(a, "{s}/python", .{dest});
    const stamp = try std.fmt.allocPrint(a, "{s}/{s}", .{ tree, STAMP });
    if (Io.Dir.cwd().readFileAlloc(io, stamp, a, .limited(1024))) |recorded| {
        if (std.mem.eql(u8, std.mem.trimEnd(u8, recorded, "\n"), asset)) {
            log("fetch-pbs: {s} already present at {s}", .{ asset, tree });
            return;
        }
    } else |_| {}
    const url = try std.fmt.allocPrint(a, "{s}/{s}/{s}", .{ pins.base, pins.tag, asset });

    log("fetch-pbs: downloading {s}", .{asset});
    const tarzst = try httpGetAlloc(io, gpa, url);
    defer gpa.free(tarzst);

    // Verify against the hash pinned in pins.json, not one fetched beside the
    // archive: this archive becomes the interpreter in every distributed
    // binary, so only a reviewed pin change may change its bytes.
    const actual = sha256Hex(tarzst);
    if (!std.mem.eql(u8, &actual, pins.sha256)) {
        die("fetch-pbs: checksum mismatch for {s}\n  pinned {s}\n  actual {s}", .{ asset, pins.sha256, &actual });
    }

    // zstd-decompress + untar into a staging dir beside the tree (entries
    // start with python/), then swap the finished tree in.
    const staging = try std.fmt.allocPrint(a, "{s}/.pbs-staging", .{dest});
    try Io.Dir.cwd().deleteTree(io, staging);
    try Io.Dir.cwd().createDirPath(io, staging);
    var ddir = try Io.Dir.cwd().openDir(io, staging, .{});
    defer ddir.close(io);

    const window = try gpa.alloc(u8, PBS_WINDOW + zstd.block_size_max);
    defer gpa.free(window);
    var src = Io.Reader.fixed(tarzst);
    var dz = zstd.Decompress.init(&src, window, .{ .window_len = PBS_WINDOW, .verify_checksum = true });
    // executable_bit_only (not .ignore!) so the bundled `python3.14` keeps its
    // exec bit -- the payload tool spawns it for pip + precompile.
    std.tar.extract(io, ddir, &dz.reader, .{ .mode_mode = .executable_bit_only, .strip_components = 0 }) catch |err|
        die("fetch-pbs: extract failed: {s}", .{@errorName(err)});

    const staged = try std.fmt.allocPrint(a, "{s}/python", .{staging});
    const staged_json = try std.fmt.allocPrint(a, "{s}/PYTHON.json", .{staged});
    if (!fileExists(io, staged_json)) die("fetch-pbs: extract produced no PYTHON.json", .{});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(a, "{s}/{s}", .{ staged, STAMP }), .data = asset });
    try Io.Dir.cwd().deleteTree(io, tree);
    try Io.Dir.cwd().rename(staged, Io.Dir.cwd(), tree, io);
    try Io.Dir.cwd().deleteTree(io, staging);
    log("fetch-pbs: ready at {s}", .{tree});
}

/// `pins.json` -> the `pbs` table. Only the four keys the seed needs are read.
fn readPins(io: Io, a: Allocator, path: []const u8, osarch: []const u8) !Pins {
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
        .sha256 = jsonString(jsonObject(pbs, "sha256", path), osarch, path),
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

fn jsonObject(table: std.json.Value, key: []const u8, path: []const u8) std.json.Value {
    const v = switch (table) {
        .object => |o| o.get(key) orelse die("fetch-pbs: {s}: pbs.{s} missing", .{ path, key }),
        else => die("fetch-pbs: {s}: \"pbs\" must be an object", .{path}),
    };
    return switch (v) {
        .object => v,
        else => die("fetch-pbs: {s}: pbs.{s} must be an object", .{ path, key }),
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

test "pbsPlatform maps the four shipped legs" {
    try std.testing.expectEqualStrings("x86_64-unknown-linux-gnu", pbsPlatform("linux-x86_64").?);
    try std.testing.expect(pbsPlatform("plan9-mips") == null);
}
