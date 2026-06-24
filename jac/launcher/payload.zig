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
const Io = std.Io;
const Allocator = std.mem.Allocator;
const flate = std.compress.flate;
const zstd = std.compress.zstd;
const Dir = Io.Dir;
const runtime = @import("runtime.zig");

// --- pinned versions (keep in lockstep with launcher.zig `py_ver`) -----------
const py_ver = "3.14";
const PBS_TAG = "20260610";
const PBS_PY = "3.14.6";
const PBS_FLAVOR = "pgo+lto-full";
const PBS_BASE = "https://github.com/astral-sh/python-build-standalone/releases/download";
// The window pbs compresses its archives with (verified: `zstd -lv` reports
// 128 MiB). `fetch-pbs.sh` passed `zstd -d --long=31` only as a permissive cap;
// the real window is 128 MiB, so that is all the decode buffer we allocate.
const PBS_WINDOW = 1 << 27; // 128 MiB

const TYPESHED_TARBALL_BASE = "https://codeload.github.com/python/typeshed/tar.gz";
const TYPESHED_VENDOR = "jaclang/vendor/typeshed";

const MAX_PATH = Dir.max_path_bytes;

const Cmd = enum { @"fetch-pbs", @"fetch-typeshed", mkpayload, @"typeshed-sha" };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var argv: [8][]const u8 = undefined;
    var n: usize = 0;
    var it = init.minimal.args.iterate();
    while (it.next()) |a| : (n += 1) {
        if (n < argv.len) argv[n] = a;
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
        .@"fetch-typeshed" => {
            if (n < 3) die("usage: payload fetch-typeshed <repo-root>", .{});
            try fetchTypeshed(io, gpa, a, argv[2]);
        },
        .mkpayload => {
            if (n < 5) die("usage: payload mkpayload <pbs-python-dir> <repo-root> <out.tar.gz>", .{});
            try mkPayload(io, gpa, a, init.environ_map, argv[2], argv[3], argv[4]);
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
    {
        var jac_src = try Dir.cwd().openDir(io, try std.fmt.allocPrint(a, "{s}/jaclang", .{repo_root}), .{ .iterate = true });
        defer jac_src.close(io);
        try copyTree(io, gpa, a, jac_src, try std.fmt.allocPrint(a, "{s}/jaclang", .{site}), skipJaclang);
    }
    try copyInto(io, a, repo_root, "_jac_finder.py", site);
    try copyInto(io, a, repo_root, "sitecustomize.py", site);

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

    // The sole runtime dependency (a binary wheel from PyPI). Pin to jac.toml's
    // declared constraint so a breaking llvmlite release can't get baked in.
    const llvmlite = tomlDepSpec(toml, "llvmlite") orelse "llvmlite>=0.43.0";
    log("==> fetching runtime dep: {s}", .{llvmlite});
    _ = runChild(io, &.{ py, "-m", "pip", "install", "--quiet", llvmlite, "--target", site }, null, false);

    try precompile(io, gpa, a, parent_env, py, pbs_py_dir, site);

    // Bundle runtime helpers (pytest/-xdist -> `jac test`, watchdog -> `jac start
    // --dev`, tomlkit -> project tooling). Installed AFTER precompile so the
    // precompiler's package walk only sees jaclang. Drop stray bytecode first so
    // pip doesn't refuse the populated --target dir.
    log("==> bundling pytest + pytest-xdist (jac test) + watchdog (jac start --dev)", .{});
    Dir.cwd().deleteTree(io, try std.fmt.allocPrint(a, "{s}/__pycache__", .{site})) catch {};
    _ = runChild(io, &.{ py, "-m", "pip", "install", "--quiet", "pytest", "pytest-xdist", "watchdog>=3.0.0", "tomlkit", "--target", site }, null, false);

    try stageTree(io, gpa, a, pbs_py_dir, site, stage);

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
/// success is judged by the JIR count, not the exit code.
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

    _ = runChild(io, &.{ py, "-S", boot }, &env, true); // non-zero exit is by design

    const jir = countJir(io, gpa, try std.fmt.allocPrint(a, "{s}/jaclang/_precompiled", .{site}));
    if (jir >= 300) {
        log("   _precompiled: {d} JIR generated (a few core modules compile at runtime by design)", .{jir});
    } else {
        // Below the healthy floor means the precompiler crashed, not the handful
        // of by-design skips. Fail rather than ship a slow cold-start binary.
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

/// Stage the runtime tree: shared libpython + stdlib + the assembled site.
fn stageTree(io: Io, gpa: Allocator, a: Allocator, pbs_py_dir: []const u8, site: []const u8, stage: []const u8) !void {
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
    // win. The exported dynamic symbols the launcher dlsym's (Py_Initialize,
    // Py_BytesMain, ...) live in .dynsym and are kept; only debug / local
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
    // llvmlite bundles libLLVM (~160 MiB); strip its shared lib too (best-effort).
    stripBestEffort(io, try std.fmt.allocPrint(a, "{s}/site/llvmlite/binding/libllvmlite.so", .{stage}));
}

/// Strip a shared library in place to shed debug info / local symbols / dead LTO
/// bitcode, keeping the exported .dynsym the launcher resolves. Best-effort: the
/// host `strip` (binutils, near-universal on Linux/macOS build hosts and CI) is
/// the one optional tool -- if it is absent the build still succeeds, shipping
/// the lib unstripped. Plain `strip` (no flags) preserves dynamic symbols for a
/// shared object, so no flag tuning is needed.
fn stripBestEffort(io: Io, path: []const u8) void {
    const before = fileSizeOrZero(io, path);
    if (before == 0) return; // not present (e.g. macOS .dylib name, or no llvmlite)
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

/// Extract a PEP 508 dep spec (e.g. `llvmlite>=0.47.0`) for `pkg` from a
/// `dependencies = ["..."]` line, terminated at the closing quote.
fn tomlDepSpec(toml: []const u8, pkg: []const u8) ?[]const u8 {
    const start = std.mem.indexOf(u8, toml, pkg) orelse return null;
    const tail = toml[start..];
    const end = std.mem.indexOfScalar(u8, tail, '"') orelse return null;
    return tail[0..end];
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
