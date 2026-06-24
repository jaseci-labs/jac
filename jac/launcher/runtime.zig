//! Runtime materialization for the jaclang single binary (Zig launcher).
//!
//! Pure-Zig half of the launcher: everything between "the process started" and
//! "CPython is about to be initialized". It is deliberately free of any
//! `@cImport`/libpython dependency so it can be unit-tested with plain
//! `zig test` (see the tests at the bottom of this file). The CPython embed
//! lives in `launcher.zig`, which calls `materialize` and then boots.
//!
//! Binary shape (written by launcher/pack.zig):
//!
//!     [ exe stub ][ runtime.tar.gz payload ][ trailer ]
//!
//!     trailer = magic("JACBIN01", 8) | payload_len(u64 LE, 8) | sha256_hex(64)
//!               = 80 bytes, fixed, at EOF.
//!
//! On first run the payload is gzip-decompressed and untarred into
//! `<cache>/rt/<hash16>/` (atomic temp-dir + rename), where `<hash16>` is the
//! first 16 hex chars of the trailer digest. A `.ok` marker guards against
//! partial extracts; subsequent runs short-circuit on it.
//!
//! The payload is gzip (deflate), not zstd, so BOTH ends of the pipe are pure
//! std: launcher/payload.zig compresses with `std.compress.flate.Compress` at
//! build time and this module decompresses with `std.compress.flate.Decompress`
//! -- no libzstd and no `zstd` host tool anywhere. Versus the C launcher this
//! also drops the hand-rolled ustar reader (-> std.tar) and the
//! `system("rm -rf")` / `system("find")` shellouts (-> std.Io.Dir.deleteTree +
//! dir iteration).

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const flate = std.compress.flate;

/// Trailer layout (must match `concat_binary` in tools/binary/impl/build.impl.jac).
pub const MAGIC = "JACBIN01";
pub const MAGIC_LEN = 8;
pub const HASH_LEN = 64; // sha256 hex
pub const TRAILER_LEN = MAGIC_LEN + 8 + HASH_LEN; // 80

/// deflate sliding-window buffer. Unlike zstd's tunable window, deflate's window
/// is fixed at 32 KiB (`flate.max_window_len`), so this is constant regardless of
/// the compression level payload.zig packs with.
const GZIP_BUF_LEN = flate.max_window_len;

const MAX_PATH = Io.Dir.max_path_bytes;

pub const Error = error{
    BinaryTooSmall,
    ShortTrailer,
    BadMagic,
    PayloadOffsetUnderflow,
    ShortPayloadRead,
    PayloadHashMismatch,
    NoWritableCacheDir,
    MaterializeFailed,
};

/// Parsed trailer: the compressed payload length, its full digest, and the
/// cache key (first 16 hex chars of the digest).
pub const Trailer = struct {
    payload_len: u64,
    /// Full sha256 hex of the compressed payload; verified on the cold path.
    hash: [HASH_LEN]u8,
    /// First 16 hex chars of `hash`; used as the `rt/<hash16>` dir name.
    hash16: [16]u8,
};

/// Lowercase hex of a 32-byte digest -- exactly HASH_LEN (64) chars, two per
/// byte. (`{x}` on a byte array does not zero-pad each byte.)
pub fn hexDigest(digest: *const [32]u8) [HASH_LEN]u8 {
    var hex: [HASH_LEN]u8 = undefined;
    const chars = "0123456789abcdef";
    for (digest, 0..) |b, i| {
        hex[i * 2] = chars[b >> 4];
        hex[i * 2 + 1] = chars[b & 0xf];
    }
    return hex;
}

/// Decode an 80-byte trailer blob. Pure function (no I/O) so it is trivially
/// testable and reused by the warm and cold paths.
pub fn parseTrailer(bytes: *const [TRAILER_LEN]u8) Error!Trailer {
    if (!std.mem.eql(u8, bytes[0..MAGIC_LEN], MAGIC)) return Error.BadMagic;
    const payload_len = std.mem.readInt(u64, bytes[MAGIC_LEN..][0..8], .little);
    var t: Trailer = .{ .payload_len = payload_len, .hash = undefined, .hash16 = undefined };
    @memcpy(&t.hash, bytes[MAGIC_LEN + 8 ..][0..HASH_LEN]);
    @memcpy(&t.hash16, t.hash[0..16]);
    return t;
}

/// Resolve the global cache root, mirroring jaclang's `cache_paths.py`:
/// `$XDG_CACHE_HOME` -> `$HOME/.cache`, then `/jac`. Falls back to a per-uid
/// temp dir when the preferred root is not writable (read-only `$HOME`).
/// Writes the chosen path into `out` and returns the slice.
pub fn cacheRoot(
    io: Io,
    xdg_cache_home: ?[]const u8,
    home: ?[]const u8,
    tmpdir: ?[]const u8,
    uid: u32,
    out: []u8,
) Error![]const u8 {
    var base_buf: [MAX_PATH]u8 = undefined;
    var base: []const u8 = "";
    if (nonEmpty(xdg_cache_home)) |x| {
        base = x;
    } else if (nonEmpty(home)) |h| {
        base = std.fmt.bufPrint(&base_buf, "{s}/.cache", .{h}) catch "";
    }

    if (base.len != 0) {
        const root = std.fmt.bufPrint(out, "{s}/jac", .{base}) catch return Error.NoWritableCacheDir;
        if (dirWritable(io, root)) return root;
    }

    // Fallback: temp dir keyed by uid so concurrent users do not collide.
    const tmp = nonEmpty(tmpdir) orelse "/tmp";
    const root = std.fmt.bufPrint(out, "{s}/jac-cache-{d}", .{ tmp, uid }) catch return Error.NoWritableCacheDir;
    if (!dirWritable(io, root)) return Error.NoWritableCacheDir;
    return root;
}

fn nonEmpty(s: ?[]const u8) ?[]const u8 {
    if (s) |v| {
        if (v.len != 0) return v;
    }
    return null;
}

/// True if `path` exists (creating it and parents if needed) and a file can be
/// created inside it. The probe-file write is the actual W_OK test -- a
/// read-only `$HOME` lets `createDirPath` succeed on an existing dir but fails
/// the probe, which is exactly when we want the temp fallback to engage.
fn dirWritable(io: Io, path: []const u8) bool {
    Io.Dir.cwd().createDirPath(io, path) catch return false;
    var dir = Io.Dir.cwd().openDir(io, path, .{}) catch return false;
    defer dir.close(io);
    const probe = dir.createFile(io, ".jac-write-probe", .{ .truncate = true }) catch return false;
    probe.close(io);
    dir.deleteFile(io, ".jac-write-probe") catch {};
    return true;
}

/// Resolve (and on first run, extract) the runtime tree for this binary.
/// Returns the `<cache>/rt/<hash16>` path inside `rt_out`.
///
/// `exe_path` is this executable; `uid`/`pid` and the three env strings are
/// passed in by the caller (launcher.zig) so this module stays libc-free.
pub fn materialize(
    io: Io,
    gpa: Allocator,
    exe_path: []const u8,
    xdg_cache_home: ?[]const u8,
    home: ?[]const u8,
    tmpdir: ?[]const u8,
    uid: u32,
    pid: i32,
    rt_out: []u8,
) ![]const u8 {
    var file = try Io.Dir.cwd().openFile(io, exe_path, .{});
    var keep_open = true;
    defer if (keep_open) file.close(io);

    const total = try file.length(io);
    if (total < TRAILER_LEN) return Error.BinaryTooSmall;

    var traw: [TRAILER_LEN]u8 = undefined;
    if (try file.readPositionalAll(io, &traw, total - TRAILER_LEN) != TRAILER_LEN)
        return Error.ShortTrailer;
    const trailer = try parseTrailer(&traw);

    var root_buf: [MAX_PATH]u8 = undefined;
    const root = try cacheRoot(io, xdg_cache_home, home, tmpdir, uid, &root_buf);

    const rt = std.fmt.bufPrint(rt_out, "{s}/rt/{s}", .{ root, &trailer.hash16 }) catch
        return Error.MaterializeFailed;

    // Warm path: a complete extract is marked by `<rt>/.ok`.
    if (pathExists(io, rt, ".ok")) return rt;

    // Cold path: read the compressed payload region into memory.
    const poff = std.math.sub(u64, total, TRAILER_LEN + trailer.payload_len) catch
        return Error.PayloadOffsetUnderflow;
    const zbuf = try gpa.alloc(u8, trailer.payload_len);
    defer gpa.free(zbuf);
    if (try file.readPositionalAll(io, zbuf, poff) != trailer.payload_len)
        return Error.ShortPayloadRead;
    file.close(io);
    keep_open = false;

    // Integrity check before populating the cache: a truncated / bit-flipped /
    // tampered payload must not silently extract and then be reused on every
    // launch. Cold path only, so the `.ok` warm path stays cost-free.
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(zbuf, &digest, .{});
    if (!std.mem.eql(u8, &hexDigest(&digest), &trailer.hash))
        return Error.PayloadHashMismatch;

    try extractPayload(io, gpa, zbuf, rt, pid);
    gcStale(io, root, &trailer.hash16);
    return rt;
}

/// zstd-decompress + untar `zbuf` into `<rt>` via a per-pid temp dir and an
/// atomic rename. Streams decompression straight into the tar reader -- the
/// full uncompressed tar is never held in memory.
fn extractPayload(
    io: Io,
    gpa: Allocator,
    zbuf: []const u8,
    rt: []const u8,
    pid: i32,
) !void {
    var tmp_buf: [MAX_PATH]u8 = undefined;
    const tmp = std.fmt.bufPrint(&tmp_buf, "{s}.tmp.{d}", .{ rt, pid }) catch
        return Error.MaterializeFailed;

    Io.Dir.cwd().deleteTree(io, tmp) catch {};
    try Io.Dir.cwd().createDirPath(io, tmp);

    {
        var dest = try Io.Dir.cwd().openDir(io, tmp, .{});
        defer dest.close(io);

        const window = try gpa.alloc(u8, GZIP_BUF_LEN);
        defer gpa.free(window);

        var src = Io.Reader.fixed(zbuf);
        var dz = flate.Decompress.init(&src, .gzip, window);
        try std.tar.extract(io, dest, &dz.reader, .{
            .mode_mode = .ignore,
            .strip_components = 0,
        });

        // Stamp the success marker inside the temp dir before the rename, so the
        // marker can never appear on an incomplete tree.
        const okf = try dest.createFile(io, ".ok", .{});
        okf.close(io);
    }

    // Atomic publish. A lost race (target already exists) is fine as long as
    // the winner left a complete (`.ok`-bearing) tree.
    Io.Dir.rename(Io.Dir.cwd(), tmp, Io.Dir.cwd(), rt, io) catch {
        Io.Dir.cwd().deleteTree(io, tmp) catch {};
        if (!pathExists(io, rt, ".ok")) return Error.MaterializeFailed;
    };
}

/// Best-effort GC of `rt/<old-hash>` trees left by previous binary versions.
/// Replaces the C launcher's `system("find ... -exec rm -rf")`.
fn gcStale(io: Io, root: []const u8, keep_hash16: *const [16]u8) void {
    var rtbuf: [MAX_PATH]u8 = undefined;
    const rtdir = std.fmt.bufPrint(&rtbuf, "{s}/rt", .{root}) catch return;
    var dir = Io.Dir.cwd().openDir(io, rtdir, .{ .iterate = true }) catch return;
    defer dir.close(io);
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.eql(u8, entry.name, keep_hash16)) continue;
        if (std.mem.indexOf(u8, entry.name, ".tmp.") != null) continue; // a live extract
        dir.deleteTree(io, entry.name) catch {};
    }
}

/// True if `<dir>/<name>` exists and is openable.
fn pathExists(io: Io, dir: []const u8, name: []const u8) bool {
    var buf: [MAX_PATH]u8 = undefined;
    const p = std.fmt.bufPrint(&buf, "{s}/{s}", .{ dir, name }) catch return false;
    const f = Io.Dir.cwd().openFile(io, p, .{}) catch return false;
    f.close(io);
    return true;
}

// ----------------------------------------------------------------- tests

const testing = std.testing;

test "parseTrailer decodes magic, length and hash16" {
    var raw: [TRAILER_LEN]u8 = undefined;
    @memcpy(raw[0..MAGIC_LEN], MAGIC);
    std.mem.writeInt(u64, raw[MAGIC_LEN..][0..8], 0x1122334455, .little);
    const hex = "0123456789abcdef" ** 4; // 64 chars
    @memcpy(raw[MAGIC_LEN + 8 ..][0..HASH_LEN], hex);

    const t = try parseTrailer(&raw);
    try testing.expectEqual(@as(u64, 0x1122334455), t.payload_len);
    try testing.expectEqualStrings("0123456789abcdef", &t.hash16);
}

test "parseTrailer rejects a bad magic" {
    var raw: [TRAILER_LEN]u8 = std.mem.zeroes([TRAILER_LEN]u8);
    @memcpy(raw[0..MAGIC_LEN], "NOTJACBN");
    try testing.expectError(Error.BadMagic, parseTrailer(&raw));
}

test "cacheRoot prefers XDG_CACHE_HOME and falls back when unwritable" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var base_buf: [MAX_PATH]u8 = undefined;
    const base = base_buf[0..try tmp.dir.realPath(io, &base_buf)];

    // Writable XDG -> <xdg>/jac.
    var out: [MAX_PATH]u8 = undefined;
    const root = try cacheRoot(io, base, null, null, 1000, &out);
    try testing.expect(std.mem.endsWith(u8, root, "/jac"));
    try testing.expect(std.mem.startsWith(u8, root, base));

    // Unwritable preferred root -> temp fallback keyed by uid.
    var tmp_buf: [MAX_PATH]u8 = undefined;
    const tmpdir = tmp_buf[0..try tmp.dir.realPath(io, &tmp_buf)];
    const fb = try cacheRoot(io, "/proc/nonexistent/ro", null, tmpdir, 4242, &out);
    try testing.expect(std.mem.indexOf(u8, fb, "jac-cache-4242") != null);
}

// End-to-end exercise of the gzip+tar plumbing: assemble a real
// [stub][payload.tar.gz][trailer] binary from the committed fixture, run
// materialize, and assert the tree extracted with correct contents -- then
// re-run to prove the `.ok` warm-path short-circuits.
test "materialize extracts the fixture payload and is idempotent" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var pbuf: [MAX_PATH]u8 = undefined;
    const home = pbuf[0..try tmp.dir.realPath(io, &pbuf)];

    // Build the fake binary: 4-byte stub + payload + trailer.
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
    const hex = hexDigest(&digest);

    var bin = std.array_list.Managed(u8).init(testing.allocator);
    defer bin.deinit();
    try bin.appendSlice("STUB");
    try bin.appendSlice(payload);
    try bin.appendSlice(MAGIC);
    var lenle: [8]u8 = undefined;
    std.mem.writeInt(u64, &lenle, payload.len, .little);
    try bin.appendSlice(&lenle);
    try bin.appendSlice(&hex);

    try tmp.dir.writeFile(io, .{ .sub_path = "jacbin", .data = bin.items });
    var ebuf: [MAX_PATH]u8 = undefined;
    const exe = ebuf[0..try tmp.dir.realPathFile(io, "jacbin", &ebuf)];

    var rtbuf: [MAX_PATH]u8 = undefined;
    const rt = try materialize(io, testing.allocator, exe, home, null, null, 1000, 7, &rtbuf);

    // Expected key = first 16 hex chars of the digest.
    try testing.expect(std.mem.endsWith(u8, rt, hex[0..16]));

    var dir = try Io.Dir.cwd().openDir(io, rt, .{});
    defer dir.close(io);
    var fbuf: [64]u8 = undefined;
    const marker = try dir.readFile(io, "python/lib/marker.txt", &fbuf);
    try testing.expectEqualStrings("pybytecode-marker\n", marker);
    const deep = try dir.readFile(io, "site/nested/deep.txt", &fbuf);
    try testing.expectEqualStrings("nested-ok\n", deep);

    // Warm path: second call returns the same rt without re-extracting.
    var rtbuf2: [MAX_PATH]u8 = undefined;
    const rt2 = try materialize(io, testing.allocator, exe, home, null, null, 1000, 7, &rtbuf2);
    try testing.expectEqualStrings(rt, rt2);
}
