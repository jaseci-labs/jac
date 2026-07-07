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
//! `<cache>/rt/<hash16>-<pathhash>/` (atomic temp-dir + rename). `<hash16>` is
//! the first 16 hex chars of the trailer digest (the payload version);
//! `<pathhash>` folds in the binary's own path so co-located checkouts with
//! identical payloads get distinct trees (see `rtKey`, issue #7012). A `.ok`
//! marker guards against partial extracts; subsequent runs short-circuit on it.
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

/// Trailer layout: magic(8) + payload_len u64-LE(8) + sha256 hex(64) = 80 bytes.
/// This is the authoritative definition; pack.zig reuses these constants, and
/// the Python repacker (`_bundle_binary` / `_split_jac_binary` in
/// jaclang/cli/commands/impl/project.impl.jac) mirrors them byte-for-byte.
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
    /// First 16 hex chars of `hash`; the payload-version prefix of the
    /// `rt/<hash16>-<pathhash>` dir name (see `rtKey`).
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

/// Length of an `rt/<key>` cache-dir name: `<hash16>` + '-' + 16 path-hash hex.
pub const RT_KEY_LEN = 16 + 1 + 16; // 33

/// Cache-key dir name for the runtime tree: the payload version (`hash16`)
/// folded together with a short digest of the binary's own path.
///
/// Keying on the path as well as the payload is what isolates co-located
/// checkouts (issue #7012): two clones whose payloads are byte-identical share
/// one `hash16`, so a payload-only key (`rt/<hash16>`) collapsed them onto a
/// single materialized tree -- and whichever ran first baked in its own
/// absolute dev-source paths, so the second checkout silently executed the
/// first's source. Distinct binary paths now yield distinct `rt/<key>` trees.
///
/// The `<hash16>-...` shape is deliberate: every key for a given payload version
/// shares the `hash16` prefix, which `gcStale` uses to keep sibling checkouts
/// while still reclaiming trees from previous versions.
pub fn rtKey(hash16: *const [16]u8, exe_path: []const u8) [RT_KEY_LEN]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(exe_path, &digest, .{});
    const path_hex = hexDigest(&digest);
    var key: [RT_KEY_LEN]u8 = undefined;
    @memcpy(key[0..16], hash16);
    key[16] = '-';
    @memcpy(key[17..RT_KEY_LEN], path_hex[0..16]);
    return key;
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
/// Returns the `<cache>/rt/<hash16>-<pathhash>` path inside `rt_out`.
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

    const key = rtKey(&trailer.hash16, exe_path);
    const rt = std.fmt.bufPrint(rt_out, "{s}/rt/{s}", .{ root, &key }) catch
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

/// Best-effort GC of `rt/<old-hash>...` trees left by previous binary versions.
/// Replaces the C launcher's `system("find ... -exec rm -rf")`.
///
/// `keep_hash16` is the CURRENT payload version. Every co-located checkout of
/// that version shares this prefix (`<hash16>-<pathhash>`, see `rtKey`), so we
/// keep them all -- evicting a sibling here would force it to re-extract on its
/// next run, churning the cache for no benefit. Trees whose prefix differs
/// belong to a previous version and are reclaimed; so are pre-fix entries named
/// by the bare `<hash16>` (a payload-only key), which no current binary looks
/// up -- the length check evicts them on the first run after upgrading rather
/// than letting them linger until the next version bump.
fn gcStale(io: Io, root: []const u8, keep_hash16: *const [16]u8) void {
    var rtbuf: [MAX_PATH]u8 = undefined;
    const rtdir = std.fmt.bufPrint(&rtbuf, "{s}/rt", .{root}) catch return;
    var dir = Io.Dir.cwd().openDir(io, rtdir, .{ .iterate = true }) catch return;
    defer dir.close(io);
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        // A current-version tree in the new key format -> keep. hash16 is a
        // fixed 16-char hex string, so a prefix match is an exact version match;
        // the length check excludes both other versions and the old bare-hash16
        // format. (A live `.tmp.<pid>` extract is longer than RT_KEY_LEN, so it
        // falls through to the explicit skip below rather than being kept here.)
        if (entry.name.len == RT_KEY_LEN and std.mem.startsWith(u8, entry.name, keep_hash16)) continue;
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
// Test helper: assemble a fake jac binary (4-byte stub + payload + trailer).
const FakeBinary = struct { bin: std.array_list.Managed(u8), hex: [64]u8 };
fn buildFakeBinary(payload: []const u8) !FakeBinary {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
    const hex = hexDigest(&digest);

    var bin = std.array_list.Managed(u8).init(testing.allocator);
    errdefer bin.deinit();
    try bin.appendSlice("STUB");
    try bin.appendSlice(payload);
    try bin.appendSlice(MAGIC);
    var lenle: [8]u8 = undefined;
    std.mem.writeInt(u64, &lenle, payload.len, .little);
    try bin.appendSlice(&lenle);
    try bin.appendSlice(&hex);
    return .{ .bin = bin, .hex = hex };
}

test "materialize extracts the fixture payload and is idempotent" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var pbuf: [MAX_PATH]u8 = undefined;
    const home = pbuf[0..try tmp.dir.realPath(io, &pbuf)];

    // Build the fake binary: 4-byte stub + payload + trailer.
    var fake = try buildFakeBinary(payload);
    defer fake.bin.deinit();
    const hex = fake.hex;

    try tmp.dir.writeFile(io, .{ .sub_path = "jacbin", .data = fake.bin.items });
    var ebuf: [MAX_PATH]u8 = undefined;
    const exe = ebuf[0..try tmp.dir.realPathFile(io, "jacbin", &ebuf)];

    var rtbuf: [MAX_PATH]u8 = undefined;
    const rt = try materialize(io, testing.allocator, exe, home, null, null, 1000, 7, &rtbuf);

    // Expected key = `<hash16>-<pathhash>` (rtKey): payload version then path.
    try testing.expect(std.mem.endsWith(u8, rt, &rtKey(hex[0..16], exe)));
    try testing.expect(std.mem.indexOf(u8, rt, hex[0..16]) != null);

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

// Regression for #7012: two co-located checkouts whose payloads are
// byte-identical (same trailer digest) must NOT share one materialized rt tree.
// Keying the rt dir on the payload digest alone made both binaries resolve to
// `rt/<hash16>`, so the second checkout silently ran the first's dev-linked
// source. Build the SAME binary at two different paths under one cache home and
// assert they materialize into distinct rt trees.
test "materialize isolates co-located binaries with identical payloads" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var pbuf: [MAX_PATH]u8 = undefined;
    const home = pbuf[0..try tmp.dir.realPath(io, &pbuf)];

    // One binary image; the two checkouts differ only by where the file lives.
    var fake = try buildFakeBinary(payload);
    defer fake.bin.deinit();
    const hex = fake.hex;

    try tmp.dir.createDirPath(io, "a");
    try tmp.dir.createDirPath(io, "b");
    try tmp.dir.writeFile(io, .{ .sub_path = "a/jacbin", .data = fake.bin.items });
    try tmp.dir.writeFile(io, .{ .sub_path = "b/jacbin", .data = fake.bin.items });
    var abuf: [MAX_PATH]u8 = undefined;
    var bbuf: [MAX_PATH]u8 = undefined;
    const exe_a = abuf[0..try tmp.dir.realPathFile(io, "a/jacbin", &abuf)];
    const exe_b = bbuf[0..try tmp.dir.realPathFile(io, "b/jacbin", &bbuf)];

    var rt_a_buf: [MAX_PATH]u8 = undefined;
    var rt_b_buf: [MAX_PATH]u8 = undefined;
    const rt_a = try materialize(io, testing.allocator, exe_a, home, null, null, 1000, 7, &rt_a_buf);
    const rt_b = try materialize(io, testing.allocator, exe_b, home, null, null, 1000, 8, &rt_b_buf);

    // Distinct checkouts -> distinct trees, even with an identical payload.
    try testing.expect(!std.mem.eql(u8, rt_a, rt_b));
    // Both still carry the payload version (hash16) so a version bump GCs both.
    try testing.expect(std.mem.indexOf(u8, rt_a, hex[0..16]) != null);
    try testing.expect(std.mem.indexOf(u8, rt_b, hex[0..16]) != null);

    // Each tree extracted independently and completely.
    for ([_][]const u8{ rt_a, rt_b }) |rt| {
        var dir = try Io.Dir.cwd().openDir(io, rt, .{});
        defer dir.close(io);
        var fbuf: [64]u8 = undefined;
        const marker = try dir.readFile(io, "python/lib/marker.txt", &fbuf);
        try testing.expectEqualStrings("pybytecode-marker\n", marker);
    }
}

// A pre-fix binary wrote the cache dir under the bare payload digest
// (`rt/<hash16>`). After upgrading to a path-folded binary, that orphaned
// old-format tree is never looked up again, so the cold-path GC must reclaim it
// on the first run rather than leaving it until the next payload-version bump.
test "materialize gc reclaims pre-fix bare-hash16 cache dirs" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var pbuf: [MAX_PATH]u8 = undefined;
    const home = pbuf[0..try tmp.dir.realPath(io, &pbuf)];

    var fake = try buildFakeBinary(payload);
    defer fake.bin.deinit();
    const hex = fake.hex;
    try tmp.dir.writeFile(io, .{ .sub_path = "jacbin", .data = fake.bin.items });
    var ebuf: [MAX_PATH]u8 = undefined;
    const exe = ebuf[0..try tmp.dir.realPathFile(io, "jacbin", &ebuf)];

    // Pre-seed the old-format tree `<home>/jac/rt/<hash16>` (bare digest, the
    // shape a pre-fix binary wrote), complete with its `.ok` marker.
    var oldrel: [MAX_PATH]u8 = undefined;
    const old_rel = std.fmt.bufPrint(&oldrel, "jac/rt/{s}", .{hex[0..16]}) catch unreachable;
    try tmp.dir.createDirPath(io, old_rel);
    var okrel: [MAX_PATH]u8 = undefined;
    const ok_rel = std.fmt.bufPrint(&okrel, "{s}/.ok", .{old_rel}) catch unreachable;
    try tmp.dir.writeFile(io, .{ .sub_path = ok_rel, .data = "" });

    var oldabs: [MAX_PATH]u8 = undefined;
    const old_abs = std.fmt.bufPrint(&oldabs, "{s}/jac/rt/{s}", .{ home, hex[0..16] }) catch unreachable;
    try testing.expect(pathExists(io, old_abs, ".ok")); // present before upgrade

    // Cold-path materialize runs gcStale; the old-format tree must be gone and
    // the new path-folded tree present.
    var rtbuf: [MAX_PATH]u8 = undefined;
    const rt = try materialize(io, testing.allocator, exe, home, null, null, 1000, 7, &rtbuf);
    try testing.expect(std.mem.endsWith(u8, rt, &rtKey(hex[0..16], exe)));
    try testing.expect(!pathExists(io, old_abs, ".ok")); // reclaimed on first run
}
