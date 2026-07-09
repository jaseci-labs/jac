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
const builtin = @import("builtin");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const flate = std.compress.flate;

/// Trailer layout: magic(8) + payload_len u64-LE(8) + sha256 hex(64) = 80 bytes.
/// This is the ONE authoritative definition of the on-disk trailer wire format
/// in the whole codebase; pack.zig reuses these constants and the append/graft
/// helpers below, and nothing outside Zig parses or writes a trailer.
pub const MAGIC = "JACBIN01";
/// Overlay marker for an appended `.jab` app image. A `jac build --as binary`
/// artifact is `[ base bundled jac ][ app.jab ][ overlay trailer ]`: the base
/// binary is byte-identical to the installed `jac`, and its own JACBIN01 payload
/// trailer is no longer at EOF. This distinct magic lets `materialize` tell an
/// app binary from a plain one in a single 8-byte read and step over the overlay
/// to find the real payload trailer. Same 80-byte layout as MAGIC, so the two
/// share the whole codec below.
pub const OVERLAY_MAGIC = "JABOVL01";
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
/// The `<hash16>-<pathhash>` shape is deliberate: `gcStale` reads the
/// `<pathhash>` suffix to reclaim only THIS binary's own older versions while
/// leaving other binaries' trees untouched.
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

/// Decode an 80-byte trailer blob, requiring `magic` (MAGIC or OVERLAY_MAGIC).
/// Pure function (no I/O) so it is trivially testable and reused by the warm and
/// cold paths, the overlay detector, and the append/graft tools.
pub fn parseTrailerMagic(bytes: *const [TRAILER_LEN]u8, magic: []const u8) Error!Trailer {
    if (!std.mem.eql(u8, bytes[0..MAGIC_LEN], magic)) return Error.BadMagic;
    const payload_len = std.mem.readInt(u64, bytes[MAGIC_LEN..][0..8], .little);
    var t: Trailer = .{ .payload_len = payload_len, .hash = undefined, .hash16 = undefined };
    @memcpy(&t.hash, bytes[MAGIC_LEN + 8 ..][0..HASH_LEN]);
    @memcpy(&t.hash16, t.hash[0..16]);
    return t;
}

/// Decode a JACBIN01 payload trailer.
pub fn parseTrailer(bytes: *const [TRAILER_LEN]u8) Error!Trailer {
    return parseTrailerMagic(bytes, MAGIC);
}

/// An appended `.jab` app overlay, located within the binary: `[off, off+len)`
/// is the raw `.jab` (tar.gz) bytes, immediately followed by the 80-byte overlay
/// trailer at EOF. The Python boot path slices exactly this region out of
/// `sys.executable` and hands it to `materialize_jab_bytes` -- so it never needs
/// to know the trailer format.
pub const Overlay = struct { off: u64, len: u64 };

/// If the file ends in an OVERLAY_MAGIC trailer, return the appended `.jab`'s
/// `[off, len]`; otherwise null (a plain bundled `jac`, ninja stub, or desktop
/// host -- all of which end in a JACBIN01 payload trailer). `total` is the full
/// file length. Pure over an open file so both `materialize` (step over the
/// overlay) and `overlayForPath` (report it to the CLI boot) share one decoder.
fn peekOverlay(io: Io, file: *Io.File, total: u64) !?Overlay {
    if (total < TRAILER_LEN) return null;
    var traw: [TRAILER_LEN]u8 = undefined;
    if ((try file.readPositionalAll(io, &traw, total - TRAILER_LEN)) != TRAILER_LEN)
        return null;
    if (!std.mem.eql(u8, traw[0..MAGIC_LEN], OVERLAY_MAGIC)) return null;
    const t = try parseTrailerMagic(&traw, OVERLAY_MAGIC);
    const off = std.math.sub(u64, total, TRAILER_LEN + t.payload_len) catch
        return Error.PayloadOffsetUnderflow;
    return Overlay{ .off = off, .len = t.payload_len };
}

/// Open `exe_path` and report a trailing `.jab` overlay (or null). Used by the
/// launcher to export JAC_APP_OVERLAY_OFF/_LEN before booting CPython, so the
/// bundled-app boot can slice its own image out of the running binary. Any I/O
/// error degrades to null -- a binary we cannot read is simply "no overlay",
/// and the normal `materialize` open below surfaces the real error.
pub fn overlayForPath(io: Io, exe_path: []const u8) ?Overlay {
    var file = Io.Dir.cwd().openFile(io, exe_path, .{}) catch return null;
    defer file.close(io);
    const total = file.length(io) catch return null;
    return (peekOverlay(io, &file, total) catch return null);
}

/// Write `[ base ][ jab ][ OVERLAY_MAGIC | jab_len u64 LE | sha256(jab) hex ]`
/// to `out_path`. `base` must be a plain bundled `jac` (its EOF is a JACBIN01
/// payload trailer, never already an overlay -- rejected as BadMagic). This is
/// the ONE writer for `jac build --as binary`; it copies the base verbatim (no
/// CPython unpack/repack) and appends the deterministic `.jab` unchanged, so the
/// artifact is reproducible whenever the inputs are. The caller chmods the
/// result executable (this module stays libc-free for `zig test`).
pub fn appendOverlay(
    io: Io,
    gpa: Allocator,
    base_path: []const u8,
    jab_path: []const u8,
    out_path: []const u8,
) !void {
    const base = try Io.Dir.cwd().readFileAlloc(io, base_path, gpa, .unlimited);
    defer gpa.free(base);
    if (base.len < TRAILER_LEN or
        !std.mem.eql(u8, base[base.len - TRAILER_LEN ..][0..MAGIC_LEN], MAGIC))
        return Error.BadMagic;

    const jab = try Io.Dir.cwd().readFileAlloc(io, jab_path, gpa, .unlimited);
    defer gpa.free(jab);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(jab, &digest, .{});
    const hex = hexDigest(&digest);
    var lenle: [8]u8 = undefined;
    std.mem.writeInt(u64, &lenle, jab.len, .little);

    var out = try Io.Dir.cwd().createFile(io, out_path, .{ .truncate = true });
    defer out.close(io);
    try out.writeStreamingAll(io, base);
    try out.writeStreamingAll(io, jab);
    try out.writeStreamingAll(io, OVERLAY_MAGIC);
    try out.writeStreamingAll(io, &lenle);
    try out.writeStreamingAll(io, &hex);
}

/// Append the running binary's `[ payload ][ JACBIN01 trailer ]` runtime suffix
/// onto `host_path` (in place), fusing the bundled CPython+jaclang runtime into
/// a foreign host binary (the `na` desktop host). Reads `self_path`, steps over
/// an overlay if one is present (the plain `jac` used for the fuse never has
/// one), validates the base ends in a JACBIN01 trailer, and appends the suffix.
/// Replaces the hand-rolled trailer parse the desktop builder used to carry.
pub fn graftRuntime(
    io: Io,
    gpa: Allocator,
    self_path: []const u8,
    host_path: []const u8,
) !void {
    const self_bytes = try Io.Dir.cwd().readFileAlloc(io, self_path, gpa, .unlimited);
    defer gpa.free(self_bytes);

    var base_total: u64 = self_bytes.len;
    if (base_total >= TRAILER_LEN and
        std.mem.eql(u8, self_bytes[base_total - TRAILER_LEN ..][0..MAGIC_LEN], OVERLAY_MAGIC))
    {
        const olen = std.mem.readInt(u64, self_bytes[base_total - TRAILER_LEN + MAGIC_LEN ..][0..8], .little);
        base_total = std.math.sub(u64, base_total, TRAILER_LEN + olen) catch
            return Error.PayloadOffsetUnderflow;
    }
    if (base_total < TRAILER_LEN or
        !std.mem.eql(u8, self_bytes[base_total - TRAILER_LEN ..][0..MAGIC_LEN], MAGIC))
        return Error.BadMagic;
    const payload_len = std.mem.readInt(u64, self_bytes[base_total - TRAILER_LEN + MAGIC_LEN ..][0..8], .little);
    const suffix_start = std.math.sub(u64, base_total, TRAILER_LEN + payload_len) catch
        return Error.PayloadOffsetUnderflow;
    const suffix = self_bytes[suffix_start..base_total];

    // Append the suffix at EOF WITHOUT truncating the host: a failed or
    // interrupted write can only leave a partial suffix (an invalid trailer --
    // harmless, the host is a regenerable build intermediate), never a zeroed
    // host, and the host's existing mode is preserved. Mirrors the old
    // `open(host, "ab")` the Python desktop builder used.
    var host_file = try Io.Dir.cwd().openFile(io, host_path, .{ .mode = .read_write });
    defer host_file.close(io);
    const end = try host_file.length(io);
    try host_file.writePositionalAll(io, suffix, end);
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

    // An app binary (`jac build --as binary`) appends `[ app.jab ][ overlay ]`
    // after the base binary's payload trailer, so EOF is the overlay, not the
    // JACBIN01 payload trailer. Step over it: everything below operates on the
    // base binary's logical length, and the appended `.jab` is mounted
    // separately (the CLI boot slices it out via JAC_APP_OVERLAY_OFF/_LEN). The
    // cache key still folds only the base payload digest + exe path, so an app
    // binary shares the extracted CPython tree with the plain `jac` it was built
    // from (same payload) yet gets its own tree per install path (issue #7012).
    const full_total = try file.length(io);
    const total = if (try peekOverlay(io, &file, full_total)) |o| o.off else full_total;
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
    if (!builtin.is_test)
        std.debug.print(
            "jac: first run, performing one-time setup...\n",
            .{},
        );

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
    gcStale(io, root, &key);
    if (!builtin.is_test)
        std.debug.print("jac: one-time setup complete.\n", .{});
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

/// Best-effort GC of THIS binary's own older-version trees. Replaces the C
/// launcher's `system("find ... -exec rm -rf")`.
///
/// `keep_key` is the CURRENT `<hash16>-<pathhash>` dir name. A tree is reclaimed
/// only when its `<pathhash>` suffix matches this binary's (an older version of
/// THIS binary) and its name differs from `keep_key`. A tree with a different
/// `<pathhash>` belongs to another binary and is left untouched, so a cold start
/// here can never evict a tree another binary is still reading from.
fn gcStale(io: Io, root: []const u8, keep_key: *const [RT_KEY_LEN]u8) void {
    var rtbuf: [MAX_PATH]u8 = undefined;
    const rtdir = std.fmt.bufPrint(&rtbuf, "{s}/rt", .{root}) catch return;
    var dir = Io.Dir.cwd().openDir(io, rtdir, .{ .iterate = true }) catch return;
    defer dir.close(io);
    // `<pathhash>` is the 16-char suffix after the '-' separator (see `rtKey`).
    const my_pathhash = keep_key[17..RT_KEY_LEN];
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.indexOf(u8, entry.name, ".tmp.") != null) continue; // a live extract
        if (entry.name.len != RT_KEY_LEN) continue; // not a current-format key
        // A different binary's tree -> never evict.
        if (!std.mem.eql(u8, entry.name[17..RT_KEY_LEN], my_pathhash)) continue;
        // Our own current version -> keep; our own older versions -> reclaim.
        if (std.mem.eql(u8, entry.name, keep_key)) continue;
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

    // Unwritable preferred root -> temp fallback keyed by uid. The probe path
    // must FAIL cleanly: a component that is a file (/dev/null) yields ENOTDIR
    // on both Linux and macOS. Do NOT use a /proc path here -- createDirPath
    // livelocks under the read-only /proc pseudo-fs on Linux (mkdir returns
    // EROFS, never ENOENT, so make-parents neither progresses nor backs off),
    // which hung this whole `zig build test` step on the Linux CI legs.
    var tmp_buf: [MAX_PATH]u8 = undefined;
    const tmpdir = tmp_buf[0..try tmp.dir.realPath(io, &tmp_buf)];
    const fb = try cacheRoot(io, "/dev/null/ro", null, tmpdir, 4242, &out);
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

// gcStale reclaims THIS binary's own older-version trees but must never evict a
// tree that carries a different `<pathhash>` -- another binary sharing the cache
// home, possibly a still-running deploy on another jac version.
test "materialize gc reclaims own old versions but spares other binaries" {
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

    // This binary's `<pathhash>` (the suffix of its current key).
    const my_key = rtKey(hex[0..16], exe);
    const my_pathhash = my_key[17..RT_KEY_LEN];

    // Seed two trees under `<home>/jac/rt/`, each with a `.ok` marker:
    //  (a) an OLD version of THIS binary: our `<pathhash>`, a bogus `<hash16>`.
    //  (b) ANOTHER binary's current-version tree: a foreign `<pathhash>`.
    var b: [MAX_PATH]u8 = undefined;
    const mine_old = std.fmt.bufPrint(&b, "0000000000000000-{s}", .{my_pathhash}) catch unreachable;
    const other = "fedcba9876543210-ffffffffffffffff"; // foreign pathhash suffix
    inline for (.{ mine_old, other }) |name| {
        var d: [MAX_PATH]u8 = undefined;
        const dd = std.fmt.bufPrint(&d, "jac/rt/{s}", .{name}) catch unreachable;
        try tmp.dir.createDirPath(io, dd);
        var r: [MAX_PATH]u8 = undefined;
        const p = std.fmt.bufPrint(&r, "{s}/.ok", .{dd}) catch unreachable;
        try tmp.dir.writeFile(io, .{ .sub_path = p, .data = "" });
    }

    var rtbuf: [MAX_PATH]u8 = undefined;
    const rt = try materialize(io, testing.allocator, exe, home, null, null, 1000, 7, &rtbuf);
    try testing.expect(std.mem.endsWith(u8, rt, &my_key)); // current tree present

    var abs: [MAX_PATH]u8 = undefined;
    // (a) our own old version -> reclaimed
    const mine_abs = std.fmt.bufPrint(&abs, "{s}/jac/rt/{s}", .{ home, mine_old }) catch unreachable;
    try testing.expect(!pathExists(io, mine_abs, ".ok"));
    // (b) another binary's tree -> spared (the concurrent-safety guard)
    const other_abs = std.fmt.bufPrint(&abs, "{s}/jac/rt/{s}", .{ home, other }) catch unreachable;
    try testing.expect(pathExists(io, other_abs, ".ok"));
}

// Join `<tmp>/<name>` into `buf`, returning an absolute path usable with
// Io.Dir.cwd() (createFile/readFileAlloc take cwd-relative-or-absolute paths).
fn tmpJoin(io: Io, tmp: *std.testing.TmpDir, name: []const u8, buf: []u8) ![]const u8 {
    var base: [MAX_PATH]u8 = undefined;
    const dir = base[0..try tmp.dir.realPath(io, &base)];
    return std.fmt.bufPrint(buf, "{s}/{s}", .{ dir, name });
}

// appendOverlay writes [ base ][ jab ][ OVERLAY_MAGIC | len | sha256 ]; peekOverlay
// (via overlayForPath) must report the .jab region [base.len, jab.len] and the
// bytes there must be the exact .jab, so the Python boot can slice it out blind.
test "appendOverlay embeds a .jab overlay and overlayForPath locates it" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);
    var fake = try buildFakeBinary(payload); // [STUB][payload][JACBIN01 trailer]
    defer fake.bin.deinit();
    const base_len = fake.bin.items.len;
    const jab = "JAB\x00fake-sealed-image-tar-gz-bytes\x01\x02\x03";

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "base", .data = fake.bin.items });
    try tmp.dir.writeFile(io, .{ .sub_path = "app.jab", .data = jab });

    var bb: [MAX_PATH]u8 = undefined;
    var jb: [MAX_PATH]u8 = undefined;
    var ob: [MAX_PATH]u8 = undefined;
    const base_p = try tmpJoin(io, &tmp, "base", &bb);
    const jab_p = try tmpJoin(io, &tmp, "app.jab", &jb);
    const out_p = try tmpJoin(io, &tmp, "appbin", &ob);

    try appendOverlay(io, testing.allocator, base_p, jab_p, out_p);

    const ovl = overlayForPath(io, out_p) orelse return error.NoOverlayDetected;
    try testing.expectEqual(@as(u64, base_len), ovl.off);
    try testing.expectEqual(@as(u64, jab.len), ovl.len);

    // The bytes at [off, off+len) are the .jab, verbatim.
    var f = try Io.Dir.cwd().openFile(io, out_p, .{});
    defer f.close(io);
    var slice: [64]u8 = undefined;
    _ = try f.readPositionalAll(io, slice[0..jab.len], ovl.off);
    try testing.expectEqualStrings(jab, slice[0..jab.len]);
}

// A plain bundled jac (JACBIN01 at EOF) has no overlay.
test "overlayForPath returns null for a plain binary" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);
    var fake = try buildFakeBinary(payload);
    defer fake.bin.deinit();

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "base", .data = fake.bin.items });
    var bb: [MAX_PATH]u8 = undefined;
    const base_p = try tmpJoin(io, &tmp, "base", &bb);
    try testing.expect(overlayForPath(io, base_p) == null);
}

// appendOverlay must reject a base that is not a bundled jac (no JACBIN01 tail),
// the single detector that replaces the old Python `_split_jac_binary` gate.
test "appendOverlay rejects a non-bundled base" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "notjac", .data = "not a bundled jac binary" });
    try tmp.dir.writeFile(io, .{ .sub_path = "app.jab", .data = "jab" });
    var bb: [MAX_PATH]u8 = undefined;
    var jb: [MAX_PATH]u8 = undefined;
    var ob: [MAX_PATH]u8 = undefined;
    const base_p = try tmpJoin(io, &tmp, "notjac", &bb);
    const jab_p = try tmpJoin(io, &tmp, "app.jab", &jb);
    const out_p = try tmpJoin(io, &tmp, "out", &ob);
    try testing.expectError(Error.BadMagic, appendOverlay(io, testing.allocator, base_p, jab_p, out_p));
}

// The whole point of the overlay marker: materialize must extract the SAME
// CPython payload from an app binary as from the plain base, stepping over the
// appended .jab instead of mis-reading the overlay trailer as the payload one.
test "materialize steps over a .jab overlay to the base payload" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);
    var fake = try buildFakeBinary(payload);
    defer fake.bin.deinit();
    const hex = fake.hex;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var pbuf: [MAX_PATH]u8 = undefined;
    const home = pbuf[0..try tmp.dir.realPath(io, &pbuf)];

    // Build the app binary: base ++ jab ++ overlay trailer, via appendOverlay.
    try tmp.dir.writeFile(io, .{ .sub_path = "base", .data = fake.bin.items });
    try tmp.dir.writeFile(io, .{ .sub_path = "app.jab", .data = "pretend-sealed-image" });
    var bb: [MAX_PATH]u8 = undefined;
    var jb: [MAX_PATH]u8 = undefined;
    var ob: [MAX_PATH]u8 = undefined;
    const base_p = try tmpJoin(io, &tmp, "base", &bb);
    const jab_p = try tmpJoin(io, &tmp, "app.jab", &jb);
    const app_p = try tmpJoin(io, &tmp, "appbin", &ob);
    try appendOverlay(io, testing.allocator, base_p, jab_p, app_p);

    var rtbuf: [MAX_PATH]u8 = undefined;
    const rt = try materialize(io, testing.allocator, app_p, home, null, null, 1000, 7, &rtbuf);

    // Cache key folds the BASE payload digest (unchanged by the overlay) + path.
    try testing.expect(std.mem.indexOf(u8, rt, hex[0..16]) != null);
    // And the CPython payload extracted correctly despite the trailing overlay.
    var dir = try Io.Dir.cwd().openDir(io, rt, .{});
    defer dir.close(io);
    var fbuf: [64]u8 = undefined;
    const marker = try dir.readFile(io, "python/lib/marker.txt", &fbuf);
    try testing.expectEqualStrings("pybytecode-marker\n", marker);
}

// graftRuntime appends the running binary's [ payload ][ JACBIN01 trailer ]
// suffix onto a host binary (the desktop fuse), replacing the Python parser.
test "graftRuntime fuses the runtime suffix onto a host binary" {
    const io = testing.io;
    const payload = try @import("tests/fixture.zig").payloadAlloc(testing.allocator);
    defer testing.allocator.free(payload);
    var fake = try buildFakeBinary(payload); // 4-byte "STUB" + payload + 80-byte trailer
    defer fake.bin.deinit();

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const host_before = "HOST-DESKTOP-STUB";
    try tmp.dir.writeFile(io, .{ .sub_path = "selfjac", .data = fake.bin.items });
    try tmp.dir.writeFile(io, .{ .sub_path = "host", .data = host_before });
    var sb: [MAX_PATH]u8 = undefined;
    var hb: [MAX_PATH]u8 = undefined;
    const self_p = try tmpJoin(io, &tmp, "selfjac", &sb);
    const host_p = try tmpJoin(io, &tmp, "host", &hb);

    try graftRuntime(io, testing.allocator, self_p, host_p);

    const grafted = try Io.Dir.cwd().readFileAlloc(io, host_p, testing.allocator, .unlimited);
    defer testing.allocator.free(grafted);
    // suffix = payload ++ trailer = everything after the 4-byte "STUB".
    const suffix = fake.bin.items[4..];
    try testing.expectEqual(host_before.len + suffix.len, grafted.len);
    try testing.expectEqualStrings(host_before, grafted[0..host_before.len]);
    try testing.expectEqualSlices(u8, suffix, grafted[host_before.len..]);
}
