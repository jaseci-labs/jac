//! Build the release Python before any Jac tooling can run. Sources are
//! checksum-pinned. A build-only CPython host emits the native JacPython replacement object.
const std = @import("std");
const native_inputs = @import("native_inputs.zig");
const build_jacpython = @import("build_jacpython.zig");
const builtin = @import("builtin");
const seed = @import("seed.zig");
const Io = std.Io;
const inputs = [_][]const u8{
    "bootstrap/build_python.zig",             "bootstrap/seed.zig",
    "bootstrap/python/sources.json",          "bootstrap/python/cpython-sources.txt",
    "bootstrap/python/build.sh",              "bootstrap/python/smoke.py",
    "bootstrap/python/finalize.py",           "bootstrap/python/build-graph.patch",
    "bootstrap/python/host-graph.patch",      "bootstrap/python/jacpython-clinic.txt",
    // Only the JacPython build reads the inputs from here on.
    "bootstrap/build_jacpython.zig",          "bootstrap/pyconfig.zig",
    "bootstrap/pyconfig_probes.zig",          "bootstrap/python/layouts_check.c",
    "bootstrap/python/features_check.c",      "bootstrap/python/prepare_native.py",
    "bootstrap/python/jacpython-modules.txt",
};
const first_jacpython_input = 10;
// The Jac generators build_jacpython.zig runs with the build-time host (the
// frozen modules, _PyRuntime, build-details.json), relative to the repository
// root, the Jac root's parent. Only the JacPython build runs them.
const generator_inputs = [_][]const u8{
    "scripts/jacpython/common.jac",
    "scripts/jacpython/gen_frozen.jac",
    "scripts/jacpython/gen_runtime_image.jac",
    "scripts/jacpython/gen_build_details.jac",
};
const Source = struct { url: []const u8, sha256: []const u8, version: ?[]const u8 = null };
const Mode = enum { host, jacpython };

fn parseMode(args: []const []const u8) !Mode {
    if (args.len == 5) return .jacpython;
    if (args.len == 6) {
        if (std.mem.eql(u8, args[5], "--host")) return .host;
    }
    return error.InvalidBuildMode;
}

// The interpreter a JacPython build runs on: it runs the Jac compiler that
// lowers the runtime, the generators, and supplies the vendored libraries.
//   auto      the previous build's own output when it is complete and on the
//             pinned version, else the bootstrap host (the default)
//   stock     always the bootstrap host: stock CPython from the pinned archive,
//             with its own configure and make (build.sh); the only choice on a
//             platform no JacPython has been built for yet
//   <path>    an installed runtime: its install prefix (.../python/install) or
//             the build output holding it
const host_flag = "--jacpython-host=";
const HostChoice = union(enum) { auto, stock, installed: []const u8 };
const Host = union(enum) { bootstrap, installed: []const u8 };

fn parseHostChoice(text: []const u8) HostChoice {
    if (text.len == 0 or std.mem.eql(u8, text, "auto")) return .auto;
    if (std.mem.eql(u8, text, "stock")) return .stock;
    return .{ .installed = text };
}

// What a build output carries forward so that the next build can run on it:
// the interpreter, and the vendored libraries' archives, headers, notices and
// CA bundle, which only the bootstrap host builds from source, with the key
// they were built under (vendoredKey).
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

fn selectHost(io: Io, a: std.mem.Allocator, choice: HostChoice, dest: []const u8, pin: []const u8, vendored: []const u8, comptime probe: anytype) !Host {
    switch (choice) {
        .stock => return .bootstrap,
        .auto => {
            // Only a finished output (it has its stamp) on the pinned version,
            // carrying the vendored libraries this recipe pins. One built
            // before outputs carried them, one built under other pins, or one
            // that no longer runs, leaves the bootstrap host to build.
            if (!pathExists(io, try std.fs.path.join(a, &.{ dest, "build-key" }))) return .bootstrap;
            const tree = try hostTree(io, a, dest) orelse return .bootstrap;
            if (!try vendoredMatches(io, a, tree, vendored)) return .bootstrap;
            const version = probe(io, a, try std.fs.path.join(a, &.{ tree, host_parts[0] })) catch return .bootstrap;
            if (!std.mem.eql(u8, version, pin)) return .bootstrap;
            return .{ .installed = tree };
        },
        .installed => |path| {
            const tree = try hostTree(io, a, path) orelse return error.IncompleteHostRuntime;
            if (!try vendoredMatches(io, a, tree, vendored)) return error.VendoredLibrariesDiffer;
            const version = try probe(io, a, try std.fs.path.join(a, &.{ tree, host_parts[0] }));
            if (!std.mem.eql(u8, version, pin)) return error.HostVersionMismatch;
            return .{ .installed = tree };
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
    var kept: std.ArrayList([]const u8) = .empty;
    for (try init.minimal.args.toSlice(a)) |arg| {
        if (std.mem.eql(u8, arg, "--reuse-lowered")) {
            reuse = true;
        } else if (std.mem.startsWith(u8, arg, host_flag)) {
            choice = parseHostChoice(arg[host_flag.len..]);
        } else try kept.append(a, arg);
    }
    const args = kept.items;
    const mode = parseMode(args) catch seed.die("usage: build_python <os-arch> <destination> <jac-root> <zig> [--host] [--reuse-lowered] [" ++ host_flag ++ "auto|stock|<install prefix>]", .{});
    const platform = args[1];
    if (!supported(platform)) seed.die("build-python: unsupported platform {s}", .{platform});
    if (!std.mem.eql(u8, platform, hostPlatform()))
        seed.die("build-python: build {s} on its matching release runner (host is {s})", .{ platform, hostPlatform() });
    const dest = args[2];
    const root = args[3];
    const host_dest = try std.fmt.allocPrint(a, "{s}.host", .{dest});
    const manifest_path = try std.fs.path.join(a, &.{ root, "bootstrap/python/sources.json" });
    const manifest = try Io.Dir.cwd().readFileAlloc(io, manifest_path, a, .unlimited);
    const sources = try std.json.parseFromSliceLeaky(std.json.ArrayHashMap(Source), a, manifest, .{});
    const smoke = try std.fs.path.join(a, &.{ root, "bootstrap/python/smoke.py" });
    const key = try buildKey(io, a, platform, root, mode);
    const vendored = try vendoredKey(io, a, platform, root);
    const stamp_path = try std.fs.path.join(a, &.{ dest, "build-key" });
    const old = Io.Dir.cwd().readFileAlloc(io, stamp_path, a, .limited(128)) catch "";
    const python = try std.fs.path.join(a, &.{ dest, "python/install/bin/python3.14" });
    if (std.mem.eql(u8, old, &key) and seed.fileExists(io, python)) {
        try runSmoke(io, python, smoke, mode);
        seed.log("build-python: cached {s} ({s})", .{ platform, key[0..16] });
        return;
    }
    const sources_stamp = try std.fs.path.join(a, &.{ dest, "build-key-sources" });
    if (mode == .jacpython and reuse and seed.fileExists(io, python)) {
        if (try sourcesKey(io, a, platform, root, dest)) |lowered| {
            const recorded = Io.Dir.cwd().readFileAlloc(io, sources_stamp, a, .limited(128)) catch "";
            if (std.mem.eql(u8, recorded, &lowered)) {
                try runSmoke(io, python, smoke, mode);
                seed.log("build-python: reusing {s}; the sources it was lowered from are unchanged ({s})", .{ platform, lowered[0..16] });
                return;
            }
        }
    }
    // Something is built: choose the interpreter the JacPython build runs on.
    var host_tree: []const u8 = host_dest;
    var provenance: []const u8 = "";
    if (mode == .jacpython) {
        const pin = (sources.map.get("cpython") orelse return error.MissingCPythonSource).version orelse return error.MissingCPythonVersion;
        const host = selectHost(io, a, choice, dest, pin, &vendored, probeVersion) catch |err|
            seed.die("build-python: cannot build on {s}: {s}. A host is a finished build output, or its install prefix, on Python {s} with python/install, python/build/{{include,lib,cacert.pem,vendored-key}} and python/licenses, its vendored-key matching these pins; " ++ host_flag ++ "stock builds the bootstrap host instead.", .{ switch (choice) {
                .installed => |path| path,
                else => dest,
            }, @errorName(err), pin });
        switch (host) {
            .bootstrap => {
                seed.log("build-python: building on the bootstrap host (stock CPython from the pinned archive)", .{});
                var host_build = try std.process.spawn(io, .{ .argv = &.{ args[0], platform, host_dest, root, args[4], "--host" } });
                const result = try host_build.wait(io);
                if (result != .exited or result.exited != 0) return error.HostPythonBuildFailed;
                const host_key = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ host_dest, "build-key" }), a, .limited(128)) catch "";
                provenance = try std.fmt.allocPrint(a, "bootstrap {s}\n", .{host_key});
            },
            .installed => |tree| {
                seed.log("build-python: building on the installed runtime at {s}", .{tree});
                host_tree = tree;
                provenance = try std.fmt.allocPrint(a, "installed {s}\n", .{try hostIdentity(io, a, tree)});
            },
        }
    }
    const work = try std.fmt.allocPrint(a, "{s}.work", .{dest});
    // A failed build never produces the completion stamp or replaces a good tree.
    try Io.Dir.cwd().deleteTree(io, work);
    try Io.Dir.cwd().createDirPath(io, work);
    const source_cache = try std.fs.path.join(a, &.{ root, ".python-build/jacpython/sources" });
    for (sources.map.keys(), sources.map.values()) |name, source| {
        if (mode == .jacpython and !std.mem.eql(u8, name, "cpython")) continue;
        seed.log("build-python: source {s}", .{name});
        const gz = try sourceArchive(io, init.gpa, source_cache, source, seed.httpGetAlloc);
        defer init.gpa.free(gz);
        const source_dir = try std.fs.path.join(a, &.{ work, "src", name });
        try Io.Dir.cwd().createDirPath(io, source_dir);
        var dir = try Io.Dir.cwd().openDir(io, source_dir, .{ .iterate = true });
        defer dir.close(io);
        const window = try init.gpa.alloc(u8, std.compress.flate.max_window_len);
        defer init.gpa.free(window);
        var reader = Io.Reader.fixed(gz);
        var decompressor: std.compress.flate.Decompress = .init(&reader, .gzip, window);
        try std.tar.extract(io, dir, &decompressor.reader, .{
            .mode_mode = .executable_bit_only,
            .strip_components = 1,
        });
        if (std.mem.eql(u8, name, "cpython")) {
            const list_path = try std.fs.path.join(a, &.{ root, "bootstrap/python/cpython-sources.txt" });
            const list = try Io.Dir.cwd().readFileAlloc(io, list_path, a, .limited(128 * 1024));
            const retained = if (mode == .jacpython) list else try cSourceManifest(a, list);
            try generatedHeadersOnly(retained);
            try retainSources(io, a, dir, retained);
            try stageGenerated(io, a, root, dir, list);
            // One parser owns the manifest. build.sh checks the finished tree
            // against this list rather than reading the markers again.
            try Io.Dir.cwd().writeFile(io, .{
                .sub_path = try std.fs.path.join(a, &.{ work, "absent-inputs" }),
                .data = try absentInputs(a, list, mode),
            });
        }
    }
    const recipe = try std.fs.path.join(a, &.{ root, "bootstrap/python" });
    switch (mode) {
        // The build-only host is stock CPython: its own configure and make.
        .host => {
            const script = try std.fs.path.join(a, &.{ recipe, "build.sh" });
            var child = try std.process.spawn(io, .{ .argv = &.{ "sh", script, platform, work, args[4], recipe } });
            const term = try child.wait(io);
            if (term != .exited or term.exited != 0) seed.die("build-python: build failed; logs at {s}/logs", .{work});
        },
        .jacpython => build_jacpython.build(io, a, .{
            .platform = platform,
            .work = work,
            .zig = args[4],
            .recipe = recipe,
            .host = host_tree,
            .root = root,
            .jobs = try jobCount(init.environ_map),
            .environ = init.environ_map,
        }) catch |err| {
            // A runtime that builds the next one can carry its own defect into
            // the build; the bootstrap host rules that out.
            if (!std.mem.eql(u8, host_tree, host_dest))
                seed.log("build-python: this build ran on the installed runtime at {s}; if that runtime is at fault, " ++ host_flag ++ "stock (zig build -Djacpython-host=stock) builds on the bootstrap host", .{host_tree});
            seed.die("build-python: build failed ({s}); logs at {s}/logs", .{ @errorName(err), work });
        },
    }
    // Cache only the runtime and link archives, not intermediate objects or sources.
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "src" }));
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "deps" }));
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "bin" }));
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "absent-inputs" }));
    // Either host built the vendored libraries under this key, or carried
    // forward ones that were (selectHost).
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ work, vendored_record }), .data = &vendored });
    if (provenance.len > 0) {
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ work, "build-host" }), .data = provenance });
    }
    try Io.Dir.cwd().deleteTree(io, dest);
    try Io.Dir.cwd().rename(work, Io.Dir.cwd(), dest, io);
    // Verify relocation before allowing a cache hit on the next invocation.
    try runSmoke(io, python, smoke, mode);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = stamp_path, .data = &key });
    if (mode == .jacpython) {
        if (try sourcesKey(io, a, platform, root, dest)) |lowered| {
            try Io.Dir.cwd().writeFile(io, .{ .sub_path = sources_stamp, .data = &lowered });
        }
    }
}

/// JAC_PYTHON_JOBS: how many compilers run at once (default 4).
fn jobCount(environ: *const std.process.Environ.Map) !usize {
    const text = environ.get("JAC_PYTHON_JOBS") orelse return 4;
    const jobs = std.fmt.parseInt(usize, text, 10) catch return error.InvalidJobCount;
    if (jobs == 0) return error.InvalidJobCount;
    return jobs;
}

// Host and native builds consume the same pinned archive. Keep it outside the
// disposable work trees, and recheck its digest on every use.
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

// The interpreter a JacPython build runs on is not part of its key, or a
// runtime that builds the next one would never be reused: the next build runs
// on it and would key differently. The bootstrap host and an installed runtime
// lower the same sources to the same native code; what they hand the build
// that can differ is the frozen modules' bytecode, which each compiles with its
// own compiler (build-host records which one did). The inputs are hashed
// instead: the recipe, which pins the vendored libraries' sources, and the
// compiler.
fn buildKey(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8, mode: Mode) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    try hashRecipe(io, a, platform, root, mode, &hash);
    if (mode == .jacpython) {
        try hashCompilerTree(io, a, root, &hash);
    }
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
    try hashRecipe(io, a, platform, root, .jacpython, &hash);
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

/// The target and the toolchain every C translation in either build uses.
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
/// built from: their pins and build.sh, which only the bootstrap host runs.
/// Every output records it; a runtime whose record differs cannot hand its
/// libraries to the next build.
fn vendoredKey(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    try hashToolchain(io, a, platform, &hash);
    for ([_][]const u8{ "bootstrap/python/sources.json", "bootstrap/python/build.sh" }) |path| {
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, path }), a, .unlimited));
    }
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn hashRecipe(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8, mode: Mode, hash: *std.crypto.hash.sha2.Sha256) !void {
    hash.update(@tagName(mode));
    try hashToolchain(io, a, platform, hash);
    for (inputs, 0..) |path, i| {
        if (mode != .jacpython and i >= first_jacpython_input) continue;
        const full = try std.fs.path.join(a, &.{ root, path });
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, full, a, .unlimited));
    }
    // The checked-in copies staged in place of archive files.
    const list_path = try std.fs.path.join(a, &.{ root, "bootstrap/python/cpython-sources.txt" });
    const list = try Io.Dir.cwd().readFileAlloc(io, list_path, a, .limited(128 * 1024));
    var lines = std.mem.splitScalar(u8, list, '\n');
    while (lines.next()) |line| {
        const entry = try markedExclusion(line) orelse continue;
        if (entry.marker != .generated) continue;
        const copy = try generatedCopy(a, entry.path);
        hash.update(copy);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, copy }), a, .unlimited));
    }
    if (mode == .jacpython) {
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

// A commented manifest path carries a marker naming the builds that must lack
// it. Every other comment is prose.
const Marker = enum {
    // Replaced by the native Jac implementation, and restored for the
    // build-only host so it can still compile Python itself.
    removed,
    // Needed by no build. Absent from the host tree as well.
    pruned,
    // Written by a Jac generator (the opcode tables, the public C API
    // headers) and checked in as bootstrap/python/generated/<path>.in; both
    // trees stage that copy where the archive's was.
    generated,
};
const Exclusion = struct { path: []const u8, marker: Marker };

// "# <path>  # <marker>: <count> source lines". Prose comments have no path in
// that position and are left alone; an unrecognized marker is a typo that would
// silently drop a source, so it fails the build instead.
fn markedExclusion(line: []const u8) !?Exclusion {
    if (!std.mem.startsWith(u8, line, "# ")) return null;
    const rest = std.mem.trimEnd(u8, line[2..], " \t\r");
    const path_end = std.mem.indexOfScalar(u8, rest, ' ') orelse return null;
    if (path_end == 0) return null;
    const tail = rest[path_end..];
    if (!std.mem.startsWith(u8, tail, "  # ")) return null;
    const word = tail[4..];
    const colon = std.mem.indexOfScalar(u8, word, ':') orelse return null;
    const marker = std.meta.stringToEnum(Marker, word[0..colon]) orelse return error.UnknownSourceMarker;
    return .{ .path = rest[0..path_end], .marker = marker };
}

// Only the build-time host retains the C compiler, so it alone restores the
// entries marked as replaced. Pruned entries stay commented for both builds.
fn cSourceManifest(a: std.mem.Allocator, manifest: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |line| {
        var value = line;
        if (try markedExclusion(line)) |excluded| {
            if (excluded.marker == .removed) value = excluded.path;
        }
        try out.appendSlice(a, value);
        try out.append(a, '\n');
    }
    return out.toOwnedSlice(a);
}

// Paths the finished build must not contain, one per line, for build.sh to
// check against the tree. Both modes drop pruned entries; only the reduced
// runtime drops the ones the host restores.
fn absentInputs(a: std.mem.Allocator, manifest: []const u8, mode: Mode) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |line| {
        const excluded = try markedExclusion(line) orelse continue;
        if (excluded.marker == .generated) continue;
        if (excluded.marker == .removed and mode != .jacpython) continue;
        try out.appendSlice(a, excluded.path);
        try out.append(a, '\n');
    }
    return out.toOwnedSlice(a);
}

// The checked-in copy of a path the manifest marks generated, relative to the
// Jac root.
fn generatedCopy(a: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.fmt.allocPrint(a, "bootstrap/python/generated/{s}.in", .{path});
}

// Every header under Include/ is generated from the Jac definitions
// (scripts/jacpython/gen_include.jac): a manifest that keeps one of the
// archive's, or a directory of them, fails the build.
fn generatedHeadersOnly(manifest: []const u8) !void {
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |raw| {
        const entry = std.mem.trim(u8, raw, " \t\r");
        if (entry.len == 0 or entry[0] == '#' or !std.mem.startsWith(u8, entry, "Include/")) continue;
        if (std.mem.endsWith(u8, entry, ".h") or std.mem.endsWith(u8, entry, "/")) {
            seed.log("build-python: {s} would come from the CPython archive; Include/ headers are generated", .{entry});
            return error.ArchiveHeader;
        }
    }
}

// Put each generated path's checked-in copy into the extracted tree. The
// manifest comments the path out, so the archive's copy is already gone and a
// missing checked-in copy fails the build instead of falling back to it.
fn stageGenerated(io: Io, a: std.mem.Allocator, root: []const u8, dir: Io.Dir, manifest: []const u8) !void {
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |line| {
        const entry = try markedExclusion(line) orelse continue;
        if (entry.marker != .generated) continue;
        const copy = try std.fs.path.join(a, &.{ root, try generatedCopy(a, entry.path) });
        const data = try Io.Dir.cwd().readFileAlloc(io, copy, a, .unlimited);
        if (std.fs.path.dirname(entry.path)) |parent| try dir.createDirPath(io, parent);
        try dir.writeFile(io, .{ .sub_path = entry.path, .data = data });
    }
}

fn runSmoke(io: Io, python: []const u8, smoke: []const u8, mode: Mode) !void {
    var check = try std.process.spawn(io, .{ .argv = &.{ python, "-X", "faulthandler", "-I", smoke, @tagName(mode) } });
    const result = try check.wait(io);
    if (result != .exited or result.exited != 0) {
        return error.RelocationFailed;
    }
}

fn safePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path)) return false;
    if (std.mem.indexOfAny(u8, path, "\\:*?[]\t\r\n") != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, "..") or std.mem.eql(u8, part, ".")) return false;
    }
    return true;
}

fn covered(path: []const u8, entries: []const []const u8) bool {
    for (entries) |entry| {
        if (std.mem.eql(u8, path, std.mem.trimEnd(u8, entry, "/"))) return true;
        if (std.mem.endsWith(u8, entry, "/") and std.mem.startsWith(u8, path, entry)) return true;
    }
    return false;
}

fn needed(path: []const u8, directory: bool, entries: []const []const u8) bool {
    if (covered(path, entries)) return true;
    if (directory) for (entries) |entry| {
        if (entry.len > path.len and entry[path.len] == '/' and std.mem.startsWith(u8, entry, path)) return true;
    };
    return false;
}

// Validate every entry before changing the extracted tree. Directory entries
// end in '/', files are exact paths, and overlapping entries are rejected so
// removing a line cannot be silently defeated by a broader directory entry.
fn retainSources(io: Io, a: std.mem.Allocator, dir: Io.Dir, manifest: []const u8) !void {
    var entries: std.ArrayList([]const u8) = .empty;
    defer entries.deinit(a);
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |raw| {
        const entry = std.mem.trim(u8, raw, " \t\r");
        if (entry.len == 0 or entry[0] == '#') continue;
        const directory = std.mem.endsWith(u8, entry, "/");
        const path = if (directory) entry[0 .. entry.len - 1] else entry;
        if (!safePath(path)) return error.UnsafeSourcePath;
        if (covered(path, entries.items)) return error.OverlappingSourceEntries;
        for (entries.items) |previous| {
            if (covered(std.mem.trimEnd(u8, previous, "/"), &.{entry})) return error.OverlappingSourceEntries;
        }
        const stat = dir.statFile(io, path, .{ .follow_symlinks = false }) catch |err| {
            seed.log("build-python: source entry {s}: {s}", .{ entry, @errorName(err) });
            return err;
        };
        const expected_kind: Io.File.Kind = if (directory) .directory else .file;
        if (stat.kind != expected_kind) return error.SourceEntryKindMismatch;
        try entries.append(a, entry);
    }
    if (entries.items.len == 0) return error.EmptySourceManifest;

    var walker = try dir.walkSelectively(a);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (!needed(entry.path, entry.kind == .directory, entries.items)) {
            try entry.dir.deleteTree(io, entry.basename);
        } else if (entry.kind == .directory and !covered(entry.path, entries.items)) {
            try walker.enter(io, entry);
        }
    }
    seed.log("build-python: retained {d} CPython source entries", .{entries.items.len});
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

test "JacPython is mandatory except for the build-only host" {
    const args = [_][]const u8{ "build_python", "linux-x86_64", "out", "root", "zig" };
    try std.testing.expectEqual(Mode.jacpython, try parseMode(&args));
    try std.testing.expectError(error.InvalidBuildMode, parseMode(&(args ++ .{"--jacpython"})));
    try std.testing.expectEqual(Mode.host, try parseMode(&(args ++ .{"--host"})));
    try std.testing.expectError(error.InvalidBuildMode, parseMode(&(args ++ .{"--typo"})));
    try std.testing.expectError(error.InvalidBuildMode, parseMode(args[0..4]));
}

test "manifest markers name the builds that must lack a path" {
    const removed = (try markedExclusion("# Parser/parser.c  # removed: 1,953 source lines")).?;
    try std.testing.expectEqual(Marker.removed, removed.marker);
    try std.testing.expectEqualStrings("Parser/parser.c", removed.path);
    const pruned = (try markedExclusion("# Lib/pydoc_data/  # pruned: 14,979 source lines")).?;
    try std.testing.expectEqual(Marker.pruned, pruned.marker);
    try std.testing.expectEqualStrings("Lib/pydoc_data/", pruned.path);
    const generated = (try markedExclusion("# Include/opcode_ids.h  # generated: 259 source lines")).?;
    try std.testing.expectEqual(Marker.generated, generated.marker);
    try std.testing.expectEqualStrings("Include/opcode_ids.h", generated.path);
    // Prose, including the header lines that quote the marker syntax.
    try std.testing.expectEqual(@as(?Exclusion, null), try markedExclusion("# Parser and tokenizer"));
    try std.testing.expectEqual(@as(?Exclusion, null), try markedExclusion("#   \"# path  # pruned: N source lines\""));
    try std.testing.expectEqual(@as(?Exclusion, null), try markedExclusion("Python/ceval.c"));
    // A misspelled marker would silently drop a source.
    try std.testing.expectError(error.UnknownSourceMarker, markedExclusion("# Python/ceval.c  # remved: 1 source lines"));
}

test "only the reduced runtime must lack the entries the host restores" {
    const a = std.testing.allocator;
    const source = "# head\n# Parser/parser.c  # removed: 100 source lines\n# Lib/turtle.py  # pruned: 4,291 source lines\n# Lib/_opcode_metadata.py  # generated: 371 source lines\nPython/ceval.c\n";
    const reduced = try absentInputs(a, source, .jacpython);
    defer a.free(reduced);
    try std.testing.expectEqualStrings("Parser/parser.c\nLib/turtle.py\n", reduced);
    const host = try absentInputs(a, source, .host);
    defer a.free(host);
    try std.testing.expectEqualStrings("Lib/turtle.py\n", host);
}

test "C compiler builds restore only marked replacement exclusions" {
    const a = std.testing.allocator;
    const source = "# source allowlist\n# Parser/parser.c  # removed: 100 source lines\n# Lib/turtle.py  # pruned: 4,291 source lines\n# unused.c\nPython/ceval.c\n";
    const restored = try cSourceManifest(a, source);
    defer a.free(restored);
    try std.testing.expectEqualStrings("# source allowlist\nParser/parser.c\n# Lib/turtle.py  # pruned: 4,291 source lines\n# unused.c\nPython/ceval.c\n\n", restored);
}

test "source paths stay inside the extracted tree" {
    try std.testing.expect(safePath("Tools/msi"));
    try std.testing.expect(!safePath("../LICENSE"));
    try std.testing.expect(!safePath("/tmp"));
    try std.testing.expect(!safePath("."));
    try std.testing.expect(!safePath("Modules//main.c"));
    try std.testing.expect(!safePath("Modules/*.c"));
    try std.testing.expect(!safePath("..\\outside"));
}

test "source allowlist preserves exact files and subtrees and removes an entry on the next build" {
    const io = std.testing.io;
    const a = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    for ([_][]const u8{ "Objects", "Lib/re", "Lib/regex", "Lib/test" }) |path| try tmp.dir.createDirPath(io, path);
    for ([_][]const u8{ "Objects/listobject.c", "Objects/dictobject.c", "Objects/listobject.c.bak", "Lib/re/__init__.py", "Lib/regex/probe.py", "Lib/test/test_list.py", "LICENSE" }) |path| {
        try tmp.dir.writeFile(io, .{ .sub_path = path, .data = "source\n" });
    }
    try retainSources(io, a, tmp.dir, "# CPython inputs\n\nObjects/listobject.c\nObjects/dictobject.c\nLib/re/\r\nLICENSE\n");
    _ = try tmp.dir.statFile(io, "Objects/listobject.c", .{});
    _ = try tmp.dir.statFile(io, "Lib/re/__init__.py", .{});
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "Objects/listobject.c.bak", .{}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "Lib/regex", .{}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "Lib/test", .{}));
    try retainSources(io, a, tmp.dir, "# Objects/listobject.c  # removed: 1 source lines\nObjects/dictobject.c\nLib/re/\nLICENSE\n");
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "Objects/listobject.c", .{}));
}

test "generated paths come from their checked-in copies" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "root/bootstrap/python/generated/Include/internal");
    try tmp.dir.writeFile(io, .{ .sub_path = "root/bootstrap/python/generated/Include/internal/table.h.in", .data = "from jac\n" });
    try tmp.dir.createDirPath(io, "tree/Include");
    try tmp.dir.writeFile(io, .{ .sub_path = "tree/Include/Python.h", .data = "header\n" });
    const root = try tmp.dir.realPathFileAlloc(io, "root", a);
    var tree = try tmp.dir.openDir(io, "tree", .{ .iterate = true });
    defer tree.close(io);
    const manifest = "Include/Python.h\n# Include/internal/table.h  # generated: 1 source lines\n";
    try std.testing.expectError(error.ArchiveHeader, generatedHeadersOnly(manifest));
    try std.testing.expectError(error.ArchiveHeader, generatedHeadersOnly("Include/internal/mimalloc/\n"));
    try generatedHeadersOnly("Include/README.rst\n# Include/Python.h  # generated: 1 source lines\n");
    try stageGenerated(io, a, root, tree, manifest);
    try std.testing.expectEqualStrings("from jac\n", try tree.readFileAlloc(io, "Include/internal/table.h", a, .unlimited));
    try std.testing.expectError(error.FileNotFound, stageGenerated(io, a, root, tree, "# Lib/missing.py  # generated: 1 source lines\n"));
}

test "invalid source manifests fail before pruning" {
    const io = std.testing.io;
    const a = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "Include");
    try tmp.dir.writeFile(io, .{ .sub_path = "Include/Python.h", .data = "header\n" });
    try std.testing.expectError(error.EmptySourceManifest, retainSources(io, a, tmp.dir, "# empty\n"));
    try std.testing.expectError(error.UnsafeSourcePath, retainSources(io, a, tmp.dir, "../outside\n"));
    try std.testing.expectError(error.FileNotFound, retainSources(io, a, tmp.dir, "missing.c\n"));
    try std.testing.expectError(error.SourceEntryKindMismatch, retainSources(io, a, tmp.dir, "Include\n"));
    try std.testing.expectError(error.OverlappingSourceEntries, retainSources(io, a, tmp.dir, "Include/\nInclude/Python.h\n"));
    try std.testing.expectError(error.OverlappingSourceEntries, retainSources(io, a, tmp.dir, "Include/Python.h\nInclude/\n"));
    _ = try tmp.dir.statFile(io, "Include/Python.h", .{});
}

test "compiler modes isolate caches; native emitter edits invalidate only JacPython" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    for (generator_inputs) |path| {
        try tmp.dir.createDirPath(io, std.fs.path.dirname(path).?);
        try tmp.dir.writeFile(io, .{ .sub_path = path, .data = "generator" });
    }
    try tmp.dir.createDirPath(io, "jac");
    var dir = try tmp.dir.openDir(io, "jac", .{});
    defer dir.close(io);
    for (inputs) |path| {
        if (std.fs.path.dirname(path)) |parent| try dir.createDirPath(io, parent);
        try dir.writeFile(io, .{ .sub_path = path, .data = "recipe" });
    }
    for (native_inputs.toolchain_inputs) |path| {
        try dir.writeFile(io, .{ .sub_path = path, .data = "toolchain" });
    }
    try dir.createDirPath(io, "native");
    try dir.createDirPath(io, "jaclang/vendor/typeshed");
    for ([_][]const u8{ "PIN", "TARBALL_SHA256" }) |name| {
        try dir.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ "jaclang/vendor/typeshed", name }), .data = "pin" });
    }
    try dir.createDirPath(io, "host");
    try dir.writeFile(io, .{ .sub_path = "host/build-key", .data = "host-key" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "compiler" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler_inputs.txt", .data = "compiler.jac\ncompiler\nruntime\n" });
    const root = try dir.realPathFileAlloc(io, ".", a);
    const before_host = try buildKey(io, a, hostPlatform(), root, .host);
    const before_runtime = try buildKey(io, a, hostPlatform(), root, .jacpython);
    try std.testing.expect(!std.mem.eql(u8, &before_host, &before_runtime));
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "changed compiler" });
    const changed_runtime = try buildKey(io, a, hostPlatform(), root, .jacpython);
    try std.testing.expect(!std.mem.eql(u8, &before_runtime, &changed_runtime));
    try std.testing.expectEqual(before_host, try buildKey(io, a, hostPlatform(), root, .host));
    try dir.writeFile(io, .{ .sub_path = "jaclang/vendor/generated.py", .data = "materialized vendor data" });
    try std.testing.expectEqual(changed_runtime, try buildKey(io, a, hostPlatform(), root, .jacpython));
    try dir.writeFile(io, .{ .sub_path = "native/shim.cpp", .data = "changed emitter" });
    try std.testing.expect(!std.mem.eql(u8, &changed_runtime, &(try buildKey(io, a, hostPlatform(), root, .jacpython))));
    try std.testing.expectEqual(before_host, try buildKey(io, a, hostPlatform(), root, .host));
    try dir.deleteFile(io, "native/shim.cpp");
    for ([_][]const u8{ "scale/server.jac", "compiler/tests/example.jac", "compiler/example.test.jac", "runtime/test/fixture.py", "compiler/.generated/source.py" }) |rel| {
        const path = try std.fs.path.join(a, &.{ "jaclang", rel });
        try dir.createDirPath(io, std.fs.path.dirname(path).?);
        try dir.writeFile(io, .{ .sub_path = path, .data = "unrelated source" });
        try std.testing.expectEqual(changed_runtime, try buildKey(io, a, hostPlatform(), root, .jacpython));
    }
    try dir.createDirPath(io, "jaclang/runtime/python");
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "new runtime input" });
    try std.testing.expect(!std.mem.eql(u8, &changed_runtime, &(try buildKey(io, a, hostPlatform(), root, .jacpython))));
    try dir.deleteFile(io, "jaclang/runtime/python/eval.jac");
    try std.testing.expectEqual(changed_runtime, try buildKey(io, a, hostPlatform(), root, .jacpython));
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/prepare_native.py", .data = "changed native emitter" });
    try std.testing.expect(!std.mem.eql(u8, &changed_runtime, &(try buildKey(io, a, hostPlatform(), root, .jacpython))));
    try std.testing.expectEqual(before_host, try buildKey(io, a, hostPlatform(), root, .host));
    const before_generator = try buildKey(io, a, hostPlatform(), root, .jacpython);
    try tmp.dir.writeFile(io, .{ .sub_path = "scripts/jacpython/gen_frozen.jac", .data = "changed generator" });
    try std.testing.expect(!std.mem.eql(u8, &before_generator, &(try buildKey(io, a, hostPlatform(), root, .jacpython))));
    try std.testing.expectEqual(before_host, try buildKey(io, a, hostPlatform(), root, .host));
    const before_recipe = try buildKey(io, a, hostPlatform(), root, .jacpython);
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/cpython-sources.txt", .data = "changed C source selection" });
    try std.testing.expect(!std.mem.eql(u8, &before_host, &(try buildKey(io, a, hostPlatform(), root, .host))));
    try std.testing.expect(!std.mem.eql(u8, &before_recipe, &(try buildKey(io, a, hostPlatform(), root, .jacpython))));
    // The interpreter that runs the build is not an input: a rebuilt
    // bootstrap host, or an installed runtime in its place, keeps the key.
    const before_host_key = try buildKey(io, a, hostPlatform(), root, .jacpython);
    try dir.writeFile(io, .{ .sub_path = "host/build-key", .data = "rebuilt host" });
    try std.testing.expectEqual(before_host_key, try buildKey(io, a, hostPlatform(), root, .jacpython));
}

test "a PR may reuse a runtime whose recorded lowered sources are unchanged" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    for (generator_inputs) |path| {
        try tmp.dir.createDirPath(io, std.fs.path.dirname(path).?);
        try tmp.dir.writeFile(io, .{ .sub_path = path, .data = "generator" });
    }
    try tmp.dir.createDirPath(io, "jac");
    var dir = try tmp.dir.openDir(io, "jac", .{});
    defer dir.close(io);
    for (inputs) |path| {
        if (std.fs.path.dirname(path)) |parent| try dir.createDirPath(io, parent);
        try dir.writeFile(io, .{ .sub_path = path, .data = "recipe" });
    }
    for (native_inputs.toolchain_inputs) |path| {
        try dir.writeFile(io, .{ .sub_path = path, .data = "toolchain" });
    }
    try dir.createDirPath(io, "native");
    try dir.createDirPath(io, "jaclang/vendor/typeshed");
    for ([_][]const u8{ "PIN", "TARBALL_SHA256" }) |name| {
        try dir.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ "jaclang/vendor/typeshed", name }), .data = "pin" });
    }
    try dir.createDirPath(io, "jaclang/runtime/python");
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "compiler" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "lowered" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler_inputs.txt", .data = "compiler.jac\nruntime\n" });
    const root = try dir.realPathFileAlloc(io, ".", a);
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
    try std.testing.expect(!std.mem.eql(u8, &lowered, &(try buildKey(io, a, hostPlatform(), root, .jacpython))));
    // An edit to a recorded source does not reuse it.
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "edited" });
    const edited = (try sourcesKey(io, a, hostPlatform(), root, built)).?;
    try std.testing.expect(!std.mem.eql(u8, &lowered, &edited));
    // Nor does a recipe or toolchain change.
    try dir.writeFile(io, .{ .sub_path = native_inputs.toolchain_inputs[0], .data = "new toolchain" });
    try std.testing.expect(!std.mem.eql(u8, &edited, &(try sourcesKey(io, a, hostPlatform(), root, built)).?));
}

test "pinned source archives survive host builds and reject corrupt cached or fetched bytes" {
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

test "the host choice names the bootstrap host, the previous output, or an installed runtime" {
    try std.testing.expectEqual(HostChoice.auto, parseHostChoice(""));
    try std.testing.expectEqual(HostChoice.auto, parseHostChoice("auto"));
    try std.testing.expectEqual(HostChoice.stock, parseHostChoice("stock"));
    try std.testing.expectEqualStrings("/opt/jacpython/python/install", parseHostChoice("/opt/jacpython/python/install").installed);
    _ = &main;
}

test "a JacPython build runs on the previous runtime when it can, else on the bootstrap host" {
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

    // Nothing built yet: only the bootstrap host can build.
    try std.testing.expectEqual(Host.bootstrap, try selectHost(io, a, .auto, out, "3.14.6", "pins", Probe.pinned));
    try std.testing.expectError(error.IncompleteHostRuntime, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", "pins", Probe.pinned));

    // An output from before outputs carried the vendored headers.
    for (host_parts) |part| {
        if (std.mem.eql(u8, part, "python/build/include")) continue;
        if (std.mem.endsWith(u8, part, "python3.14") or std.mem.endsWith(u8, part, ".pem") or std.mem.endsWith(u8, part, "-key")) {
            try tmp.dir.createDirPath(io, std.fs.path.dirname(try std.fs.path.join(a, &.{ "out", part })).?);
            try tmp.dir.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ "out", part }), .data = "pins" });
        } else try tmp.dir.createDirPath(io, try std.fs.path.join(a, &.{ "out", part }));
    }
    try tmp.dir.writeFile(io, .{ .sub_path = "out/build-key", .data = "key" });
    try std.testing.expectEqual(Host.bootstrap, try selectHost(io, a, .auto, out, "3.14.6", "pins", Probe.pinned));
    try std.testing.expectError(error.IncompleteHostRuntime, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", "pins", Probe.pinned));

    try tmp.dir.createDirPath(io, "out/python/build/include");
    // The finished previous output, named by itself or by its install prefix.
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .auto, out, "3.14.6", "pins", Probe.pinned)).installed);
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", "pins", Probe.pinned)).installed);
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .{ .installed = out }, base, "3.14.6", "pins", Probe.pinned)).installed);
    // stock always builds on the bootstrap host.
    try std.testing.expectEqual(Host.bootstrap, try selectHost(io, a, .stock, out, "3.14.6", "pins", Probe.pinned));
    // A runtime on another version, or one that no longer runs: the default
    // falls back, a named host is an error.
    try std.testing.expectEqual(Host.bootstrap, try selectHost(io, a, .auto, out, "3.14.6", "pins", Probe.older));
    try std.testing.expectEqual(Host.bootstrap, try selectHost(io, a, .auto, out, "3.14.6", "pins", Probe.broken));
    try std.testing.expectError(error.HostVersionMismatch, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", "pins", Probe.older));
    try std.testing.expectError(error.HostDoesNotRun, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", "pins", Probe.broken));
    // Vendored libraries built under other pins: the default rebuilds them
    // on the bootstrap host, a named host is an error.
    try std.testing.expectEqual(Host.bootstrap, try selectHost(io, a, .auto, out, "3.14.6", "new pins", Probe.pinned));
    try std.testing.expectError(error.VendoredLibrariesDiffer, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", "new pins", Probe.pinned));
    // An unfinished output (no stamp) is never the default host.
    try tmp.dir.deleteFile(io, "out/build-key");
    try std.testing.expectEqual(Host.bootstrap, try selectHost(io, a, .auto, out, "3.14.6", "pins", Probe.pinned));
}

test "the vendored libraries' key follows their pins and build.sh, not the runtime's inputs" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "bootstrap/python");
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = "pins" });
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/build.sh", .data = "recipe" });
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/cpython-sources.txt", .data = "selection" });
    const root = try tmp.dir.realPathFileAlloc(io, ".", a);
    const before = try vendoredKey(io, a, hostPlatform(), root);
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/cpython-sources.txt", .data = "changed selection" });
    try std.testing.expectEqual(before, try vendoredKey(io, a, hostPlatform(), root));
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = "new pins" });
    const pinned = try vendoredKey(io, a, hostPlatform(), root);
    try std.testing.expect(!std.mem.eql(u8, &before, &pinned));
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/build.sh", .data = "new recipe" });
    try std.testing.expect(!std.mem.eql(u8, &pinned, &(try vendoredKey(io, a, hostPlatform(), root))));
}
