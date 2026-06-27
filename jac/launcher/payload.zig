const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const flate = std.compress.flate;
const zstd = std.compress.zstd;
const Dir = Io.Dir;
const runtime = @import("runtime.zig");

const py_ver = "3.14";
const PBS_TAG = "20260610";
const PBS_PY = "3.14.6";
const PBS_FLAVOR = "pgo+lto-full";
const PBS_BASE = "https://github.com/astral-sh/python-build-standalone/releases/download";
const PBS_WINDOW = 1 << 27;

const TYPESHED_TARBALL_BASE = "https://codeload.github.com/python/typeshed/tar.gz";
const TYPESHED_VENDOR = "jaclang/vendor/typeshed";

const BUN_VERSION = "1.3.11";
const BUN_BASE = "https://github.com/oven-sh/bun/releases/download";

const MAX_PATH = Dir.max_path_bytes;

const Cmd = enum { @"fetch-pbs", @"fetch-typeshed", @"fetch-llvm", @"fetch-bun", mkpayload, @"typeshed-sha" };

const LLVM_VER = "22.1.8";

const SLICE_BASE = "https://github.com/jaseci-labs/llvm-slice/releases/download";
const SLICE_TAG = "v" ++ LLVM_VER;

const LlvmRelease = struct {
    dirname: []const u8,
    triple: []const u8,
    manifest_sha256: []const u8,
    zip_size: u64,
};
fn llvmRelease() ?LlvmRelease {
    return switch (builtin.os.tag) {
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => .{
                .dirname = "LLVM-22.1.8-Linux-X64",
                .triple = "x86_64-linux",
                .manifest_sha256 = "353ec23280b6453595714bd4db3fa3339fdcec96c8fb0ccfe4f8fa4de455b64a",
                .zip_size = 970350875,
            },
            .aarch64 => .{
                .dirname = "LLVM-22.1.8-Linux-ARM64",
                .triple = "aarch64-linux",
                .manifest_sha256 = "b1aae9c16de5feff6fd4441f0bf32671b27c6dda98382ee389d305db6351e598",
                .zip_size = 932506999,
            },
            else => null,
        },
        .macos => switch (builtin.cpu.arch) {
            .aarch64 => .{
                .dirname = "LLVM-22.1.8-macOS-ARM64",
                .triple = "aarch64-apple-darwin",
                .manifest_sha256 = "541721f3501de4bd4f19b0319d857b7d51651856b26fa8f600ad317edb8ea441",
                .zip_size = 743879473,
            },
            else => null,
        },
        else => null,
    };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var argv: [16][]const u8 = undefined;
    var n: usize = 0;
    var it = init.minimal.args.iterate();
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
        .@"fetch-typeshed" => {
            if (n < 3) die("usage: payload fetch-typeshed <repo-root>", .{});
            try fetchTypeshed(io, gpa, a, argv[2]);
        },
        .mkpayload => {
            if (n < 5) die("usage: payload mkpayload <pbs-python-dir> <repo-root> <out.tar.gz> [--shim=PATH] [--skip-precompile] [--link-source=PATH]", .{});
            var shim_so: ?[]const u8 = null;
            var pyembed_so: ?[]const u8 = null;
            var bun_bin: ?[]const u8 = null;
            var skip_precompile = false;
            var link_source: ?[]const u8 = null;
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
                }
            }
            try mkPayload(io, gpa, a, init.environ_map, argv[2], argv[3], argv[4], shim_so, pyembed_so, bun_bin, skip_precompile, link_source);
        },
        .@"typeshed-sha" => {
            if (n < 3) die("usage: payload typeshed-sha <commit>", .{});
            try typeshedSha(io, gpa, a, argv[2]);
        },
    }
}

fn typeshedSha(io: Io, gpa: Allocator, a: Allocator, commit: []const u8) !void {
    const url = try std.fmt.allocPrint(a, "{s}/{s}", .{ TYPESHED_TARBALL_BASE, commit });
    const gz = try httpGetAlloc(io, gpa, url);
    defer gpa.free(gz);
    const tar = try gzipDecompressAlloc(io, gpa, gz);
    defer gpa.free(tar);
    const hex = sha256Hex(tar);
    var buf: [128]u8 = undefined;
    var w = Io.File.stdout().writer(io, &buf);
    w.interface.print("{s}\n", .{&hex}) catch {};
    w.interface.flush() catch {};
}

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

    const sums_url = try std.fmt.allocPrint(a, "{s}/{s}/SHA256SUMS", .{ PBS_BASE, PBS_TAG });
    const sums = try httpGetAlloc(io, gpa, sums_url);
    defer gpa.free(sums);
    const expected = findSumLine(sums, asset) orelse die("fetch-pbs: no checksum for {s} in SHA256SUMS", .{asset});
    const actual = sha256Hex(tarzst);
    if (!std.mem.eql(u8, &actual, expected)) {
        die("fetch-pbs: checksum mismatch for {s}\n  expected {s}\n  actual   {s}", .{ asset, expected, &actual });
    }

    try Dir.cwd().createDirPath(io, dest);
    var ddir = try Dir.cwd().openDir(io, dest, .{});
    defer ddir.close(io);

    const window = try gpa.alloc(u8, PBS_WINDOW + zstd.block_size_max);
    defer gpa.free(window);
    var src = Io.Reader.fixed(tarzst);
    var dz = zstd.Decompress.init(&src, window, .{ .window_len = PBS_WINDOW, .verify_checksum = true });
    std.tar.extract(io, ddir, &dz.reader, .{ .mode_mode = .executable_bit_only, .strip_components = 0 }) catch |err|
        die("fetch-pbs: extract failed: {s}", .{@errorName(err)});

    if (!fileExists(io, marker)) die("fetch-pbs: extract produced no PYTHON.json", .{});
    log("fetch-pbs: ready at {s}/python", .{dest});
}

fn fetchLlvm(io: Io, gpa: Allocator, a: Allocator, dest: []const u8) !void {
    const rel = llvmRelease() orelse
        die("fetch-llvm: no pinned LLVM release for this host ({s}-{s}); add a row to llvmRelease().", .{ @tagName(builtin.cpu.arch), @tagName(builtin.os.tag) });
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

fn sliceWanted(name: []const u8) bool {
    if (std.mem.startsWith(u8, name, "lib/libLLVM") and std.mem.endsWith(u8, name, ".a")) return true;
    if (std.mem.startsWith(u8, name, "include/llvm/")) return true;
    if (std.mem.startsWith(u8, name, "include/llvm-c/")) return true;
    if (builtin.os.tag == .macos and std.mem.eql(u8, name, "lib/libLTO.dylib")) return true;
    return false;
}

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

fn fetchLlvmSlice(io: Io, gpa: Allocator, a: Allocator, dest: []const u8, rel: LlvmRelease) !void {
    const zip_url = try std.fmt.allocPrint(a, "{s}/{s}/llvm-{s}-{s}-dev.zip", .{ SLICE_BASE, SLICE_TAG, LLVM_VER, rel.triple });
    const man_url = try std.fmt.allocPrint(a, "{s}/{s}/llvm-{s}-{s}-manifest.json", .{ SLICE_BASE, SLICE_TAG, LLVM_VER, rel.triple });
    log("fetch-llvm: slice range-fetch (~84 MB) from llvm-slice {s} {s}", .{ SLICE_TAG, rel.triple });

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

    const tail_len: u64 = @min(rel.zip_size, 65536);
    const tail = try httpGetRange(io, gpa, zip_url, rel.zip_size - tail_len, rel.zip_size - 1);
    defer gpa.free(tail);
    const eocd = std.mem.lastIndexOf(u8, tail, "PK\x05\x06") orelse die("fetch-llvm: no zip EOCD found", .{});
    const cd_size = rdU32(tail, eocd + 12);
    const cd_off = rdU32(tail, eocd + 16);

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
    std.sort.block(ZipMember, members, {}, lessByLho);

    var rdir = try Dir.cwd().openDir(io, dest, .{});
    defer rdir.close(io);
    var name_buf: [Dir.max_path_bytes]u8 = undefined;
    var content_buf: [64 * 1024]u8 = undefined;

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
        const ra = i;
        var rb = i;
        var j = i + 1;
        while (j < count) : (j += 1) {
            if (!sliceWanted(members[j].name)) continue;
            if (members[j].lho - end_byte(members, rb, cd_off) >= GAP) break;
            rb = j;
        }
        const run_start = members[ra].lho;
        const run_end = end_byte(members, rb, cd_off);
        const run = try httpGetRange(io, gpa, zip_url, run_start, run_end - 1);
        defer gpa.free(run);
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
            if (sha_map.get(m.name)) |want_sha| {
                const got = sha256Hex(bytes);
                if (!std.mem.eql(u8, &got, want_sha)) die("fetch-llvm: sha256 mismatch for {s}", .{m.name});
            }
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
        i = rb + 1;
    }
    log("fetch-llvm: slice extracted {d} members", .{written});
}

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

    const sums_url = try std.fmt.allocPrint(a, "{s}/bun-v{s}/SHASUMS256.txt", .{ BUN_BASE, BUN_VERSION });
    const sums = try httpGetAlloc(io, gpa, sums_url);
    defer gpa.free(sums);
    const expected = findSumLine(sums, zip_name) orelse die("fetch-bun: no checksum for {s} in SHASUMS256.txt", .{zip_name});
    const actual = sha256Hex(zip);
    if (!std.mem.eql(u8, &actual, expected))
        die("fetch-bun: checksum mismatch for {s}\n  expected {s}\n  actual   {s}", .{ zip_name, expected, &actual });

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

fn fetchTypeshed(io: Io, gpa: Allocator, a: Allocator, repo_root: []const u8) !void {
    const vendor = try std.fmt.allocPrint(a, "{s}/{s}", .{ repo_root, TYPESHED_VENDOR });
    const commit = try readTrimmed(io, gpa, a, try std.fmt.allocPrint(a, "{s}/PIN", .{vendor})) orelse
        die("fetch-typeshed: no PIN at {s}/PIN", .{vendor});
    const expected_sha = try readTrimmed(io, gpa, a, try std.fmt.allocPrint(a, "{s}/TARBALL_SHA256", .{vendor})) orelse
        die("fetch-typeshed: no TARBALL_SHA256 at {s}/TARBALL_SHA256", .{vendor});

    const versions = try std.fmt.allocPrint(a, "{s}/stdlib/VERSIONS", .{vendor});
    const stamp_path = try std.fmt.allocPrint(a, "{s}/stdlib/.typeshed-sha", .{vendor});
    if (fileExists(io, versions)) {
        if (try readTrimmed(io, gpa, a, stamp_path)) |s| {
            if (std.mem.eql(u8, s, commit)) return;
        }
    }

    const url = try std.fmt.allocPrint(a, "{s}/{s}", .{ TYPESHED_TARBALL_BASE, commit });
    log("fetch-typeshed: fetching typeshed @ {s}", .{commit});
    const gz = try httpGetAlloc(io, gpa, url);
    defer gpa.free(gz);

    const tar = try gzipDecompressAlloc(io, gpa, gz);
    defer gpa.free(tar);
    const actual = sha256Hex(tar);
    if (!std.mem.eql(u8, &actual, expected_sha)) {
        die("fetch-typeshed: tarball checksum mismatch @ {s}\n  expected {s}\n  actual   {s}", .{ commit, expected_sha, &actual });
    }

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
    try copyTree(io, gpa, a, stdlib_src, stdlib_dst, skipTypeshedTests);

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

fn mkPayload(
    io: Io,
    gpa: Allocator,
    a: Allocator,
    parent_env: *std.process.Environ.Map,
    pbs_py_dir: []const u8,
    repo_root: []const u8,
    out: []const u8,
    shim_so: ?[]const u8,
    pyembed_so: ?[]const u8,
    bun_bin: ?[]const u8,
    skip_precompile: bool,
    link_source: ?[]const u8,
) !void {
    const py = try resolvePython(io, a, pbs_py_dir);
    const work = try std.fmt.allocPrint(a, "{s}.work", .{out});
    Dir.cwd().deleteTree(io, work) catch {};
    try Dir.cwd().createDirPath(io, work);
    defer Dir.cwd().deleteTree(io, work) catch {};

    const site = try std.fmt.allocPrint(a, "{s}/site", .{work});
    const stage = try std.fmt.allocPrint(a, "{s}/stage", .{work});

    const ts_versions = try std.fmt.allocPrint(a, "{s}/{s}/stdlib/VERSIONS", .{ repo_root, TYPESHED_VENDOR });
    if (!fileExists(io, ts_versions)) try fetchTypeshed(io, gpa, a, repo_root);

    log("==> assembling jaclang site from source (no pyproject build)", .{});
    _ = runChild(io, &.{ py, "-m", "ensurepip", "--upgrade" }, null, true);
    _ = runChild(io, &.{ py, "-m", "pip", "install", "--quiet", "--upgrade", "pip" }, null, true);
    try Dir.cwd().createDirPath(io, site);

    if (link_source == null) {
        var jac_src = try Dir.cwd().openDir(io, try std.fmt.allocPrint(a, "{s}/jaclang", .{repo_root}), .{ .iterate = true });
        defer jac_src.close(io);
        try copyTree(io, gpa, a, jac_src, try std.fmt.allocPrint(a, "{s}/jaclang", .{site}), skipJaclang);
    } else {
        log("==> linked-source mode: NOT bundling jaclang (compiler served from {s})", .{link_source.?});
    }
    try copyInto(io, a, repo_root, "_jac_finder.py", site);
    try copyInto(io, a, repo_root, "sitecustomize.py", site);
    if (link_source) |src| {
        try Dir.cwd().writeFile(io, .{
            .sub_path = try std.fmt.allocPrint(a, "{s}/jac_linked_source", .{site}),
            .data = src,
        });
    }

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

    if (link_source == null) {
        const so = shim_so orelse die(
            "mkpayload: no LLVM shim (--shim). Run `zig build fetch-llvm` once so the" ++
                " build can compile + statically link the LLVMPY_* shim.",
            .{},
        );
        const dst_dir = try std.fmt.allocPrint(a, "{s}/jaclang/compiler/passes/native/llvm", .{site});
        try Dir.cwd().createDirPath(io, dst_dir);
        const shim_base = std.fs.path.basename(so);
        log("==> bundling Zig-built LLVMPY_* shim ({s})", .{so});
        try Dir.cwd().copyFile(so, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ dst_dir, shim_base }), io, .{});
    }

    if (link_source == null) {
        if (pyembed_so) |pso| {
            const dst_dir = try std.fmt.allocPrint(a, "{s}/jaclang/runtimelib/client/targets/desktop/native", .{site});
            try Dir.cwd().createDirPath(io, dst_dir);
            const pso_base = std.fs.path.basename(pso);
            log("==> bundling libjacpyembed shim ({s})", .{pso});
            try Dir.cwd().copyFile(pso, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ dst_dir, pso_base }), io, .{});
        }
    }

    if (link_source == null) {
        if (bun_bin) |bb| {
            const bun_base = std.fs.path.basename(bb);
            const dst_dir = try std.fmt.allocPrint(a, "{s}/jaclang/runtimelib/client/_bun", .{site});
            try Dir.cwd().createDirPath(io, dst_dir);
            log("==> bundling contained bun runtime ({s})", .{bb});
            try Dir.cwd().copyFile(bb, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ dst_dir, bun_base }), io, .{});
        }
    }

    if (skip_precompile or link_source != null) {
        log("==> skipping JIR precompile; modules compile on first run", .{});
    } else {
        try precompile(io, gpa, a, parent_env, py, pbs_py_dir, site);
    }

    log("==> bundling pytest + pytest-xdist (jac test) + watchdog (jac start --dev)", .{});
    Dir.cwd().deleteTree(io, try std.fmt.allocPrint(a, "{s}/__pycache__", .{site})) catch {};
    _ = runChild(io, &.{ py, "-m", "pip", "install", "--quiet", "pytest", "pytest-xdist", "watchdog>=3.0.0", "tomlkit", "--target", site }, null, false);

    try stageTree(io, gpa, a, pbs_py_dir, site, stage);

    log("==> packing tar | gzip", .{});
    try tarGzDir(io, gpa, a, stage, out);
    log("==> payload: {s}", .{out});
}

fn resolvePython(io: Io, a: Allocator, pbs_py_dir: []const u8) ![]const u8 {
    const p1 = try std.fmt.allocPrint(a, "{s}/install/bin/python{s}", .{ pbs_py_dir, py_ver });
    if (fileExists(io, p1)) return p1;
    const p2 = try std.fmt.allocPrint(a, "{s}/install/bin/python3", .{pbs_py_dir});
    if (fileExists(io, p2)) return p2;
    die("mkpayload: no python at {s}/install/bin", .{pbs_py_dir});
}

fn precompile(io: Io, gpa: Allocator, a: Allocator, parent_env: *std.process.Environ.Map, py: []const u8, pbs_py_dir: []const u8, site: []const u8) !void {
    const pc = try std.fmt.allocPrint(a, "{s}/jaclang/utils/precompile_bytecode.jac", .{site});
    if (!fileExists(io, pc)) return;
    log("==> precompiling jaclang -> _precompiled JIR (fast first run)", .{});

    const boot = try std.fmt.allocPrint(a, "{s}/precompile_boot.py", .{site});
    try Dir.cwd().writeFile(io, .{
        .sub_path = boot,
        .data = try std.fmt.allocPrint(a,
            \\import sys
            \\import _jac_finder; _jac_finder.install()
            \\sys.argv = ['jac', 'run', r'''{s}''', r'''{s}''']
            \\from jaclang.jac0core.cli_boot import start_cli
            \\start_cli()
            \\
        , .{ pc, site }),
    });

    var env = try cloneEnv(gpa, parent_env);
    defer env.deinit();
    try env.put("PYTHONHOME", try std.fmt.allocPrint(a, "{s}/install", .{pbs_py_dir}));
    try env.put("PYTHONPATH", site);
    try env.put("PYTHONUTF8", "1");
    try env.put("PYTHONDONTWRITEBYTECODE", "1");
    try env.put("HOME", site);
    try env.put("PATH", "/usr/bin:/bin");

    _ = runChild(io, &.{ py, "-S", boot }, &env, true);

    const jir = countJir(io, gpa, try std.fmt.allocPrint(a, "{s}/jaclang/_precompiled", .{site}));
    if (jir >= 300) {
        log("   _precompiled: {d} JIR generated (a few core modules compile at runtime by design)", .{jir});
    } else {
        die("mkpayload: only {d} JIR produced (expected >=300); precompiler likely crashed.", .{jir});
    }
}

fn countJir(io: Io, gpa: Allocator, dir_path: []const u8) usize {
    var dir = Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close(io);
    var walker = dir.walk(gpa) catch return 0;
    defer walker.deinit();
    var count: usize = 0;
    while (walker.next(io) catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".jir")) count += 1;
    }
    return count;
}

fn stageTree(io: Io, gpa: Allocator, a: Allocator, pbs_py_dir: []const u8, site: []const u8, stage: []const u8) !void {
    log("==> staging runtime tree (shared libpython + stdlib + site)", .{});
    const lib_dst = try std.fmt.allocPrint(a, "{s}/python/lib", .{stage});
    try Dir.cwd().createDirPath(io, lib_dst);

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
    stripBestEffort(io, staged_lib);

    {
        const stdlib_dst = try std.fmt.allocPrint(a, "{s}/python{s}", .{ lib_dst, py_ver });
        var stdlib_src = try Dir.cwd().openDir(io, try std.fmt.allocPrint(a, "{s}/python{s}", .{ pbs_lib, py_ver }), .{ .iterate = true });
        defer stdlib_src.close(io);
        try copyTree(io, gpa, a, stdlib_src, stdlib_dst, skipNone);

        for ([_][]const u8{ "test", "idlelib", "turtledemo", "tkinter", "lib2to3" }) |d| {
            Dir.cwd().deleteTree(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ stdlib_dst, d })) catch {};
        }
        var sd = try Dir.cwd().openDir(io, stdlib_dst, .{ .iterate = true });
        defer sd.close(io);
        var dit = sd.iterate();
        while (dit.next(io) catch null) |e| {
            if (e.kind == .directory and std.mem.startsWith(u8, e.name, "config-")) {
                Dir.cwd().deleteTree(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ stdlib_dst, e.name })) catch {};
            }
        }
    }

    {
        var site_src = try Dir.cwd().openDir(io, site, .{ .iterate = true });
        defer site_src.close(io);
        try copyTree(io, gpa, a, site_src, try std.fmt.allocPrint(a, "{s}/site", .{stage}), skipStageSite);
    }
    stripBestEffort(io, try std.fmt.allocPrint(a, "{s}/site/jaclang/compiler/passes/native/llvm/{s}", .{ stage, shimFileName() }));

    try stageFloor(io, gpa, a, pbs_py_dir, stage);
}

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

fn stageFloor(io: Io, gpa: Allocator, a: Allocator, pbs_py_dir: []const u8, stage: []const u8) !void {
    const osarch = hostOsArch();
    const floor_dst = try std.fmt.allocPrint(a, "{s}/python/floor/{s}", .{ stage, osarch });
    try Dir.cwd().createDirPath(io, floor_dst);
    const src_lib = try std.fmt.allocPrint(a, "{s}/build/lib", .{pbs_py_dir});

    const FLOOR = [_][]const u8{
        "libssl.a", "libcrypto.a", "libsqlite3.a", "libmpdec.a", "liblzma.a",
        "libbz2.a", "libexpat.a",  "libz.a",       "libzstd.a",
    };
    var staged: usize = 0;
    for (FLOOR) |name| {
        const src = try std.fmt.allocPrint(a, "{s}/{s}", .{ src_lib, name });
        if (!fileExists(io, src)) continue;
        try Dir.cwd().copyFile(src, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/{s}", .{ floor_dst, name }), io, .{});
        staged += 1;
    }
    log("==> staged {d} C-floor archive(s) -> python/floor/{s}", .{ staged, osarch });

    if (try findCaBundle(io, gpa, a, pbs_py_dir)) |ca| {
        try Dir.cwd().copyFile(ca, Dir.cwd(), try std.fmt.allocPrint(a, "{s}/python/floor/cacert.pem", .{stage}), io, .{});
        log("==> staged CA bundle -> python/floor/cacert.pem", .{});
    } else {
        log("   no CA bundle found under pbs site-packages; ssl floor will fall back to a system bundle", .{});
    }
}

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

fn shimFileName() []const u8 {
    return switch (builtin.os.tag) {
        .windows => "jacllvm.dll",
        .macos => "libjacllvm.dylib",
        else => "libjacllvm.so",
    };
}

fn stripBestEffort(io: Io, path: []const u8) void {
    const before = fileSizeOrZero(io, path);
    if (before == 0) return;
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

fn findLibpython(io: Io, a: Allocator, lib_dir: []const u8) !FoundLib {
    const so = "libpython" ++ py_ver ++ ".so";
    const dy = "libpython" ++ py_ver ++ ".dylib";
    if (fileExists(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ lib_dir, so }))) return .{ .src = so, .bare = so };
    if (fileExists(io, try std.fmt.allocPrint(a, "{s}/{s}", .{ lib_dir, dy }))) return .{ .src = dy, .bare = dy };
    var dir = try Dir.cwd().openDir(io, lib_dir, .{ .iterate = true });
    defer dir.close(io);
    var dit = dir.iterate();
    while (dit.next(io) catch null) |e| {
        if (std.mem.startsWith(u8, e.name, so)) return .{ .src = try a.dupe(u8, e.name), .bare = so };
        if (std.mem.startsWith(u8, e.name, dy)) return .{ .src = try a.dupe(u8, e.name), .bare = dy };
    }
    die("mkpayload: shared libpython not found under {s}", .{lib_dir});
}

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

fn sha256Hex(bytes: []const u8) [64]u8 {
    var d: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &d, .{});
    return runtime.hexDigest(&d);
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

fn copyInto(io: Io, a: Allocator, repo_root: []const u8, name: []const u8, dst: []const u8) !void {
    try Dir.cwd().copyFile(
        try std.fmt.allocPrint(a, "{s}/{s}", .{ repo_root, name }),
        Dir.cwd(),
        try std.fmt.allocPrint(a, "{s}/{s}", .{ dst, name }),
        io,
        .{},
    );
}

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
        std.mem.indexOf(u8, p, "libjacllvm.") != null or
        std.mem.indexOf(u8, p, "libjacpyembed.") != null or
        std.mem.indexOf(u8, p, "jacpyembed.dll") != null or
        std.mem.indexOf(u8, p, "client/_bun") != null or
        std.mem.endsWith(u8, p, ".pyc");
}

fn skipStageSite(p: []const u8) bool {
    const base = std.fs.path.basename(p);
    return std.mem.startsWith(u8, base, "._") or std.mem.eql(u8, base, ".DS_Store");
}

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
    try testing.expect(!fileExists(io, exp(a, stage, try std.fmt.allocPrint(a, "{s}/libX11.a", .{osarch}))));
}
