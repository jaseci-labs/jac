//! Build the JacPython runtime before any Jac tooling can run. A JacPython
//! build runs on an earlier JacPython: the previous build's output, an
//! installed runtime, or the checksum-pinned bootstrap seed of
//! bootstrap/python/seed.json. Every other input is checked in or pinned.
const std = @import("std");
const native_inputs = @import("native_inputs.zig");
const build_jacpython = @import("build_jacpython.zig");
const builtin = @import("builtin");
const seed = @import("seed.zig");
const Io = std.Io;
const inputs = [_][]const u8{
    "bootstrap/build_python.zig",              "bootstrap/seed.zig",
    "bootstrap/python/sources.json",           "bootstrap/python/vendored.sh",
    "bootstrap/python/smoke.py",               "bootstrap/python/finalize.py",
    "bootstrap/python/jacpython-clinic.txt",   "bootstrap/build_jacpython.zig",
    "bootstrap/pyconfig.zig",                  "bootstrap/pyconfig_probes.zig",
    "bootstrap/python/layouts_check.c",        "bootstrap/python/features_check.c",
    "bootstrap/python/prepare_native.py",      "bootstrap/python/jacpython-modules.txt",
    "bootstrap/python/main.c",
};
// The trees a build reads file by file: the Python sources (the standard
// library, getpath.py, HACL* and the install templates) and the files the
// Jac generators write (the C API headers and opcode tables).
const vendored_sources = "bootstrap/python/src";
const generated_sources = "bootstrap/python/generated";
const input_trees = [_][]const u8{ vendored_sources, generated_sources };
// The Jac generators build_jacpython.zig runs with the host (the frozen
// modules, _PyRuntime, build-details.json), relative to the repository root,
// the Jac root's parent.
const generator_inputs = [_][]const u8{
    "scripts/jacpython/common.jac",
    "scripts/jacpython/gen_frozen.jac",
    "scripts/jacpython/gen_runtime_image.jac",
    "scripts/jacpython/gen_build_details.jac",
};
const Source = struct { url: []const u8, sha256: []const u8 };
// bootstrap/python/seed.json: the Python version the runtime implements and,
// per platform, the runtime a build starts from when it has no other.
const SeedPins = struct { python: []const u8, seeds: std.json.ArrayHashMap(Source) };

// The interpreter a JacPython build runs on: it runs the Jac compiler that
// lowers the runtime and the generators, and can hand the build its vendored
// libraries.
//   auto      the previous build's own output when it is complete and on the
//             pinned version, else the bootstrap seed (the default)
//   seed      always the bootstrap seed
//   <path>    an installed runtime: its install prefix (.../python/install) or
//             the build output holding it
const host_flag = "--jacpython-host=";
const HostChoice = union(enum) { auto, seed, installed: []const u8 };

fn parseHostChoice(text: []const u8) HostChoice {
    if (text.len == 0 or std.mem.eql(u8, text, "auto")) return .auto;
    if (std.mem.eql(u8, text, "seed")) return .seed;
    return .{ .installed = text };
}

// What a build output carries forward so that the next build can run on it:
// the interpreter, and the vendored libraries' archives, headers, notices and
// CA bundle, with the key they were built under (vendoredKey).
const vendored_record = "python/build/vendored-key";
const host_parts = [_][]const u8{
    "python/install/bin/python3.14", "python/build/include", "python/build/lib",
    "python/build/cacert.pem",       "python/licenses",      vendored_record,
};

fn pathExists(io: Io, path: []const u8) bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

// The build output holding `path`: `path` itself, or the output whose install
// prefix it is. Null when either lacks a part the build reads.
fn hostTree(io: Io, a: std.mem.Allocator, path: []const u8) !?[]const u8 {
    var candidates: [2]?[]const u8 = .{ path, null };
    if (std.fs.path.dirname(path)) |python| candidates[1] = std.fs.path.dirname(python);
    for (candidates) |candidate| {
        const tree = candidate orelse continue;
        const complete = for (host_parts) |part| {
            if (!pathExists(io, try std.fs.path.join(a, &.{ tree, part }))) break false;
        } else true;
        if (complete) return try Io.Dir.cwd().realPathFileAlloc(io, tree, a);
    }
    return null;
}

fn probeVersion(io: Io, a: std.mem.Allocator, python: []const u8) ![]const u8 {
    const run = try std.process.run(a, io, .{ .argv = &.{ python, "-I", "-c", "import sys; print('%d.%d.%d' % sys.version_info[:3])" } });
    if (run.term != .exited or run.term.exited != 0) return error.HostDoesNotRun;
    return std.mem.trim(u8, run.stdout, " \r\n");
}

fn vendoredMatches(io: Io, a: std.mem.Allocator, tree: []const u8, vendored: []const u8) !bool {
    const recorded = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ tree, vendored_record }), a, .limited(128)) catch return false;
    return std.mem.eql(u8, std.mem.trim(u8, recorded, " \r\n"), vendored);
}

// The runtime to run on, or null for the bootstrap seed.
fn selectHost(io: Io, a: std.mem.Allocator, choice: HostChoice, dest: []const u8, pin: []const u8, comptime probe: anytype) !?[]const u8 {
    switch (choice) {
        .seed => return null,
        .auto => {
            // Only a finished output (it has its stamp) on the pinned version.
            // One that no longer runs leaves the seed to build.
            if (!pathExists(io, try std.fs.path.join(a, &.{ dest, "build-key" }))) return null;
            const tree = try hostTree(io, a, dest) orelse return null;
            const version = probe(io, a, try std.fs.path.join(a, &.{ tree, host_parts[0] })) catch return null;
            if (!std.mem.eql(u8, version, pin)) return null;
            return tree;
        },
        .installed => |path| {
            const tree = try hostTree(io, a, path) orelse return error.IncompleteHostRuntime;
            const version = try probe(io, a, try std.fs.path.join(a, &.{ tree, host_parts[0] }));
            if (!std.mem.eql(u8, version, pin)) return error.HostVersionMismatch;
            return tree;
        },
    }
}

// Recorded in the output's build-host: which runtime built it.
fn hostIdentity(io: Io, a: std.mem.Allocator, tree: []const u8) ![]const u8 {
    const key = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ tree, "build-key" }), a, .limited(128)) catch "unstamped";
    const native = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ tree, "python/build/jacpython-native-sha256" }), a, .limited(128)) catch "none";
    return std.fmt.allocPrint(a, "{s} key={s} native={s}", .{ tree, std.mem.trim(u8, key, " \r\n"), std.mem.trim(u8, native, " \r\n") });
}

pub fn supported(platform: []const u8) bool {
    for ([_][]const u8{ "linux-x86_64", "linux-aarch64", "macos-x86_64", "macos-aarch64" }) |p| {
        if (std.mem.eql(u8, p, platform)) return true;
    }
    return false;
}

fn hostPlatform() []const u8 {
    return switch (builtin.os.tag) {
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => "linux-x86_64",
            .aarch64 => "linux-aarch64",
            else => "unsupported",
        },
        .macos => switch (builtin.cpu.arch) {
            .x86_64 => "macos-x86_64",
            .aarch64 => "macos-aarch64",
            else => "unsupported",
        },
        else => "unsupported",
    };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    var reuse = false;
    var choice: HostChoice = .auto;
    var args: std.ArrayList([]const u8) = .empty;
    for (try init.minimal.args.toSlice(a)) |arg| {
        if (std.mem.eql(u8, arg, "--reuse-lowered")) {
            reuse = true;
        } else if (std.mem.startsWith(u8, arg, host_flag)) {
            choice = parseHostChoice(arg[host_flag.len..]);
        } else try args.append(a, arg);
    }
    if (args.items.len != 5) seed.die("usage: build_python <os-arch> <destination> <jac-root> <zig> [--reuse-lowered] [" ++ host_flag ++ "auto|seed|<install prefix>]", .{});
    const platform = args.items[1];
    if (!supported(platform)) seed.die("build-python: unsupported platform {s}", .{platform});
    if (!std.mem.eql(u8, platform, hostPlatform()))
        seed.die("build-python: build {s} on its matching release runner (host is {s})", .{ platform, hostPlatform() });
    const dest = args.items[2];
    const root = args.items[3];
    const zig = args.items[4];
    const sources = try std.json.parseFromSliceLeaky(std.json.ArrayHashMap(Source), a, try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, "bootstrap/python/sources.json" }), a, .unlimited), .{});
    const pins = try std.json.parseFromSliceLeaky(SeedPins, a, try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, "bootstrap/python/seed.json" }), a, .unlimited), .{});
    const smoke = try std.fs.path.join(a, &.{ root, "bootstrap/python/smoke.py" });
    const key = try buildKey(io, a, platform, root);
    const vendored = try vendoredKey(io, a, platform, root);
    const stamp_path = try std.fs.path.join(a, &.{ dest, "build-key" });
    const old = Io.Dir.cwd().readFileAlloc(io, stamp_path, a, .limited(128)) catch "";
    const python = try std.fs.path.join(a, &.{ dest, "python/install/bin/python3.14" });
    if (std.mem.eql(u8, old, &key) and seed.fileExists(io, python)) {
        try runSmoke(io, python, smoke);
        seed.log("build-python: cached {s} ({s})", .{ platform, key[0..16] });
        return;
    }
    const sources_stamp = try std.fs.path.join(a, &.{ dest, "build-key-sources" });
    if (reuse and seed.fileExists(io, python)) {
        if (try sourcesKey(io, a, platform, root, dest)) |lowered| {
            const recorded = Io.Dir.cwd().readFileAlloc(io, sources_stamp, a, .limited(128)) catch "";
            if (std.mem.eql(u8, recorded, &lowered)) {
                try runSmoke(io, python, smoke);
                seed.log("build-python: reusing {s}; the sources it was lowered from are unchanged ({s})", .{ platform, lowered[0..16] });
                return;
            }
        }
    }
    // Something is built: choose the interpreter the build runs on.
    const cache_dir = try std.fs.path.join(a, &.{ root, ".python-build/sources" });
    const selected = selectHost(io, a, choice, dest, pins.python, probeVersion) catch |err|
        seed.die("build-python: cannot build on {s}: {s}. A host is a finished build output, or its install prefix, on Python {s} with python/install, python/build/{{include,lib,cacert.pem,vendored-key}} and python/licenses; " ++ host_flag ++ "seed builds on the bootstrap seed instead.", .{ switch (choice) {
            .installed => |path| path,
            else => dest,
        }, @errorName(err), pins.python });
    const host_tree = selected orelse host: {
        const pinned = pins.seeds.map.get(platform) orelse seed.die("build-python: bootstrap/python/seed.json pins no seed for {s}", .{platform});
        seed.log("build-python: building on the bootstrap seed {s}", .{pinned.sha256[0..16]});
        break :host try seedTree(io, init.gpa, a, cache_dir, try std.fmt.allocPrint(a, "{s}.seed", .{dest}), pinned, seed.httpGetAlloc);
    };
    if (selected != null) seed.log("build-python: building on the runtime at {s}", .{host_tree});
    const version = probeVersion(io, a, try std.fs.path.join(a, &.{ host_tree, host_parts[0] })) catch |err|
        seed.die("build-python: the host at {s} does not run: {s}", .{ host_tree, @errorName(err) });
    if (!std.mem.eql(u8, version, pins.python))
        seed.die("build-python: the host at {s} is Python {s}; seed.json pins {s}", .{ host_tree, version, pins.python });
    const provenance = try std.fmt.allocPrint(a, "{s} {s}\n", .{ if (selected == null) "seed" else "installed", try hostIdentity(io, a, host_tree) });

    const work = try std.fmt.allocPrint(a, "{s}.work", .{dest});
    // A failed build never produces the completion stamp or replaces a good tree.
    try Io.Dir.cwd().deleteTree(io, work);
    try Io.Dir.cwd().createDirPath(io, work);
    const recipe = try std.fs.path.join(a, &.{ root, "bootstrap/python" });

    // The vendored libraries come from the host when it built them under these
    // pins, else from their pinned sources.
    const vendored_tree = if (try vendoredMatches(io, a, host_tree, &vendored)) host_tree else libs: {
        const tree = try std.fs.path.join(a, &.{ work, "vendored" });
        for (sources.map.keys(), sources.map.values()) |name, source| {
            seed.log("build-python: source {s}", .{name});
            const gz = try sourceArchive(io, init.gpa, cache_dir, source, seed.httpGetAlloc);
            defer init.gpa.free(gz);
            try extractArchive(io, init.gpa, gz, try std.fs.path.join(a, &.{ tree, "src", name }), 1);
        }
        var child = try std.process.spawn(io, .{ .argv = &.{ "sh", try std.fs.path.join(a, &.{ recipe, "vendored.sh" }), platform, tree, zig } });
        const term = try child.wait(io);
        if (term != .exited or term.exited != 0) seed.die("build-python: vendored libraries failed; logs at {s}/logs", .{tree});
        break :libs tree;
    };

    const python_src = try std.fs.path.join(a, &.{ work, "src/python" });
    try stageSources(io, a, root, python_src);
    build_jacpython.build(io, a, .{
        .platform = platform,
        .work = work,
        .zig = zig,
        .recipe = recipe,
        .host = host_tree,
        .vendored = vendored_tree,
        .root = root,
        .jobs = try jobCount(init.environ_map),
        .environ = init.environ_map,
    }) catch |err| {
        // A runtime that builds the next one can carry its own defect into
        // the build; the seed rules that out.
        if (selected != null)
            seed.log("build-python: this build ran on the runtime at {s}; if that runtime is at fault, " ++ host_flag ++ "seed (zig build -Djacpython-host=seed) builds on the bootstrap seed", .{host_tree});
        seed.die("build-python: build failed ({s}); logs at {s}/logs", .{ @errorName(err), work });
    };
    // Cache only the runtime and link archives, not intermediate objects or sources.
    for ([_][]const u8{ "src", "deps", "vendored" }) |transient| {
        try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, transient }));
    }
    // The host built the vendored libraries under this key, or this build did.
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ work, vendored_record }), .data = &vendored });
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ work, "build-host" }), .data = provenance });
    try Io.Dir.cwd().deleteTree(io, dest);
    try Io.Dir.cwd().rename(work, Io.Dir.cwd(), dest, io);
    // Verify relocation before allowing a cache hit on the next invocation.
    try runSmoke(io, python, smoke);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = stamp_path, .data = &key });
    if (try sourcesKey(io, a, platform, root, dest)) |lowered| {
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = sources_stamp, .data = &lowered });
    }
}

/// JAC_PYTHON_JOBS: how many compilers run at once (default 4).
fn jobCount(environ: *const std.process.Environ.Map) !usize {
    const text = environ.get("JAC_PYTHON_JOBS") orelse return 4;
    const jobs = std.fmt.parseInt(usize, text, 10) catch return error.InvalidJobCount;
    if (jobs == 0) return error.InvalidJobCount;
    return jobs;
}

// Pinned archives (the seeds and the vendored libraries' sources) live outside
// the disposable work trees, and their digest is rechecked on every use.
fn sourceArchive(io: Io, a: std.mem.Allocator, cache_dir: []const u8, source: Source, comptime fetch: anytype) ![]u8 {
    const path = try std.fmt.allocPrint(a, "{s}/{s}.tar.gz", .{ cache_dir, source.sha256 });
    defer a.free(path);
    const cached = Io.Dir.cwd().readFileAlloc(io, path, a, .unlimited) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (cached) |bytes| {
        const digest = seed.sha256Hex(bytes);
        if (std.mem.eql(u8, &digest, source.sha256)) return bytes;
        a.free(bytes);
    }
    const bytes = try fetch(io, a, source.url);
    errdefer a.free(bytes);
    const digest = seed.sha256Hex(bytes);
    if (!std.mem.eql(u8, &digest, source.sha256)) return error.SourceChecksumMismatch;
    var file = try Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, bytes);
    try file.replace(io);
    return bytes;
}

fn extractArchive(io: Io, gpa: std.mem.Allocator, gz: []const u8, target: []const u8, strip: u32) !void {
    try Io.Dir.cwd().createDirPath(io, target);
    var dir = try Io.Dir.cwd().openDir(io, target, .{ .iterate = true });
    defer dir.close(io);
    const window = try gpa.alloc(u8, std.compress.flate.max_window_len);
    defer gpa.free(window);
    var reader = Io.Reader.fixed(gz);
    var decompressor: std.compress.flate.Decompress = .init(&reader, .gzip, window);
    try std.tar.extract(io, dir, &decompressor.reader, .{
        .mode_mode = .executable_bit_only,
        .strip_components = strip,
    });
}

// The bootstrap seed, extracted once per pin next to the build output. The
// stamp names the archive it came from; a partial extraction has none.
fn seedTree(io: Io, gpa: std.mem.Allocator, a: std.mem.Allocator, cache_dir: []const u8, target: []const u8, source: Source, comptime fetch: anytype) ![]const u8 {
    const stamp = try std.fs.path.join(a, &.{ target, "seed-sha256" });
    const recorded = Io.Dir.cwd().readFileAlloc(io, stamp, a, .limited(128)) catch "";
    if (std.mem.eql(u8, recorded, source.sha256)) {
        if (try hostTree(io, a, target)) |tree| return tree;
    }
    const gz = try sourceArchive(io, gpa, cache_dir, source, fetch);
    defer gpa.free(gz);
    try Io.Dir.cwd().deleteTree(io, target);
    try extractArchive(io, gpa, gz, target, 0);
    const tree = try hostTree(io, a, target) orelse return error.IncompleteSeed;
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = stamp, .data = source.sha256 });
    return tree;
}

// Every regular file under `rel` (relative to `root`), sorted, so a hash over
// them does not depend on directory order.
fn treeFiles(io: Io, a: std.mem.Allocator, root: []const u8, rel: []const u8) ![]const []const u8 {
    var dir = try Io.Dir.cwd().openDir(io, try std.fs.path.join(a, &.{ root, rel }), .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(a);
    defer walker.deinit();
    var paths: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |entry| {
        if (entry.kind == .file) try paths.append(a, try a.dupe(u8, entry.path));
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn less(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.less);
    return paths.items;
}

// The tree build_jacpython.zig compiles in: the vendored Python sources, with
// each generated file staged at its path (bootstrap/python/generated/<path>.in).
// A generated path must not shadow a vendored one, and the C API headers are
// only ever generated.
fn stageSources(io: Io, a: std.mem.Allocator, root: []const u8, target: []const u8) !void {
    for (try treeFiles(io, a, root, vendored_sources)) |rel| {
        if (std.mem.startsWith(u8, rel, "Include/")) {
            seed.log("build-python: {s}/{s}: Include/ headers are generated", .{ vendored_sources, rel });
            return error.VendoredHeader;
        }
        const dest = try std.fs.path.join(a, &.{ target, rel });
        try Io.Dir.copyFile(.cwd(), try std.fs.path.join(a, &.{ root, vendored_sources, rel }), .cwd(), dest, io, .{ .make_path = true });
    }
    for (try treeFiles(io, a, root, generated_sources)) |rel| {
        if (!std.mem.endsWith(u8, rel, ".in")) return error.UnexpectedGeneratedFile;
        const dest = try std.fs.path.join(a, &.{ target, rel[0 .. rel.len - ".in".len] });
        if (pathExists(io, dest)) {
            seed.log("build-python: {s}/{s} shadows a vendored source", .{ generated_sources, rel });
            return error.GeneratedShadowsSource;
        }
        try Io.Dir.copyFile(.cwd(), try std.fs.path.join(a, &.{ root, generated_sources, rel }), .cwd(), dest, io, .{ .make_path = true });
    }
}

// The interpreter a build runs on is not part of its key, or a runtime that
// builds the next one would never be reused: the next build runs on it and
// would key differently. Any host lowers the same sources to the same native
// code; what it hands the build that can differ is the frozen modules'
// bytecode, which each compiles with its own compiler (build-host records
// which one did). The inputs are hashed instead: the recipe, which pins the
// vendored libraries' sources, the Python sources, and the compiler.
fn buildKey(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    try hashRecipe(io, a, platform, root, &hash);
    try hashCompilerTree(io, a, root, &hash);
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

// A PR build may reuse the runtime main last built when the sources JacPython
// was lowered from are unchanged, even though the compiler that lowered them
// has moved on. The key is the same recipe and the recorded sources (paths and
// contents) in place of the whole compiler tree. Main keeps
// the full key, so a runtime is never more than one main build behind.
fn sourcesKey(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8, dest: []const u8) !?[64]u8 {
    const record_path = try std.fs.path.join(a, &.{ dest, "python/build/jacpython-native-sources" });
    const record = Io.Dir.cwd().readFileAlloc(io, record_path, a, .limited(4 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    try hashRecipe(io, a, platform, root, &hash);
    hash.update("lowered-sources");
    var lines = std.mem.splitScalar(u8, record, '\n');
    var count: usize = 0;
    while (lines.next()) |raw| {
        const rel = std.mem.trim(u8, raw, " \r\t");
        if (rel.len == 0) continue;
        count += 1;
        hash.update(rel);
        const content = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, rel }), a, .unlimited) catch |err| switch (err) {
            error.FileNotFound => {
                hash.update("\x00missing");
                continue;
            },
            else => return err,
        };
        hash.update(content);
    }
    if (count == 0) return null;
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

/// The target and the toolchain every C translation uses.
fn hashToolchain(io: Io, a: std.mem.Allocator, platform: []const u8, hash: *std.crypto.hash.sha2.Sha256) !void {
    hash.update(platform);
    hash.update(builtin.zig_version_string);
    if (builtin.os.tag == .macos) {
        const sdk = try std.process.run(a, io, .{ .argv = &.{ "xcrun", "--sdk", "macosx", "--show-sdk-version" } });
        if (sdk.term != .exited or sdk.term.exited != 0) return error.MissingMacOSSDK;
        hash.update(std.mem.trim(u8, sdk.stdout, " \r\n"));
    }
}

/// What the vendored libraries' archives, headers, notices and CA bundle are
/// built from: their pins and vendored.sh. Every output records it; a runtime
/// whose record differs cannot hand its libraries to the next build.
fn vendoredKey(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    try hashToolchain(io, a, platform, &hash);
    for ([_][]const u8{ "bootstrap/python/sources.json", "bootstrap/python/vendored.sh" }) |path| {
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, path }), a, .unlimited));
    }
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn hashRecipe(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8, hash: *std.crypto.hash.sha2.Sha256) !void {
    try hashToolchain(io, a, platform, hash);
    for (inputs) |path| {
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, path }), a, .unlimited));
    }
    for (input_trees) |tree| {
        for (try treeFiles(io, a, root, tree)) |rel| {
            const path = try std.fs.path.join(a, &.{ tree, rel });
            hash.update(path);
            hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, path }), a, .unlimited));
        }
    }
    for (generator_inputs) |path| {
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, "..", path }), a, .unlimited));
    }
    // Rebuild the native replacement when the producing compiler or its
    // source inputs change; never reuse an object from another generation.
    for ([_][]const u8{ "jaclang/vendor/typeshed/PIN", "jaclang/vendor/typeshed/TARBALL_SHA256" }) |path| {
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, path }), a, .limited(1024)));
    }
    // prepare_native emits through the LLVM shim. Prefix-restored runtime
    // trees must reject changes to that toolchain even when Jac is unchanged.
    try native_inputs.hashShimInputs(io, a, root, hash);
}

fn hashCompilerTree(io: Io, a: std.mem.Allocator, root: []const u8, hash: *std.crypto.hash.sha2.Sha256) !void {
    const package_path = try std.fs.path.join(a, &.{ root, "jaclang" });
    var package = try Io.Dir.cwd().openDir(io, package_path, .{ .iterate = true });
    defer package.close(io);
    const compiler_inputs = try package.readFileAlloc(io, "compiler_inputs.txt", a, .limited(16 * 1024));
    hash.update("compiler_inputs.txt");
    hash.update(compiler_inputs);
    var walker = try package.walkSelectively(a);
    defer walker.deinit();
    var paths: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory) {
            if (!std.mem.startsWith(u8, entry.basename, ".") and
                !std.mem.eql(u8, entry.basename, "node_modules") and
                !std.mem.eql(u8, entry.basename, "__pycache__") and
                !std.mem.eql(u8, entry.basename, "tests") and
                !std.mem.eql(u8, entry.basename, "test") and
                !std.mem.eql(u8, entry.basename, "vendor")) try walker.enter(io, entry);
        } else if (entry.kind == .file and (std.mem.endsWith(u8, entry.path, ".jac") or std.mem.endsWith(u8, entry.path, ".py"))) {
            if (compilerInput(compiler_inputs, entry.path)) try paths.append(a, try a.dupe(u8, entry.path));
        }
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn less(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.less);
    for (paths.items) |path| {
        hash.update(path);
        hash.update(try package.readFileAlloc(io, path, a, .unlimited));
    }
}

// Same source boundary as jir.compiler_source_files. A change to an app,
// example, or test cannot change the compiler object produced by prepare_native.
fn compilerInput(manifest: []const u8, path: []const u8) bool {
    if (std.mem.indexOf(u8, path, ".test.") != null) return false;
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |raw| {
        const entry = std.mem.trim(u8, raw, " \r\t");
        if (entry.len == 0 or entry[0] == '#') continue;
        if (std.mem.eql(u8, path, entry) or
            (std.mem.startsWith(u8, path, entry) and path.len > entry.len and path[entry.len] == '/')) return true;
    }
    return false;
}

fn runSmoke(io: Io, python: []const u8, smoke: []const u8) !void {
    var check = try std.process.spawn(io, .{ .argv = &.{ python, "-X", "faulthandler", "-I", smoke } });
    const result = try check.wait(io);
    if (result != .exited or result.exited != 0) {
        return error.RelocationFailed;
    }
}

test {
    // The JacPython builder's and pyconfig.h probes' own tests.
    _ = build_jacpython;
}

test "only release targets are accepted" {
    try std.testing.expect(supported("linux-x86_64"));
    try std.testing.expect(supported("macos-aarch64"));
    try std.testing.expect(!supported("windows-x86_64"));
}

// A Jac root holding every file the build key reads.
fn fakeRoot(io: Io, a: std.mem.Allocator, tmp: *std.testing.TmpDir) !struct { dir: Io.Dir, root: []const u8 } {
    for (generator_inputs) |path| {
        try tmp.dir.createDirPath(io, std.fs.path.dirname(path).?);
        try tmp.dir.writeFile(io, .{ .sub_path = path, .data = "generator" });
    }
    try tmp.dir.createDirPath(io, "jac");
    var dir = try tmp.dir.openDir(io, "jac", .{});
    for (inputs) |path| {
        if (std.fs.path.dirname(path)) |parent| try dir.createDirPath(io, parent);
        try dir.writeFile(io, .{ .sub_path = path, .data = "recipe" });
    }
    try dir.createDirPath(io, vendored_sources ++ "/Lib");
    try dir.writeFile(io, .{ .sub_path = vendored_sources ++ "/Lib/os.py", .data = "stdlib" });
    try dir.createDirPath(io, generated_sources ++ "/Include");
    try dir.writeFile(io, .{ .sub_path = generated_sources ++ "/Include/Python.h.in", .data = "header" });
    for (native_inputs.toolchain_inputs) |path| {
        try dir.writeFile(io, .{ .sub_path = path, .data = "toolchain" });
    }
    try dir.createDirPath(io, "native");
    try dir.createDirPath(io, "jaclang/vendor/typeshed");
    for ([_][]const u8{ "PIN", "TARBALL_SHA256" }) |name| {
        try dir.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ "jaclang/vendor/typeshed", name }), .data = "pin" });
    }
    return .{ .dir = dir, .root = try dir.realPathFileAlloc(io, ".", a) };
}

test "the runtime key follows the recipe, the Python sources and the compiler, not the host" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const fake = try fakeRoot(io, a, &tmp);
    var dir = fake.dir;
    defer dir.close(io);
    const root = fake.root;
    try dir.createDirPath(io, "host");
    try dir.writeFile(io, .{ .sub_path = "host/build-key", .data = "host-key" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "compiler" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler_inputs.txt", .data = "compiler.jac\ncompiler\nruntime\n" });
    const before = try buildKey(io, a, hostPlatform(), root);
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "changed compiler" });
    const changed = try buildKey(io, a, hostPlatform(), root);
    try std.testing.expect(!std.mem.eql(u8, &before, &changed));
    try dir.writeFile(io, .{ .sub_path = "jaclang/vendor/generated.py", .data = "materialized vendor data" });
    try std.testing.expectEqual(changed, try buildKey(io, a, hostPlatform(), root));
    try dir.writeFile(io, .{ .sub_path = "native/shim.cpp", .data = "changed emitter" });
    try std.testing.expect(!std.mem.eql(u8, &changed, &(try buildKey(io, a, hostPlatform(), root))));
    try dir.deleteFile(io, "native/shim.cpp");
    for ([_][]const u8{ "scale/server.jac", "compiler/tests/example.jac", "compiler/example.test.jac", "runtime/test/fixture.py", "compiler/.generated/source.py" }) |rel| {
        const path = try std.fs.path.join(a, &.{ "jaclang", rel });
        try dir.createDirPath(io, std.fs.path.dirname(path).?);
        try dir.writeFile(io, .{ .sub_path = path, .data = "unrelated source" });
        try std.testing.expectEqual(changed, try buildKey(io, a, hostPlatform(), root));
    }
    try dir.createDirPath(io, "jaclang/runtime/python");
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "new runtime input" });
    try std.testing.expect(!std.mem.eql(u8, &changed, &(try buildKey(io, a, hostPlatform(), root))));
    try dir.deleteFile(io, "jaclang/runtime/python/eval.jac");
    try std.testing.expectEqual(changed, try buildKey(io, a, hostPlatform(), root));
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/prepare_native.py", .data = "changed native emitter" });
    const before_generator = try buildKey(io, a, hostPlatform(), root);
    try std.testing.expect(!std.mem.eql(u8, &changed, &before_generator));
    try tmp.dir.writeFile(io, .{ .sub_path = "scripts/jacpython/gen_frozen.jac", .data = "changed generator" });
    const before_sources = try buildKey(io, a, hostPlatform(), root);
    try std.testing.expect(!std.mem.eql(u8, &before_generator, &before_sources));
    // A vendored or a generated Python source.
    try dir.writeFile(io, .{ .sub_path = vendored_sources ++ "/Lib/os.py", .data = "patched stdlib" });
    const patched = try buildKey(io, a, hostPlatform(), root);
    try std.testing.expect(!std.mem.eql(u8, &before_sources, &patched));
    try dir.writeFile(io, .{ .sub_path = generated_sources ++ "/Include/Python.h.in", .data = "regenerated" });
    try std.testing.expect(!std.mem.eql(u8, &patched, &(try buildKey(io, a, hostPlatform(), root))));
    // The interpreter that runs the build is not an input: a rebuilt host, or
    // an installed runtime in its place, keeps the key.
    const before_host = try buildKey(io, a, hostPlatform(), root);
    try dir.writeFile(io, .{ .sub_path = "host/build-key", .data = "rebuilt host" });
    try std.testing.expectEqual(before_host, try buildKey(io, a, hostPlatform(), root));
}

test "a PR may reuse a runtime whose recorded lowered sources are unchanged" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const fake = try fakeRoot(io, a, &tmp);
    var dir = fake.dir;
    defer dir.close(io);
    const root = fake.root;
    try dir.createDirPath(io, "jaclang/runtime/python");
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "compiler" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "lowered" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler_inputs.txt", .data = "compiler.jac\nruntime\n" });
    const built = try std.fs.path.join(a, &.{ root, "built" });

    // No record: nothing to reuse.
    try std.testing.expect((try sourcesKey(io, a, hostPlatform(), root, built)) == null);
    try dir.createDirPath(io, "built/python/build");
    try dir.writeFile(io, .{ .sub_path = "built/python/build/jacpython-native-sources", .data = "jaclang/runtime/python/eval.jac\n" });
    const lowered = (try sourcesKey(io, a, hostPlatform(), root, built)).?;
    // A compiler edit outside what the runtime was lowered from keeps it...
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "changed compiler" });
    try std.testing.expectEqual(lowered, (try sourcesKey(io, a, hostPlatform(), root, built)).?);
    // ...while the full key, which main uses, still moves.
    try std.testing.expect(!std.mem.eql(u8, &lowered, &(try buildKey(io, a, hostPlatform(), root))));
    // An edit to a recorded source does not reuse it.
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "edited" });
    const edited = (try sourcesKey(io, a, hostPlatform(), root, built)).?;
    try std.testing.expect(!std.mem.eql(u8, &lowered, &edited));
    // Nor does a recipe or toolchain change.
    try dir.writeFile(io, .{ .sub_path = native_inputs.toolchain_inputs[0], .data = "new toolchain" });
    try std.testing.expect(!std.mem.eql(u8, &edited, &(try sourcesKey(io, a, hostPlatform(), root, built)).?));
}

test "pinned archives are cached and reject corrupt cached or fetched bytes" {
    const Fetch = struct {
        fn archive(_: Io, a: std.mem.Allocator, _: []const u8) ![]u8 {
            return a.dupe(u8, "pinned archive");
        }
        fn forbidden(_: Io, _: std.mem.Allocator, _: []const u8) anyerror![]u8 {
            return error.UnexpectedFetch;
        }
    };
    const io = std.testing.io;
    const a = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(io, ".", a);
    defer a.free(root);
    const digest = seed.sha256Hex("pinned archive");
    const source = Source{ .url = "https://example.invalid/source.tgz", .sha256 = &digest };
    const first = try sourceArchive(io, a, root, source, Fetch.archive);
    defer a.free(first);
    const again = try sourceArchive(io, a, root, source, Fetch.forbidden);
    defer a.free(again);
    try std.testing.expectEqualStrings(first, again);
    const filename = try std.fmt.allocPrint(a, "{s}.tar.gz", .{digest});
    defer a.free(filename);
    try tmp.dir.writeFile(io, .{ .sub_path = filename, .data = "corrupt cache" });
    try std.testing.expectError(error.UnexpectedFetch, sourceArchive(io, a, root, source, Fetch.forbidden));
    const repaired = try sourceArchive(io, a, root, source, Fetch.archive);
    defer a.free(repaired);
    try std.testing.expectEqualStrings("pinned archive", repaired);
    const other_digest = seed.sha256Hex("different pin");
    const other = Source{ .url = source.url, .sha256 = &other_digest };
    try std.testing.expectError(error.SourceChecksumMismatch, sourceArchive(io, a, root, other, Fetch.archive));
}

test "the host choice names the previous output, the seed, or an installed runtime" {
    try std.testing.expectEqual(HostChoice.auto, parseHostChoice(""));
    try std.testing.expectEqual(HostChoice.auto, parseHostChoice("auto"));
    try std.testing.expectEqual(HostChoice.seed, parseHostChoice("seed"));
    try std.testing.expectEqualStrings("/opt/jacpython/python/install", parseHostChoice("/opt/jacpython/python/install").installed);
    _ = &main;
}

test "a build runs on the previous runtime when it can, else on the seed" {
    const Probe = struct {
        fn pinned(_: Io, _: std.mem.Allocator, _: []const u8) ![]const u8 {
            return "3.14.6";
        }
        fn older(_: Io, _: std.mem.Allocator, _: []const u8) ![]const u8 {
            return "3.14.5";
        }
        fn broken(_: Io, _: std.mem.Allocator, _: []const u8) ![]const u8 {
            return error.HostDoesNotRun;
        }
    };
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(io, ".", a);
    const out = try std.fs.path.join(a, &.{ base, "out" });
    const prefix = try std.fs.path.join(a, &.{ out, "python/install" });

    // Nothing built yet: only the seed can build.
    try std.testing.expectEqual(@as(?[]const u8, null), try selectHost(io, a, .auto, out, "3.14.6", Probe.pinned));
    try std.testing.expectError(error.IncompleteHostRuntime, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.pinned));

    // An output missing a part the build reads.
    for (host_parts) |part| {
        if (std.mem.eql(u8, part, "python/build/include")) continue;
        if (std.mem.endsWith(u8, part, "python3.14") or std.mem.endsWith(u8, part, ".pem") or std.mem.endsWith(u8, part, "-key")) {
            try tmp.dir.createDirPath(io, std.fs.path.dirname(try std.fs.path.join(a, &.{ "out", part })).?);
            try tmp.dir.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ "out", part }), .data = "pins" });
        } else try tmp.dir.createDirPath(io, try std.fs.path.join(a, &.{ "out", part }));
    }
    try tmp.dir.writeFile(io, .{ .sub_path = "out/build-key", .data = "key" });
    try std.testing.expectEqual(@as(?[]const u8, null), try selectHost(io, a, .auto, out, "3.14.6", Probe.pinned));
    try std.testing.expectError(error.IncompleteHostRuntime, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.pinned));

    try tmp.dir.createDirPath(io, "out/python/build/include");
    // The finished previous output, named by itself or by its install prefix.
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .auto, out, "3.14.6", Probe.pinned)).?);
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.pinned)).?);
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .{ .installed = out }, base, "3.14.6", Probe.pinned)).?);
    // seed always builds on the seed.
    try std.testing.expectEqual(@as(?[]const u8, null), try selectHost(io, a, .seed, out, "3.14.6", Probe.pinned));
    // A runtime on another version, or one that no longer runs: the default
    // falls back, a named host is an error.
    try std.testing.expectEqual(@as(?[]const u8, null), try selectHost(io, a, .auto, out, "3.14.6", Probe.older));
    try std.testing.expectEqual(@as(?[]const u8, null), try selectHost(io, a, .auto, out, "3.14.6", Probe.broken));
    try std.testing.expectError(error.HostVersionMismatch, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.older));
    try std.testing.expectError(error.HostDoesNotRun, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.broken));
    // Vendored libraries built under other pins do not disqualify a host:
    // the build rebuilds the libraries instead.
    try std.testing.expect(try vendoredMatches(io, a, out, "pins"));
    try std.testing.expect(!try vendoredMatches(io, a, out, "new pins"));
    // An unfinished output (no stamp) is never the default host.
    try tmp.dir.deleteFile(io, "out/build-key");
    try std.testing.expectEqual(@as(?[]const u8, null), try selectHost(io, a, .auto, out, "3.14.6", Probe.pinned));
}

test "the vendored libraries' key follows their pins and vendored.sh, not the runtime's inputs" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "bootstrap/python");
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = "pins" });
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/vendored.sh", .data = "recipe" });
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/smoke.py", .data = "checks" });
    const root = try tmp.dir.realPathFileAlloc(io, ".", a);
    const before = try vendoredKey(io, a, hostPlatform(), root);
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/smoke.py", .data = "changed checks" });
    try std.testing.expectEqual(before, try vendoredKey(io, a, hostPlatform(), root));
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = "new pins" });
    const pinned = try vendoredKey(io, a, hostPlatform(), root);
    try std.testing.expect(!std.mem.eql(u8, &before, &pinned));
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/vendored.sh", .data = "new recipe" });
    try std.testing.expect(!std.mem.eql(u8, &pinned, &(try vendoredKey(io, a, hostPlatform(), root))));
}

test "the build tree is the vendored sources with each generated file staged" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const fake = try fakeRoot(io, a, &tmp);
    var dir = fake.dir;
    defer dir.close(io);
    const root = fake.root;
    try dir.createDirPath(io, generated_sources ++ "/Lib");
    try dir.writeFile(io, .{ .sub_path = generated_sources ++ "/Lib/_opcode_metadata.py.in", .data = "from jac" });
    const target = try std.fs.path.join(a, &.{ root, "tree" });
    try stageSources(io, a, root, target);
    try std.testing.expectEqualStrings("stdlib", try dir.readFileAlloc(io, "tree/Lib/os.py", a, .unlimited));
    try std.testing.expectEqualStrings("header", try dir.readFileAlloc(io, "tree/Include/Python.h", a, .unlimited));
    try std.testing.expectEqualStrings("from jac", try dir.readFileAlloc(io, "tree/Lib/_opcode_metadata.py", a, .unlimited));
    // A generated file may not replace a vendored one.
    try dir.writeFile(io, .{ .sub_path = generated_sources ++ "/Lib/os.py.in", .data = "shadow" });
    try std.testing.expectError(error.GeneratedShadowsSource, stageSources(io, a, root, try std.fs.path.join(a, &.{ root, "tree2" })));
    try dir.deleteFile(io, generated_sources ++ "/Lib/os.py.in");
    // Nor may the vendored tree carry a C API header.
    try dir.createDirPath(io, vendored_sources ++ "/Include");
    try dir.writeFile(io, .{ .sub_path = vendored_sources ++ "/Include/object.h", .data = "upstream" });
    try std.testing.expectError(error.VendoredHeader, stageSources(io, a, root, try std.fs.path.join(a, &.{ root, "tree3" })));
}
