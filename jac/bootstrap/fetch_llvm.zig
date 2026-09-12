//! Bootstrap seed: range-fetch the pinned LLVM slice the jacllvm shim needs.
//! Pure Zig (std.http + zip central-directory parse + raw deflate) so
//! `zig build fetch-llvm` never depends on the source-built CPython bootstrap.
//!
//!     fetch_llvm <os-arch> <dest-dir> <pins.json>
//!
//! Idempotent: a no-op when the platform marker library already exists under
//! <dest>/<slice-dirname>/lib/. Mirrors jaclang.dist.payload fetch_llvm.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const SLICE_RUN_GAP: u64 = 16 * 1024 * 1024;
const ZIP_EOCD_SIG: [4]u8 = .{ 0x50, 0x4b, 0x05, 0x06 };
const ZIP_CDH_SIG: [4]u8 = .{ 0x50, 0x4b, 0x01, 0x02 };
const ZIP_LFH_SIG: [4]u8 = .{ 0x50, 0x4b, 0x03, 0x04 };

const LlvmRelease = struct {
    dirname: []const u8,
    triple: []const u8,
    manifest_sha256: []const u8,
    zip_size: u64,
    upstream: bool,
};

const ZipMember = struct {
    name: []const u8,
    method: u16,
    csize: u32,
    crc: u32,
    lho: u32,
};

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
    if (n < 4) die("usage: fetch_llvm <os-arch> <dest-dir> <pins.json>", .{});
    const osarch = args[1];
    const dest = args[2];
    const rel = try readLlvmRelease(io, a, args[3], osarch);
    const macos = std.mem.startsWith(u8, osarch, "macos");
    const marker_lib = if (macos and rel.upstream) "libLTO.dylib" else "libLLVMCore.a";
    const marker = try std.fmt.allocPrint(a, "{s}/{s}/lib/{s}", .{ dest, rel.dirname, marker_lib });
    if (fileExists(io, marker)) {
        log("fetch-llvm: already present at {s}/{s}", .{ dest, rel.dirname });
        return;
    }

    try Io.Dir.cwd().createDirPath(io, dest);
    try fetchLlvmSlice(io, gpa, a, args[3], dest, rel, macos);
    if (!fileExists(io, marker)) die("fetch-llvm: fetch produced no {s}", .{marker_lib});
    log("fetch-llvm: ready at {s}/{s}", .{ dest, rel.dirname });
}

fn readLlvmRelease(io: Io, a: Allocator, path: []const u8, osarch: []const u8) !LlvmRelease {
    const raw = Io.Dir.cwd().readFileAlloc(io, path, a, .unlimited) catch |err|
        die("fetch-llvm: cannot read {s}: {s}", .{ path, @errorName(err) });
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, a, raw, .{}) catch |err|
        die("fetch-llvm: {s} is not valid JSON: {s}", .{ path, @errorName(err) });
    const llvm = field(parsed, "llvm") orelse die("fetch-llvm: {s} has no \"llvm\" table", .{path});
    const slices = field(llvm, "slices") orelse die("fetch-llvm: {s}: llvm.slices missing", .{path});
    const slice = field(slices, osarch) orelse
        die("fetch-llvm: no pinned LLVM release for this host ({s}); add a row to bootstrap/pins.json llvm.slices.", .{osarch});
    const zip_size_v = field(slice, "zip_size") orelse die("fetch-llvm: llvm.slices.{s}.zip_size missing", .{osarch});
    const upstream_v = field(slice, "upstream") orelse die("fetch-llvm: llvm.slices.{s}.upstream missing", .{osarch});
  return .{
        .dirname = jsonString(slice, "dirname", path),
        .triple = jsonString(slice, "triple", path),
        .manifest_sha256 = jsonString(slice, "manifest_sha256", path),
        .zip_size = switch (zip_size_v) {
            .integer => |i| @intCast(i),
            else => die("fetch-llvm: zip_size must be an integer", .{}),
        },
        .upstream = switch (upstream_v) {
            .bool => |x| x,
            else => die("fetch-llvm: upstream must be a bool", .{}),
        },
    };
}

fn llvmPins(io: Io, a: Allocator, path: []const u8) struct { version: []const u8, slice_base: []const u8 } {
    const raw = Io.Dir.cwd().readFileAlloc(io, path, a, .unlimited) catch |err|
        die("fetch-llvm: cannot read {s}: {s}", .{ path, @errorName(err) });
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, a, raw, .{}) catch |err|
        die("fetch-llvm: {s} is not valid JSON: {s}", .{ path, @errorName(err) });
    const llvm = field(parsed, "llvm") orelse die("fetch-llvm: {s} has no \"llvm\" table", .{path});
    return .{
        .version = jsonString(llvm, "version", path),
        .slice_base = jsonString(llvm, "slice_base", path),
    };
}

fn field(v: std.json.Value, key: []const u8) ?std.json.Value {
    return switch (v) {
        .object => |o| o.get(key),
        else => null,
    };
}

fn jsonString(table: std.json.Value, key: []const u8, path: []const u8) []const u8 {
    const v = field(table, key) orelse die("fetch-llvm: {s}: {s} missing", .{ path, key });
    return switch (v) {
        .string => |s| s,
        else => die("fetch-llvm: {s}: {s} must be a string", .{ path, key }),
    };
}

fn fetchLlvmSlice(io: Io, gpa: Allocator, a: Allocator, pins_path: []const u8, dest: []const u8, rel: LlvmRelease, macos: bool) !void {
    const llvm = llvmPins(io, a, pins_path);
    const slice_tag = try std.fmt.allocPrint(a, "v{s}", .{llvm.version});
    const zip_url = try std.fmt.allocPrint(a, "{s}/{s}/llvm-{s}-{s}-dev.zip", .{ llvm.slice_base, slice_tag, llvm.version, rel.triple });
    const man_url = try std.fmt.allocPrint(a, "{s}/{s}/llvm-{s}-{s}-manifest.json", .{ llvm.slice_base, slice_tag, llvm.version, rel.triple });
    log("fetch-llvm: slice range-fetch (~84 MB) from llvm-slice {s} {s}", .{ slice_tag, rel.triple });

    const manifest = try httpGetAlloc(io, gpa, man_url);
    defer gpa.free(manifest);
    const sha_map = try manifestShaMap(a, manifest, rel);

    const tail_len = @min(rel.zip_size, 65536);
    const tail = try httpGetRangeAlloc(io, gpa, zip_url, rel.zip_size - tail_len, rel.zip_size - 1);
    defer gpa.free(tail);
    const cd_parts = try parseEocd(tail);
    const cd_size: u32 = @intCast(cd_parts[0]);
    const cd_off: u32 = @intCast(cd_parts[1]);

    const cd = try httpGetRangeAlloc(io, gpa, zip_url, cd_off, cd_off + cd_size - 1);
    defer gpa.free(cd);
    const members = try parseCentralDirectory(a, cd);
    std.mem.sort(ZipMember, members, {}, struct {
        fn less(_: void, x: ZipMember, y: ZipMember) bool {
            return x.lho < y.lho;
        }
    }.less);

    const slice_root = try std.fmt.allocPrint(a, "{s}/{s}", .{ dest, rel.dirname });
    var written: usize = 0;
    var i: usize = 0;
    while (i < members.len) {
        if (!sliceWanted(members[i].name, macos)) {
            i += 1;
            continue;
        }
        const ra = i;
        var rb = i;
        var j = i + 1;
        while (j < members.len) {
            if (sliceWanted(members[j].name, macos)) {
                if (members[j].lho -% runEnd(members, rb, cd_off) >= SLICE_RUN_GAP) break;
                rb = j;
            }
            j += 1;
        }
        const run_start = members[ra].lho;
        const run_end = runEnd(members, rb, cd_off);
        const run = try httpGetRangeAlloc(io, gpa, zip_url, run_start, run_end - 1);
        defer gpa.free(run);
        var k = ra;
        while (k <= rb) : (k += 1) {
            const m = members[k];
            if (!sliceWanted(m.name, macos)) continue;
            const data = try inflateMember(gpa, m.method, try memberData(run, run_start, m));
            defer gpa.free(data);
            if (std.hash.Crc32.hash(data) != m.crc) die("fetch-llvm: crc mismatch for {s}", .{m.name});
            if (sha_map.get(m.name)) |want_sha| {
                const got = sha256Hex(data);
                if (!std.mem.eql(u8, &got, want_sha[0..])) die("fetch-llvm: sha256 mismatch for {s}", .{m.name});
            }
            try writeSliceMember(io, slice_root, m.name, data);
            written += 1;
        }
        i = rb + 1;
    }
    log("fetch-llvm: slice extracted {d} members", .{written});
}

fn manifestShaMap(a: Allocator, manifest: []const u8, rel: LlvmRelease) !std.StringArrayHashMapUnmanaged([64]u8) {
    const ms = sha256Hex(manifest);
    if (!std.mem.eql(u8, &ms, rel.manifest_sha256)) {
        die("fetch-llvm: manifest checksum mismatch\n  expected {s}\n  actual   {s}", .{ rel.manifest_sha256, &ms });
    }
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, a, manifest, .{}) catch |err|
        die("fetch-llvm: manifest parse failed: {s}", .{@errorName(err)});
    var map: std.StringArrayHashMapUnmanaged([64]u8) = .{};
    const libs = field(parsed, "libs") orelse return map;
    const obj = switch (libs) {
        .object => |o| o,
        else => return map,
    };
    var it = obj.iterator();
    while (it.next()) |entry| {
        const v = entry.value_ptr.*;
        const o = switch (v) {
            .object => |x| x,
            else => continue,
        };
        const fv = o.get("file") orelse continue;
        const sv = o.get("sha256") orelse continue;
        const file = switch (fv) {
            .string => |s| s,
            else => continue,
        };
        const sha = switch (sv) {
            .string => |s| s,
            else => continue,
        };
        if (sha.len != 64) continue;
        var hex: [64]u8 = undefined;
        @memcpy(&hex, sha);
        try map.put(a, file, hex);
    }
    return map;
}

fn sliceWanted(name: []const u8, macos: bool) bool {
    if (std.mem.startsWith(u8, name, "lib/libLLVM") and std.mem.endsWith(u8, name, ".a")) return true;
    if (std.mem.startsWith(u8, name, "include/llvm/") or std.mem.startsWith(u8, name, "include/llvm-c/")) return true;
    return macos and std.mem.eql(u8, name, "lib/libLTO.dylib");
}

fn parseEocd(tail: []const u8) ![2]u64 {
    const sig = std.mem.lastIndexOf(u8, tail, &ZIP_EOCD_SIG) orelse die("fetch-llvm: no zip EOCD found", .{});
    if (sig + 16 + 4 > tail.len) die("fetch-llvm: truncated EOCD", .{});
    const cd_size = rdU32(tail, sig + 12);
    const cd_off = rdU32(tail, sig + 16);
    return .{ cd_size, cd_off };
}

fn parseCentralDirectory(a: Allocator, cd: []const u8) ![]ZipMember {
    var members: std.ArrayListUnmanaged(ZipMember) = .empty;
    errdefer members.deinit(a);
    var p: usize = 0;
    while (p + 46 <= cd.len and std.mem.eql(u8, cd[p .. p + 4], &ZIP_CDH_SIG)) {
        const method = rdU16(cd, p + 10);
        const crc = rdU32(cd, p + 16);
        const csize = rdU32(cd, p + 20);
        const nlen = rdU16(cd, p + 28);
        const elen = rdU16(cd, p + 30);
        const clen = rdU16(cd, p + 32);
        const lho = rdU32(cd, p + 42);
        const name = cd[p + 46 .. p + 46 + nlen];
        try members.append(a, .{
            .name = name,
            .method = method,
            .csize = csize,
            .crc = crc,
            .lho = lho,
        });
        p += 46 + nlen + elen + clen;
    }
    return members.toOwnedSlice(a);
}

fn runEnd(members: []const ZipMember, i: usize, cd_off: u32) u32 {
    if (i + 1 < members.len) return members[i + 1].lho;
    return cd_off;
}

fn memberData(run: []const u8, run_start: u32, m: ZipMember) ![]const u8 {
    const o: usize = m.lho -% run_start;
    if (o + 4 > run.len or !std.mem.eql(u8, run[o .. o + 4], &ZIP_LFH_SIG)) die("fetch-llvm: bad local header for {s}", .{m.name});
    const data_off = o + 30 + rdU16(run, o + 26) + rdU16(run, o + 28);
    if (data_off + m.csize > run.len) die("fetch-llvm: member data out of range for {s}", .{m.name});
    return run[data_off .. data_off + m.csize];
}

fn inflateMember(gpa: Allocator, method: u16, data: []const u8) ![]u8 {
    if (method == 0) return gpa.dupe(u8, data);
    if (method != 8) die("fetch-llvm: unsupported zip compression method {d}", .{method});
    var in: std.Io.Reader = .fixed(data);
    var aw: std.Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    var decompress: std.compress.flate.Decompress = .init(&in, .raw, &.{});
    _ = try decompress.reader.streamRemaining(&aw.writer);
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

fn writeSliceMember(io: Io, slice_root: []const u8, name: []const u8, data: []const u8) !void {
    const rel_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/{s}", .{ slice_root, name });
    defer std.heap.page_allocator.free(rel_path);
    if (std.mem.endsWith(u8, name, "/")) {
        try Io.Dir.cwd().createDirPath(io, rel_path);
        return;
    }
    if (std.fs.path.dirname(rel_path)) |dir| try Io.Dir.cwd().createDirPath(io, dir);
    const f = try Io.Dir.cwd().createFile(io, rel_path, .{ .truncate = true });
    defer f.close(io);
    try f.writeStreamingAll(io, data);
}

fn rdU16(buf: []const u8, off: usize) u16 {
    return @as(u16, buf[off]) | (@as(u16, buf[off + 1]) << 8);
}

fn rdU32(buf: []const u8, off: usize) u32 {
    return @as(u32, buf[off]) |
        (@as(u32, buf[off + 1]) << 8) |
        (@as(u32, buf[off + 2]) << 16) |
        (@as(u32, buf[off + 3]) << 24);
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
    }) catch |err| die("fetch-llvm: http fetch failed for {s}: {s}", .{ url, @errorName(err) });
    if (res.status != .ok) die("fetch-llvm: http {d} for {s}", .{ @intFromEnum(res.status), url });
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

fn httpGetRangeAlloc(io: Io, gpa: Allocator, url: []const u8, start: u64, end: u64) ![]u8 {
    var client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const range_hdr = try std.fmt.allocPrint(gpa, "bytes={d}-{d}", .{ start, end });
    defer gpa.free(range_hdr);
    const res = client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &aw.writer,
        .redirect_behavior = @enumFromInt(10),
        .extra_headers = &.{
            .{ .name = "Range", .value = range_hdr },
        },
    }) catch |err| die("fetch-llvm: range fetch failed for {s}: {s}", .{ url, @errorName(err) });
    if (res.status != .partial_content) die("fetch-llvm: expected 206 for range bytes={d}-{d}, got {d}", .{ start, end, @intFromEnum(res.status) });
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

test "parseEocd reads central-directory size and offset" {
    var tail: [64]u8 = undefined;
    @memset(&tail, 0);
    @memcpy(tail[tail.len - 22 ..][0..4], &ZIP_EOCD_SIG);
    tail[tail.len - 10] = 0x34;
    tail[tail.len - 9] = 0x12;
    tail[tail.len - 6] = 0x78;
    tail[tail.len - 5] = 0x56;
    const parts = try parseEocd(&tail);
    try std.testing.expectEqual(@as(u64, 0x1234), parts[0]);
    try std.testing.expectEqual(@as(u64, 0x5678), parts[1]);
}

test "sliceWanted selects llvm libs and headers" {
    try std.testing.expect(sliceWanted("lib/libLLVMCore.a", false));
    try std.testing.expect(sliceWanted("include/llvm/ADT/Foo.h", false));
    try std.testing.expect(!sliceWanted("share/doc/README", false));
    try std.testing.expect(sliceWanted("lib/libLTO.dylib", true));
    try std.testing.expect(!sliceWanted("lib/libLTO.dylib", false));
}
