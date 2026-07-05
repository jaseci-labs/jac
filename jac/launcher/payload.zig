//! Build-time payload tool (pure Zig, std-only) -- replaces the three bash
//! scripts (fetch-pbs.sh, fetch-typeshed.sh, mkpayload.sh) with one executable.
//!
//! The host-tool dependencies the scripts needed (bash, curl, git, zstd, tar,
//! find, cp) are gone: HTTP is `std.http.Client`, integrity is
//! `std.crypto.sha2`, the pbs archive is decoded with `std.compress.zstd`, the
//! typeshed tarball with `std.compress.flate`, the final payload is written with
//! `std.tar.Writer` + `std.compress.flate` (gzip), and all file shuffling is
//! `std.Io.Dir`. The remaining shellouts are to the freshly-fetched pbs
//! `python` -- pip installs and the JIR precompile -- because those genuinely
//! require executing CPython (see launcher/README.md "Bucket B"), plus a
//! best-effort `strip` to shed the unstripped pbs libpython's debug/bitcode
//! bloat (optional; the build still works if `strip` is absent).
//!
//! Subcommands (build.zig invokes the tool once per step, mirroring the old
//! script split so each keeps its caching semantics):
//!
//!   payload fetch-pbs <os-arch> <dest-dir>
//!       Download + verify + extract a python-build-standalone tree into
//!       <dest-dir>/python. Idempotent (no-op if <dest>/python/PYTHON.json).
//!
//!   payload fetch-typeshed <repo-root>
//!       Materialize the gitignored typeshed stdlib stubs at the pinned commit
//!       (jaclang/vendor/typeshed/PIN) into jaclang/vendor/typeshed/stdlib,
//!       verified against jaclang/vendor/typeshed/TARBALL_SHA256. Idempotent.
//!
//!   payload mkpayload <pbs-python-dir> <repo-root> <out.tar.gz>
//!       Assemble the runtime payload: jaclang site + private CPython, tarred
//!       and gzip-compressed (the format runtime.zig decompresses).
//!
//!   payload typeshed-sha <commit>
//!       Print the decompressed-tar sha256 for a typeshed commit -- the value to
//!       write into jaclang/vendor/typeshed/TARBALL_SHA256 when bumping the PIN.

const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const flate = std.compress.flate;
const zstd = std.compress.zstd;
const Dir = Io.Dir;
const runtime = @import("runtime.zig");

// --- pinned versions ----------------------------------------------------------
// The bundled CPython minor version has ONE definition (embed.zig); only the
// pbs patch release is pinned here and must match it.
const py_ver = @import("embed.zig").py_ver;
const PBS_TAG = "20260610";
const PBS_PY = "3.14.6";
comptime {
    if (!std.mem.startsWith(u8, PBS_PY, py_ver ++ "."))
        @compileError("PBS_PY must be a patch release of embed.zig's py_ver");
}
const PBS_FLAVOR = "pgo+lto-full";
const PBS_BASE = "https://github.com/astral-sh/python-build-standalone/releases/download";
// The window pbs compresses its archives with (verified: `zstd -lv` reports
// 128 MiB). `fetch-pbs.sh` passed `zstd -d --long=31` only as a permissive cap;
// the real window is 128 MiB, so that is all the decode buffer we allocate.
const PBS_WINDOW = 1 << 27; // 128 MiB

const TYPESHED_TARBALL_BASE = "https://codeload.github.com/python/typeshed/tar.gz";
const TYPESHED_VENDOR = "jaclang/vendor/typeshed";

// Pinned bun version -- keep in lockstep with bun_installer.jac `BUN_VERSION`
// (the Jac-side single source of truth for the resolver/dev-download). bun is
// bundled, contained, inside the client package (see mkpayload's --bun staging)
// and resolved by absolute path at runtime -- never placed on the user's PATH.
const BUN_VERSION = "1.3.11";
const BUN_BASE = "https://github.com/oven-sh/bun/releases/download";

const MAX_PATH = Dir.max_path_bytes;

const Cmd = enum { @"fetch-pbs", @"fetch-typeshed", @"fetch-llvm", @"fetch-bun", @"build-musl", @"build-wasm-libc", mkpayload, @"typeshed-sha" };

// The pinned LLVM release + per-platform slice table lives in llvm_release.zig
// (shared with build.zig, so the fetch and the build can't drift).
const llvm_release = @import("llvm_release.zig");
const LLVM_VER = llvm_release.LLVM_VER;
const LlvmRelease = llvm_release.LlvmRelease;

// jaseci-labs/llvm-slice repackages the official LLVM release into a per-member,
// HTTP-range-fetchable zip. fetchLlvmSlice pulls only the ~84 MB the shim needs
// (lib/libLLVM*.a + include/llvm[-c], +macOS lib/libLTO.dylib) out of the ~970 MB
// "dev" zip -- skipping the slow xz tarball download+decompress entirely. The
// pinned `manifest_sha256` anchors a hash chain (verified manifest -> per-archive
// sha256), so no swapped asset slips into the archives linked into the shipped shim.
const SLICE_BASE = "https://github.com/jaseci-labs/llvm-slice/releases/download";
const SLICE_TAG = "v" ++ LLVM_VER;

// The release is selected for the build host (this tool runs on it).
fn llvmRelease() ?LlvmRelease {
    return llvm_release.llvmRelease(builtin.os.tag, builtin.cpu.arch);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var argv: [16][]const u8 = undefined;
    var n: usize = 0;
    var it = init.minimal.args.iterate();
    // Cap at argv.len: every subcommand here takes a fixed, small set of args, so
    // dropping any beyond the cap is harmless -- and it keeps `n` an exact count
    // of the SLOTS WRITTEN, so the later flag loops (`while (i < n)`) never index
    // past the array. (Unconditionally incrementing `n` would let it exceed
    // argv.len and read uninitialized/out-of-bounds slots.)
    while (it.next()) |a| {
        if (n >= argv.len) break;
        argv[n] = a;
        n += 1;
    }
    if (n < 2) die("usage: payload <fetch-pbs|fetch-typeshed|mkpayload> ...", .{});

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const cmd = std.meta.stringToEnum(Cmd, argv[1]) orelse die("unknown subcommand '{s}'", .{argv[1]});
    switch (cmd) {
        .@"fetch-pbs" => {
            if (n < 4) die("usage: payload fetch-pbs <os-arch> <dest-dir>", .{});
            try fetchPbs(io, gpa, a, argv[2], argv[3]);
        },
        .@"fetch-llvm" => {
            if (n < 3) die("usage: payload fetch-llvm <dest-dir>", .{});
            try fetchLlvm(io, gpa, a, argv[2]);
        },
        .@"fetch-bun" => {
            if (n < 4) die("usage: payload fetch-bun <os-arch> <dest-dir>", .{});
            try fetchBun(io, gpa, a, argv[2], argv[3]);
        },
        .@"build-musl" => {
            if (n < 5) die("usage: payload build-musl <os-arch> <dest-dir> <zig-exe>", .{});
            try buildMusl(io, gpa, a, init.environ_map, argv[2], argv[3], argv[4]);
        },
        .@"build-wasm-libc" => {
            if (n < 5) die("usage: payload build-wasm-libc <wasm-rt-src-dir> <dest-dir> <zig-exe>", .{});
            try buildWasmLibc(io, gpa, a, argv[2], argv[3], argv[4]);
        },
        .@"fetch-typeshed" => {
            if (n < 3) die("usage: payload fetch-typeshed <repo-root>", .{});
            try fetchTypeshed(io, gpa, a, argv[2]);
        },
        .mkpayload => {
            if (n < 5) die("usage: payload mkpayload <pbs-python-dir> <repo-root> <out.tar.gz> [--shim=PATH] [--skip-precompile] [--link-source=PATH] [--precompiled-cache=DIR] [--nvim=DIR] [--seal] [--debug-src]\n(--seal: freeze bootstrap + emit MANIFEST.json; the payload boots from JIR, sources ship for tracebacks)", .{});
            // Trailing flags (after the positional pbs/root/out, see build.zig):
            var shim_so: ?[]const u8 = null;
            var pyembed_so: ?[]const u8 = null;
            var bun_bin: ?[]const u8 = null;
            var skip_precompile = false;
            var link_source: ?[]const u8 = null;
            var musl_dir: ?[]const u8 = null;
            var wasm_libc_dir: ?[]const u8 = null;
            var precompiled_cache: ?[]const u8 = null;
            var nvim_dir: ?[]const u8 = null;
            var seal = false;
            var debug_src = false;
            var i: usize = 5;
            while (i < n) : (i += 1) {
                const arg = argv[i];
                if (std.mem.startsWith(u8, arg, "--shim=")) {
                    shim_so = arg["--shim=".len..];
                } else if (std.mem.startsWith(u8, arg, "--pyembed=")) {
                    pyembed_so = arg["--pyembed=".len..];
                } else if (std.mem.startsWith(u8, arg, "--bun=")) {
                    bun_bin = arg["--bun=".len..];
                } else if (std.mem.eql(u8, arg, "--skip-precompile")) {
                    skip_precompile = true;
                } else if (std.mem.startsWith(u8, arg, "--link-source=")) {
                    link_source = arg["--link-source=".len..];
                } else if (std.mem.startsWith(u8, arg, "--musl=")) {
                    musl_dir = arg["--musl=".len..];
                } else if (std.mem.startsWith(u8, arg, "--wasm-libc=")) {
                    wasm_libc_dir = arg["--wasm-libc=".len..];
                } else if (std.mem.startsWith(u8, arg, "--precompiled-cache=")) {
                    precompiled_cache = arg["--precompiled-cache=".len..];
                } else if (std.mem.startsWith(u8, arg, "--nvim=")) {
                    nvim_dir = arg["--nvim=".len..];
                } else if (std.mem.eql(u8, arg, "--seal")) {
                    seal = true;
                } else if (std.mem.eql(u8, arg, "--debug-src")) {
                    debug_src = true;
                }
            }
            try mkPayload(io, gpa, a, init.environ_map, argv[2], argv[3], argv[4], shim_so, pyembed_so, bun_bin, skip_precompile, link_source, musl_dir, wasm_libc_dir, precompiled_cache, nvim_dir, seal, debug_src);
        },
        .@"typeshed-sha" => {
            if (n < 3) die("usage: payload typeshed-sha <commit>", .{});
            try typeshedSha(io, gpa, a, argv[2]);
        },
    }
}

/// Print the decompressed-tar sha256 for a typeshed commit -- the value to pin
/// in TARBALL_SHA256 when bumping PIN. (No verification: this is how you obtain
/// the trusted value, after reviewing the commit.)
fn typeshedSha(io: Io, gpa: Allocator, a: Allocator, commit: []const u8) !void {
    const url = try std.fmt.allocPrint(a, "{s}/{s}", .{ TYPESHED_TARBALL_BASE, commit });
    const gz = try httpGetAlloc(io, gpa, url);
    defer gpa.free(gz);
    const tar = try gzipDecompressAlloc(io, gpa, gz);
    defer gpa.free(tar);
    const hex = sha256Hex(tar);
    // stdout (not the log stream) so it is pipeable.
    var buf: [128]u8 = undefined;
    var w = Io.File.stdout().writer(io, &buf);
    w.interface.print("{s}\n", .{&hex}) catch {};
    w.interface.flush() catch {};
}

// =============================================================== fetch-pbs ===

fn fetchPbs(io: Io, gpa: Allocator, a: Allocator, osarch: []const u8, dest: []const u8) !void {
    const marker = try std.fmt.allocPrint(a, "{s}/python/PYTHON.json", .{dest});
    if (fileExists(io, marker)) {
        log("fetch-pbs: already present at {s}/python", .{dest});
        return;
    }

    const plat = pbsPlatform(osarch) orelse die("fetch-pbs: unsupported platform '{s}'", .{osarch});
    const asset = try std.fmt.allocPrint(a, "cpython-{s}+{s}-{s}-{s}.tar.zst", .{ PBS_PY, PBS_TAG, plat, PBS_FLAVOR });
    const url = try std.fmt.allocPrint(a, "{s}/{s}/{s}", .{ PBS_BASE, PBS_TAG, asset });

    log("fetch-pbs: downloading {s}", .{asset});
    const tarzst = try httpGetAlloc(io, gpa, url);
    defer gpa.free(tarzst);

    // Verify against the release's SHA256SUMS -- this archive becomes the
    // libpython embedded in every distributed binary, so a swapped/MITM'd asset
    // must not slip through.
    const sums_url = try std.fmt.allocPrint(a, "{s}/{s}/SHA256SUMS", .{ PBS_BASE, PBS_TAG });
    const sums = try httpGetAlloc(io, gpa, sums_url);
    defer gpa.free(sums);
    const expected = findSumLine(sums, asset) orelse die("fetch-pbs: no checksum for {s} in SHA256SUMS", .{asset});
    const actual = sha256Hex(tarzst);
    if (!std.mem.eql(u8, &actual, expected)) {
        die("fetch-pbs: checksum mismatch for {s}\n  expected {s}\n  actual   {s}", .{ asset, expected, &actual });
    }

    // zstd-decompress + untar straight into <dest> (entries start with python/).
    try Dir.cwd().createDirPath(io, dest);
    var ddir = try Dir.cwd().openDir(io, dest, .{});
    defer ddir.close(io);

    const window = try gpa.alloc(u8, PBS_WINDOW + zstd.block_size_max);
    defer gpa.free(window);
    var src = Io.Reader.fixed(tarzst);
    var dz = zstd.Decompress.init(&src, window, .{ .window_len = PBS_WINDOW, .verify_checksum = true });
    // executable_bit_only (not .ignore!) so the bundled `python3.14` keeps its
    // exec bit -- mkpayload spawns it for pip + precompile. With .ignore it
    // extracts 0o644 and the spawn fails EACCES (AccessDenied).
    std.tar.extract(io, ddir, &dz.reader, .{ .mode_mode = .executable_bit_only, .strip_components = 0 }) catch |err|
        die("fetch-pbs: extract failed: {s}", .{@errorName(err)});

    if (!fileExists(io, marker)) die("fetch-pbs: extract produced no PYTHON.json", .{});
    log("fetch-pbs: ready at {s}/python", .{dest});
}

// =============================================================== fetch-llvm ===

/// fetch-llvm: materialize the LLVM headers + static archives the LLVMPY_* shim
/// links, into <dest>/LLVM-...; build.zig points -Dllvm-dir there. Idempotent
/// (skips when the marker archive is already present). fetchLlvmSlice range-fetches
/// only the ~84 MB subset the shim needs from the llvm-slice repackaged zip (no xz,
/// no clang/tools).
fn fetchLlvm(io: Io, gpa: Allocator, a: Allocator, dest: []const u8) !void {
    const rel = llvmRelease() orelse
        die("fetch-llvm: no pinned LLVM release for this host ({s}-{s}); add a row to llvmRelease().", .{ @tagName(builtin.cpu.arch), @tagName(builtin.os.tag) });
    // Presence marker / success check. On macOS the shim link needs the release's
    // own libLTO.dylib (ThinLTO bitcode archives; see build.zig macosShim, #6938),
    // so require it there. A missing marker re-fetches (self-heals a stale cache).
    const marker_lib = if (builtin.os.tag == .macos) "libLTO.dylib" else "libLLVMCore.a";
    const marker = try std.fmt.allocPrint(a, "{s}/{s}/lib/{s}", .{ dest, rel.dirname, marker_lib });
    if (fileExists(io, marker)) {
        log("fetch-llvm: already present at {s}/{s}", .{ dest, rel.dirname });
        return;
    }
    try Dir.cwd().createDirPath(io, dest);

    try fetchLlvmSlice(io, gpa, a, dest, rel);

    if (!fileExists(io, marker)) die("fetch-llvm: fetch produced no {s}", .{marker_lib});
    log("fetch-llvm: ready at {s}/{s}", .{ dest, rel.dirname });
}

// ------------------------------------------------------ slice (range) fetch ---
// Pull only the ~84 MB the shim links (lib/libLLVM*.a + include/llvm[-c], +macOS
// lib/libLTO.dylib) out of the ~1 GB llvm-slice "dev" zip via a handful of HTTP
// range requests -- the zip stores each member with its own DEFLATE stream, so we
// fetch the central directory, then just the byte spans covering our members.

fn rdU16(b: []const u8, off: usize) u16 {
    return std.mem.readInt(u16, b[off..][0..2], .little);
}
fn rdU32(b: []const u8, off: usize) u32 {
    return std.mem.readInt(u32, b[off..][0..4], .little);
}

const ZipMember = struct { name: []const u8, method: u16, csize: u32, usize_: u32, crc: u32, lho: u64 };
fn lessByLho(_: void, x: ZipMember, y: ZipMember) bool {
    return x.lho < y.lho;
}

/// True for the zip members the shim needs: the LLVM static archives, the llvm/
/// + llvm-c/ headers, and (macOS) the release's libLTO.dylib.
fn sliceWanted(name: []const u8) bool {
    if (std.mem.startsWith(u8, name, "lib/libLLVM") and std.mem.endsWith(u8, name, ".a")) return true;
    if (std.mem.startsWith(u8, name, "include/llvm/")) return true;
    if (std.mem.startsWith(u8, name, "include/llvm-c/")) return true;
    if (builtin.os.tag == .macos and std.mem.eql(u8, name, "lib/libLTO.dylib")) return true;
    return false;
}

/// HTTP GET of [start, end] (inclusive) into a fresh buffer (caller frees).
/// Follows the GitHub -> signed-CDN redirect and REQUIRES a 206: a 200 would mean
/// the range was ignored and we'd pull the whole ~1 GB zip, so reject it loudly.
fn httpGetRange(io: Io, gpa: Allocator, url: []const u8, start: u64, end: u64) ![]u8 {
    var rbuf: [64]u8 = undefined;
    const range = std.fmt.bufPrint(&rbuf, "bytes={d}-{d}", .{ start, end }) catch unreachable;
    var client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const res = client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &aw.writer,
        .redirect_behavior = @enumFromInt(10),
        .extra_headers = &.{.{ .name = "range", .value = range }},
    }) catch |err| die("fetch-llvm: range fetch failed for {s}: {s}", .{ url, @errorName(err) });
    if (res.status != .partial_content)
        die("fetch-llvm: expected 206 for range {s}, got {d} (server ignored Range)", .{ range, @intFromEnum(res.status) });
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

/// Decompress one zip member's DEFLATE (method 8) or stored (0) payload.
fn inflateMember(gpa: Allocator, method: u16, data: []const u8) ![]u8 {
    if (method == 0) return gpa.dupe(u8, data);
    if (method != 8) die("fetch-llvm: unsupported zip compression method {d}", .{method});
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const window = try gpa.alloc(u8, flate.max_window_len);
    defer gpa.free(window);
    var src = Io.Reader.fixed(data);
    var dz = flate.Decompress.init(&src, .raw, window);
    _ = dz.reader.streamRemaining(&aw.writer) catch |err| die("fetch-llvm: inflate failed: {s}", .{@errorName(err)});
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

/// Range-fetch only the shim's subset from the llvm-slice zip.
/// Writes into <dest>/<rel.dirname>/{include,lib} (the slice members carry no
/// top-level dir, unlike the upstream tarball, so we root them under rel.dirname).
fn fetchLlvmSlice(io: Io, gpa: Allocator, a: Allocator, dest: []const u8, rel: LlvmRelease) !void {
    const zip_url = try std.fmt.allocPrint(a, "{s}/{s}/llvm-{s}-{s}-dev.zip", .{ SLICE_BASE, SLICE_TAG, LLVM_VER, rel.triple });
    const man_url = try std.fmt.allocPrint(a, "{s}/{s}/llvm-{s}-{s}-manifest.json", .{ SLICE_BASE, SLICE_TAG, LLVM_VER, rel.triple });
    log("fetch-llvm: slice range-fetch (~84 MB) from llvm-slice {s} {s}", .{ SLICE_TAG, rel.triple });

    // 1) manifest -> pinned-hash anchor + per-archive sha256 map. The strings the
    //    map points at live in `manifest`/`parsed`, so both outlive its use.
    const manifest = try httpGetAlloc(io, gpa, man_url);
    defer gpa.free(manifest);
    {
        const ms = sha256Hex(manifest);
        if (!std.mem.eql(u8, &ms, rel.manifest_sha256))
            die("fetch-llvm: manifest checksum mismatch\n  expected {s}\n  actual   {s}", .{ rel.manifest_sha256, &ms });
    }
    var parsed = std.json.parseFromSlice(std.json.Value, gpa, manifest, .{}) catch |err|
        die("fetch-llvm: manifest parse failed: {s}", .{@errorName(err)});
    defer parsed.deinit();
    var sha_map = std.StringHashMap([]const u8).init(gpa);
    defer sha_map.deinit();
    if (parsed.value.object.get("libs")) |libs_v| {
        var lit = libs_v.object.iterator();
        while (lit.next()) |e| {
            const o = e.value_ptr.*.object;
            const fv = o.get("file") orelse continue;
            const sv = o.get("sha256") orelse continue;
            if (fv != .string or sv != .string) continue;
            try sha_map.put(fv.string, sv.string);
        }
    }

    // 2) EOCD (last 64 KiB) -> central-directory offset/size. These releases are
    //    < 4 GiB with < 65535 members, so no Zip64 record to chase.
    const tail_len: u64 = @min(rel.zip_size, 65536);
    const tail = try httpGetRange(io, gpa, zip_url, rel.zip_size - tail_len, rel.zip_size - 1);
    defer gpa.free(tail);
    const eocd = std.mem.lastIndexOf(u8, tail, "PK\x05\x06") orelse die("fetch-llvm: no zip EOCD found", .{});
    const cd_size = rdU32(tail, eocd + 12);
    const cd_off = rdU32(tail, eocd + 16);

    // 3) central directory -> every member's (name, method, sizes, crc, offset).
    const cd = try httpGetRange(io, gpa, zip_url, cd_off, @as(u64, cd_off) + cd_size - 1);
    defer gpa.free(cd);
    var count: usize = 0;
    {
        var p: usize = 0;
        while (p + 46 <= cd.len and std.mem.eql(u8, cd[p..][0..4], "PK\x01\x02")) {
            count += 1;
            p += 46 + rdU16(cd, p + 28) + rdU16(cd, p + 30) + rdU16(cd, p + 32);
        }
    }
    const members = try gpa.alloc(ZipMember, count);
    defer gpa.free(members);
    {
        var p: usize = 0;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const nlen = rdU16(cd, p + 28);
            members[i] = .{
                .method = rdU16(cd, p + 10),
                .crc = rdU32(cd, p + 16),
                .csize = rdU32(cd, p + 20),
                .usize_ = rdU32(cd, p + 24),
                .lho = rdU32(cd, p + 42),
                .name = cd[p + 46 ..][0..nlen],
            };
            p += 46 + nlen + rdU16(cd, p + 30) + rdU16(cd, p + 32);
        }
    }
    // Sort by local-header offset: member i's stored bytes end where member i+1
    // begins (or at the central directory for the last), which bounds each fetch.
    std.sort.block(ZipMember, members, {}, lessByLho);

    var rdir = try Dir.cwd().openDir(io, dest, .{});
    defer rdir.close(io);
    var name_buf: [Dir.max_path_bytes]u8 = undefined;
    var content_buf: [64 * 1024]u8 = undefined;

    // 4) coalesce wanted members into byte runs (merge when the gap to the next
    //    wanted member is < 16 MiB) and range-fetch each run, then extract every
    //    wanted member from the in-memory span. For these zips the wanted set is
    //    two contiguous groups (lib archives, then headers) -> ~2 range requests.
    const end_byte = struct {
        fn f(ms: []const ZipMember, i: usize, cdo: u64) u64 {
            return if (i + 1 < ms.len) ms[i + 1].lho else cdo;
        }
    }.f;
    const GAP: u64 = 16 * 1024 * 1024;
    var written: usize = 0;
    var i: usize = 0;
    while (i < count) {
        if (!sliceWanted(members[i].name)) {
            i += 1;
            continue;
        }
        // Grow a run [ra..rb] over consecutive wanted members with small gaps.
        const ra = i;
        var rb = i;
        var j = i + 1;
        while (j < count) : (j += 1) {
            if (!sliceWanted(members[j].name)) continue;
            if (members[j].lho - end_byte(members, rb, cd_off) >= GAP) break;
            rb = j;
        }
        const run_start = members[ra].lho;
        const run_end = end_byte(members, rb, cd_off); // exclusive
        const run = try httpGetRange(io, gpa, zip_url, run_start, run_end - 1);
        defer gpa.free(run);
        // Extract each wanted member whose data lies in this run.
        var k = ra;
        while (k <= rb) : (k += 1) {
            const m = members[k];
            if (!sliceWanted(m.name)) continue;
            const o: usize = @intCast(m.lho - run_start);
            if (!std.mem.eql(u8, run[o..][0..4], "PK\x03\x04")) die("fetch-llvm: bad local header for {s}", .{m.name});
            const data_off = o + 30 + rdU16(run, o + 26) + rdU16(run, o + 28);
            const data = run[data_off..][0..m.csize];
            const bytes = try inflateMember(gpa, m.method, data);
            defer gpa.free(bytes);
            if (std.hash.crc.Crc32.hash(bytes) != m.crc) die("fetch-llvm: crc mismatch for {s}", .{m.name});
            // Linked archives carry a pinned sha256 in the verified manifest.
            if (sha_map.get(m.name)) |want_sha| {
                const got = sha256Hex(bytes);
                if (!std.mem.eql(u8, &got, want_sha)) die("fetch-llvm: sha256 mismatch for {s}", .{m.name});
            }
            // Write <dest>/<dirname>/<member.name>, creating parent dirs.
            const rel_path = std.fmt.bufPrint(&name_buf, "{s}/{s}", .{ rel.dirname, m.name }) catch
                die("fetch-llvm: path too long: {s}", .{m.name});
            const fh = rdir.createFile(io, rel_path, .{}) catch |err| blk: {
                if (err != error.FileNotFound) return err;
                try rdir.createDirPath(io, std.fs.path.dirname(rel_path).?);
                break :blk try rdir.createFile(io, rel_path, .{});
            };
            defer fh.close(io);
            var fw = fh.writer(io, &content_buf);
            try fw.interface.writeAll(bytes);
            try fw.interface.flush();
            written += 1;
        }
        i = rb + 1; // advance past the run we just processed
    }
    log("fetch-llvm: slice extracted {d} members", .{written});
}

// ================================================================ fetch-bun ===

/// Map a build `<os>-<arch>` key (the fetch-pbs / osArchString form) to bun's
/// release asset basename. Mirrors bun_installer.jac's _PLATFORM_MAP.
fn bunAssetName(osarch: []const u8) ?[]const u8 {
    const m = std.StaticStringMap([]const u8).initComptime(.{
        .{ "macos-aarch64", "bun-darwin-aarch64" },
        .{ "macos-x86_64", "bun-darwin-x64" },
        .{ "linux-x86_64", "bun-linux-x64" },
        .{ "linux-aarch64", "bun-linux-aarch64" },
        .{ "windows-x86_64", "bun-windows-x64" },
    });
    return m.get(osarch);
}

/// fetch-bun: download + sha256-verify + extract the pinned bun binary for
/// `osarch` into `<dest>/bun` (or bun.exe). Idempotent (no-op if already
/// present). The binary is bundled into every distributed jac, so the asset is
/// verified against the release SHASUMS256.txt before it is trusted. The exec
/// bit is (re)applied at runtime by get_bun() -- the materialized payload tar is
/// extracted mode-agnostically -- so this just writes the bytes.
fn fetchBun(io: Io, gpa: Allocator, a: Allocator, osarch: []const u8, dest: []const u8) !void {
    const is_windows = std.mem.startsWith(u8, osarch, "windows");
    const bun_name = if (is_windows) "bun.exe" else "bun";
    const out_path = try std.fmt.allocPrint(a, "{s}/{s}", .{ dest, bun_name });
    if (fileExists(io, out_path)) {
        log("fetch-bun: already present at {s}", .{out_path});
        return;
    }

    const asset = bunAssetName(osarch) orelse die("fetch-bun: unsupported platform '{s}'", .{osarch});
    const zip_name = try std.fmt.allocPrint(a, "{s}.zip", .{asset});
    const url = try std.fmt.allocPrint(a, "{s}/bun-v{s}/{s}", .{ BUN_BASE, BUN_VERSION, zip_name });

    log("fetch-bun: downloading {s}", .{zip_name});
    const zip = try httpGetAlloc(io, gpa, url);
    defer gpa.free(zip);

    // Verify against the release SHASUMS256.txt (`<hex>  <filename>` lines, the
    // same format as pbs's SHA256SUMS). A swapped/MITM'd asset must not slip
    // into the binary shipped to every user.
    const sums_url = try std.fmt.allocPrint(a, "{s}/bun-v{s}/SHASUMS256.txt", .{ BUN_BASE, BUN_VERSION });
    const sums = try httpGetAlloc(io, gpa, sums_url);
    defer gpa.free(sums);
    const expected = findSumLine(sums, zip_name) orelse die("fetch-bun: no checksum for {s} in SHASUMS256.txt", .{zip_name});
    const actual = sha256Hex(zip);
    if (!std.mem.eql(u8, &actual, expected))
        die("fetch-bun: checksum mismatch for {s}\n  expected {s}\n  actual   {s}", .{ zip_name, expected, &actual });

    // bun zips store the binary at `bun-<platform>/<bun_name>`.
    const suffix = try std.fmt.allocPrint(a, "/{s}", .{bun_name});
    const bun_bytes = try unzipMemberBySuffix(gpa, zip, suffix);
    defer gpa.free(bun_bytes);

    try Dir.cwd().createDirPath(io, dest);
    {
        var fh = try Dir.cwd().createFile(io, out_path, .{ .truncate = true });
        defer fh.close(io);
        var wbuf: [64 * 1024]u8 = undefined;
        var fw = fh.writer(io, &wbuf);
        try fw.interface.writeAll(bun_bytes);
        try fw.interface.flush();
    }
    if (!fileExists(io, out_path)) die("fetch-bun: extract produced no {s}", .{bun_name});
    log("fetch-bun: ready at {s} ({d} MiB)", .{ out_path, bun_bytes.len >> 20 });
}

// =============================================================== build-musl ===

/// Harvest a complete static-musl runtime (libc.a + libzigc.a + compiler-rt +
/// crt) into `dest`, so `jac nacompile` can fully static-link Linux executables
/// against musl with no toolchain at compile time. Unlike the other vendored
/// deps this is BUILT, not downloaded: the bundled Zig already ships musl, so we
/// link a tiny stub for the target (which materializes the archives into an
/// isolated Zig cache) and copy the artifacts out. Idempotent; only meaningful
/// for Linux targets.
fn buildMusl(io: Io, gpa: Allocator, a: Allocator, parent_env: *std.process.Environ.Map, osarch: []const u8, dest: []const u8, zig_exe: []const u8) !void {
    const ztarget = if (std.mem.eql(u8, osarch, "linux-x86_64"))
        "x86_64-linux-musl"
    else if (std.mem.eql(u8, osarch, "linux-aarch64"))
        "aarch64-linux-musl"
    else
        die("build-musl: unsupported osarch '{s}' (need linux-x86_64|linux-aarch64)", .{osarch});

    // crt1 + libc.a + libzigc.a are mandatory; compiler-rt + crti/crtn optional
    // (musl's modern startup uses init-array, not legacy _init).
    const ARTIFACTS = [_][]const u8{
        "libc.a", "libzigc.a", "libcompiler_rt.a", "crt1.o", "crti.o", "crtn.o",
    };

    try Dir.cwd().createDirPath(io, dest);
    // Idempotent: a complete set already present -> nothing to do.
    // Skip only when the MANDATORY set is present. A generic count can pass with
    // the optional artifacts (compiler-rt + crti/crtn) while libc.a/libzigc.a are
    // missing, leaving an unusable runtime.
    const MANDATORY = [_][]const u8{ "libc.a", "libzigc.a", "crt1.o" };
    var have_all = true;
    for (MANDATORY) |name| {
        if (!fileExists(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ dest, name }))) have_all = false;
    }
    if (have_all) {
        log("==> musl runtime already vendored in {s}; skipping", .{dest});
        return;
    }

    // Isolated scratch: a stub + a private Zig cache, so the harvest grabs only
    // the artifacts THIS link produced (never a stale global-cache copy).
    const work = try std.fmt.allocPrint(a, "{s}.musl-work", .{dest});
    Dir.cwd().deleteTree(io, work) catch {};
    defer Dir.cwd().deleteTree(io, work) catch {};
    const cache = try std.fmt.allocPrint(a, "{s}/cache", .{work});
    try Dir.cwd().createDirPath(io, cache);
    const stub = try std.fmt.allocPrint(a, "{s}/stub.c", .{work});
    try Dir.cwd().writeFile(io, .{
        .sub_path = stub,
        // Touch a spread of subsystems so Zig materializes the full musl, its
        // helper archive (libzigc), and compiler-rt.
        .data = "#include <string.h>\n#include <stdlib.h>\n#include <stdio.h>\n#include <math.h>\nint main(int c, char **v){char b[8];snprintf(b,sizeof b,\"%d\",c);void*p=malloc(8);free(p);return (int)(strncmp(b,\"x\",1)+(long)sin((double)v[0][0]));}\n",
    });
    const stub_out = try std.fmt.allocPrint(a, "{s}/stub", .{work});

    var env = try cloneEnv(gpa, parent_env);
    defer env.deinit();
    try env.put("ZIG_GLOBAL_CACHE_DIR", cache);
    log("==> building static musl ({s}) via {s} ...", .{ ztarget, zig_exe });
    if (!runChild(io, &.{ zig_exe, "cc", "-target", ztarget, "-static", "-o", stub_out, stub }, &env, false))
        die("build-musl: `zig cc -target {s} -static` failed", .{ztarget});

    // Harvest: walk the isolated cache and pick out the named artifacts.
    var found = std.StringHashMap([]const u8).init(gpa);
    defer found.deinit();
    {
        var cdir = Dir.cwd().openDir(io, cache, .{ .iterate = true }) catch
            die("build-musl: zig cache dir missing at {s}", .{cache});
        defer cdir.close(io);
        var walker = cdir.walk(gpa) catch die("build-musl: cache walk failed", .{});
        defer walker.deinit();
        while (walker.next(io) catch null) |entry| {
            if (entry.kind != .file) continue;
            const base = std.fs.path.basename(entry.path);
            for (ARTIFACTS) |name| {
                if (std.mem.eql(u8, base, name) and !found.contains(name))
                    found.put(name, try std.fmt.allocPrint(a, "{s}/{s}", .{ cache, entry.path })) catch {};
            }
        }
    }

    var staged: usize = 0;
    for (ARTIFACTS) |name| {
        const src = found.get(name) orelse continue;
        try Dir.cwd().copyFile(src, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ dest, name }), io, .{});
        staged += 1;
    }
    log("==> staged {d} musl artifact(s) -> {s}", .{ staged, dest });
    if (staged < 4) die("build-musl: incomplete harvest ({d}/6 artifacts)", .{staged});
}

// ========================================================== build-wasm-libc ===

/// Compile the in-repo wasm_rt libc (vendored musl/wasi-libc subset + the jac
/// allocator/io/abi adapters) to LLVM bitcode for wasm32, one .bc per source
/// file, into `dest`. wasm_build.jac links these into every na->wasm module so
/// pure-compute libc never becomes a browser import (#7048). Like build-musl
/// this is BUILT from the bundled Zig (its clang emits wasm32 bitcode that the
/// jacllvm LLVM reads); unlike musl the output is target-independent, so there
/// is one set for all platforms. Idempotent by mtime: a .bc is rebuilt when it
/// is missing or older than its source (headers count against every unit), so
/// editing wasm_rt sources Just Works on the next build.
fn buildWasmLibc(io: Io, gpa: Allocator, a: Allocator, src_root: []const u8, dest: []const u8, zig_exe: []const u8) !void {
    // Collect sources: jac_*.c at the wasm_rt root, then everything under
    // vendor/. Output names flatten the vendor path (string/strlen.c ->
    // string_strlen.bc) to match wasm_build.jac's flat directory scan.
    var srcs: std.ArrayList([]const u8) = .empty; // absolute-ish source paths
    defer srcs.deinit(gpa);
    var outs: std.ArrayList([]const u8) = .empty; // matching .bc basenames
    defer outs.deinit(gpa);
    var hdr_m: i96 = 0; // newest non-.c file (headers/prelude) under wasm_rt
    {
        var root = Dir.cwd().openDir(io, src_root, .{ .iterate = true }) catch
            die("build-wasm-libc: wasm_rt source dir missing at {s}", .{src_root});
        defer root.close(io);
        var it = root.iterate();
        while (it.next(io) catch null) |entry| {
            if (entry.kind != .file) continue;
            const full = try std.fmt.allocPrint(a, "{s}/{s}", .{ src_root, entry.name });
            if (!std.mem.startsWith(u8, entry.name, "jac_") or !std.mem.endsWith(u8, entry.name, ".c")) {
                hdr_m = @max(hdr_m, mtimeNs(io, full) orelse 0);
                continue;
            }
            try srcs.append(gpa, full);
            try outs.append(gpa, try std.fmt.allocPrint(a, "{s}bc", .{entry.name[0 .. entry.name.len - 1]}));
        }
        const vendor = try std.fmt.allocPrint(a, "{s}/vendor", .{src_root});
        var vdir = Dir.cwd().openDir(io, vendor, .{ .iterate = true }) catch
            die("build-wasm-libc: vendor dir missing at {s}", .{vendor});
        defer vdir.close(io);
        var walker = vdir.walk(gpa) catch die("build-wasm-libc: vendor walk failed", .{});
        defer walker.deinit();
        while (walker.next(io) catch null) |entry| {
            if (entry.kind != .file) continue;
            const full = try std.fmt.allocPrint(a, "{s}/{s}", .{ vendor, entry.path });
            if (!std.mem.endsWith(u8, entry.path, ".c")) {
                hdr_m = @max(hdr_m, mtimeNs(io, full) orelse 0);
                continue;
            }
            try srcs.append(gpa, full);
            const flat = try a.dupe(u8, entry.path);
            for (flat) |*ch| {
                if (ch.* == '/' or ch.* == '\\') ch.* = '_';
            }
            try outs.append(gpa, try std.fmt.allocPrint(a, "{s}bc", .{flat[0 .. flat.len - 1]}));
        }
    }
    if (srcs.items.len == 0) die("build-wasm-libc: no sources found under {s}", .{src_root});

    try Dir.cwd().createDirPath(io, dest);
    var stale: usize = 0;
    for (srcs.items, outs.items) |src, out_name| {
        const out_path = try std.fmt.allocPrint(a, "{s}/{s}", .{ dest, out_name });
        const out_m = mtimeNs(io, out_path) orelse {
            stale += 1;
            continue;
        };
        if (@max(mtimeNs(io, src) orelse 0, hdr_m) > out_m) stale += 1;
    }
    if (stale == 0) {
        log("==> wasm libc bitcode up to date in {s}; skipping", .{dest});
        return;
    }

    log("==> compiling {d} stale/missing wasm_rt source(s) to bitcode via {s} ...", .{ stale, zig_exe });
    // wasm32-wasi supplies the public libc headers; the vendored internal
    // headers ride -I flags. -fno-builtin keeps libc-defining TUs from
    // folding into themselves; -g0 because debug relocs would bloat objects
    // the in-house WasmLinker then has to skip.
    const prelude = try std.fmt.allocPrint(a, "{s}/prelude.h", .{src_root});
    const inc_include = try std.fmt.allocPrint(a, "-I{s}/vendor/include", .{src_root});
    const inc_internal = try std.fmt.allocPrint(a, "-I{s}/vendor/internal", .{src_root});
    const inc_arch = try std.fmt.allocPrint(a, "-I{s}/vendor/arch/wasm32", .{src_root});
    const inc_private = try std.fmt.allocPrint(a, "-I{s}/vendor/private", .{src_root});
    const inc_math = try std.fmt.allocPrint(a, "-I{s}/vendor/math", .{src_root});
    var built: usize = 0;
    for (srcs.items, outs.items) |src, out_name| {
        const out_path = try std.fmt.allocPrint(a, "{s}/{s}", .{ dest, out_name });
        if (mtimeNs(io, out_path)) |out_m| {
            if (@max(mtimeNs(io, src) orelse 0, hdr_m) <= out_m) continue;
        }
        if (!runChild(io, &.{
            zig_exe,                                                                       "cc",         "-target",    "wasm32-wasi",  "-O2",      "-g0",
            "-w",                                                                          "-c",         "-emit-llvm", "-fno-builtin", "-include", prelude,
            inc_include,                                                                   inc_internal, inc_arch,     inc_private,    inc_math,   "-D__wasilibc_printscan_no_long_double",
            "-D__wasilibc_printscan_full_support_option=\"long double support disabled\"", "-o",         out_path,     src,
        }, null, false))
            die("build-wasm-libc: zig cc failed for {s}", .{src});
        built += 1;
    }
    // The merged-module cache is derived from the parts; a fresh compile
    // invalidates it.
    Dir.cwd().deleteFile(io, try std.fmt.allocPrint(a, "{s}/_merged.bc", .{dest})) catch {};
    log("==> compiled {d} wasm libc bitcode file(s) -> {s}", .{ built, dest });
}

/// Extract the single zip member whose name ends with `suffix` from an in-memory
/// zip, returning its decompressed bytes (caller frees). Reuses the central-
/// directory parsing helpers from the llvm-slice path; bun's zips are small so
/// the whole archive is already in memory (no range fetch needed).
fn unzipMemberBySuffix(gpa: Allocator, zip: []const u8, suffix: []const u8) ![]u8 {
    if (zip.len < 22) die("fetch-bun: zip too small", .{});
    const eocd = std.mem.lastIndexOf(u8, zip, "PK\x05\x06") orelse die("fetch-bun: no zip EOCD found", .{});
    const cd_size = rdU32(zip, eocd + 12);
    const cd_off = rdU32(zip, eocd + 16);
    if (@as(usize, cd_off) + cd_size > zip.len) die("fetch-bun: central directory out of range", .{});
    const cd_end: usize = @as(usize, cd_off) + cd_size;
    var p: usize = cd_off;
    while (p + 46 <= cd_end and std.mem.eql(u8, zip[p..][0..4], "PK\x01\x02")) {
        const method = rdU16(zip, p + 10);
        const csize = rdU32(zip, p + 20);
        const nlen = rdU16(zip, p + 28);
        const elen = rdU16(zip, p + 30);
        const clen = rdU16(zip, p + 32);
        const lho = rdU32(zip, p + 42);
        const name = zip[p + 46 ..][0..nlen];
        if (std.mem.endsWith(u8, name, suffix)) {
            if (@as(usize, lho) + 30 > zip.len or !std.mem.eql(u8, zip[lho..][0..4], "PK\x03\x04"))
                die("fetch-bun: bad local header for {s}", .{name});
            const l_nlen = rdU16(zip, lho + 26);
            const l_elen = rdU16(zip, lho + 28);
            const data_off: usize = @as(usize, lho) + 30 + l_nlen + l_elen;
            if (data_off + csize > zip.len) die("fetch-bun: member data out of range for {s}", .{name});
            return inflateMember(gpa, method, zip[data_off..][0..csize]);
        }
        p += 46 + nlen + elen + clen;
    }
    die("fetch-bun: no member ending in '{s}' found in zip", .{suffix});
}

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

// =========================================================== fetch-typeshed ===

fn fetchTypeshed(io: Io, gpa: Allocator, a: Allocator, repo_root: []const u8) !void {
    const vendor = try std.fmt.allocPrint(a, "{s}/{s}", .{ repo_root, TYPESHED_VENDOR });
    const commit = try readTrimmed(io, gpa, a, try std.fmt.allocPrint(a, "{s}/PIN", .{vendor})) orelse
        die("fetch-typeshed: no PIN at {s}/PIN", .{vendor});
    const expected_sha = try readTrimmed(io, gpa, a, try std.fmt.allocPrint(a, "{s}/TARBALL_SHA256", .{vendor})) orelse
        die("fetch-typeshed: no TARBALL_SHA256 at {s}/TARBALL_SHA256", .{vendor});

    // Idempotent: the stamp records the commit the stubs were materialized at.
    const versions = try std.fmt.allocPrint(a, "{s}/stdlib/VERSIONS", .{vendor});
    const stamp_path = try std.fmt.allocPrint(a, "{s}/stdlib/.typeshed-sha", .{vendor});
    if (fileExists(io, versions)) {
        if (try readTrimmed(io, gpa, a, stamp_path)) |s| {
            if (std.mem.eql(u8, s, commit)) return; // already at the pin
        }
    }

    const url = try std.fmt.allocPrint(a, "{s}/{s}", .{ TYPESHED_TARBALL_BASE, commit });
    log("fetch-typeshed: fetching typeshed @ {s}", .{commit});
    const gz = try httpGetAlloc(io, gpa, url);
    defer gpa.free(gz);

    // gzip-decompress the whole tar into memory, then verify the decompressed
    // tar's sha256 against the pin. Git's `archive` output for a commit is
    // content-stable (mtime = the commit date), so this is the integrity story
    // that replaces git's content-addressing.
    const tar = try gzipDecompressAlloc(io, gpa, gz);
    defer gpa.free(tar);
    const actual = sha256Hex(tar);
    if (!std.mem.eql(u8, &actual, expected_sha)) {
        die("fetch-typeshed: tarball checksum mismatch @ {s}\n  expected {s}\n  actual   {s}", .{ commit, expected_sha, &actual });
    }

    // Extract the whole tree (strip the `typeshed-<sha>/` top dir) to a temp dir,
    // then lift just stdlib/ + LICENSE into the vendor dir. The tarball is small
    // (~13 MiB uncompressed) so a full extract-then-copy is fine and avoids
    // hand-filtering the tar stream.
    const tmp = try std.fmt.allocPrint(a, "{s}/.ts-extract", .{vendor});
    Dir.cwd().deleteTree(io, tmp) catch {};
    try Dir.cwd().createDirPath(io, tmp);
    defer Dir.cwd().deleteTree(io, tmp) catch {};
    {
        var tdir = try Dir.cwd().openDir(io, tmp, .{});
        defer tdir.close(io);
        var tar_reader = Io.Reader.fixed(tar);
        std.tar.extract(io, tdir, &tar_reader, .{ .mode_mode = .ignore, .strip_components = 1 }) catch |err|
            die("fetch-typeshed: extract failed: {s}", .{@errorName(err)});
    }

    const stdlib_dst = try std.fmt.allocPrint(a, "{s}/stdlib", .{vendor});
    Dir.cwd().deleteTree(io, stdlib_dst) catch {};
    var stdlib_src = Dir.cwd().openDir(io, try std.fmt.allocPrint(a, "{s}/stdlib", .{tmp}), .{ .iterate = true }) catch
        die("fetch-typeshed: tarball has no stdlib/ (bad commit?)", .{});
    defer stdlib_src.close(io);
    // typeshed's own test suite (@tests) is not shipped.
    try copyTree(io, gpa, a, stdlib_src, stdlib_dst, skipTypeshedTests);

    // LICENSE rides along (Apache-2.0); ignore if absent.
    Dir.cwd().copyFile(
        try std.fmt.allocPrint(a, "{s}/LICENSE", .{tmp}),
        Dir.cwd(),
        try std.fmt.allocPrint(a, "{s}/LICENSE", .{vendor}),
        io,
        .{},
    ) catch {};

    try Dir.cwd().writeFile(io, .{ .sub_path = stamp_path, .data = commit });
    log("fetch-typeshed: ready ({s})", .{commit});
}

fn skipTypeshedTests(path: []const u8) bool {
    return std.mem.indexOf(u8, path, "@tests") != null;
}

// =============================================================== mkpayload ===

fn mkPayload(
    io: Io,
    gpa: Allocator,
    a: Allocator,
    parent_env: *std.process.Environ.Map,
    pbs_py_dir: []const u8,
    repo_root: []const u8,
    out: []const u8,
    shim_so: ?[]const u8,
    // The Zig-built libjacpyembed shim (launcher/pyembed.zig): the na desktop
    // host DT_NEEDEDs it to bring up THIS fused runtime instead of the build
    // machine's libpython. Bundled beside the desktop native assets so the host
    // build can stage it $ORIGIN-adjacent. Null only in unusual standalone packs.
    pyembed_so: ?[]const u8,
    // The pinned bun binary (fetch-bun output) to bundle inside the client
    // package at jaclang/runtimelib/client/_bun/<bun>. get_bun() resolves it
    // there by absolute path -- contained in the jac ecosystem, never on PATH.
    // Null in linked-source / standalone packs (dev uses an on-demand copy).
    bun_bin: ?[]const u8,
    skip_precompile: bool,
    // Editable dev binary: an absolute path to the dir CONTAINING jaclang/. When
    // set, the compiler is NOT bundled -- the payload ships only CPython + the
    // bootstrap shims + the test runner, and a baked `site/jac_linked_source`
    // marker reroutes `import jaclang` to this dir at startup (see _jac_finder.py
    // apply_dev_source_override). Implies skip_precompile and a tiny, fast build.
    link_source: ?[]const u8,
    // The vendored static-musl runtime dir (scripts/vendor_musl.sh output:
    // libc.a + libzigc.a + compiler-rt + crt). Bundled so an installed binary can
    // fully static-link Linux executables against musl at `nacompile` time, with
    // no toolchain. Null for mac/windows builds (musl is Linux-only).
    musl_dir: ?[]const u8,
    // The vendored wasm32 libc bitcode dir (payload build-wasm-libc output).
    // Bundled so an installed binary links pure-compute libc INTO na->wasm
    // modules instead of leaking env imports (#7048). Target-independent, so
    // every platform's payload carries the same set.
    wasm_libc_dir: ?[]const u8,
    // Persistent JIR precompile cache dir. When set, site/jaclang/_precompiled
    // is seeded from it before the precompile and the refreshed tree is copied
    // back after -- the precompiler validates every seeded .jir by its
    // content-addressed module key and recompiles only stale ones, so the
    // multi-minute full precompile shrinks to just the changed modules. A
    // stale or partial dir is harmless (it only misses reuse), which is why
    // CI can restore it with prefix-fallback keys unlike the binary cache.
    precompiled_cache: ?[]const u8,
    // The assembled ninja editor tree (jac/build.zig composes it from the
    // neovim dependency's exported runtime + the jac/editor/ninja config
    // layer). Staged verbatim under stage/nvim/ -- the launcher's `jac ninja`
    // dispatch points VIMRUNTIME at <rt>/nvim/runtime and sources
    // <rt>/nvim/ninja/init.lua. Null when the build disables the editor.
    nvim_dir: ?[]const u8,
    // Seal the runtime (issue #7135): freeze the jac0core bootstrap layer and
    // emit _precompiled/MANIFEST.json so the payload boots from JIR (sources
    // ship for tracebacks but are never compiled at runtime). Strict: any
    // precompile failure aborts the build rather than shipping a half-sealed
    // tree.
    seal: bool,
    // Embed zlib-compressed source text in each sealed .jir (dev sealed
    // builds); release omits it.
    debug_src: bool,
) !void {
    const py = try resolvePython(io, a, pbs_py_dir);
    const work = try std.fmt.allocPrint(a, "{s}.work", .{out});
    Dir.cwd().deleteTree(io, work) catch {};
    try Dir.cwd().createDirPath(io, work);
    defer Dir.cwd().deleteTree(io, work) catch {};

    const site = try std.fmt.allocPrint(a, "{s}/site", .{work});
    const stage = try std.fmt.allocPrint(a, "{s}/stage", .{work});

    // typeshed stubs are gitignored; materialize them if the build step that
    // normally precedes us was skipped (e.g. -Dpayload-progress reorders).
    const ts_versions = try std.fmt.allocPrint(a, "{s}/{s}/stdlib/VERSIONS", .{ repo_root, TYPESHED_VENDOR });
    if (!fileExists(io, ts_versions)) try fetchTypeshed(io, gpa, a, repo_root);

    log("==> assembling jaclang site from source (no pyproject build)", .{});
    _ = runChild(io, &.{ py, "-m", "ensurepip", "--upgrade" }, null, true);
    _ = runChild(io, &.{ py, "-m", "pip", "install", "--quiet", "--upgrade", "pip" }, null, true);
    try Dir.cwd().createDirPath(io, site);

    // jaclang is pure source + data (no compiled extension), so copy it straight
    // from the tree -- no wheel build. Skip caches, node_modules, and a stale
    // _precompiled (regenerated below) and the full typeshed stubs/ (stdlib only).
    // In linked-source mode we skip this entirely: the compiler stays in `link_source`
    // and the runtime reroutes to it (no bundled copy, no stale-source risk).
    if (link_source == null) {
        var jac_src = try Dir.cwd().openDir(io, try std.fmt.allocPrint(a, "{s}/jaclang", .{repo_root}), .{ .iterate = true });
        defer jac_src.close(io);
        try copyTree(io, gpa, a, jac_src, try std.fmt.allocPrint(a, "{s}/jaclang", .{site}), skipJaclang);
    } else {
        log("==> linked-source mode: NOT bundling jaclang (compiler served from {s})", .{link_source.?});
    }
    try copyInto(io, a, repo_root, "_jac_finder.py", site);
    try copyInto(io, a, repo_root, "sitecustomize.py", site);
    // Bake the linked compiler path so the binary reroutes regardless of cwd or
    // any jac.toml [dev] stanza -- read first by apply_dev_source_override.
    if (link_source) |src| {
        try Dir.cwd().writeFile(io, .{
            .sub_path = try std.fmt.allocPrint(a, "{s}/jac_linked_source", .{site}),
            .data = src,
        });
    }

    // Minimal dist-info so importlib.metadata sees jaclang -- the version keys
    // JIR (pkg_version) and the entry points back the pytest11 plugin (`jac
    // test`) and the built-in `jac.modules` (desktop). Version comes from
    // jac.toml; the build never reads pyproject.toml.
    const toml = try Dir.cwd().readFileAlloc(io, try std.fmt.allocPrint(a, "{s}/jac.toml", .{repo_root}), a, .unlimited);
    const ver = tomlString(toml, "version") orelse die("mkpayload: no version in jac.toml", .{});
    const di = try std.fmt.allocPrint(a, "{s}/jaclang-{s}.dist-info", .{ site, ver });
    try Dir.cwd().createDirPath(io, di);
    try Dir.cwd().writeFile(io, .{
        .sub_path = try std.fmt.allocPrint(a, "{s}/METADATA", .{di}),
        .data = try std.fmt.allocPrint(a, "Metadata-Version: 2.1\nName: jaclang\nVersion: {s}\n", .{ver}),
    });
    try Dir.cwd().writeFile(io, .{
        .sub_path = try std.fmt.allocPrint(a, "{s}/entry_points.txt", .{di}),
        .data =
        \\[pytest11]
        \\jaclang = jaclang.pytest_plugin
        \\
        \\[jac.modules]
        \\desktop = jaclang.runtimelib.client.desktop_plugin_config:desktop_sdk_path
        \\
        \\[jac.module_exports]
        \\desktop = jaclang.runtimelib.client.desktop_plugin_config:desktop_sdk_exports
        \\
        ,
    });

    // Native LLVM: bundle the Zig-built LLVMPY_* shim (jac/native, statically
    // linked against host LLVM) next to its Jac binding. The Jac binding
    // ctypes-loads it (jaclang/compiler/passes/native/llvm/binding/ffi.jac).
    // The shim is required -- there is no llvmlite wheel fallback (#6925).
    // Skipped in linked-source mode: there is no bundled site/jaclang/ to host
    // it, and build.zig's `place` step writes the shim into the linked tree
    // (jaclang/compiler/passes/native/llvm/) where ffi.jac finds it instead.
    if (link_source == null) {
        const so = shim_so orelse die(
            "mkpayload: no LLVM shim (--shim). Run `zig build fetch-llvm` once so the" ++
                " build can compile + statically link the LLVMPY_* shim.",
            .{},
        );
        const dst_dir = try std.fmt.allocPrint(a, "{s}/jaclang/compiler/passes/native/llvm", .{site});
        try Dir.cwd().createDirPath(io, dst_dir);
        // Keep the platform-correct basename (libjacllvm.so / .dylib / jacllvm.dll)
        // so ffi.jac's _shim_name() finds it; build.zig emits the right name per OS.
        const shim_base = std.fs.path.basename(so);
        log("==> bundling Zig-built LLVMPY_* shim ({s})", .{so});
        try Dir.cwd().copyFile(so, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ dst_dir, shim_base }), io, .{});
    }

    // Native desktop: bundle the Zig-built libjacpyembed shim next to the desktop
    // native assets. The na desktop host DT_NEEDEDs it (logical name `jacpyembed`)
    // and the desktop build copies it $ORIGIN-adjacent; jac_engine_boot() then
    // brings up THIS fused runtime in the app process. Platform-correct basename
    // (libjacpyembed.so / .dylib / jacpyembed.dll) is preserved -- build.zig emits
    // the right one per OS. Skipped in linked-source mode (build.zig's `place`
    // step writes it into the linked source tree instead, mirroring the LLVM shim).
    if (link_source == null) {
        if (pyembed_so) |pso| {
            const dst_dir = try std.fmt.allocPrint(a, "{s}/jaclang/runtimelib/client/targets/desktop/native", .{site});
            try Dir.cwd().createDirPath(io, dst_dir);
            const pso_base = std.fs.path.basename(pso);
            log("==> bundling libjacpyembed shim ({s})", .{pso});
            try Dir.cwd().copyFile(pso, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ dst_dir, pso_base }), io, .{});
        }
    }

    // Contained bun runtime: bundle the fetched bun inside the client package at
    // jaclang/runtimelib/client/_bun/<bun>. get_bun() resolves it relative to
    // the package (mirroring the native shims) and always invokes it by absolute
    // path -- it is never placed on the user's PATH. Skipped in linked-source
    // mode (dev resolves an on-demand .jac/bin copy instead). skipJaclang drops
    // any source-tree `_bun/`, so this staged copy is the only one shipped.
    if (link_source == null) {
        if (bun_bin) |bb| {
            const bun_base = std.fs.path.basename(bb);
            const dst_dir = try std.fmt.allocPrint(a, "{s}/jaclang/runtimelib/client/_bun", .{site});
            try Dir.cwd().createDirPath(io, dst_dir);
            log("==> bundling contained bun runtime ({s})", .{bb});
            try Dir.cwd().copyFile(bb, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ dst_dir, bun_base }), io, .{});
        }
    }

    // Linked-source mode implies skip-precompile: the compiler lives in the
    // linked tree and the dev override sets JAC_NO_PRECOMPILE, so a bundled JIR
    // cache would never be consulted anyway.
    if (skip_precompile or link_source != null) {
        log("==> skipping JIR precompile; modules compile on first run", .{});
    } else {
        const site_pre = try std.fmt.allocPrint(a, "{s}/jaclang/_precompiled", .{site});
        if (precompiled_cache) |pc| {
            if (Dir.cwd().openDir(io, pc, .{ .iterate = true })) |d| {
                var seed = d;
                defer seed.close(io);
                log("==> seeding JIR precompile from {s}", .{pc});
                try copyTree(io, gpa, a, seed, site_pre, skipNone);
            } else |_| {} // no seed yet; first build populates it below
        }
        try precompile(io, gpa, a, parent_env, py, pbs_py_dir, site, seal, debug_src);
        if (precompiled_cache) |pc| {
            Dir.cwd().deleteTree(io, pc) catch {};
            var fresh = try Dir.cwd().openDir(io, site_pre, .{ .iterate = true });
            defer fresh.close(io);
            try copyTree(io, gpa, a, fresh, pc, skipNone);
        }
    }

    // Bundle runtime helpers (pytest/-xdist -> `jac test`, watchdog -> `jac start
    // --dev`, tomlkit -> project tooling). Installed AFTER precompile so the
    // precompiler's package walk only sees jaclang. Drop stray bytecode first so
    // pip doesn't refuse the populated --target dir.
    log("==> bundling pytest + pytest-xdist (jac test) + watchdog (jac start --dev)", .{});
    Dir.cwd().deleteTree(io, try std.fmt.allocPrint(a, "{s}/__pycache__", .{site})) catch {};
    _ = runChild(io, &.{ py, "-m", "pip", "install", "--quiet", "pytest", "pytest-xdist", "watchdog>=3.0.0", "tomlkit", "--target", site }, null, false);

    try stageTree(io, gpa, a, pbs_py_dir, site, stage, musl_dir, wasm_libc_dir);

    // ninja editor: the assembled nvim tree (runtime/ + ninja/) rides the
    // payload verbatim -- the launcher's `jac ninja` dispatch resolves it at
    // <rt>/nvim without booting Python.
    if (nvim_dir) |nd| {
        log("==> bundling ninja editor tree (nvim runtime + config)", .{});
        var nsrc = try Dir.cwd().openDir(io, nd, .{ .iterate = true });
        defer nsrc.close(io);
        try copyTree(io, gpa, a, nsrc, try std.fmt.allocPrint(a, "{s}/nvim", .{stage}), skipNone);
    }

    log("==> packing tar | gzip", .{});
    try tarGzDir(io, gpa, a, stage, out);
    log("==> payload: {s}", .{out});
}

/// `<pbs>/install/bin/python3.14`, falling back to `python3`.
fn resolvePython(io: Io, a: Allocator, pbs_py_dir: []const u8) ![]const u8 {
    const p1 = try std.fmt.allocPrint(a, "{s}/install/bin/python{s}", .{ pbs_py_dir, py_ver });
    if (fileExists(io, p1)) return p1;
    const p2 = try std.fmt.allocPrint(a, "{s}/install/bin/python3", .{pbs_py_dir});
    if (fileExists(io, p2)) return p2;
    die("mkpayload: no python at {s}/install/bin", .{pbs_py_dir});
}

/// Precompile jaclang -> _precompiled JIR for a fast first run. The precompiler
/// intentionally cannot bytecode-compile a few core modules and exits non-zero;
/// success is judged by the PRECOMPILE_RESULT.json completion marker it writes
/// at the end of an uncrashed run, not the exit code.
fn precompile(io: Io, gpa: Allocator, a: Allocator, parent_env: *std.process.Environ.Map, py: []const u8, pbs_py_dir: []const u8, site: []const u8, seal: bool, debug_src: bool) !void {
    const pc = try std.fmt.allocPrint(a, "{s}/jaclang/utils/precompile_bytecode.jac", .{site});
    if (!fileExists(io, pc)) return;
    if (seal) {
        log("==> precompiling + SEALING jaclang (JIR-authoritative image, #7135)", .{});
    } else {
        log("==> precompiling jaclang -> _precompiled JIR (fast first run)", .{});
    }

    // One fixed boot shim for both passes; the precompiler's arguments travel
    // through the child's real argv, never spliced into Python source. Pass 1
    // is compile-only (--seal-compile excludes jac0core and does NOT finalize),
    // so a mid-loop crash on an un-precompilable native module leaves the
    // generated JIRs intact for the crash-isolated --seal-finalize pass below.
    const boot = try std.fmt.allocPrint(a, "{s}/precompile_boot.py", .{site});
    try Dir.cwd().writeFile(io, .{
        .sub_path = boot,
        .data =
        \\import sys
        \\import _jac_finder; _jac_finder.install()
        \\sys.argv = ['jac', 'run'] + sys.argv[1:]
        \\from jaclang.jac0core.cli_boot import start_cli
        \\start_cli()
        \\
        ,
    });
    var argv_buf: [7][]const u8 = undefined;
    var argc: usize = 0;
    for ([_][]const u8{ py, "-S", boot, pc, site }) |s| {
        argv_buf[argc] = s;
        argc += 1;
    }
    if (seal) {
        argv_buf[argc] = "--seal-compile";
        argc += 1;
    }
    if (seal and debug_src) {
        argv_buf[argc] = "--debug-src";
        argc += 1;
    }

    // Controlled, hermetic env (clone parent, then override) -- mirrors the env
    // the shell prefixed the precompiler with. DONTWRITEBYTECODE so importing
    // jaclang here doesn't litter site/__pycache__ (which would make the later
    // `pip install --target` refuse the dir); JIR generation is independent.
    var env = try cloneEnv(gpa, parent_env);
    defer env.deinit();
    try env.put("PYTHONHOME", try std.fmt.allocPrint(a, "{s}/install", .{pbs_py_dir}));
    try env.put("PYTHONPATH", site);
    try env.put("PYTHONUTF8", "1");
    try env.put("PYTHONDONTWRITEBYTECODE", "1");
    try env.put("HOME", site);
    try env.put("PATH", "/usr/bin:/bin");
    // Pin the precompiler to the bundled (staged-site) jaclang, NOT a dev-source
    // tree. The build runs inside the repo whose jac.toml carries
    // [dev] jaclang_source, so _jac_finder's apply_dev_source_override would
    // otherwise reroute `import jaclang` to the source tree and stamp every JIR's
    // module key with the source's (often stale) egg-info version. The shipped
    // binary reports jac.toml's version, so a dev-source stamp makes the whole
    // bundle fail validation at runtime and every module recompiles on first run.
    // JAC_NO_DEV_SOURCE keeps pkg_version reading the staged dist-info we ship.
    try env.put("JAC_NO_DEV_SOURCE", "1");
    // The staged jaclang imports itself to run the precompiler; it must run
    // UNSEALED (from source), never sealed-load the manifest it is regenerating
    // (which may still be a seeded, older-format image). #7135.
    try env.put("JAC_NO_SEAL", "1");

    _ = runChild(io, argv_buf[0..argc], &env, true); // non-zero exit is by design

    // The precompiler removes PRECOMPILE_RESULT.json before its loop and
    // rewrites it after (see precompile_bytecode.jac RESULT_NAME); presence
    // means "ran to completion", the one thing the exit code cannot say.
    const pre_dir = try std.fmt.allocPrint(a, "{s}/jaclang/_precompiled", .{site});
    const result = try std.fmt.allocPrint(a, "{s}/PRECOMPILE_RESULT.json", .{pre_dir});
    if (!fileExists(io, result))
        die("mkpayload: precompiler did not run to completion (no {s}); it likely crashed. Fail rather than ship a slow cold-start binary.", .{result});
    Dir.cwd().deleteFile(io, result) catch {};
    log("   _precompiled: compile pass ran to completion", .{});

    if (seal) {
        // Second, crash-isolated pass: the best-effort precompile above can die
        // mid-loop on an un-precompilable native module (the "exits non-zero by
        // design" case), which would skip the inline seal. --seal-finalize does
        // ONLY the seal (verify every sealable module has a JIR, build the
        // manifest, freeze the bootstrap) with no compilation, so it always
        // completes -- and it fails loudly when the compile pass left gaps.
        var fin_argc: usize = 0;
        for ([_][]const u8{ py, "-S", boot, pc, site, "--seal-finalize" }) |s| {
            argv_buf[fin_argc] = s;
            fin_argc += 1;
        }
        if (debug_src) {
            argv_buf[fin_argc] = "--debug-src";
            fin_argc += 1;
        }
        log("==> sealing (finalize): completeness check + manifest + freeze bootstrap", .{});
        if (!runChild(io, argv_buf[0..fin_argc], &env, true))
            die("mkpayload: seal-finalize failed (see log above).", .{});

        // Strict: MANIFEST.json (sealed.py MANIFEST_NAME) must exist -- never
        // ship a half-sealed tree.
        const manifest = try std.fmt.allocPrint(a, "{s}/MANIFEST.json", .{pre_dir});
        if (!fileExists(io, manifest)) {
            die("mkpayload: seal produced no MANIFEST.json; the seal failed (see log above).", .{});
        }
        log("   sealed: MANIFEST.json present; payload boots from JIR (sources ship for tracebacks, never compiled).", .{});
    }
}


/// Stage the runtime tree: shared libpython + stdlib + the assembled site.
fn stageTree(io: Io, gpa: Allocator, a: Allocator, pbs_py_dir: []const u8, site: []const u8, stage: []const u8, musl_dir: ?[]const u8, wasm_libc_dir: ?[]const u8) !void {
    log("==> staging runtime tree (shared libpython + stdlib + site)", .{});
    const lib_dst = try std.fmt.allocPrint(a, "{s}/python/lib", .{stage});
    try Dir.cwd().createDirPath(io, lib_dst);

    // Stage the shared libpython under its bare name. pbs may ship it only as
    // libpython3.14.so.1.0 (with a .so symlink); copyFile dereferences, so the
    // real library lands at the bare name the launcher dlopens.
    const pbs_lib = try std.fmt.allocPrint(a, "{s}/install/lib", .{pbs_py_dir});
    const found = try findLibpython(io, a, pbs_lib);
    const staged_lib = try std.fmt.allocPrint(a, "{s}/{s}", .{ lib_dst, found.bare });
    try Dir.cwd().copyFile(
        try std.fmt.allocPrint(a, "{s}/{s}", .{ pbs_lib, found.src }),
        Dir.cwd(),
        staged_lib,
        io,
        .{},
    );
    // pbs ships the pgo+lto-full libpython UNSTRIPPED (debug info + .llvmbc LTO
    // bitcode) at ~245 MiB. Strip it to ~20 MiB -- the single biggest payload
    // win. The exported dynamic symbols the launcher dlsym's (PyInitConfig_*,
    // Py_RunMain, ...) live in .dynsym and are kept; only debug / local
    // symbols / dead bitcode go, so the PGO+LTO-optimized code is untouched.
    stripBestEffort(io, staged_lib);

    // Copy the stdlib as-is (keeps shipped .pyc), then prune heavy/build-only
    // bits. KEEP lib-dynload, encodings, ensurepip.
    {
        const stdlib_dst = try std.fmt.allocPrint(a, "{s}/python{s}", .{ lib_dst, py_ver });
        var stdlib_src = try Dir.cwd().openDir(io, try std.fmt.allocPrint(a, "{s}/python{s}", .{ pbs_lib, py_ver }), .{ .iterate = true });
        defer stdlib_src.close(io);
        try copyTree(io, gpa, a, stdlib_src, stdlib_dst, skipNone);

        for ([_][]const u8{ "test", "idlelib", "turtledemo", "tkinter", "lib2to3" }) |d| {
            Dir.cwd().deleteTree(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ stdlib_dst, d })) catch {};
        }
        // config-3.14-* build dirs.
        var sd = try Dir.cwd().openDir(io, stdlib_dst, .{ .iterate = true });
        defer sd.close(io);
        var dit = sd.iterate();
        while (dit.next(io) catch null) |e| {
            if (e.kind == .directory and std.mem.startsWith(u8, e.name, "config-")) {
                Dir.cwd().deleteTree(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ stdlib_dst, e.name })) catch {};
            }
        }
    }

    // The assembled site (already pruned during copy).
    {
        var site_src = try Dir.cwd().openDir(io, site, .{ .iterate = true });
        defer site_src.close(io);
        try copyTree(io, gpa, a, site_src, try std.fmt.allocPrint(a, "{s}/site", .{stage}), skipStageSite);
    }
    // The LLVMPY_* shim statically links LLVM (~130 MiB); strip it (best-effort).
    stripBestEffort(io, try std.fmt.allocPrint(a, "{s}/site/jaclang/compiler/passes/native/llvm/{s}", .{ stage, shimFileName() }));

    // Static C-floor archives + CA bundle so an installed binary can static-link
    // a bundled C floor at `nacompile` time, not just dev builds (#6978 0.2).
    try stageFloor(io, gpa, a, pbs_py_dir, stage);

    // Vendored static-musl runtime, so an installed binary can fully static-link
    // Linux executables against musl at `nacompile` time (no glibc/loader dep).
    if (musl_dir) |md| try stageMusl(io, a, md, stage);

    // Vendored wasm32 libc bitcode, so an installed binary links libc into
    // na->wasm modules (in-module libc + jac_host1 import contract, #7048).
    if (wasm_libc_dir) |wd| try stageWasmLibc(io, a, wd, stage);
}

/// The build host's `<os>-<arch>` key, matching the fetch-pbs osarch dir names
/// (`linux-x86_64`, `macos-aarch64`, ...). The payload tool builds for and runs
/// on the host, so `builtin` is the source of truth. Used to arch-key the staged
/// floor archives so a cross-`--target` nacompile never links the wrong arch.
fn hostOsArch() []const u8 {
    const os_name = switch (builtin.os.tag) {
        .linux => "linux",
        .macos => "macos",
        .windows => "windows",
        else => @compileError("floor staging: unsupported host OS"),
    };
    const arch_name = switch (builtin.cpu.arch) {
        .x86_64 => "x86_64",
        .aarch64 => "aarch64",
        else => @compileError("floor staging: unsupported host arch"),
    };
    return os_name ++ "-" ++ arch_name;
}

/// Stage the static C-floor archives + a CA bundle into the payload so an
/// installed (non-dev) binary can static-link a bundled C floor at `nacompile`
/// time -- the dev path reads the same archives straight from `.pbs-build`, this
/// is the shipped-binary counterpart (#6978 Phase 0.2). Archives land arch-keyed
/// under `python/floor/<osarch>/` (so a cross-`--target` build never grabs the
/// host's wrong-arch archives) and the CA bundle at `python/floor/cacert.pem`
/// (arch-independent). Best-effort per file: pbs's `build/lib/` set differs by
/// platform (no `libz.a` on macOS, which uses the system zlib), so a missing
/// member is skipped rather than fatal.
fn stageFloor(io: Io, gpa: Allocator, a: Allocator, pbs_py_dir: []const u8, stage: []const u8) !void {
    const osarch = hostOsArch();
    const floor_dst = try std.fmt.allocPrint(a, "{s}/python/floor/{s}", .{ stage, osarch });
    try Dir.cwd().createDirPath(io, floor_dst);
    const src_lib = try std.fmt.allocPrint(a, "{s}/build/lib", .{pbs_py_dir});

    // The bundled-C floor set the na stdlib roadmap (#6978 §12) targets -- the
    // exact archives CPython's own C extensions link. Everything else in
    // build/lib/ (libX11, libedit, libncursesw, tcl/tk stubs, ...) is not a floor
    // target and stays out, to bound the binary size.
    const FLOOR = [_][]const u8{
        "libssl.a", "libcrypto.a", "libsqlite3.a", "libmpdec.a", "liblzma.a",
        "libbz2.a", "libexpat.a",  "libz.a",       "libzstd.a",
    };
    var staged: usize = 0;
    for (FLOOR) |name| {
        const src = try std.fmt.allocPrint(a, "{s}/{s}", .{ src_lib, name });
        if (!fileExists(io, src)) continue; // not present for this platform
        try Dir.cwd().copyFile(src, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ floor_dst, name }), io, .{});
        staged += 1;
    }
    log("==> staged {d} C-floor archive(s) -> python/floor/{s}", .{ staged, osarch });

    // CA bundle (certifi's cacert.pem, vendored in pbs's pip) -> a stable,
    // pip-layout-independent path the ssl floor (Phase 1) reads.
    if (try findCaBundle(io, gpa, a, pbs_py_dir)) |ca| {
        try Dir.cwd().copyFile(ca, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/python/floor/cacert.pem", .{stage}), io, .{});
        log("==> staged CA bundle -> python/floor/cacert.pem", .{});
    } else {
        log("   no CA bundle found under pbs site-packages; ssl floor will fall back to a system bundle", .{});
    }
}

/// Stage the vendored static-musl runtime into the payload so an installed
/// (non-dev) binary can fully static-link Linux executables against musl at
/// `nacompile` time -- no glibc/loader dependency, runs on Alpine/scratch/any
/// glibc. Mirrors stageFloor: artifacts land arch-keyed under
/// `python/floor/<osarch>/musl/`, exactly where nacompile's _musl_lib_dir looks
/// in a shipped binary. Best-effort per file (compiler-rt + crti/crtn are
/// optional); the dev/source path reads the same set straight from `.pbs-build`.
fn stageMusl(io: Io, a: Allocator, musl_dir: []const u8, stage: []const u8) !void {
    const osarch = hostOsArch();
    const dst = try std.fmt.allocPrint(a, "{s}/python/floor/{s}/musl", .{ stage, osarch });
    try Dir.cwd().createDirPath(io, dst);
    const ARTIFACTS = [_][]const u8{
        "libc.a", "libzigc.a", "libcompiler_rt.a", "crt1.o", "crti.o", "crtn.o",
    };
    var staged: usize = 0;
    for (ARTIFACTS) |name| {
        const src = try std.fmt.allocPrint(a, "{s}/{s}", .{ musl_dir, name });
        if (!fileExists(io, src)) continue;
        try Dir.cwd().copyFile(src, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ dst, name }), io, .{});
        staged += 1;
    }
    log("==> staged {d} musl runtime artifact(s) -> python/floor/{s}/musl", .{ staged, osarch });
}

/// Stage the vendored wasm32 libc bitcode into the payload so an installed
/// binary links libc into na->wasm modules at build time (in-module libc +
/// jac_host1 import contract, #7048). Lands at `python/floor/wasm32/libc/`,
/// exactly where wasm_build.jac's _wasm_libc_dir looks in a shipped binary;
/// NOT arch-keyed — bitcode for wasm32 is the same on every build host. The
/// derived `_merged.bc` cache is skipped: it is regenerated on first use.
fn stageWasmLibc(io: Io, a: Allocator, wasm_libc_dir: []const u8, stage: []const u8) !void {
    const dst = try std.fmt.allocPrint(a, "{s}/python/floor/wasm32/libc", .{stage});
    try Dir.cwd().createDirPath(io, dst);
    var dir = Dir.cwd().openDir(io, wasm_libc_dir, .{ .iterate = true }) catch
        die("wasm-libc staging: dir missing at {s} (run `zig build vendor-wasm-libc`)", .{wasm_libc_dir});
    defer dir.close(io);
    var staged: usize = 0;
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".bc")) continue;
        if (std.mem.eql(u8, entry.name, "_merged.bc")) continue;
        try Dir.cwd().copyFile(
            try std.fmt.allocPrint(a, "{s}/{s}", .{ wasm_libc_dir, entry.name }),
            Dir.cwd(),
            try std.fmt.allocPrint(a, "{s}/{s}", .{ dst, entry.name }),
            io,
            .{},
        );
        staged += 1;
    }
    log("==> staged {d} wasm libc bitcode file(s) -> python/floor/wasm32/libc", .{staged});
    if (staged == 0) die("wasm-libc staging: no .bc files in {s}", .{wasm_libc_dir});
}

/// Locate certifi's `cacert.pem` in the pbs tree (pip vendors it). Tries the
/// canonical pip path first, then a bounded walk of site-packages for any
/// `certifi/cacert.pem` (so a pip layout shift still resolves). Null if absent.
fn findCaBundle(io: Io, gpa: Allocator, a: Allocator, pbs_py_dir: []const u8) !?[]const u8 {
    const direct = try std.fmt.allocPrint(a, "{s}/install/lib/python{s}/site-packages/pip/_vendor/certifi/cacert.pem", .{ pbs_py_dir, py_ver });
    if (fileExists(io, direct)) return direct;
    const sp = try std.fmt.allocPrint(a, "{s}/install/lib/python{s}/site-packages", .{ pbs_py_dir, py_ver });
    var dir = Dir.cwd().openDir(io, sp, .{ .iterate = true }) catch return null;
    defer dir.close(io);
    var walker = dir.walk(gpa) catch return null;
    defer walker.deinit();
    while (walker.next(io) catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, "certifi/cacert.pem"))
            return try std.fmt.allocPrint(a, "{s}/{s}", .{ sp, entry.path });
    }
    return null;
}

/// The host's LLVMPY_* shim filename, matching build.zig's emitted name and
/// ffi.jac's _shim_name() (the payload tool runs on -- and builds for -- the
/// host, so builtin.os.tag is the target OS).
fn shimFileName() []const u8 {
    return switch (builtin.os.tag) {
        .windows => "jacllvm.dll",
        .macos => "libjacllvm.dylib",
        else => "libjacllvm.so",
    };
}

/// Strip a shared library in place to shed debug info / local symbols / dead LTO
/// bitcode, keeping the exported .dynsym the launcher resolves. Best-effort: the
/// host `strip` (binutils, near-universal on Linux/macOS build hosts and CI) is
/// the one optional tool -- if it is absent the build still succeeds, shipping
/// the lib unstripped. Plain `strip` (no flags) preserves dynamic symbols for a
/// shared object, so no flag tuning is needed.
fn stripBestEffort(io: Io, path: []const u8) void {
    const before = fileSizeOrZero(io, path);
    if (before == 0) return; // shim not present at this path; nothing to strip
    var child = std.process.spawn(io, .{
        .argv = &.{ "strip", path },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    }) catch {
        log("   strip unavailable; shipping {s} unstripped", .{path});
        return;
    };
    _ = child.wait(io) catch return;
    const after = fileSizeOrZero(io, path);
    if (after != 0 and after < before) {
        log("   stripped {s}: {d} -> {d} MiB", .{ path, before >> 20, after >> 20 });
    }
}

fn fileSizeOrZero(io: Io, path: []const u8) u64 {
    const f = Dir.cwd().openFile(io, path, .{}) catch return 0;
    defer f.close(io);
    return f.length(io) catch 0;
}

const FoundLib = struct { src: []const u8, bare: []const u8 };

/// Find the shared libpython in `lib_dir` and the bare name to stage it under.
fn findLibpython(io: Io, a: Allocator, lib_dir: []const u8) !FoundLib {
    const so = "libpython" ++ py_ver ++ ".so";
    const dy = "libpython" ++ py_ver ++ ".dylib";
    if (fileExists(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ lib_dir, so }))) return .{ .src = so, .bare = so };
    if (fileExists(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ lib_dir, dy }))) return .{ .src = dy, .bare = dy };
    // Versioned variant (e.g. libpython3.14.so.1.0).
    var dir = try Dir.cwd().openDir(io, lib_dir, .{ .iterate = true });
    defer dir.close(io);
    var dit = dir.iterate();
    while (dit.next(io) catch null) |e| {
        if (std.mem.startsWith(u8, e.name, so)) return .{ .src = try a.dupe(u8, e.name), .bare = so };
        if (std.mem.startsWith(u8, e.name, dy)) return .{ .src = try a.dupe(u8, e.name), .bare = dy };
    }
    die("mkpayload: shared libpython not found under {s}", .{lib_dir});
}

// =================================================================== utils ===

fn die(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print("payload: " ++ fmt ++ "\n", args);
    std.process.exit(1);
}

fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

fn fileExists(io: Io, path: []const u8) bool {
    const f = Dir.cwd().openFile(io, path, .{}) catch return false;
    f.close(io);
    return true;
}

/// File mtime in ns, or null if unreadable. Backs the wasm-libc staleness check.
fn mtimeNs(io: Io, path: []const u8) ?i96 {
    const f = Dir.cwd().openFile(io, path, .{}) catch return null;
    defer f.close(io);
    const st = f.stat(io) catch return null;
    return st.mtime.nanoseconds;
}

fn sha256Hex(bytes: []const u8) [64]u8 {
    var d: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &d, .{});
    return runtime.hexDigest(&d);
}

/// HTTP GET into a freshly-allocated buffer (caller frees). Follows redirects
/// (GitHub release / codeload -> S3) and verifies TLS against the system CA
/// bundle (auto-rescanned by std.http.Client on the first HTTPS connection).
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

fn gzipDecompressAlloc(io: Io, gpa: Allocator, gz: []const u8) ![]u8 {
    _ = io;
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const window = try gpa.alloc(u8, flate.max_window_len);
    defer gpa.free(window);
    var src = Io.Reader.fixed(gz);
    var dz = flate.Decompress.init(&src, .gzip, window);
    _ = dz.reader.streamRemaining(&aw.writer) catch |err| die("gzip decompress failed: {s}", .{@errorName(err)});
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

fn readTrimmed(io: Io, gpa: Allocator, a: Allocator, path: []const u8) !?[]const u8 {
    const raw = Dir.cwd().readFileAlloc(io, path, gpa, .unlimited) catch return null;
    defer gpa.free(raw);
    const t = std.mem.trim(u8, raw, " \t\r\n");
    if (t.len == 0) return null;
    return try a.dupe(u8, t);
}

/// Copy `<repo>/<name>` into `<dst>/<name>`.
fn copyInto(io: Io, a: Allocator, repo_root: []const u8, name: []const u8, dst: []const u8) !void {
    try Dir.cwd().copyFile(
        try std.fmt.allocPrint(a, "{s}/{s}", .{ repo_root, name }),
        Dir.cwd(),
        try std.fmt.allocPrint(a, "{s}/{s}", .{ dst, name }),
        io,
        .{},
    );
}

/// Recursively copy `src_dir` into `dst_path` (created), skipping entries for
/// which `skipFn` returns true. Symlinks are dereferenced (copyFile opens the
/// source), so the result is a flat, self-contained tree.
fn copyTree(io: Io, gpa: Allocator, a: Allocator, src_dir: Dir, dst_path: []const u8, skipFn: *const fn ([]const u8) bool) !void {
    _ = a;
    try Dir.cwd().createDirPath(io, dst_path);
    var dst_dir = try Dir.cwd().openDir(io, dst_path, .{});
    defer dst_dir.close(io);
    var walker = try src_dir.walk(gpa);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (skipFn(entry.path)) continue;
        switch (entry.kind) {
            .directory => dst_dir.createDirPath(io, entry.path) catch {},
            else => src_dir.copyFile(entry.path, dst_dir, entry.path, io, .{ .make_path = true }) catch |err|
                die("copy {s} failed: {s}", .{ entry.path, @errorName(err) }),
        }
    }
}

fn skipNone(_: []const u8) bool {
    return false;
}

fn skipJaclang(p: []const u8) bool {
    return std.mem.indexOf(u8, p, "__pycache__") != null or
        std.mem.indexOf(u8, p, "node_modules") != null or
        std.mem.indexOf(u8, p, "_precompiled") != null or
        std.mem.indexOf(u8, p, "vendor/typeshed/stubs") != null or
        // The LLVMPY_* shim is placed fresh via --shim, not copied from the
        // (gitignored, build-placed) source-tree artifact -- skip it here.
        std.mem.indexOf(u8, p, "libjacllvm.") != null or
        // Same for the libjacpyembed desktop shim (placed via --pyembed).
        std.mem.indexOf(u8, p, "libjacpyembed.") != null or
        std.mem.indexOf(u8, p, "jacpyembed.dll") != null or
        // The contained bun runtime is staged fresh via --bun, not copied from
        // any (gitignored) source-tree placement -- skip it here.
        std.mem.indexOf(u8, p, "client/_bun") != null or
        std.mem.endsWith(u8, p, ".pyc");
}

/// macOS hygiene: AppleDouble (._*) sidecars break jaclang's .impl scanner.
fn skipStageSite(p: []const u8) bool {
    const base = std.fs.path.basename(p);
    return std.mem.startsWith(u8, base, "._") or std.mem.eql(u8, base, ".DS_Store");
}

/// jac.toml `key = "value"` -> value (first match; good enough for the flat
/// [project] table this reads: version).
fn tomlString(toml: []const u8, key: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, toml, '\n');
    while (lines.next()) |line| {
        const t = std.mem.trimStart(u8, line, " \t");
        if (!std.mem.startsWith(u8, t, key)) continue;
        const rest = std.mem.trimStart(u8, t[key.len..], " \t");
        if (!std.mem.startsWith(u8, rest, "=")) continue;
        const q1 = std.mem.indexOfScalar(u8, rest, '"') orelse continue;
        const after = rest[q1 + 1 ..];
        const q2 = std.mem.indexOfScalar(u8, after, '"') orelse continue;
        return after[0..q2];
    }
    return null;
}

fn cloneEnv(gpa: Allocator, parent: *std.process.Environ.Map) !std.process.Environ.Map {
    var env = std.process.Environ.Map.init(gpa);
    errdefer env.deinit();
    const keys = parent.keys();
    const vals = parent.values();
    for (keys, vals) |k, v| try env.put(k, v);
    return env;
}

/// Spawn `argv` (inheriting stdio so the outer `zig build` Run captures or
/// streams it under -Dpayload-progress) and wait. Dies on non-zero exit unless
/// `allow_fail`. Returns whether the child exited 0.
fn runChild(io: Io, argv: []const []const u8, env: ?*const std.process.Environ.Map, allow_fail: bool) bool {
    var child = std.process.spawn(io, .{
        .argv = argv,
        .environ_map = env,
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    }) catch |err| die("spawn {s} failed: {s}", .{ argv[0], @errorName(err) });
    const term = child.wait(io) catch |err| die("wait {s} failed: {s}", .{ argv[0], @errorName(err) });
    const ok = switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!ok and !allow_fail) die("command failed: {s}", .{argv[0]});
    return ok;
}

/// tar `stage` (its top-level `python` + `site`) and gzip it to `out`. The
/// runtime side (runtime.zig) decompresses this exact format.
fn tarGzDir(io: Io, gpa: Allocator, a: Allocator, stage: []const u8, out: []const u8) !void {
    var file = try Dir.cwd().createFile(io, out, .{ .truncate = true });
    defer file.close(io);
    var fbuf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &fbuf);

    const cbuf = try gpa.alloc(u8, flate.max_window_len);
    defer gpa.free(cbuf);
    var comp = try flate.Compress.init(&fw.interface, cbuf, .gzip, .best);

    var tw: std.tar.Writer = .{ .underlying_writer = &comp.writer };

    var stage_dir = try Dir.cwd().openDir(io, stage, .{ .iterate = true });
    defer stage_dir.close(io);
    var walker = try stage_dir.walk(gpa);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        switch (entry.kind) {
            .directory => try tw.writeDir(entry.path, .{}),
            else => {
                const bytes = try stage_dir.readFileAlloc(io, entry.path, a, .unlimited);
                defer a.free(bytes);
                try tw.writeFileBytes(entry.path, bytes, .{});
            },
        }
    }

    try comp.finish();
    try fw.interface.flush();
}

// ----------------------------------------------------------------- tests

const testing = std.testing;

test "stageFloor stages the floor allow-list + CA bundle, skips non-floor archives" {
    const io = testing.io;
    const gpa = testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var base_buf: [MAX_PATH]u8 = undefined;
    const base = base_buf[0..try tmp.dir.realPath(io, &base_buf)];

    // A fake pbs tree: two floor archives, one NON-floor archive (must be left
    // behind), and certifi's CA bundle at the canonical pip path.
    const pbs = try std.fmt.allocPrint(a, "{s}/pbs", .{base});
    const lib = try std.fmt.allocPrint(a, "{s}/build/lib", .{pbs});
    try Dir.cwd().createDirPath(io, lib);
    for ([_][]const u8{ "libz.a", "libssl.a", "libX11.a" }) |n| {
        try Dir.cwd().writeFile(io, .{
            .sub_path = try std.fmt.allocPrint(a, "{s}/{s}", .{ lib, n }),
            .data = "!<arch>\n",
        });
    }
    const certdir = try std.fmt.allocPrint(a, "{s}/install/lib/python{s}/site-packages/pip/_vendor/certifi", .{ pbs, py_ver });
    try Dir.cwd().createDirPath(io, certdir);
    try Dir.cwd().writeFile(io, .{
        .sub_path = try std.fmt.allocPrint(a, "{s}/cacert.pem", .{certdir}),
        .data = "# ca\n",
    });

    const stage = try std.fmt.allocPrint(a, "{s}/stage", .{base});
    try stageFloor(io, gpa, a, pbs, stage);

    const osarch = hostOsArch();
    const exp = struct {
        fn p(al: Allocator, st: []const u8, rest: []const u8) []const u8 {
            return std.fmt.allocPrint(al, "{s}/python/floor/{s}", .{ st, rest }) catch unreachable;
        }
    }.p;
    try testing.expect(fileExists(io, exp(a, stage, try std.fmt.allocPrint(a, "{s}/libz.a", .{osarch}))));
    try testing.expect(fileExists(io, exp(a, stage, try std.fmt.allocPrint(a, "{s}/libssl.a", .{osarch}))));
    try testing.expect(fileExists(io, exp(a, stage, "cacert.pem")));
    // The non-floor archive present in build/lib must NOT be staged.
    try testing.expect(!fileExists(io, exp(a, stage, try std.fmt.allocPrint(a, "{s}/libX11.a", .{osarch}))));
}
