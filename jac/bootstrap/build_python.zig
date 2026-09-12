//! Build the release Python before any Jac tooling can run. Sources are
//! checksum-pinned. JacPython is opt-in; its separate host produces the seed.
const std = @import("std");
const builtin = @import("builtin");
const seed = @import("seed.zig");
const Io = std.Io;
const inputs = [_][]const u8{
    "bootstrap/build_python.zig",           "bootstrap/seed.zig",
    "bootstrap/python/sources.json",        "bootstrap/python/cpython-sources.txt",
    "bootstrap/python/build.sh",            "bootstrap/python/smoke.py",
    "bootstrap/python/finalize.py",         "bootstrap/python/compiler-bridge.patch",
    "bootstrap/python/host-compiler.patch", "bootstrap/python/compiler_bridge.c",
    "bootstrap/python/compiler_bridge.h",   "bootstrap/python/prepare_seed.py",
    "bootstrap/python/seed_runtime.py",
};
const Source = struct { url: []const u8, sha256: []const u8, version: ?[]const u8 = null };
const Mode = enum { cpython, host, jacpython };

fn parseMode(args: []const []const u8) !Mode {
    if (args.len == 5) return .cpython;
    if (args.len == 6) {
        if (std.mem.eql(u8, args[5], "--host")) return .host;
        if (std.mem.eql(u8, args[5], "--jacpython")) return .jacpython;
    }
    return error.InvalidBuildMode;
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
    const args = try init.minimal.args.toSlice(a);
    const mode = parseMode(args) catch seed.die("usage: build_python <os-arch> <destination> <jac-root> <zig> [--jacpython|--host]", .{});
    const platform = args[1];
    if (!supported(platform)) seed.die("build-python: unsupported platform {s}", .{platform});
    if (!std.mem.eql(u8, platform, hostPlatform()))
        seed.die("build-python: build {s} on its matching release runner (host is {s})", .{ platform, hostPlatform() });
    const dest = args[2];
    const root = args[3];
    const host_dest = try std.fmt.allocPrint(a, "{s}.host", .{dest});
    if (mode == .jacpython) {
        var host_build = try std.process.spawn(io, .{ .argv = &.{ args[0], platform, host_dest, root, args[4], "--host" } });
        const result = try host_build.wait(io);
        if (result != .exited or result.exited != 0) return error.HostPythonBuildFailed;
    }
    const smoke = try std.fs.path.join(a, &.{ root, "bootstrap/python/smoke.py" });
    const key = try buildKey(io, a, platform, root, host_dest, mode);
    const stamp_path = try std.fs.path.join(a, &.{ dest, "build-key" });
    const old = Io.Dir.cwd().readFileAlloc(io, stamp_path, a, .limited(128)) catch "";
    const python = try std.fs.path.join(a, &.{ dest, "python/install/bin/python3.14" });
    if (std.mem.eql(u8, old, &key) and seed.fileExists(io, python)) {
        try runSmoke(io, python, smoke, mode);
        seed.log("build-python: cached {s} ({s})", .{ platform, key[0..16] });
        return;
    }
    const work = try std.fmt.allocPrint(a, "{s}.work", .{dest});
    // A failed build never produces the completion stamp or replaces a good tree.
    try Io.Dir.cwd().deleteTree(io, work);
    try Io.Dir.cwd().createDirPath(io, work);
    const manifest_path = try std.fs.path.join(a, &.{ root, "bootstrap/python/sources.json" });
    const manifest = try Io.Dir.cwd().readFileAlloc(io, manifest_path, a, .unlimited);
    const sources = try std.json.parseFromSliceLeaky(std.json.ArrayHashMap(Source), a, manifest, .{});
    for (sources.map.keys(), sources.map.values()) |name, source| {
        if (mode == .jacpython and !std.mem.eql(u8, name, "cpython")) continue;
        seed.log("build-python: fetch {s}", .{name});
        const gz = try seed.httpGetAlloc(io, init.gpa, source.url);
        defer init.gpa.free(gz);
        const actual = seed.sha256Hex(gz);
        if (!std.mem.eql(u8, &actual, source.sha256))
            seed.die("build-python: checksum mismatch for {s}", .{name});
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
            try retainSources(io, a, dir, if (mode == .jacpython) list else try cSourceManifest(a, list));
        }
    }
    const recipe = try std.fs.path.join(a, &.{ root, "bootstrap/python" });
    const script = try std.fs.path.join(a, &.{ recipe, "build.sh" });
    var child = try std.process.spawn(io, .{ .argv = &.{ "sh", script, platform, work, args[4], recipe, if (mode == .jacpython) host_dest else "", root, @tagName(mode) } });
    const term = try child.wait(io);
    if (term != .exited or term.exited != 0) seed.die("build-python: build failed; logs at {s}/logs", .{work});
    // Cache only the runtime and link archives, not intermediate objects or sources.
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "src" }));
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "deps" }));
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "bin" }));
    try Io.Dir.cwd().deleteTree(io, dest);
    try Io.Dir.cwd().rename(work, Io.Dir.cwd(), dest, io);
    // Verify relocation before allowing a cache hit on the next invocation.
    try runSmoke(io, python, smoke, mode);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = stamp_path, .data = &key });
}

fn buildKey(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8, host_dest: []const u8, mode: Mode) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(@tagName(mode));
    hash.update(platform);
    hash.update(builtin.zig_version_string);
    if (builtin.os.tag == .macos) {
        const sdk = try std.process.run(a, io, .{ .argv = &.{ "xcrun", "--sdk", "macosx", "--show-sdk-version" } });
        if (sdk.term != .exited or sdk.term.exited != 0) return error.MissingMacOSSDK;
        hash.update(std.mem.trim(u8, sdk.stdout, " \r\n"));
    }
    for (inputs) |path| {
        if (mode == .cpython and std.mem.endsWith(u8, path, "/host-compiler.patch")) continue;
        if (mode != .jacpython and (std.mem.endsWith(u8, path, "/compiler-bridge.patch") or
            std.mem.endsWith(u8, path, "/compiler_bridge.c") or std.mem.endsWith(u8, path, "/compiler_bridge.h") or
            std.mem.endsWith(u8, path, "/prepare_seed.py") or std.mem.endsWith(u8, path, "/seed_runtime.py"))) continue;
        const full = try std.fs.path.join(a, &.{ root, path });
        const content = try Io.Dir.cwd().readFileAlloc(io, full, a, .unlimited);
        hash.update(path);
        hash.update(content);
    }
    if (mode == .jacpython) {
        // The producing compiler and its Jac/Python inputs are part of the
        // embedded seed. Source edits must invalidate the reduced runtime.
        for ([_][]const u8{ "jaclang/vendor/typeshed/PIN", "jaclang/vendor/typeshed/TARBALL_SHA256" }) |path| {
            hash.update(path);
            hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, path }), a, .limited(1024)));
        }
        const package_path = try std.fs.path.join(a, &.{ root, "jaclang" });
        var package = try Io.Dir.cwd().openDir(io, package_path, .{ .iterate = true });
        defer package.close(io);
        var walker = try package.walkSelectively(a);
        defer walker.deinit();
        var paths: std.ArrayList([]const u8) = .empty;
        while (try walker.next(io)) |entry| {
            if (entry.kind == .directory) {
                if (!std.mem.startsWith(u8, entry.basename, ".") and
                    !std.mem.eql(u8, entry.basename, "node_modules") and
                    !std.mem.eql(u8, entry.basename, "__pycache__") and
                    !std.mem.eql(u8, entry.basename, "vendor")) try walker.enter(io, entry);
            } else if (entry.kind == .file and (std.mem.endsWith(u8, entry.path, ".jac") or std.mem.endsWith(u8, entry.path, ".py"))) {
                try paths.append(a, try a.dupe(u8, entry.path));
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
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ host_dest, "build-key" }), a, .limited(128)));
    }
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

// The default CPython runtime and JacPython's build-time host retain the C
// compiler. Only the opt-in JacPython runtime applies the marked exclusions.
fn cSourceManifest(a: std.mem.Allocator, manifest: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |line| {
        var value = line;
        if (std.mem.startsWith(u8, line, "# ")) {
            if (std.mem.indexOf(u8, line, "  # removed:")) |end| value = line[2..end];
        }
        try out.appendSlice(a, value);
        try out.append(a, '\n');
    }
    return out.toOwnedSlice(a);
}

fn runSmoke(io: Io, python: []const u8, smoke: []const u8, mode: Mode) !void {
    var check = try std.process.spawn(io, .{ .argv = &.{ python, "-I", smoke, @tagName(mode) } });
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

test "only release targets are accepted" {
    try std.testing.expect(supported("linux-x86_64"));
    try std.testing.expect(supported("macos-aarch64"));
    try std.testing.expect(!supported("windows-x86_64"));
}

test "CPython is the default and JacPython must be explicitly selected" {
    const args = [_][]const u8{ "build_python", "linux-x86_64", "out", "root", "zig" };
    try std.testing.expectEqual(Mode.cpython, try parseMode(&args));
    try std.testing.expectEqual(Mode.jacpython, try parseMode(&(args ++ .{"--jacpython"})));
    try std.testing.expectEqual(Mode.host, try parseMode(&(args ++ .{"--host"})));
    try std.testing.expectError(error.InvalidBuildMode, parseMode(&(args ++ .{"--typo"})));
    try std.testing.expectError(error.InvalidBuildMode, parseMode(args[0..4]));
}

test "C compiler builds restore only marked replacement exclusions" {
    const a = std.testing.allocator;
    const source = "# source allowlist\n# Parser/parser.c  # removed: 100 source lines\n# unused.c\nPython/ceval.c\n";
    const restored = try cSourceManifest(a, source);
    defer a.free(restored);
    try std.testing.expectEqualStrings("# source allowlist\nParser/parser.c\n# unused.c\nPython/ceval.c\n\n", restored);
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

test "compiler modes isolate caches; seed edits invalidate only JacPython" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    for (inputs) |path| {
        if (std.fs.path.dirname(path)) |parent| try tmp.dir.createDirPath(io, parent);
        try tmp.dir.writeFile(io, .{ .sub_path = path, .data = "recipe" });
    }
    try tmp.dir.createDirPath(io, "jaclang/vendor/typeshed");
    for ([_][]const u8{ "PIN", "TARBALL_SHA256" }) |name| {
        try tmp.dir.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ "jaclang/vendor/typeshed", name }), .data = "pin" });
    }
    try tmp.dir.createDirPath(io, "host");
    try tmp.dir.writeFile(io, .{ .sub_path = "host/build-key", .data = "host-key" });
    try tmp.dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "compiler" });
    const root = try tmp.dir.realPathFileAlloc(io, ".", a);
    const host = try std.fs.path.join(a, &.{ root, "host" });
    const before_cpython = try buildKey(io, a, hostPlatform(), root, host, .cpython);
    const before_host = try buildKey(io, a, hostPlatform(), root, host, .host);
    const before_runtime = try buildKey(io, a, hostPlatform(), root, host, .jacpython);
    try std.testing.expect(!std.mem.eql(u8, &before_cpython, &before_host));
    try std.testing.expect(!std.mem.eql(u8, &before_host, &before_runtime));
    try tmp.dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "changed compiler" });
    const changed_runtime = try buildKey(io, a, hostPlatform(), root, host, .jacpython);
    try std.testing.expect(!std.mem.eql(u8, &before_runtime, &changed_runtime));
    try std.testing.expectEqual(before_host, try buildKey(io, a, hostPlatform(), root, host, .host));
    try tmp.dir.writeFile(io, .{ .sub_path = "jaclang/vendor/generated.py", .data = "materialized vendor data" });
    try std.testing.expectEqual(changed_runtime, try buildKey(io, a, hostPlatform(), root, host, .jacpython));
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/seed_runtime.py", .data = "changed seed loader" });
    try std.testing.expect(!std.mem.eql(u8, &changed_runtime, &(try buildKey(io, a, hostPlatform(), root, host, .jacpython))));
    try std.testing.expectEqual(before_host, try buildKey(io, a, hostPlatform(), root, host, .host));
    try std.testing.expectEqual(before_cpython, try buildKey(io, a, hostPlatform(), root, host, .cpython));
    const before_recipe = try buildKey(io, a, hostPlatform(), root, host, .jacpython);
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/cpython-sources.txt", .data = "changed C source selection" });
    try std.testing.expect(!std.mem.eql(u8, &before_host, &(try buildKey(io, a, hostPlatform(), root, host, .host))));
    try std.testing.expect(!std.mem.eql(u8, &before_recipe, &(try buildKey(io, a, hostPlatform(), root, host, .jacpython))));
    const before_host_key = try buildKey(io, a, hostPlatform(), root, host, .jacpython);
    try tmp.dir.writeFile(io, .{ .sub_path = "host/build-key", .data = "rebuilt host" });
    try std.testing.expect(!std.mem.eql(u8, &before_host_key, &(try buildKey(io, a, hostPlatform(), root, host, .jacpython))));
}
