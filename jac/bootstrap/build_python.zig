//! Build the release Python, JacPython, before any Jac tooling can run.
//! Sources are checksum-pinned. A JacPython runs the build: the previous
//! output for this machine's platform, one named with -Djacpython-host, or the
//! pinned seed.
const std = @import("std");
const native_inputs = @import("native_inputs.zig");
const build_jacpython = @import("build_jacpython.zig");
const builtin = @import("builtin");
const seed = @import("seed.zig");
const Io = std.Io;
// sources.json is keyed through hashPins, without the seed.
const inputs = [_][]const u8{
    "bootstrap/build_python.zig",            "bootstrap/seed.zig",
    "bootstrap/python/cpython-sources.txt",  "bootstrap/python/build.sh",
    "bootstrap/python/smoke.py",             "bootstrap/python/finalize.py",
    "bootstrap/python/jacpython-clinic.txt", "bootstrap/build_jacpython.zig",
    "bootstrap/pyconfig.zig",                "bootstrap/pyconfig_probes.zig",
    "bootstrap/python/layouts_check.c",      "bootstrap/python/features_check.c",
    "bootstrap/python/prepare_native.py",    "bootstrap/python/jacpython-modules.txt",
};
// The Jac generators build_jacpython.zig runs (the frozen modules,
// _PyRuntime, build-details.json), relative to the repository root, the Jac
// root's parent.
const generator_inputs = [_][]const u8{
    "scripts/jacpython/common.jac",
    "scripts/jacpython/gen_frozen.jac",
    "scripts/jacpython/gen_runtime_image.jac",
    "scripts/jacpython/gen_build_details.jac",
};
// The generators of the frozen modules and the _PyRuntime image, which a
// native object carries (lowered into it and shipped beside it).
const object_generators = generator_inputs[0..3];
const Source = struct { url: []const u8, sha256: []const u8, version: ?[]const u8 = null };

// sources.json: the pinned archives by name, and under "jacpython-seed" a
// JacPython to build on for each platform that has one. Only linux-x86_64
// has one: another platform's build adopts a native object lowered there
// (-Djacpython-object) and runs Python only on the interpreter it builds.
const seed_pins = "jacpython-seed";
const Pins = struct {
    sources: std.StringArrayHashMapUnmanaged(Source) = .empty,
    seeds: std.StringArrayHashMapUnmanaged(Source) = .empty,
};

fn parsePins(a: std.mem.Allocator, text: []const u8) !Pins {
    const value = try std.json.parseFromSliceLeaky(std.json.Value, a, text, .{});
    if (value != .object) return error.InvalidSourcePins;
    var pins: Pins = .{};
    var entries = value.object.iterator();
    while (entries.next()) |entry| {
        if (!std.mem.eql(u8, entry.key_ptr.*, seed_pins)) {
            try pins.sources.put(a, entry.key_ptr.*, try pinOf(entry.value_ptr.*));
            continue;
        }
        if (entry.value_ptr.* != .object) return error.InvalidSourcePins;
        var platforms = entry.value_ptr.object.iterator();
        while (platforms.next()) |p| try pins.seeds.put(a, p.key_ptr.*, try pinOf(p.value_ptr.*));
    }
    return pins;
}

fn pinOf(value: std.json.Value) !Source {
    if (value != .object) return error.InvalidSourcePins;
    var fields: [3]?[]const u8 = @splat(null);
    for ([_][]const u8{ "url", "sha256", "version" }, &fields) |name, *field| {
        if (value.object.get(name)) |v| field.* = if (v == .string) v.string else return error.InvalidSourcePins;
    }
    return .{ .url = fields[0] orelse return error.InvalidSourcePins, .sha256 = fields[1] orelse return error.InvalidSourcePins, .version = fields[2] };
}

fn readPins(io: Io, a: std.mem.Allocator, root: []const u8) !Pins {
    return parsePins(a, try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, "bootstrap/python/sources.json" }), a, .unlimited));
}

// The archives' pins, which every key covers. The seed's are left out: a seed
// is an interpreter a build runs on, which no key covers (buildKey).
fn hashPins(io: Io, a: std.mem.Allocator, root: []const u8, hash: *std.crypto.hash.sha2.Sha256) !void {
    const pins = try readPins(io, a, root);
    for (pins.sources.keys(), pins.sources.values()) |name, pin| {
        for ([_][]const u8{ name, pin.url, pin.sha256, pin.version orelse "" }) |part| {
            hash.update(part);
            hash.update("\x00");
        }
    }
}

// The interpreter a build runs on: it runs the Jac compiler that lowers the
// native object, and the generators.
//   auto      the previous build's own output when it is finished and on the
//             pinned version, else the pinned seed (the default)
//   <path>    a JacPython: a build output, its install prefix, or a seed
//             (`zig build jacpython-seed-pack`)
// A build that adopts a native object for this machine's platform runs Python
// only on the interpreter it builds, and needs neither.
const host_flag = "--jacpython-host=";
// A native object lowered elsewhere (-Djacpython-object): the directory
// `--object-only` wrote, or the object in it. The build refuses it unless it
// is the object this build would lower.
const adopt_flag = "--adopt-object=";
// Lower only the native object and write it, with its manifest, to this
// directory (`zig build jacpython-object`); the output tree is left alone.
const object_only_flag = "--object-only=";
// Pack the finished output as a seed at this path (`zig build
// jacpython-seed-pack`) instead of building.
const seed_pack_flag = "--seed-pack=";
const HostChoice = union(enum) { auto, installed: []const u8 };
const Host = union(enum) { seed, installed: []const u8 };

fn parseHostChoice(text: []const u8) !HostChoice {
    if (text.len == 0 or std.mem.eql(u8, text, "auto")) return .auto;
    if (std.mem.eql(u8, text, "stock")) return error.StockHostRemoved;
    return .{ .installed = text };
}

// What a build output needs to be a host: the interpreter and its library.
const host_parts = [_][]const u8{ "python/install/bin/python3.14", "python/install/lib/python3.14/os.py" };
// The vendored libraries' archives, headers, notices and CA bundle, with the
// key they were built under (vendoredKey). Every output carries them too.
const vendored_record = "python/build/vendored-key";
const vendored_parts = [_][]const u8{ "python/build/include", "python/build/lib", "python/build/cacert.pem", "python/licenses", vendored_record };

fn pathExists(io: Io, path: []const u8) bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

fn hasParts(io: Io, a: std.mem.Allocator, tree: []const u8, parts: []const []const u8) !bool {
    for (parts) |part| {
        if (!pathExists(io, try std.fs.path.join(a, &.{ tree, part }))) return false;
    }
    return true;
}

// The build output holding `path`: `path` itself, or the output whose install
// prefix it is. Null when either lacks a part a host needs.
fn hostTree(io: Io, a: std.mem.Allocator, path: []const u8) !?[]const u8 {
    var candidates: [2]?[]const u8 = .{ path, null };
    if (std.fs.path.dirname(path)) |python| candidates[1] = std.fs.path.dirname(python);
    for (candidates) |candidate| {
        const tree = candidate orelse continue;
        if (try hasParts(io, a, tree, &host_parts)) return try Io.Dir.cwd().realPathFileAlloc(io, tree, a);
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

fn selectHost(io: Io, a: std.mem.Allocator, choice: HostChoice, dest: []const u8, pin: []const u8, comptime probe: anytype) !Host {
    switch (choice) {
        .auto => {
            // Only a finished output (it has its stamp) on the pinned version
            // that still runs; else the seed.
            if (!pathExists(io, try std.fs.path.join(a, &.{ dest, "build-key" }))) return .seed;
            const tree = try hostTree(io, a, dest) orelse return .seed;
            const version = probe(io, a, try std.fs.path.join(a, &.{ tree, host_parts[0] })) catch return .seed;
            if (!std.mem.eql(u8, version, pin)) return .seed;
            return .{ .installed = tree };
        },
        .installed => |path| {
            const tree = try hostTree(io, a, path) orelse return error.IncompleteHostRuntime;
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

// ---------------------------------------------------------------- the seed

// A seed is a finished output packed by `zig build jacpython-seed-pack`
// (packSeed): the install prefix, build-key, build-host and the native
// object's digest. It is unpacked once, into seeds/<sha256> under the
// source cache's parent, and checked as any host is.
const seed_parts = [_][]const u8{ "build-key", "build-host", "python/build/jacpython-native-sha256", "python/install" };

fn isSha256(text: []const u8) bool {
    if (text.len != 64) return false;
    for (text) |ch| if (!std.ascii.isDigit(ch) and !(ch >= 'a' and ch <= 'f')) return false;
    return true;
}

// The pinned seed for `platform`. A placeholder pin is an error, not a fetch.
fn seedPin(pins: Pins, platform: []const u8) !Source {
    const pin = pins.seeds.get(platform) orelse return error.NoSeedForPlatform;
    if (!isSha256(pin.sha256)) return error.SeedPlaceholder;
    return pin;
}

fn seedDir(a: std.mem.Allocator, cache: []const u8, digest: []const u8) ![]const u8 {
    return std.fs.path.join(a, &.{ cache, "seeds", digest });
}

// The seed for this machine's platform, fetched (or read from the source
// cache) by its pin and unpacked.
fn fetchSeed(io: Io, gpa: std.mem.Allocator, a: std.mem.Allocator, cache: []const u8, platform: []const u8, pins: Pins, comptime fetch: anytype) ![]const u8 {
    const pin = try seedPin(pins, platform);
    const dir = try seedDir(a, cache, pin.sha256);
    if (try unpacked(io, a, dir, pin.sha256)) return dir;
    seed.log("build-python: fetching the JacPython seed for {s} ({s})", .{ platform, pin.sha256[0..16] });
    const bytes = try sourceArchive(io, gpa, try std.fs.path.join(a, &.{ cache, "sources" }), pin, fetch);
    defer gpa.free(bytes);
    return unpackSeed(io, gpa, a, cache, bytes, pin.sha256);
}

fn unpacked(io: Io, a: std.mem.Allocator, dir: []const u8, digest: []const u8) !bool {
    const recorded = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ dir, "seed-sha256" }), a, .limited(128)) catch return false;
    return std.mem.eql(u8, recorded, digest);
}

fn unpackSeed(io: Io, gpa: std.mem.Allocator, a: std.mem.Allocator, cache: []const u8, archive: []const u8, digest: []const u8) ![]const u8 {
    const dir = try seedDir(a, cache, digest);
    if (try unpacked(io, a, dir, digest)) return dir;
    const work = try std.fmt.allocPrint(a, "{s}.work", .{dir});
    try Io.Dir.cwd().deleteTree(io, work);
    try Io.Dir.cwd().createDirPath(io, work);
    var out = try Io.Dir.cwd().openDir(io, work, .{ .iterate = true });
    defer out.close(io);
    try extractTarGz(gpa, io, archive, out, 0);
    try out.writeFile(io, .{ .sub_path = "seed-sha256", .data = digest });
    try Io.Dir.cwd().deleteTree(io, dir);
    try Io.Dir.cwd().rename(work, Io.Dir.cwd(), dir, io);
    return dir;
}

fn isTarball(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".tar.gz") or std.mem.endsWith(u8, path, ".tgz");
}

// Pack the finished output `tree` as a seed at `out` and return its sha256.
// Paths are sorted, and every entry has mtime 0, so packing a tree twice
// gives the same bytes.
fn packSeed(io: Io, gpa: std.mem.Allocator, a: std.mem.Allocator, tree: []const u8, out: []const u8) ![64]u8 {
    if (!pathExists(io, try std.fs.path.join(a, &.{ tree, "build-key" })) or !try hasParts(io, a, tree, &host_parts))
        return error.NotAFinishedOutput;
    const Entry = struct { path: []const u8, kind: Io.File.Kind };
    var entries: std.ArrayList(Entry) = .empty;
    var dir = try Io.Dir.cwd().openDir(io, tree, .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(a);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        const wanted = for (seed_parts) |part| {
            if (std.mem.eql(u8, entry.path, part) or (entry.path.len > part.len and std.mem.startsWith(u8, entry.path, part) and entry.path[part.len] == '/')) break true;
        } else false;
        if (wanted) try entries.append(a, .{ .path = try a.dupe(u8, entry.path), .kind = entry.kind });
    }
    std.mem.sort(Entry, entries.items, {}, struct {
        fn less(_: void, left: Entry, right: Entry) bool {
            return std.mem.lessThan(u8, left.path, right.path);
        }
    }.less);

    var file = try Io.Dir.cwd().createFileAtomic(io, out, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buffer: [64 * 1024]u8 = undefined;
    var writer = file.file.writerStreaming(io, &buffer);
    const window = try gpa.alloc(u8, std.compress.flate.max_window_len);
    defer gpa.free(window);
    var gzip = try std.compress.flate.Compress.init(&writer.interface, window, .gzip, .default);
    var tar: std.tar.Writer = .{ .underlying_writer = &gzip.writer };
    var link: [std.fs.max_path_bytes]u8 = undefined;
    for (entries.items) |entry| switch (entry.kind) {
        .directory => try tar.writeDir(entry.path, .{ .mode = 0o755 }),
        .sym_link => try tar.writeLink(entry.path, link[0..try dir.readLink(io, entry.path, &link)], .{ .mode = 0o777 }),
        .file => {
            const bytes = try dir.readFileAlloc(io, entry.path, gpa, .unlimited);
            defer gpa.free(bytes);
            const stat = try dir.statFile(io, entry.path, .{});
            const executable = stat.permissions.toMode() & 0o100 != 0;
            try tar.writeFileBytes(entry.path, bytes, .{ .mode = if (executable) 0o755 else 0o644 });
        },
        else => return error.UnpackableSeedEntry,
    };
    try tar.finishPedantically();
    try gzip.finish();
    try writer.interface.flush();
    try file.replace(io);
    const packed_bytes = try Io.Dir.cwd().readFileAlloc(io, out, gpa, .unlimited);
    defer gpa.free(packed_bytes);
    return seed.sha256Hex(packed_bytes);
}

// The interpreter this build runs on, and the provenance line build-host
// records for it.
const BuildHost = struct { tree: []const u8, provenance: []const u8 };

fn buildHost(io: Io, gpa: std.mem.Allocator, a: std.mem.Allocator, choice: HostChoice, platform_dest: []const u8, cache: []const u8, build_platform: []const u8, pins: Pins, pin: []const u8) !BuildHost {
    var resolved = choice;
    var origin: []const u8 = "installed";
    if (choice == .installed and isTarball(choice.installed)) {
        const bytes = try Io.Dir.cwd().readFileAlloc(io, choice.installed, gpa, .unlimited);
        defer gpa.free(bytes);
        const digest = seed.sha256Hex(bytes);
        resolved = .{ .installed = try unpackSeed(io, gpa, a, cache, bytes, &digest) };
        origin = try std.fmt.allocPrint(a, "seed {s}", .{choice.installed});
    }
    const named = switch (resolved) {
        .installed => |path| path,
        .auto => platform_dest,
    };
    const host = selectHost(io, a, resolved, platform_dest, pin, probeVersion) catch |err|
        seed.die("build-python: cannot build on {s}: {s}. A host is a JacPython on Python {s}: a finished build output, its install prefix, or a seed (`zig build jacpython-seed-pack`); " ++ host_flag ++ "auto falls back to the pinned seed.", .{ named, @errorName(err), pin });
    const tree = switch (host) {
        .installed => |tree| tree,
        .seed => blk: {
            const dir = fetchSeed(io, gpa, a, cache, build_platform, pins, seed.httpGetAlloc) catch |err| switch (err) {
                error.NoSeedForPlatform => seed.die("build-python: no JacPython to build on: {s} has no finished output and bootstrap/python/sources.json pins no " ++ seed_pins ++ " for {s}. Seeds come from linux-x86_64: on {s}, adopt a native object lowered there (-Djacpython-object=DIR), or name a JacPython with -Djacpython-host=<path>.", .{ platform_dest, build_platform, build_platform }),
                error.SeedPlaceholder => seed.die("build-python: the " ++ seed_pins ++ " pin for {s} in bootstrap/python/sources.json is a placeholder. Pack a seed from a JacPython build with `zig build jacpython-seed-pack`, publish it and pin its URL and sha256, or name a JacPython with -Djacpython-host=<path>.", .{build_platform}),
                else => return err,
            };
            origin = "seed";
            break :blk switch (selectHost(io, a, .{ .installed = dir }, platform_dest, pin, probeVersion) catch |err|
                seed.die("build-python: the pinned seed for {s}, unpacked at {s}, is not a JacPython on Python {s}: {s}", .{ build_platform, dir, pin, @errorName(err) })) {
                .installed => |seeded| seeded,
                .seed => unreachable,
            };
        },
    };
    seed.log("build-python: building on the JacPython at {s}", .{tree});
    return .{ .tree = tree, .provenance = try std.fmt.allocPrint(a, "{s} {s}\n", .{ origin, try hostIdentity(io, a, tree) }) };
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
    var choice_text: []const u8 = "auto";
    var adopt: ?[]const u8 = null;
    var object_out: ?[]const u8 = null;
    var seed_pack: ?[]const u8 = null;
    var kept: std.ArrayList([]const u8) = .empty;
    for (try init.minimal.args.toSlice(a)) |arg| {
        if (std.mem.eql(u8, arg, "--reuse-lowered")) {
            reuse = true;
        } else if (std.mem.startsWith(u8, arg, host_flag)) {
            choice_text = arg[host_flag.len..];
        } else if (std.mem.startsWith(u8, arg, adopt_flag)) {
            adopt = arg[adopt_flag.len..];
        } else if (std.mem.startsWith(u8, arg, object_only_flag)) {
            object_out = arg[object_only_flag.len..];
        } else if (std.mem.startsWith(u8, arg, seed_pack_flag)) {
            seed_pack = arg[seed_pack_flag.len..];
        } else try kept.append(a, arg);
    }
    const args = kept.items;
    if (args.len != 5) seed.die("usage: build_python <os-arch> <destination> <jac-root> <zig> [--reuse-lowered] [" ++ host_flag ++ "auto|<JacPython>] [" ++ adopt_flag ++ "<dir>] [" ++ object_only_flag ++ "<dir>] [" ++ seed_pack_flag ++ "<file>]", .{});
    const choice = parseHostChoice(choice_text) catch
        seed.die("build-python: " ++ host_flag ++ "stock is gone: JacPython is the only Python and builds on JacPython. Use auto (the previous output, else the pinned seed) or a JacPython's path.", .{});
    if (adopt != null and object_out != null)
        seed.die("build-python: " ++ adopt_flag ++ " and " ++ object_only_flag ++ " exclude each other", .{});
    const platform = args[1];
    if (!supported(platform)) seed.die("build-python: unsupported platform {s}", .{platform});
    // A JacPython for another platform is cross-built on this machine's own
    // interpreter: the previous output for this machine's platform beside
    // the destination, or the seed.
    const build_platform = hostPlatform();
    if (!supported(build_platform)) seed.die("build-python: JacPython builds on linux-x86_64, linux-aarch64, macos-x86_64 or macos-aarch64, not {s}", .{build_platform});
    const cross = !std.mem.eql(u8, platform, build_platform);
    const dest = args[2];
    const root = args[3];
    // Seeds and source archives are cached beside the outputs.
    const cache = try std.fs.path.join(a, &.{ root, ".python-build/jacpython" });
    if (seed_pack) |out| {
        const digest = packSeed(io, init.gpa, a, dest, out) catch |err|
            seed.die("build-python: cannot pack {s} as a seed: {s}; build it first with `zig build build-python`", .{ dest, @errorName(err) });
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(a, "{s}.sha256", .{out}), .data = try std.fmt.allocPrint(a, "{s}  {s}\n", .{ &digest, std.fs.path.basename(out) }) });
        seed.log("build-python: packed the seed {s}\n  sha256 {s}\n  pin it under \"" ++ seed_pins ++ "\".\"{s}\" in bootstrap/python/sources.json once it is published", .{ out, &digest, platform });
        return;
    }
    const host_platform_dest = if (cross) try std.fs.path.join(a, &.{ std.fs.path.dirname(dest) orelse ".", build_platform }) else dest;
    const pins = try readPins(io, a, root);
    const pin = (pins.sources.get("cpython") orelse return error.MissingCPythonSource).version orelse return error.MissingCPythonVersion;
    const smoke = try std.fs.path.join(a, &.{ root, "bootstrap/python/smoke.py" });
    const key = try buildKey(io, a, platform, root);
    const vendored = try vendoredKey(io, a, platform, root);
    const stamp_path = try std.fs.path.join(a, &.{ dest, "build-key" });
    const old = Io.Dir.cwd().readFileAlloc(io, stamp_path, a, .limited(128)) catch "";
    const python = try std.fs.path.join(a, &.{ dest, "python/install/bin/python3.14" });
    // An object to adopt is checked for its target and its inputs before
    // anything is built; build_jacpython.zig checks the headers it was
    // lowered against once pyconfig.h is written.
    var adopted: ?build_jacpython.ObjectManifest = null;
    if (adopt) |given| {
        const dir = if (std.mem.endsWith(u8, given, ".o")) std.fs.path.dirname(given) orelse "." else given;
        adopt = dir;
        const tools = try objectTools(io, a, root, try build_jacpython.loweredSources(io, a, dir));
        switch (try build_jacpython.checkObject(io, a, dir, .{ .platform = platform, .tools = &tools, .root = root })) {
            .refused => |why| seed.die("build-python: refusing the prebuilt native object: {s}", .{why}),
            .adopted => |m| adopted = m,
        }
    }
    // A finished tree for this key is reused, unless an object to adopt is
    // given and the tree links another one.
    const links_adopted = if (adopted) |m| blk: {
        const linked = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ dest, "python/build/jacpython-native-sha256" }), a, .limited(128)) catch "";
        break :blk std.mem.eql(u8, std.mem.trim(u8, linked, " \r\n"), m.object);
    } else true;
    if (object_out == null and links_adopted and std.mem.eql(u8, old, &key) and seed.fileExists(io, python)) {
        if (!cross) try runSmoke(io, python, smoke);
        seed.log("build-python: cached {s} ({s})", .{ platform, key[0..16] });
        return;
    }
    const sources_stamp = try std.fs.path.join(a, &.{ dest, "build-key-sources" });
    if (object_out == null and reuse and seed.fileExists(io, python)) {
        if (try sourcesKey(io, a, platform, root, dest)) |lowered| {
            const recorded = Io.Dir.cwd().readFileAlloc(io, sources_stamp, a, .limited(128)) catch "";
            if (std.mem.eql(u8, recorded, &lowered)) {
                if (!cross) try runSmoke(io, python, smoke);
                seed.log("build-python: reusing {s}; the sources it was lowered from are unchanged ({s})", .{ platform, lowered[0..16] });
                return;
            }
        }
    }
    // Something is built: first the vendored libraries for the target, then
    // the interpreter the build runs on. That host lowers the native object,
    // and runs the Python of a build for a platform this machine cannot run.
    // A build that adopts an object for this machine's platform runs Python
    // only on the interpreter it builds, and has no host.
    const vendored_tree = try vendoredLibraries(io, init.gpa, a, platform, dest, root, args[4], pins, &vendored);
    var host_tree: ?[]const u8 = null;
    var provenance: []const u8 = "";
    if (adopted == null or cross) {
        const host = try buildHost(io, init.gpa, a, choice, host_platform_dest, cache, build_platform, pins, pin);
        host_tree = host.tree;
        provenance = host.provenance;
    }
    if (cross) provenance = try std.fmt.allocPrint(a, "{s}cross-built on {s}\n", .{ provenance, build_platform });
    if (adopted) |m| provenance = try std.fmt.allocPrint(a, "{s}adopted native object {s} lowered on {s}\n", .{ provenance, m.object, m.lowered_on });
    const work = try std.fmt.allocPrint(a, "{s}.work", .{dest});
    // A failed build never produces the completion stamp or replaces a good tree.
    try Io.Dir.cwd().deleteTree(io, work);
    try Io.Dir.cwd().createDirPath(io, work);
    try extractSources(io, init.gpa, a, root, work, pins, .cpython);
    build_jacpython.build(io, a, .{
        .platform = platform,
        .work = work,
        .zig = args[4],
        .recipe = try std.fs.path.join(a, &.{ root, "bootstrap/python" }),
        .host = host_tree,
        .vendored = vendored_tree,
        .cross = cross,
        .root = root,
        .jobs = try jobCount(init.environ_map),
        .environ = init.environ_map,
        .object_tools = objectTools,
        .adopt_object = adopt,
        .object_out = object_out,
    }) catch |err| {
        if (err == error.NativeObjectRefused)
            seed.die("build-python: the prebuilt native object was refused (see above); logs at {s}/logs", .{work});
        // A runtime that builds the next one can carry its own defect into
        // the build; another JacPython rules that out.
        if (host_tree) |tree|
            seed.log("build-python: this build ran on the JacPython at {s}; if that runtime is at fault, name another with " ++ host_flag ++ "<path> (zig build -Djacpython-host=...), such as the pinned seed under {s}/seeds", .{ tree, cache });
        seed.die("build-python: build failed ({s}); logs at {s}/logs", .{ @errorName(err), work });
    };
    // Only the object was wanted: the output tree stays as it was.
    if (object_out != null) {
        try Io.Dir.cwd().deleteTree(io, work);
        return;
    }
    // Cache only the runtime and link archives, not intermediate objects or sources.
    for ([_][]const u8{ "src", "deps", "bin", "absent-inputs" }) |rel| {
        try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, rel }));
    }
    // The vendored libraries were built under this key (vendoredLibraries).
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ work, vendored_record }), .data = &vendored });
    if (provenance.len > 0) {
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ work, "build-host" }), .data = provenance });
    }
    try Io.Dir.cwd().deleteTree(io, dest);
    try Io.Dir.cwd().rename(work, Io.Dir.cwd(), dest, io);
    // Verify relocation before allowing a cache hit on the next invocation.
    // A cross-built runtime is checked on its target.
    if (!cross) try runSmoke(io, python, smoke);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = stamp_path, .data = &key });
    if (try sourcesKey(io, a, platform, root, dest)) |lowered| {
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = sources_stamp, .data = &lowered });
    }
}

fn extractTarGz(gpa: std.mem.Allocator, io: Io, archive: []const u8, dir: Io.Dir, strip: u32) !void {
    const window = try gpa.alloc(u8, std.compress.flate.max_window_len);
    defer gpa.free(window);
    var reader = Io.Reader.fixed(archive);
    var decompressor: std.compress.flate.Decompress = .init(&reader, .gzip, window);
    try std.tar.extract(io, dir, &decompressor.reader, .{
        .mode_mode = .executable_bit_only,
        .strip_components = strip,
    });
}

// The pinned archives a build reads, extracted into <work>/src: the CPython
// tree pruned to cpython-sources.txt, and for the vendored libraries' build
// every archive (CPython's for its notices).
fn extractSources(io: Io, gpa: std.mem.Allocator, a: std.mem.Allocator, root: []const u8, work: []const u8, pins: Pins, which: enum { cpython, all }) !void {
    const source_cache = try std.fs.path.join(a, &.{ root, ".python-build/jacpython/sources" });
    for (pins.sources.keys(), pins.sources.values()) |name, source| {
        if (which == .cpython and !std.mem.eql(u8, name, "cpython")) continue;
        seed.log("build-python: source {s}", .{name});
        const gz = try sourceArchive(io, gpa, source_cache, source, seed.httpGetAlloc);
        defer gpa.free(gz);
        const source_dir = try std.fs.path.join(a, &.{ work, "src", name });
        try Io.Dir.cwd().createDirPath(io, source_dir);
        var dir = try Io.Dir.cwd().openDir(io, source_dir, .{ .iterate = true });
        defer dir.close(io);
        try extractTarGz(gpa, io, gz, dir, 1);
        if (std.mem.eql(u8, name, "cpython")) {
            const list_path = try std.fs.path.join(a, &.{ root, "bootstrap/python/cpython-sources.txt" });
            const list = try Io.Dir.cwd().readFileAlloc(io, list_path, a, .limited(128 * 1024));
            try generatedHeadersOnly(list);
            try retainSources(io, a, dir, list);
            try stageGenerated(io, a, root, dir, list);
            // One parser owns the manifest. build_jacpython.zig checks the
            // finished tree against this list rather than reading the
            // markers again.
            try Io.Dir.cwd().writeFile(io, .{
                .sub_path = try std.fs.path.join(a, &.{ work, "absent-inputs" }),
                .data = try absentInputs(a, list),
            });
        }
    }
}

// The vendored libraries a build links and ships: build.sh compiles them for
// the target (cross-compiling them for a platform this machine cannot run)
// into <dest>.vendored, laid out as an output's python/build and
// python/licenses. They are reused while their key holds, from there or from
// the previous output, which carries them.
fn vendoredLibraries(io: Io, gpa: std.mem.Allocator, a: std.mem.Allocator, platform: []const u8, dest: []const u8, root: []const u8, zig: []const u8, pins: Pins, vendored: []const u8) ![]const u8 {
    const tree = try std.fmt.allocPrint(a, "{s}.vendored", .{dest});
    for ([_][]const u8{ tree, dest }) |candidate| {
        if (try hasParts(io, a, candidate, &vendored_parts) and try vendoredMatches(io, a, candidate, vendored)) {
            seed.log("build-python: cached vendored libraries for {s} ({s})", .{ platform, vendored[0..16] });
            return candidate;
        }
    }
    seed.log("build-python: building the vendored libraries for {s}", .{platform});
    const work = try std.fmt.allocPrint(a, "{s}.work", .{tree});
    try Io.Dir.cwd().deleteTree(io, work);
    try Io.Dir.cwd().createDirPath(io, work);
    try extractSources(io, gpa, a, root, work, pins, .all);
    var child = try std.process.spawn(io, .{ .argv = &.{ "sh", try std.fs.path.join(a, &.{ root, "bootstrap/python/build.sh" }), platform, work, zig } });
    const term = try child.wait(io);
    if (term != .exited or term.exited != 0) seed.die("build-python: building {s}'s vendored libraries failed; logs at {s}/logs", .{ platform, work });
    for ([_][]const u8{ "src", "deps", "bin", "cc-cache", "absent-inputs" }) |rel| {
        try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, rel }));
    }
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ work, vendored_record }), .data = vendored });
    try Io.Dir.cwd().deleteTree(io, tree);
    try Io.Dir.cwd().rename(work, Io.Dir.cwd(), tree, io);
    return tree;
}

/// JAC_PYTHON_JOBS: how many compilers run at once (default 4).
fn jobCount(environ: *const std.process.Environ.Map) !usize {
    const text = environ.get("JAC_PYTHON_JOBS") orelse return 4;
    const jobs = std.fmt.parseInt(usize, text, 10) catch return error.InvalidJobCount;
    if (jobs == 0) return error.InvalidJobCount;
    return jobs;
}

// The pinned archives (and seeds) are kept outside the disposable work trees,
// and their digest is rechecked on every use.
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

// The interpreter a build runs on is not part of its key, or a runtime that
// builds the next one would never be reused: the next build runs on it and
// would key differently. The seed and the previous output lower the same
// sources to the same native code; what they hand the build that can differ
// is the frozen modules' bytecode, which each compiles with its own compiler
// (build-host records which one did). The inputs are hashed instead: the
// recipe, which pins the vendored libraries' sources, and the compiler.
fn buildKey(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    try hashRecipe(io, a, platform, root, &hash);
    try hashCompilerTree(io, a, root, &.{}, &hash);
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
    if (std.mem.startsWith(u8, platform, "macos-")) {
        const sdk = try std.process.run(a, io, .{ .argv = &.{ "xcrun", "--sdk", "macosx", "--show-sdk-version" } });
        if (sdk.term != .exited or sdk.term.exited != 0) return error.MissingMacOSSDK;
        hash.update(std.mem.trim(u8, sdk.stdout, " \r\n"));
    }
}

/// What the vendored libraries' archives, headers, notices and CA bundle are
/// built from: their pins and build.sh. Every output records it; libraries
/// whose record differs are built again (vendoredLibraries).
fn vendoredKey(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    try hashToolchain(io, a, platform, &hash);
    try hashPins(io, a, root, &hash);
    hash.update("bootstrap/python/build.sh");
    hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, "bootstrap/python/build.sh" }), a, .unlimited));
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn hashRecipe(io: Io, a: std.mem.Allocator, platform: []const u8, root: []const u8, hash: *std.crypto.hash.sha2.Sha256) !void {
    try hashToolchain(io, a, platform, hash);
    // A runtime cross-built for this platform elsewhere is a seed: its key
    // differs from the one a build here computes, so the target builds its
    // own on it instead of taking it as cached.
    if (!std.mem.eql(u8, platform, hostPlatform())) {
        hash.update("cross-built on");
        hash.update(hostPlatform());
    }
    try hashPins(io, a, root, hash);
    for (inputs) |path| {
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

// What lowers JacPython's native object, apart from `lowered`, the sources
// it lowers (an object's manifest records those one by one, so they are left
// out here): the compiler tree, prepare_native.py, the CPython pin it checks
// the interpreter against (and the Lib/ the frozen modules are compiled
// from), the generators of the two modules the object carries, the typeshed
// pin and the LLVM shim's inputs. Nothing here names the platform or the
// checkout that runs the build, so an object lowered for a target on another
// machine keys the same as one lowered there.
fn objectTools(io: Io, a: std.mem.Allocator, root: []const u8, lowered: []const []const u8) anyerror![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("jacpython-object-tools");
    try hashPins(io, a, root, &hash);
    for ([_][]const u8{ "bootstrap/python/prepare_native.py", "jaclang/vendor/typeshed/PIN", "jaclang/vendor/typeshed/TARBALL_SHA256" }) |path| {
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, path }), a, .unlimited));
    }
    for (object_generators) |path| {
        hash.update(path);
        hash.update(try Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ root, "..", path }), a, .unlimited));
    }
    try native_inputs.hashShimInputs(io, a, root, &hash);
    try hashCompilerTree(io, a, root, lowered, &hash);
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

// The compiler tree's sources, except those `excluded` names (by their path
// in the Jac root).
fn hashCompilerTree(io: Io, a: std.mem.Allocator, root: []const u8, excluded: []const []const u8, hash: *std.crypto.hash.sha2.Sha256) !void {
    var skip: std.StringHashMapUnmanaged(void) = .empty;
    for (excluded) |path| if (std.mem.startsWith(u8, path, "jaclang/")) try skip.put(a, path["jaclang/".len..], {});
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
            if (compilerInput(compiler_inputs, entry.path) and !skip.contains(entry.path)) try paths.append(a, try a.dupe(u8, entry.path));
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

// A commented manifest path carries a marker saying why the build lacks it.
// Every other comment is prose.
const Marker = enum {
    // Needed by neither the build nor the runtime.
    pruned,
    // Written by a Jac generator (the opcode tables, the public C API
    // headers) and checked in as bootstrap/python/generated/<path>.in; the
    // build stages that copy where the archive's was.
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

// Paths the finished build must not contain, one per line, for
// build_jacpython.zig to check against the tree: the pruned entries.
fn absentInputs(a: std.mem.Allocator, manifest: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |line| {
        const excluded = try markedExclusion(line) orelse continue;
        if (excluded.marker != .pruned) continue;
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

fn runSmoke(io: Io, python: []const u8, smoke: []const u8) !void {
    var check = try std.process.spawn(io, .{ .argv = &.{ python, "-X", "faulthandler", "-I", smoke } });
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

const test_pins =
    \\{"cpython": {"url": "https://example.invalid/Python-3.14.6.tgz", "sha256": "c", "version": "3.14.6"},
    \\ "jacpython-seed": {"linux-x86_64": {"url": "TBD-SEED", "sha256": "TBD-SEED"}}}
;
const test_pins_new_seed =
    \\{"cpython": {"url": "https://example.invalid/Python-3.14.6.tgz", "sha256": "c", "version": "3.14.6"},
    \\ "jacpython-seed": {"linux-x86_64": {"url": "https://example.invalid/seed.tar.gz", "sha256": "s"}}}
;
const test_pins_new_cpython =
    \\{"cpython": {"url": "https://example.invalid/Python-3.14.7.tgz", "sha256": "d", "version": "3.14.7"},
    \\ "jacpython-seed": {"linux-x86_64": {"url": "https://example.invalid/seed.tar.gz", "sha256": "s"}}}
;

test {
    // The JacPython builder's and pyconfig.h probes' own tests.
    _ = build_jacpython;
}

test "only release targets are accepted" {
    try std.testing.expect(supported("linux-x86_64"));
    try std.testing.expect(supported("macos-aarch64"));
    try std.testing.expect(!supported("windows-x86_64"));
}

test "manifest markers say why the build lacks a path" {
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
    // A misspelled marker would silently drop a source, and `removed` is no
    // longer a marker.
    try std.testing.expectError(error.UnknownSourceMarker, markedExclusion("# Python/ceval.c  # prunned: 1 source lines"));
    try std.testing.expectError(error.UnknownSourceMarker, markedExclusion("# Parser/parser.c  # removed: 1,953 source lines"));
}

test "the finished tree must lack the pruned entries" {
    const a = std.testing.allocator;
    const source = "# head\n# Lib/turtle.py  # pruned: 4,291 source lines\n# Lib/_opcode_metadata.py  # generated: 371 source lines\nPython/ceval.c\n";
    const absent = try absentInputs(a, source);
    defer a.free(absent);
    try std.testing.expectEqualStrings("Lib/turtle.py\n", absent);
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

test "the build key follows the compiler, the recipe and the archives' pins, not the seed or the host" {
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
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins });
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
    const before_runtime = try buildKey(io, a, hostPlatform(), root);
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler.jac", .data = "changed compiler" });
    const changed_runtime = try buildKey(io, a, hostPlatform(), root);
    try std.testing.expect(!std.mem.eql(u8, &before_runtime, &changed_runtime));
    try dir.writeFile(io, .{ .sub_path = "jaclang/vendor/generated.py", .data = "materialized vendor data" });
    try std.testing.expectEqual(changed_runtime, try buildKey(io, a, hostPlatform(), root));
    try dir.writeFile(io, .{ .sub_path = "native/shim.cpp", .data = "changed emitter" });
    try std.testing.expect(!std.mem.eql(u8, &changed_runtime, &(try buildKey(io, a, hostPlatform(), root))));
    try dir.deleteFile(io, "native/shim.cpp");
    for ([_][]const u8{ "scale/server.jac", "compiler/tests/example.jac", "compiler/example.test.jac", "runtime/test/fixture.py", "compiler/.generated/source.py" }) |rel| {
        const path = try std.fs.path.join(a, &.{ "jaclang", rel });
        try dir.createDirPath(io, std.fs.path.dirname(path).?);
        try dir.writeFile(io, .{ .sub_path = path, .data = "unrelated source" });
        try std.testing.expectEqual(changed_runtime, try buildKey(io, a, hostPlatform(), root));
    }
    try dir.createDirPath(io, "jaclang/runtime/python");
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "new runtime input" });
    try std.testing.expect(!std.mem.eql(u8, &changed_runtime, &(try buildKey(io, a, hostPlatform(), root))));
    try dir.deleteFile(io, "jaclang/runtime/python/eval.jac");
    try std.testing.expectEqual(changed_runtime, try buildKey(io, a, hostPlatform(), root));
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/prepare_native.py", .data = "changed native emitter" });
    try std.testing.expect(!std.mem.eql(u8, &changed_runtime, &(try buildKey(io, a, hostPlatform(), root))));
    const before_generator = try buildKey(io, a, hostPlatform(), root);
    try tmp.dir.writeFile(io, .{ .sub_path = "scripts/jacpython/gen_frozen.jac", .data = "changed generator" });
    try std.testing.expect(!std.mem.eql(u8, &before_generator, &(try buildKey(io, a, hostPlatform(), root))));
    const before_recipe = try buildKey(io, a, hostPlatform(), root);
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/cpython-sources.txt", .data = "changed C source selection" });
    try std.testing.expect(!std.mem.eql(u8, &before_recipe, &(try buildKey(io, a, hostPlatform(), root))));
    // The interpreter that runs the build is not an input: another host, or
    // another pinned seed, keeps the key. An archive's pin does not.
    const before_host_key = try buildKey(io, a, hostPlatform(), root);
    try dir.writeFile(io, .{ .sub_path = "host/build-key", .data = "rebuilt host" });
    try std.testing.expectEqual(before_host_key, try buildKey(io, a, hostPlatform(), root));
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins_new_seed });
    try std.testing.expectEqual(before_host_key, try buildKey(io, a, hostPlatform(), root));
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins_new_cpython });
    try std.testing.expect(!std.mem.eql(u8, &before_host_key, &(try buildKey(io, a, hostPlatform(), root))));
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
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins });
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
    try std.testing.expect(!std.mem.eql(u8, &lowered, &(try buildKey(io, a, hostPlatform(), root))));
    // An edit to a recorded source does not reuse it.
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "edited" });
    const edited = (try sourcesKey(io, a, hostPlatform(), root, built)).?;
    try std.testing.expect(!std.mem.eql(u8, &lowered, &edited));
    // Nor does a recipe or toolchain change.
    try dir.writeFile(io, .{ .sub_path = native_inputs.toolchain_inputs[0], .data = "new toolchain" });
    try std.testing.expect(!std.mem.eql(u8, &edited, &(try sourcesKey(io, a, hostPlatform(), root, built)).?));
}

test "pinned source archives survive builds and reject corrupt cached or fetched bytes" {
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

test "the host choice names the previous output or a JacPython; stock is gone" {
    try std.testing.expectEqual(HostChoice.auto, try parseHostChoice(""));
    try std.testing.expectEqual(HostChoice.auto, try parseHostChoice("auto"));
    try std.testing.expectError(error.StockHostRemoved, parseHostChoice("stock"));
    try std.testing.expectEqualStrings("/opt/jacpython/python/install", (try parseHostChoice("/opt/jacpython/python/install")).installed);
    try std.testing.expect(isTarball("/tmp/jacpython-seed-linux-x86_64.tar.gz") and !isTarball("/opt/jacpython"));
    _ = &main;
}

// A finished output's host parts, its stamp and its vendored libraries under
// `pins`, at `tree` below `base`.
fn testOutput(io: Io, a: std.mem.Allocator, base: std.Io.Dir, tree: []const u8, pins: []const u8) !void {
    for (host_parts ++ vendored_parts) |part| {
        const path = try std.fs.path.join(a, &.{ tree, part });
        if (std.mem.endsWith(u8, part, "include") or std.mem.endsWith(u8, part, "lib") or std.mem.endsWith(u8, part, "licenses")) {
            try base.createDirPath(io, path);
        } else {
            try base.createDirPath(io, std.fs.path.dirname(path).?);
            try base.writeFile(io, .{ .sub_path = path, .data = pins });
        }
    }
    try base.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ tree, "build-key" }), .data = "key" });
}

test "a build runs on the previous output when it can, else on the seed" {
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

    // Nothing built yet: the seed.
    try std.testing.expectEqual(Host.seed, try selectHost(io, a, .auto, out, "3.14.6", Probe.pinned));
    try std.testing.expectError(error.IncompleteHostRuntime, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.pinned));

    // The finished previous output, named by itself or by its install prefix.
    try testOutput(io, a, tmp.dir, "out", "pins");
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .auto, out, "3.14.6", Probe.pinned)).installed);
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.pinned)).installed);
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .{ .installed = out }, base, "3.14.6", Probe.pinned)).installed);
    // A runtime on another version, or one that no longer runs: the default
    // falls back to the seed, a named host is an error.
    try std.testing.expectEqual(Host.seed, try selectHost(io, a, .auto, out, "3.14.6", Probe.older));
    try std.testing.expectEqual(Host.seed, try selectHost(io, a, .auto, out, "3.14.6", Probe.broken));
    try std.testing.expectError(error.HostVersionMismatch, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.older));
    try std.testing.expectError(error.HostDoesNotRun, selectHost(io, a, .{ .installed = prefix }, out, "3.14.6", Probe.broken));
    // A host lends only its interpreter: one whose vendored libraries were
    // built under other pins still hosts.
    try tmp.dir.writeFile(io, .{ .sub_path = "out/" ++ vendored_record, .data = "old pins" });
    try std.testing.expectEqualStrings(out, (try selectHost(io, a, .auto, out, "3.14.6", Probe.pinned)).installed);
    // An unfinished output (no stamp) is never the default host.
    try tmp.dir.deleteFile(io, "out/build-key");
    try std.testing.expectEqual(Host.seed, try selectHost(io, a, .auto, out, "3.14.6", Probe.pinned));
}

test "the seed is pinned per platform, and a placeholder pin refuses before any fetch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const placeholder = try parsePins(a, test_pins);
    try std.testing.expectEqualStrings("3.14.6", placeholder.sources.get("cpython").?.version.?);
    try std.testing.expectEqual(@as(usize, 1), placeholder.sources.count());
    try std.testing.expectError(error.SeedPlaceholder, seedPin(placeholder, "linux-x86_64"));
    try std.testing.expectError(error.NoSeedForPlatform, seedPin(placeholder, "macos-aarch64"));
    const digest = "0123456789abcdef" ** 4;
    const pinned = try parsePins(a, "{\"jacpython-seed\": {\"linux-x86_64\": {\"url\": \"https://example.invalid/seed.tar.gz\", \"sha256\": \"" ++ digest ++ "\"}}}");
    try std.testing.expectEqualStrings(digest, (try seedPin(pinned, "linux-x86_64")).sha256);
    try std.testing.expectError(error.SeedPlaceholder, seedPin(try parsePins(a, "{\"jacpython-seed\": {\"linux-x86_64\": {\"url\": \"u\", \"sha256\": \"" ++ ("0123456789ABCDEF" ** 4) ++ "\"}}}"), "linux-x86_64"));
    try std.testing.expectError(error.InvalidSourcePins, parsePins(a, "{\"cpython\": {\"url\": \"u\"}}"));
    try std.testing.expectError(error.InvalidSourcePins, parsePins(a, "{\"jacpython-seed\": \"u\"}"));
    // The real pins parse, and name the archives the build extracts.
    const real = try parsePins(a, @embedFile("python/sources.json"));
    try std.testing.expect(real.sources.get("cpython") != null and real.sources.get("openssl") != null);
    try std.testing.expect(real.sources.get(seed_pins) == null);
    _ = seedPin(real, "linux-x86_64") catch |err| try std.testing.expect(err == error.SeedPlaceholder);
}

test "a packed seed unpacks to a host, is fetched by its pin once, and is refused when it does not match it" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const gpa = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try testOutput(io, a, tmp.dir, "out", "pins");
    try tmp.dir.writeFile(io, .{ .sub_path = "out/build-host", .data = "seed\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "out/python/install/bin/python3.14", .data = "#!/bin/sh\n" });
    // An executable, a symlink beside it, and a library deep in the tree.
    var exe = try tmp.dir.openFile(io, "out/python/install/bin/python3.14", .{});
    try exe.setPermissions(io, .fromMode(0o755));
    exe.close(io);
    try tmp.dir.symLink(io, "python3.14", "out/python/install/bin/python3", .{});
    try tmp.dir.createDirPath(io, "out/python/install/lib/python3.14/encodings");
    try tmp.dir.writeFile(io, .{ .sub_path = "out/python/install/lib/python3.14/encodings/utf_8.py", .data = "codec\n" });
    const base = try tmp.dir.realPathFileAlloc(io, ".", a);
    const out = try std.fs.path.join(a, &.{ base, "out" });
    const archive = try std.fs.path.join(a, &.{ base, "seed.tar.gz" });

    // Not finished: nothing to pack.
    try std.testing.expectError(error.NotAFinishedOutput, packSeed(io, gpa, a, try std.fs.path.join(a, &.{ base, "missing" }), archive));
    const digest = try packSeed(io, gpa, a, out, archive);
    // The same tree packs to the same bytes.
    try std.testing.expectEqual(digest, try packSeed(io, gpa, a, out, try std.fs.path.join(a, &.{ base, "again.tar.gz" })));
    const bytes = try tmp.dir.readFileAlloc(io, "seed.tar.gz", gpa, .unlimited);
    defer gpa.free(bytes);
    try std.testing.expectEqualStrings(&digest, &seed.sha256Hex(bytes));

    const Fetch = struct {
        var served: []const u8 = "";
        var count: usize = 0;
        fn seedArchive(_: Io, al: std.mem.Allocator, _: []const u8) ![]u8 {
            count += 1;
            return al.dupe(u8, served);
        }
    };
    Fetch.served = bytes;
    const cache = try std.fs.path.join(a, &.{ base, "cache" });
    const pins = try parsePins(a, try std.fmt.allocPrint(a, "{{\"jacpython-seed\": {{\"linux-x86_64\": {{\"url\": \"https://example.invalid/seed.tar.gz\", \"sha256\": \"{s}\"}}}}}}", .{&digest}));
    const tree = try fetchSeed(io, gpa, a, cache, "linux-x86_64", pins, Fetch.seedArchive);
    try std.testing.expectEqual(@as(usize, 1), Fetch.count);
    // The host parts, the provenance and the native digest; not the
    // vendored libraries, which a host no longer lends.
    try std.testing.expectEqualStrings(tree, (try hostTree(io, a, tree)).?);
    var unpacked_dir = try Io.Dir.cwd().openDir(io, tree, .{});
    defer unpacked_dir.close(io);
    try std.testing.expectEqualStrings("codec\n", try unpacked_dir.readFileAlloc(io, "python/install/lib/python3.14/encodings/utf_8.py", a, .unlimited));
    try std.testing.expectEqualStrings("seed\n", try unpacked_dir.readFileAlloc(io, "build-host", a, .unlimited));
    var target: [64]u8 = undefined;
    try std.testing.expectEqualStrings("python3.14", target[0..try unpacked_dir.readLink(io, "python/install/bin/python3", &target)]);
    const stat = try unpacked_dir.statFile(io, "python/install/bin/python3.14", .{});
    try std.testing.expect(stat.permissions.toMode() & 0o100 != 0);
    try std.testing.expectError(error.FileNotFound, unpacked_dir.statFile(io, "python/build/lib", .{}));
    // Unpacked once: the next build neither fetches nor unpacks it again.
    try std.testing.expectEqualStrings(tree, try fetchSeed(io, gpa, a, cache, "linux-x86_64", pins, Fetch.seedArchive));
    try std.testing.expectEqual(@as(usize, 1), Fetch.count);

    // Bytes that are not the pinned seed are refused.
    Fetch.served = "not the seed";
    const other = "fedcba9876543210" ** 4;
    const wrong = try parsePins(a, "{\"jacpython-seed\": {\"linux-x86_64\": {\"url\": \"u\", \"sha256\": \"" ++ other ++ "\"}}}");
    try std.testing.expectError(error.SourceChecksumMismatch, fetchSeed(io, gpa, a, cache, "linux-x86_64", wrong, Fetch.seedArchive));
}

test "the vendored libraries come from their own tree or the previous output while their key holds" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(io, ".", a);
    const out = try std.fs.path.join(a, &.{ base, "out" });
    const key = "v" ** 64;
    // The previous output carries them.
    try testOutput(io, a, tmp.dir, "out", key);
    try std.testing.expectEqualStrings(out, try vendoredLibraries(io, std.testing.allocator, a, "linux-x86_64", out, base, "zig", .{}, key));
    // Their own tree wins.
    try testOutput(io, a, tmp.dir, "out.vendored", key);
    try std.testing.expectEqualStrings(try std.fmt.allocPrint(a, "{s}.vendored", .{out}), try vendoredLibraries(io, std.testing.allocator, a, "linux-x86_64", out, base, "zig", .{}, key));
}

test "the vendored libraries' key follows their pins and build.sh, not the runtime's inputs or the seed" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "bootstrap/python");
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins });
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/build.sh", .data = "recipe" });
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/cpython-sources.txt", .data = "selection" });
    const root = try tmp.dir.realPathFileAlloc(io, ".", a);
    const before = try vendoredKey(io, a, hostPlatform(), root);
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/cpython-sources.txt", .data = "changed selection" });
    try std.testing.expectEqual(before, try vendoredKey(io, a, hostPlatform(), root));
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins_new_seed });
    try std.testing.expectEqual(before, try vendoredKey(io, a, hostPlatform(), root));
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins_new_cpython });
    const pinned = try vendoredKey(io, a, hostPlatform(), root);
    try std.testing.expect(!std.mem.eql(u8, &before, &pinned));
    try tmp.dir.writeFile(io, .{ .sub_path = "bootstrap/python/build.sh", .data = "new recipe" });
    try std.testing.expect(!std.mem.eql(u8, &pinned, &(try vendoredKey(io, a, hostPlatform(), root))));
}

test "every release platform's native object triple is prepare_native.py's" {
    const script = @embedFile("python/prepare_native.py");
    for ([_][]const u8{ "linux-x86_64", "linux-aarch64", "macos-x86_64", "macos-aarch64" }) |platform| {
        var line: [128]u8 = undefined;
        const entry = try std.fmt.bufPrint(&line, "\"{s}\": \"{s}\",", .{ platform, try build_jacpython.llvmTriple(platform) });
        try std.testing.expect(std.mem.indexOf(u8, script, entry) != null);
    }
}

test "the tools that lower the native object are keyed apart from the build machine, the rest of the recipe and the lowered sources" {
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
    for (native_inputs.toolchain_inputs) |path| try dir.writeFile(io, .{ .sub_path = path, .data = "toolchain" });
    try dir.createDirPath(io, "native");
    try dir.createDirPath(io, "jaclang/vendor/typeshed");
    for ([_][]const u8{ "PIN", "TARBALL_SHA256" }) |name| {
        try dir.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ "jaclang/vendor/typeshed", name }), .data = "pin" });
    }
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins });
    try dir.createDirPath(io, "jaclang/runtime/python");
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "runtime" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/lowering.jac", .data = "compiler" });
    try dir.writeFile(io, .{ .sub_path = "jaclang/compiler_inputs.txt", .data = "runtime\n" });
    const root = try dir.realPathFileAlloc(io, ".", a);
    const lowered = &[_][]const u8{"jaclang/runtime/python/eval.jac"};
    const before = try objectTools(io, a, root, lowered);
    // The rest of the recipe builds around the object, not into it.
    try dir.writeFile(io, .{ .sub_path = "bootstrap/build_jacpython.zig", .data = "changed builder" });
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/build.sh", .data = "changed vendored recipe" });
    try tmp.dir.writeFile(io, .{ .sub_path = "scripts/jacpython/gen_build_details.jac", .data = "changed build details" });
    try std.testing.expectEqual(before, try objectTools(io, a, root, lowered));
    // So does the seed the build runs on.
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/sources.json", .data = test_pins_new_seed });
    try std.testing.expectEqual(before, try objectTools(io, a, root, lowered));
    // A lowered source is keyed by the manifest, one digest per source.
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/eval.jac", .data = "changed runtime" });
    try std.testing.expectEqual(before, try objectTools(io, a, root, lowered));
    try std.testing.expect(!std.mem.eql(u8, &before, &(try objectTools(io, a, root, &.{}))));
    try dir.writeFile(io, .{ .sub_path = "bootstrap/python/prepare_native.py", .data = "changed lowering" });
    const lowering = try objectTools(io, a, root, lowered);
    try std.testing.expect(!std.mem.eql(u8, &before, &lowering));
    try dir.writeFile(io, .{ .sub_path = "jaclang/runtime/python/lowering.jac", .data = "changed compiler" });
    const compiler = try objectTools(io, a, root, lowered);
    try std.testing.expect(!std.mem.eql(u8, &lowering, &compiler));
    try tmp.dir.writeFile(io, .{ .sub_path = "scripts/jacpython/gen_frozen.jac", .data = "changed frozen generator" });
    const generator = try objectTools(io, a, root, lowered);
    try std.testing.expect(!std.mem.eql(u8, &compiler, &generator));
    try dir.writeFile(io, .{ .sub_path = "native/shim.cpp", .data = "changed emitter" });
    try std.testing.expect(!std.mem.eql(u8, &generator, &(try objectTools(io, a, root, lowered))));
}

test "a prebuilt native object is adopted only for its target, its inputs and its headers, wherever it was lowered" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "root/jaclang/runtime/python");
    try tmp.dir.writeFile(io, .{ .sub_path = "root/jaclang/runtime/python/eval.jac", .data = "eval" });
    try tmp.dir.writeFile(io, .{ .sub_path = "root/jaclang/runtime/python/inittab.jac", .data = "inittab" });
    const root = try tmp.dir.realPathFileAlloc(io, "root", a);
    try tmp.dir.createDirPath(io, "object");
    const dir = try tmp.dir.realPathFileAlloc(io, "object", a);
    const tools = "t" ** 64;
    const headers = "h" ** 64;
    // A relocatable x86_64 ELF header, then code.
    var elf: [64]u8 = @splat(0);
    @memcpy(elf[0..6], "\x7fELF\x02\x01");
    std.mem.writeInt(u16, elf[18..20], 62, .little);
    const sources = "jaclang/runtime/python/eval.jac\njaclang/runtime/python/inittab.jac\n";
    const Lower = struct {
        fn object(t: std.testing.TmpDir, r: []const u8, platform: []const u8, bytes: []const u8, list: []const u8) !void {
            const al = std.testing.allocator;
            var scratch = std.heap.ArenaAllocator.init(al);
            defer scratch.deinit();
            const sa = scratch.allocator();
            const tio = std.testing.io;
            try t.dir.writeFile(tio, .{ .sub_path = "object/jacpython.o", .data = bytes });
            try t.dir.writeFile(tio, .{ .sub_path = "object/sha256", .data = &seed.sha256Hex(bytes) });
            try t.dir.writeFile(tio, .{ .sub_path = "object/sources", .data = list });
            try t.dir.writeFile(tio, .{ .sub_path = "object/frozen_modules.jac", .data = "frozen" });
            try t.dir.writeFile(tio, .{ .sub_path = "object/runtime_image.jac", .data = "image" });
            try t.dir.writeFile(tio, .{ .sub_path = "object/manifest.json", .data = try build_jacpython.objectManifestJson(tio, sa, .{
                .platform = platform,
                .tools = "t" ** 64,
                .root = r,
                .sources = list,
                .object = bytes,
                .frozen = &seed.sha256Hex("frozen"),
                .runtime_image = &seed.sha256Hex("image"),
                .headers = "h" ** 64,
                .lowered_on = "linux-x86_64",
            }) });
        }
    };
    const expect: build_jacpython.ObjectExpect = .{ .platform = "linux-x86_64", .tools = tools, .root = root, .headers = headers };
    const Check = struct {
        fn refused(verdict: build_jacpython.ObjectCheck, reason: []const u8) !void {
            switch (verdict) {
                .adopted => return error.TestUnexpectedlyAdopted,
                .refused => |why| if (std.mem.indexOf(u8, why, reason) == null) {
                    std.debug.print("refusal without \"{s}\": {s}\n", .{ reason, why });
                    return error.TestWrongRefusal;
                },
            }
        }
    };

    // Not lowered yet: nothing to adopt.
    try Check.refused(try build_jacpython.checkObject(io, a, dir, expect), "has no manifest.json");
    try std.testing.expectEqual(@as(usize, 0), (try build_jacpython.loweredSources(io, a, dir)).len);

    // The object lowered from these sources for this target is adopted,
    // both before pyconfig.h is written and after. Nothing in the manifest
    // names the checkout or the host that lowered it.
    try Lower.object(tmp, root, "linux-x86_64", &elf, sources);
    try std.testing.expectEqual(@as(usize, 2), (try build_jacpython.loweredSources(io, a, dir)).len);
    const manifest = try tmp.dir.readFileAlloc(io, "object/manifest.json", a, .unlimited);
    try std.testing.expect(std.mem.indexOf(u8, manifest, root) == null);
    const early = try build_jacpython.checkObject(io, a, dir, .{ .platform = "linux-x86_64", .tools = tools, .root = root });
    try std.testing.expectEqualStrings("linux-x86_64", early.adopted.platform);
    const adopted = try build_jacpython.checkObject(io, a, dir, expect);
    try std.testing.expectEqualStrings(&seed.sha256Hex(&elf), adopted.adopted.object);
    try std.testing.expectEqual(@as(usize, 2), adopted.adopted.sources.map.count());

    // Another target's build refuses it.
    try Check.refused(try build_jacpython.checkObject(io, a, dir, .{ .platform = "linux-aarch64", .tools = tools, .root = root }), "was lowered for linux-x86_64 (x86_64-unknown-linux-gnu); this build is for linux-aarch64");
    // So does one whose manifest names the target but whose code is another's.
    try Lower.object(tmp, root, "linux-aarch64", &elf, sources);
    try Check.refused(try build_jacpython.checkObject(io, a, dir, .{ .platform = "linux-aarch64", .tools = tools, .root = root }), "is ELF x86_64 code; linux-aarch64 needs ELF aarch64");
    try Lower.object(tmp, root, "linux-x86_64", &elf, sources);

    // An object changed after its manifest was written.
    var patched = elf;
    patched[63] = 1;
    try tmp.dir.writeFile(io, .{ .sub_path = "object/jacpython.o", .data = &patched });
    try Check.refused(try build_jacpython.checkObject(io, a, dir, expect), "is not the object its manifest describes");
    try Lower.object(tmp, root, "linux-x86_64", &elf, sources);

    // The modules lowered into it ship with it, unchanged.
    try tmp.dir.writeFile(io, .{ .sub_path = "object/frozen_modules.jac", .data = "other frozen" });
    try Check.refused(try build_jacpython.checkObject(io, a, dir, expect), "frozen_modules.jac is not the module its manifest says was lowered into the object");
    try Lower.object(tmp, root, "linux-x86_64", &elf, sources);
    try tmp.dir.deleteFile(io, "object/runtime_image.jac");
    try Check.refused(try build_jacpython.checkObject(io, a, dir, expect), "has no runtime_image.jac");
    try Lower.object(tmp, root, "linux-x86_64", &elf, sources);

    // A lowered source edited since: refused, naming it and nothing else.
    try tmp.dir.writeFile(io, .{ .sub_path = "root/jaclang/runtime/python/inittab.jac", .data = "edited inittab" });
    const edited = try build_jacpython.checkObject(io, a, dir, expect);
    try Check.refused(edited, "1 of the sources it was lowered from differ here: jaclang/runtime/python/inittab.jac.");
    try std.testing.expect(std.mem.indexOf(u8, edited.refused, "what lowers it differs") == null);
    try tmp.dir.writeFile(io, .{ .sub_path = "root/jaclang/runtime/python/inittab.jac", .data = "inittab" });
    try std.testing.expect(try build_jacpython.checkObject(io, a, dir, expect) == .adopted);
    // Another compiler, prepare_native.py, generator or LLVM shim.
    var other = expect;
    other.tools = "u" ** 64;
    const tooled = try build_jacpython.checkObject(io, a, dir, other);
    try Check.refused(tooled, "was not lowered from this checkout: what lowers it differs");
    // Both at once: each named once.
    try tmp.dir.writeFile(io, .{ .sub_path = "root/jaclang/runtime/python/eval.jac", .data = "edited eval" });
    try Check.refused(try build_jacpython.checkObject(io, a, dir, other), "differ here: jaclang/runtime/python/eval.jac; and what lowers it differs");
    try tmp.dir.writeFile(io, .{ .sub_path = "root/jaclang/runtime/python/eval.jac", .data = "eval" });

    // The headers the C around it is compiled against.
    other = expect;
    other.headers = "g" ** 64;
    try Check.refused(try build_jacpython.checkObject(io, a, dir, other), "was lowered against another pyconfig.h or Include/");

    // A sources record that disagrees with the manifest.
    try tmp.dir.writeFile(io, .{ .sub_path = "object/sources", .data = "jaclang/runtime/python/eval.jac\n" });
    try Check.refused(try build_jacpython.checkObject(io, a, dir, expect), "lists 1 sources and its manifest 2");
}
