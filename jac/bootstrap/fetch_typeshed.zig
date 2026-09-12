//! Bootstrap seed for the jac build: materialize the pinned typeshed stdlib
//! stubs into the checkout.
//!
//!     fetch_typeshed <vendor-dir>
//!
//! Type inference is on the critical path of every compilation, so these stubs
//! are a build input on exactly the same footing as the source-built CPython: they must
//! be on disk before the first `.jac` file is compiled. Compiling the Jac
//! payload tool IS a compilation, so the fetch cannot live there -- the tool
//! that fetches typeshed would need typeshed to exist before it could run.
//! That is why this is Zig, next to `build_python.zig`, on the one rung of the
//! bootstrap that runs before any Python does.
//!
//! `<vendor-dir>` is `jaclang/vendor/typeshed`, which carries the pin (`PIN`, a
//! typeshed commit) and the SHA256 of that commit's tarball
//! (`TARBALL_SHA256`) -- the same two files `jaclang.dist.payload`'s own
//! `fetch-typeshed` reads, so the two fetchers can never disagree. Idempotent:
//! a no-op once `stdlib/.typeshed-sha` names the pinned commit.

const std = @import("std");
const seed = @import("seed.zig");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const TARBALL_BASE = "https://codeload.github.com/python/typeshed/tar.gz";
const STDLIB = "stdlib";
const STAMP = "stdlib/.typeshed-sha";
const MARKER = "stdlib/VERSIONS";

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    var args: [2][]const u8 = undefined;
    var n: usize = 0;
    var it = init.minimal.args.iterate();
    while (it.next()) |arg| : (n += 1) {
        if (n < args.len) args[n] = arg;
    }
    if (n < 2) seed.die("usage: fetch_typeshed <vendor-dir>", .{});
    const vendor_path = args[1];

    var vendor = Io.Dir.cwd().openDir(io, vendor_path, .{}) catch |err|
        seed.die("fetch-typeshed: cannot open {s}: {s}", .{ vendor_path, @errorName(err) });
    defer vendor.close(io);

    const commit = try readPin(io, a, vendor, vendor_path, "PIN");
    const expected = try readPin(io, a, vendor, vendor_path, "TARBALL_SHA256");

    if (upToDate(io, a, vendor, commit)) {
        seed.log("fetch-typeshed: already present ({s})", .{commit});
        return;
    }

    seed.log("fetch-typeshed: fetching typeshed @ {s}", .{commit});
    const url = try std.fmt.allocPrint(a, "{s}/{s}", .{ TARBALL_BASE, commit });
    const gz = try seed.httpGetAlloc(io, gpa, url);
    defer gpa.free(gz);

    const tar = gunzip(gpa, gz) catch |err|
        seed.die("fetch-typeshed: gzip decompress failed: {s}", .{@errorName(err)});
    defer gpa.free(tar);

    // The pin names a commit, but a commit is only as trustworthy as the host
    // serving it; the digest is what actually fixes the bytes.
    const actual = seed.sha256Hex(tar);
    if (!std.mem.eql(u8, &actual, expected)) {
        seed.die(
            "fetch-typeshed: tarball checksum mismatch @ {s}\n  expected {s}\n  actual   {s}",
            .{ commit, expected, &actual },
        );
    }

    install(io, gpa, vendor, tar, commit) catch |err|
        seed.die("fetch-typeshed: install failed: {s}", .{@errorName(err)});
    seed.log("fetch-typeshed: ready ({s})", .{commit});
}

/// True when `<vendor>/stdlib` is already the tree for `commit`. The stamp is
/// written last, so a torn install never reads as up to date.
pub fn upToDate(io: Io, gpa: Allocator, vendor: Io.Dir, commit: []const u8) bool {
    vendor.access(io, MARKER, .{}) catch return false;
    const stamp = vendor.readFileAlloc(io, STAMP, gpa, .limited(256)) catch return false;
    defer gpa.free(stamp);
    return std.mem.eql(u8, std.mem.trim(u8, stamp, " \t\r\n"), commit);
}

/// Replace `<vendor>/stdlib` with the stubs in `tar` and stamp it with `commit`.
/// Replace, not merge: a pin bump that drops a stub upstream must drop it here
/// too, or the type checker keeps resolving a module typeshed no longer has.
pub fn install(io: Io, gpa: Allocator, vendor: Io.Dir, tar: []const u8, commit: []const u8) !void {
    try vendor.deleteTree(io, STDLIB);

    var name_buf: [std.fs.max_path_bytes]u8 = undefined;
    var link_buf: [std.fs.max_path_bytes]u8 = undefined;
    const copy_buf = try gpa.alloc(u8, 64 * 1024);
    defer gpa.free(copy_buf);

    var src = Io.Reader.fixed(tar);
    var entries: std.tar.Iterator = .init(&src, .{
        .file_name_buffer = &name_buf,
        .link_name_buffer = &link_buf,
    });
    while (try entries.next()) |entry| {
        if (entry.kind != .file) continue;
        const dest = vendorPath(entry.name) orelse continue;
        if (std.fs.path.dirnamePosix(dest)) |parent| try vendor.createDirPath(io, parent);
        var out = try vendor.createFile(io, dest, .{});
        defer out.close(io);
        var writer = out.writer(io, copy_buf);
        try entries.streamRemaining(entry, &writer.interface);
        try writer.interface.flush();
    }

    // A tarball with no stdlib/ means a bad pin, not an empty typeshed. Say so
    // instead of stamping an empty tree as good.
    vendor.access(io, MARKER, .{}) catch return error.NoStdlib;
    try vendor.writeFile(io, .{ .sub_path = STAMP, .data = commit });
}

/// Where a tar entry lands under the vendor dir, or null when the vendored tree
/// does not carry it. The archive is rooted at `typeshed-<commit>/`, of which
/// only the stdlib stubs and the license are vendored; typeshed's own `@tests`
/// fixtures are dropped, matching the payload tool's `skip_typeshed_tests`.
pub fn vendorPath(entry: []const u8) ?[]const u8 {
    const root_end = std.mem.indexOfScalar(u8, entry, '/') orelse return null;
    const rel = entry[root_end + 1 ..];
    if (rel.len == 0 or !safeRelative(rel)) return null;
    if (std.mem.indexOf(u8, rel, "@tests") != null) return null;
    if (std.mem.eql(u8, rel, "LICENSE")) return rel;
    if (std.mem.startsWith(u8, rel, STDLIB ++ "/") and rel.len > STDLIB.len + 1) return rel;
    return null;
}

/// Reject anything that would write outside the vendor dir. The tarball is
/// digest-pinned, so this is belt and braces -- but the seed runs unsandboxed
/// over a path it took off the network.
fn safeRelative(rel: []const u8) bool {
    if (std.fs.path.isAbsolutePosix(rel)) return false;
    var parts = std.mem.splitScalar(u8, rel, '/');
    while (parts.next()) |part| {
        if (std.mem.eql(u8, part, "..")) return false;
    }
    return true;
}

fn readPin(io: Io, a: Allocator, vendor: Io.Dir, vendor_path: []const u8, name: []const u8) ![]const u8 {
    const raw = vendor.readFileAlloc(io, name, a, .limited(4096)) catch |err|
        seed.die("fetch-typeshed: cannot read {s}/{s}: {s}", .{ vendor_path, name, @errorName(err) });
    const trimmed = std.mem.trim(u8, raw, " \t\r\n");
    if (trimmed.len == 0) seed.die("fetch-typeshed: {s}/{s} is empty", .{ vendor_path, name });
    return trimmed;
}

fn gunzip(gpa: Allocator, gz: []const u8) ![]u8 {
    const window = try gpa.alloc(u8, std.compress.flate.max_window_len);
    defer gpa.free(window);
    var src = Io.Reader.fixed(gz);
    var dz: std.compress.flate.Decompress = .init(&src, .gzip, window);
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    _ = try dz.reader.streamRemaining(&aw.writer);
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

test "vendorPath keeps the stdlib stubs and the license, drops the rest" {
    const root = "typeshed-bbbf7530a987e59c8458127351cacad2e57f04bf/";
    try std.testing.expectEqualStrings("stdlib/typing.pyi", vendorPath(root ++ "stdlib/typing.pyi").?);
    try std.testing.expectEqualStrings("stdlib/asyncio/tasks.pyi", vendorPath(root ++ "stdlib/asyncio/tasks.pyi").?);
    try std.testing.expectEqualStrings("stdlib/VERSIONS", vendorPath(root ++ "stdlib/VERSIONS").?);
    try std.testing.expectEqualStrings("LICENSE", vendorPath(root ++ "LICENSE").?);

    try std.testing.expect(vendorPath(root ++ "stdlib/@tests/test_cases/check_re.py") == null);
    try std.testing.expect(vendorPath(root ++ "stdlib/asyncio/@tests/check_task.py") == null);
    try std.testing.expect(vendorPath(root ++ "stubs/six/six/__init__.pyi") == null);
    try std.testing.expect(vendorPath(root ++ "README.md") == null);
    try std.testing.expect(vendorPath(root ++ "stdlib/") == null);
    try std.testing.expect(vendorPath(root ++ "stdlib/../../escape.pyi") == null);
    try std.testing.expect(vendorPath("stdlib/typing.pyi") == null);
    try std.testing.expect(vendorPath("no-root-component") == null);
}

test "install materializes the stdlib tree with no Jac compile in the loop" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const commit = "bbbf7530a987e59c8458127351cacad2e57f04bf";
    const tar = try testTarball(gpa, commit);
    defer gpa.free(tar);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try std.testing.expect(!upToDate(io, gpa, tmp.dir, commit));
    try install(io, gpa, tmp.dir, tar, commit);
    try std.testing.expect(upToDate(io, gpa, tmp.dir, commit));

    try expectFile(io, gpa, tmp.dir, "stdlib/typing.pyi", "class Any: ...\n");
    try expectFile(io, gpa, tmp.dir, "stdlib/asyncio/tasks.pyi", "def sleep(): ...\n");
    try expectFile(io, gpa, tmp.dir, "stdlib/VERSIONS", "typing: 3.0-\n");
    try expectFile(io, gpa, tmp.dir, "LICENSE", "Apache-2.0\n");
    try expectFile(io, gpa, tmp.dir, "stdlib/.typeshed-sha", commit);

    try std.testing.expect(!exists(io, tmp.dir, "stdlib/@tests/test_cases/check_re.py"));
    try std.testing.expect(!exists(io, tmp.dir, "stubs/six/six/__init__.pyi"));
    try std.testing.expect(!exists(io, tmp.dir, "README.md"));
}

test "a re-install for another pin replaces the tree instead of merging into it" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const commit = "bbbf7530a987e59c8458127351cacad2e57f04bf";
    const tar = try testTarball(gpa, commit);
    defer gpa.free(tar);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try install(io, gpa, tmp.dir, tar, commit);
    try tmp.dir.writeFile(io, .{ .sub_path = "stdlib/dropped_upstream.pyi", .data = "stale\n" });
    try std.testing.expect(!upToDate(io, gpa, tmp.dir, "0000000000000000000000000000000000000000"));

    try install(io, gpa, tmp.dir, tar, commit);
    try std.testing.expect(!exists(io, tmp.dir, "stdlib/dropped_upstream.pyi"));
    try expectFile(io, gpa, tmp.dir, "stdlib/typing.pyi", "class Any: ...\n");
}

test "a tarball with no stdlib is rejected rather than half-installed" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const tar = try makeTar(gpa, &.{
        .{ "typeshed-deadbeef/LICENSE", "Apache-2.0\n" },
        .{ "typeshed-deadbeef/stubs/six/six/__init__.pyi", "x: int\n" },
    });
    defer gpa.free(tar);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try std.testing.expectError(error.NoStdlib, install(io, gpa, tmp.dir, tar, "deadbeef"));
    try std.testing.expect(!upToDate(io, gpa, tmp.dir, "deadbeef"));
}

fn testTarball(gpa: std.mem.Allocator, commit: []const u8) ![]u8 {
    const root = try std.fmt.allocPrint(gpa, "typeshed-{s}/", .{commit});
    defer gpa.free(root);
    var names: [7][]u8 = undefined;
    const rels = [_][]const u8{
        "LICENSE",
        "README.md",
        "stdlib/VERSIONS",
        "stdlib/typing.pyi",
        "stdlib/asyncio/tasks.pyi",
        "stdlib/@tests/test_cases/check_re.py",
        "stubs/six/six/__init__.pyi",
    };
    const bodies = [_][]const u8{
        "Apache-2.0\n",
        "not vendored\n",
        "typing: 3.0-\n",
        "class Any: ...\n",
        "def sleep(): ...\n",
        "assert False\n",
        "x: int\n",
    };
    var rows: [rels.len][2][]const u8 = undefined;
    var made: usize = 0;
    errdefer for (names[0..made]) |n| gpa.free(n);
    for (rels, 0..) |rel, i| {
        names[i] = try std.fmt.allocPrint(gpa, "{s}{s}", .{ root, rel });
        made += 1;
        rows[i] = .{ names[i], bodies[i] };
    }
    defer for (names[0..made]) |n| gpa.free(n);
    return makeTar(gpa, &rows);
}

fn makeTar(gpa: std.mem.Allocator, rows: []const [2][]const u8) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    var tw: std.tar.Writer = .{ .underlying_writer = &aw.writer };
    for (rows) |row| try tw.writeFileBytes(row[0], row[1], .{ .mode = 0o644, .mtime = 0 });
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

fn exists(io: std.Io, dir: std.Io.Dir, sub_path: []const u8) bool {
    const f = dir.openFile(io, sub_path, .{}) catch return false;
    f.close(io);
    return true;
}

fn expectFile(
    io: std.Io,
    gpa: std.mem.Allocator,
    dir: std.Io.Dir,
    sub_path: []const u8,
    want: []const u8,
) !void {
    const got = try dir.readFileAlloc(io, sub_path, gpa, .limited(4096));
    defer gpa.free(got);
    try std.testing.expectEqualStrings(want, got);
}
