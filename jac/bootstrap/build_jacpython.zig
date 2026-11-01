//! The JacPython runtime, built without autoconf or make. build_python.zig has
//! extracted the pruned CPython tree; this lowers the native Jac object on the
//! host JacPython (or adopts one lowered elsewhere), writes pyconfig.h from
//! compiler probes, compiles the C that remains with the flags CPython's
//! makefile uses, links libpython and the interpreter, and installs the tree
//! `make install` installs.
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const Environ = std.process.Environ;
const builtin = @import("builtin");
const pyconfig = @import("pyconfig.zig");

pub const Options = struct {
    platform: []const u8,
    /// The build tree: src/cpython (extracted), and the install prefix
    /// python/install.
    work: []const u8,
    zig: []const u8,
    /// bootstrap/python.
    recipe: []const u8,
    /// The JacPython output the build runs on (its python/install): it lowers
    /// the native object and runs the generators. Null for a build that
    /// adopts an object for this machine's platform, which runs Python only
    /// on the interpreter it builds.
    host: ?[]const u8 = null,
    /// The tree whose python/build (the vendored archives, their headers and
    /// the CA bundle) and python/licenses this build links and ships, as
    /// build.sh built them for the target.
    vendored: []const u8,
    /// The target is another platform. Every step that runs Python runs on
    /// the host, told the target as CPython's own cross builds tell their
    /// build Python, and the smoke test is left to the target.
    cross: bool = false,
    /// The Jac root (jac/).
    root: []const u8,
    jobs: usize,
    environ: *const Environ.Map,
    /// What lowers the native object apart from the sources it lowers:
    /// build_python.zig's objectTools. Recorded in the object's manifest.
    object_tools: ?ToolsFn = null,
    /// A native object lowered elsewhere (a directory the native stage
    /// wrote, see object_files): checked against this build and linked in
    /// place of lowering one.
    adopt_object: ?[]const u8 = null,
    /// Stop after the native stage and copy the object with its manifest to
    /// this directory.
    object_out: ?[]const u8 = null,
};

const version = "3.14";
const soabi_version = "314";

const Platform = struct {
    os: pyconfig.Os,
    arch: pyconfig.Arch,
    /// zig cc -target.
    target: []const u8,
    /// The LLVM triple prepare_native.py lowers the native object for.
    llvm_triple: []const u8,
    /// PLATFORM_TRIPLET: the sysconfigdata name, SOABI and LIBPL suffix.
    triplet: []const u8,
    /// sysconfig.get_platform() on the target: _PYTHON_HOST_PLATFORM when
    /// another platform's interpreter writes its sysconfig data.
    sysconfig_platform: []const u8,
    deployment_target: ?[]const u8 = null,
};

fn platformOf(name: []const u8) !Platform {
    if (std.mem.eql(u8, name, "linux-x86_64")) return .{ .os = .linux, .arch = .x86_64, .target = "x86_64-linux-gnu.2.17", .llvm_triple = "x86_64-unknown-linux-gnu", .triplet = "x86_64-linux-gnu", .sysconfig_platform = "linux-x86_64" };
    if (std.mem.eql(u8, name, "linux-aarch64")) return .{ .os = .linux, .arch = .aarch64, .target = "aarch64-linux-gnu.2.17", .llvm_triple = "aarch64-unknown-linux-gnu", .triplet = "aarch64-linux-gnu", .sysconfig_platform = "linux-aarch64" };
    if (std.mem.eql(u8, name, "macos-x86_64")) return .{ .os = .macos, .arch = .x86_64, .target = "x86_64-macos.12.0", .llvm_triple = "x86_64-apple-macosx12.0.0", .triplet = "darwin", .sysconfig_platform = "macosx-12.0-x86_64", .deployment_target = "12.0" };
    if (std.mem.eql(u8, name, "macos-aarch64")) return .{ .os = .macos, .arch = .aarch64, .target = "aarch64-macos.11.0", .llvm_triple = "arm64-apple-macosx11.0.0", .triplet = "darwin", .sysconfig_platform = "macosx-11.0-arm64", .deployment_target = "11.0" };
    return error.UnsupportedPlatform;
}

const Ctx = struct {
    io: Io,
    a: Allocator,
    o: Options,
    p: Platform,
    src: []const u8,
    deps: []const u8,
    prefix: []const u8,
    logs: []const u8,
    cache: []const u8,
    env: Environ.Map,
    /// The C compiler command: zig cc for the target, plus the run path the
    /// relocatable interpreter needs and, on macOS, the SDK.
    cc: []const []const u8,
    probes: pyconfig.Results = .{},
    log: ?Io.File = null,

    fn path(c: *Ctx, parts: []const []const u8) []const u8 {
        return std.fs.path.join(c.a, parts) catch @panic("out of memory");
    }

    fn print(c: *Ctx, comptime fmt: []const u8, args: anytype) void {
        const line = std.fmt.allocPrint(c.a, fmt ++ "\n", args) catch return;
        if (c.log) |f| f.writeStreamingAll(c.io, line) catch {};
    }
};

pub fn build(io: Io, a: Allocator, o: Options) !void {
    const p = try platformOf(o.platform);
    var c: Ctx = .{
        .io = io,
        .a = a,
        .o = o,
        .p = p,
        .src = try std.fs.path.join(a, &.{ o.work, "src/cpython" }),
        .deps = try std.fs.path.join(a, &.{ o.work, "deps" }),
        .prefix = try std.fs.path.join(a, &.{ o.work, "python/install" }),
        .logs = try std.fs.path.join(a, &.{ o.work, "logs" }),
        .cache = try std.fs.path.join(a, &.{ o.work, "cc-cache" }),
        .env = try o.environ.clone(a),
        .cc = &.{},
    };
    for ([_][]const u8{ c.prefix, c.logs, c.path(&.{ c.deps, "lib" }), c.path(&.{ c.deps, "include" }) }) |dir| {
        try Io.Dir.cwd().createDirPath(io, dir);
    }
    // Only the pinned toolchain and the vendored libraries reach the compiler.
    for ([_][]const u8{ "CFLAGS", "CPPFLAGS", "LDFLAGS", "CXXFLAGS", "CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "LIBRARY_PATH", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "PYTHONPATH", "PYTHONHOME", "_PYTHON_HOST_PLATFORM", "_PYTHON_SYSCONFIGDATA_NAME", "_PYTHON_SYSCONFIGDATA_PATH", "_PYTHON_PROJECT_BASE" }) |name| {
        _ = c.env.swapRemove(name);
    }
    // Transient compiler caches stay in the build tree.
    try c.env.put("ZIG_LOCAL_CACHE_DIR", c.cache);
    try c.env.put("ZIG_GLOBAL_CACHE_DIR", c.cache);
    try c.env.put("SOURCE_DATE_EPOCH", "0");
    var cc: std.ArrayList([]const u8) = .empty;
    try cc.appendSlice(a, &.{ o.zig, "cc", "-target", p.target });
    if (p.os == .macos) {
        try c.env.put("MACOSX_DEPLOYMENT_TARGET", p.deployment_target.?);
        const sdk = try std.process.run(a, io, .{ .argv = &.{ "xcrun", "--sdk", "macosx", "--show-sdk-path" } });
        if (sdk.term != .exited or sdk.term.exited != 0) return error.MissingMacOSSDK;
        const root = std.mem.trim(u8, sdk.stdout, " \r\n");
        // Framework stubs reexport libraries from the SDK, including libobjc.
        try cc.appendSlice(a, &.{ "-isysroot", root, "-isystem", c.path(&.{ root, "usr/include" }), "-L", c.path(&.{ root, "usr/lib" }), "-F", c.path(&.{ root, "System/Library/Frameworks" }) });
    }
    try cc.appendSlice(a, &.{ "-Wno-unused-command-line-argument", "-Wno-error=date-time" });
    // The shared interpreter must survive relocation into the Jac payload.
    try cc.append(a, if (p.os == .linux) "-Wl,-rpath,$ORIGIN/../lib" else "-Wl,-rpath,@loader_path/../lib");
    c.cc = cc.items;

    // The vendored libraries and their notices.
    const vendored_build = c.path(&.{ o.vendored, "python/build" });
    try copyTree(&c, c.path(&.{ vendored_build, "include" }), c.path(&.{ c.deps, "include" }));
    try copyMatching(&c, c.path(&.{ vendored_build, "lib" }), c.path(&.{ c.deps, "lib" }), ".a");
    try copyTree(&c, c.path(&.{ o.vendored, "python/licenses" }), c.path(&.{ o.work, "python/licenses" }));

    try step(&c, "pyconfig", writePyconfig, .{&c});

    // The frozen modules (importlib's bootstrap, zipimport, getpath.py and the
    // startup stdlib), compiled and marshalled by the host JacPython as
    // _freeze_module.py would, and written as one Jac module the native
    // object links. _PyRuntime's initializer, which only the C preprocessor
    // builds from pycore_runtime_init.h, compiled for this target against
    // this tree's pyconfig.h and written as the C data of another. Then the
    // native object itself. An adopted object carries both modules, from the
    // build that lowered it, so this build's host generates neither.
    const native = c.path(&.{ o.work, "native" });
    const frozen = c.path(&.{ native, frozen_module });
    const runtime_image = c.path(&.{ native, runtime_image_module });
    try Io.Dir.cwd().createDirPath(io, native);
    try writeFile(&c, c.path(&.{ native, "jac.toml" }), unit_root_marker, mode_data);
    if (o.adopt_object) |dir| {
        try step(&c, "adopt-native", adoptObject, .{ &c, dir, native });
    } else {
        const host = try hostPython(&c);
        try step(&c, "frozen", generate, .{ &c, host, try frozenArgs(&c, frozen) });
        try step(&c, "runtime_image", generate, .{ &c, host, try runtimeImageArgs(&c, runtime_image) });
        try step(&c, "native", runArgv, .{ &c, &[_][]const u8{ host, "-I", c.path(&.{ o.recipe, "prepare_native.py" }), o.root, native, o.platform, frozen, runtime_image }, null });
        try step(&c, "native-manifest", writeObjectManifest, .{ &c, native });
    }
    if (o.object_out) |out| {
        const tmp = try std.fmt.allocPrint(a, "{s}.tmp", .{out});
        try Io.Dir.cwd().deleteTree(io, tmp);
        try Io.Dir.cwd().createDirPath(io, tmp);
        for (object_files) |name| {
            try Io.Dir.copyFile(.cwd(), c.path(&.{ native, name }), .cwd(), c.path(&.{ tmp, name }), io, .{});
        }
        try Io.Dir.cwd().deleteTree(io, out);
        try Io.Dir.cwd().rename(tmp, Io.Dir.cwd(), out, io);
        std.debug.print("build-python: {s}'s native object and its manifest are in {s}\n", .{ o.platform, out });
        return;
    }

    try step(&c, "compile", compile, .{&c});
    try step(&c, "link", link, .{&c});
    try step(&c, "install", install, .{&c});
    try step(&c, "sysconfig", sysconfig, .{&c});
    try step(&c, "compileall", compileall, .{&c});
    try step(&c, "install-tools", installTools, .{&c});
    try absentInputs(&c);

    try step(&c, "finalize", runArgv, .{ &c, &[_][]const u8{ try installedPython(&c), "-I", c.path(&.{ o.recipe, "finalize.py" }), c.prefix }, null });
    const build_dir = c.path(&.{ o.work, "python/build" });
    try Io.Dir.cwd().createDirPath(io, c.path(&.{ build_dir, "lib" }));
    try copyMatching(&c, c.path(&.{ c.deps, "lib" }), c.path(&.{ build_dir, "lib" }), ".a");
    // The headers too: with the archives, they let the next build link them
    // without building them again (build_python.zig vendoredLibraries).
    try copyTree(&c, c.path(&.{ c.deps, "include" }), c.path(&.{ build_dir, "include" }));
    try Io.Dir.copyFile(.cwd(), c.path(&.{ vendored_build, "cacert.pem" }), .cwd(), c.path(&.{ build_dir, "cacert.pem" }), io, .{});
    try Io.Dir.copyFile(.cwd(), c.path(&.{ native, "sha256" }), .cwd(), c.path(&.{ build_dir, "jacpython-native-sha256" }), io, .{});
    try Io.Dir.copyFile(.cwd(), c.path(&.{ native, "sources" }), .cwd(), c.path(&.{ build_dir, "jacpython-native-sources" }), io, .{});
    try Io.Dir.cwd().deleteTree(io, native);
    try c.env.put("PYTHONFAULTHANDLER", "1");
    if (o.cross) {
        std.debug.print("build-python: smoke skipped: {s} does not run on this machine; run bootstrap/python/smoke.py with its interpreter on the target\n", .{o.platform});
    } else {
        try step(&c, "smoke", runArgv, .{ &c, &[_][]const u8{ c.path(&.{ c.prefix, "bin/python" ++ version }), "-X", "faulthandler", "-I", c.path(&.{ o.recipe, "smoke.py" }) }, null });
    }
    // No compiled test modules, docs, or configuration machinery in the runtime.
    for ([_][]const u8{ "share", "lib/python" ++ version ++ "/test", "lib/python" ++ version ++ "/idlelib", "lib/python" ++ version ++ "/tkinter", "lib/python" ++ version ++ "/turtledemo" }) |rel| {
        try Io.Dir.cwd().deleteTree(io, c.path(&.{ c.prefix, rel }));
    }
    std.debug.print("build-python: runtime and native archives ready\n", .{});
}

fn hostPython(c: *Ctx) ![]const u8 {
    const host = c.o.host orelse return error.NoHostInterpreter;
    return c.path(&.{ host, "python/install/bin/python" ++ version });
}

/// The interpreter that runs Python over the installed tree (sysconfig,
/// build-details.json, compileall, finalize): the new one, or the host when
/// the target is another platform. The byte-code is the same either way.
fn installedPython(c: *Ctx) ![]const u8 {
    return if (c.o.cross) hostPython(c) else layout(c).exename;
}

/// One build step: its own log under logs/, the last lines of which are
/// printed when it fails; the compiler cache is dropped after it.
fn step(c: *Ctx, label: []const u8, comptime f: anytype, args: anytype) !void {
    std.debug.print("build-python: {s}\n", .{label});
    const log_path = c.path(&.{ c.logs, try std.fmt.allocPrint(c.a, "{s}.log", .{label}) });
    c.log = try Io.Dir.cwd().createFile(c.io, log_path, .{});
    const result = @call(.auto, f, args);
    c.log.?.close(c.io);
    c.log = null;
    Io.Dir.cwd().deleteTree(c.io, c.cache) catch {};
    result catch |err| {
        const text = Io.Dir.cwd().readFileAlloc(c.io, log_path, c.a, .limited(64 * 1024 * 1024)) catch "";
        var start = text.len;
        var lines: usize = 0;
        while (start > 0 and lines <= 80) : (start -= 1) {
            if (text[start - 1] == '\n') lines += 1;
        }
        std.debug.print("{s}\nbuild-python: {s} failed: {s}\n", .{ text[start..], label, @errorName(err) });
        return err;
    };
}

fn spawn(c: *Ctx, argv: []const []const u8, cwd: ?[]const u8) !std.process.Child {
    c.print("+ {s}", .{try std.mem.join(c.a, " ", argv)});
    const out: std.process.SpawnOptions.StdIo = if (c.log) |f| .{ .file = f } else .inherit;
    return std.process.spawn(c.io, .{
        .argv = argv,
        .cwd = if (cwd) |d| .{ .path = d } else .inherit,
        .environ_map = &c.env,
        .stdin = .ignore,
        .stdout = out,
        .stderr = out,
    });
}

fn runArgv(c: *Ctx, argv: []const []const u8, cwd: ?[]const u8) !void {
    var child = try spawn(c, argv, cwd);
    const term = try child.wait(c.io);
    if (term != .exited or term.exited != 0) return error.CommandFailed;
}

/// One of scripts/jacpython's generators, run by `python` with the
/// checkout's jaclang on its path; the generator's main() takes the arguments.
fn generate(c: *Ctx, python: []const u8, args: []const []const u8) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(c.a, &.{
        python,   "-I",                                           "-c",
        \\import importlib, sys
        \\sys.path[:0] = sys.argv[1:3]
        \\import jaclang
        \\importlib.import_module(sys.argv[3]).main(sys.argv[4:])
        ,
        c.o.root, c.path(&.{ c.o.root, "../scripts/jacpython" }),
    });
    try argv.appendSlice(c.a, args);
    try runArgv(c, argv.items, null);
}

/// gen_frozen's arguments.
fn frozenArgs(c: *Ctx, output: []const u8) ![]const []const u8 {
    return c.a.dupe([]const u8, &.{ "gen_frozen", "--source", c.src, "--output", output });
}

/// gen_runtime_image's arguments: this tree's configured headers, then the
/// target's C compiler.
fn runtimeImageArgs(c: *Ctx, output: []const u8) ![]const []const u8 {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(c.a, &.{ "gen_runtime_image", "--include", c.src, "--include", c.path(&.{ c.src, "Include" }) });
    try argv.appendSlice(c.a, &.{ "--platform", c.o.platform, "--output", output, "--" });
    try argv.appendSlice(c.a, c.cc);
    return argv.items;
}

// ------------------------------------------------------------- native object

// The Jac compiler names a module's native symbols (its global
// initializer, among others) by its path below the nearest unit root, a
// directory holding jac.toml, prefixed with that directory's name. Without a
// root of their own the generated modules would be named by their path from
// the repository root, which starts with the checkout's directory name, so
// the same object lowered in two checkouts would differ. This file makes the
// native directory their root: they are native/frozen_modules.jac and
// native/runtime_image.jac in every checkout. The modules import nothing
// from Jac, and the compile takes its configuration from the working
// directory, so the file changes nothing else.
const unit_root_marker = "# The unit root of the generated modules (build_jacpython.zig).\n";

const frozen_module = "frozen_modules.jac";
const runtime_image_module = "runtime_image.jac";

/// What the native stage leaves next to the object, and what a directory
/// given to -Djacpython-object holds: the object, its sha256 and the sources
/// it was lowered from (both recorded in python/build), the two generated
/// modules lowered into it, and the manifest another build checks the
/// object against before it links it.
pub const object_files = [_][]const u8{ "jacpython.o", "sha256", "sources", frozen_module, runtime_image_module, "manifest.json" };

/// build_python.zig's objectTools: the digest of what lowers an object, given
/// the sources it lowers (which it leaves out).
pub const ToolsFn = *const fn (Io, Allocator, []const u8, []const []const u8) anyerror![64]u8;

/// manifest.json.
pub const ObjectManifest = struct {
    /// The os-arch the object was lowered for, and prepare_native.py's triple.
    platform: []const u8,
    triple: []const u8,
    /// objectInputs over `tools` and `sources`: a build adopts the object
    /// only when what it would lower gives the same digest.
    inputs: []const u8,
    /// What lowers the object apart from the sources it lowers
    /// (build_python.zig's objectTools).
    tools: []const u8,
    /// The sha256 of every lowered source, by its path in the Jac root.
    sources: std.json.ArrayHashMap([]const u8),
    /// The sha256 of the two generated modules lowered into the object and
    /// shipped beside it: the frozen modules, marshalled by the lowering
    /// build's host, and the _PyRuntime image.
    frozen: []const u8,
    runtime_image: []const u8,
    /// headersDigest of the tree the object was lowered for: the pyconfig.h
    /// and Include/ the _PyRuntime image was computed from, which a build
    /// compiles the C around the object against.
    headers: []const u8,
    /// The sha256 of jacpython.o.
    object: []const u8,
    lowered_on: []const u8,
};

fn sha256Hex(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn fileSha256(io: Io, a: Allocator, file_path: []const u8) ![64]u8 {
    return sha256Hex(try Io.Dir.cwd().readFileAlloc(io, file_path, a, .unlimited));
}

/// The digest an object's manifest records as `inputs`.
pub fn objectInputs(tools: []const u8, names: []const []const u8, digests: []const []const u8) [64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("jacpython-object-inputs\x00");
    hash.update(tools);
    for (names, digests) |name, digest| {
        hash.update("\x00");
        hash.update(name);
        hash.update("\x00");
        hash.update(digest);
    }
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

const SourceDigests = struct { names: []const []const u8, digests: []const []const u8 };

/// The sha256 of each source a `sources` record lists, read from the Jac
/// root; "missing" for one that is not there.
fn sourceDigests(io: Io, a: Allocator, root: []const u8, list: []const u8) !SourceDigests {
    var names: std.ArrayList([]const u8) = .empty;
    var digests: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, list, '\n');
    while (lines.next()) |raw| {
        const rel = std.mem.trim(u8, raw, " \r\t");
        if (rel.len == 0) continue;
        try names.append(a, rel);
        const digest = fileSha256(io, a, try std.fs.path.join(a, &.{ root, rel })) catch |err| switch (err) {
            error.FileNotFound => {
                try digests.append(a, "missing");
                continue;
            },
            else => return err,
        };
        try digests.append(a, try a.dupe(u8, &digest));
    }
    return .{ .names = names.items, .digests = digests.items };
}

const ObjectFormat = struct { os: pyconfig.Os, arch: pyconfig.Arch };

/// The OS and CPU a relocatable object's header names: a 64-bit
/// little-endian ELF (Linux) or Mach-O (macOS) object.
fn objectFormat(bytes: []const u8) ?ObjectFormat {
    if (bytes.len >= 20 and std.mem.eql(u8, bytes[0..4], "\x7fELF") and bytes[4] == 2 and bytes[5] == 1) {
        return switch (std.mem.readInt(u16, bytes[18..20], .little)) {
            62 => .{ .os = .linux, .arch = .x86_64 },
            183 => .{ .os = .linux, .arch = .aarch64 },
            else => null,
        };
    }
    if (bytes.len >= 8 and std.mem.readInt(u32, bytes[0..4], .little) == 0xfeedfacf) {
        return switch (std.mem.readInt(u32, bytes[4..8], .little)) {
            0x01000007 => .{ .os = .macos, .arch = .x86_64 },
            0x0100000c => .{ .os = .macos, .arch = .aarch64 },
            else => null,
        };
    }
    return null;
}

fn describeFormat(format: ?ObjectFormat) []const u8 {
    const f = format orelse return "neither a 64-bit ELF nor a Mach-O object for a release target";
    return switch (f.os) {
        .linux => if (f.arch == .x86_64) "ELF x86_64" else "ELF aarch64",
        .macos => if (f.arch == .x86_64) "Mach-O x86_64" else "Mach-O arm64",
    };
}

/// What a manifest is made from.
pub const ObjectRecord = struct {
    platform: []const u8,
    tools: []const u8,
    root: []const u8,
    /// The `sources` record prepare_native.py wrote.
    sources: []const u8,
    object: []const u8,
    frozen: []const u8,
    runtime_image: []const u8,
    headers: []const u8,
    lowered_on: []const u8,
};

/// manifest.json for an object, as the native stage writes it.
pub fn objectManifestJson(io: Io, a: Allocator, r: ObjectRecord) ![]const u8 {
    const lowered = try sourceDigests(io, a, r.root, r.sources);
    var sources: std.json.ArrayHashMap([]const u8) = .{};
    for (lowered.names, lowered.digests) |name, digest| try sources.map.put(a, name, digest);
    const inputs = objectInputs(r.tools, lowered.names, lowered.digests);
    const object_sha = sha256Hex(r.object);
    const manifest: ObjectManifest = .{
        .platform = r.platform,
        .triple = (try platformOf(r.platform)).llvm_triple,
        .inputs = &inputs,
        .tools = r.tools,
        .sources = sources,
        .frozen = r.frozen,
        .runtime_image = r.runtime_image,
        .headers = r.headers,
        .object = &object_sha,
        .lowered_on = r.lowered_on,
    };
    return std.fmt.allocPrint(a, "{s}\n", .{try std.json.Stringify.valueAlloc(a, manifest, .{ .whitespace = .indent_1 })});
}

/// After prepare_native.py: the manifest that lets another build, on this
/// machine or another, check the object before it links it.
fn writeObjectManifest(c: *Ctx, native: []const u8) !void {
    const object = try Io.Dir.cwd().readFileAlloc(c.io, c.path(&.{ native, "jacpython.o" }), c.a, .unlimited);
    const object_sha = sha256Hex(object);
    if (!std.mem.eql(u8, std.mem.trim(u8, try readFile(c, c.path(&.{ native, "sha256" })), " \r\n"), &object_sha))
        return error.NativeObjectDigestMismatch;
    const format = objectFormat(object);
    if (format == null or format.?.os != c.p.os or format.?.arch != c.p.arch) {
        c.print("jacpython.o is {s} code; {s} needs {s}", .{ describeFormat(format), c.o.platform, describeFormat(.{ .os = c.p.os, .arch = c.p.arch }) });
        return error.NativeObjectForAnotherTarget;
    }
    const frozen_sha = try fileSha256(c.io, c.a, c.path(&.{ native, frozen_module }));
    const image_sha = try fileSha256(c.io, c.a, c.path(&.{ native, runtime_image_module }));
    const headers = try headersDigest(c);
    const tools = try c.o.object_tools.?(c.io, c.a, c.o.root, try loweredSources(c.io, c.a, native));
    const text = try objectManifestJson(c.io, c.a, .{
        .platform = c.o.platform,
        .tools = &tools,
        .root = c.o.root,
        .sources = try readFile(c, c.path(&.{ native, "sources" })),
        .object = object,
        .frozen = &frozen_sha,
        .runtime_image = &image_sha,
        .headers = &headers,
        .lowered_on = try std.fmt.allocPrint(c.a, "{s}-{s}", .{ @tagName(buildOs()), @tagName(buildArch()) }),
    });
    try writeFile(c, c.path(&.{ native, "manifest.json" }), text, mode_data);
    c.print("{s} jacpython.o {s}, manifest written", .{ c.o.platform, object_sha[0..16] });
}

/// prepare_native.py's triple for a release platform.
pub fn llvmTriple(platform: []const u8) ![]const u8 {
    return (try platformOf(platform)).llvm_triple;
}

/// What the build adopting an object knows to check it against: `tools` is
/// objectTools over the object's own `sources` record (loweredSources).
/// `headers` is null before pyconfig.h is written, as in build_python.zig's
/// early check.
pub const ObjectExpect = struct {
    platform: []const u8,
    tools: []const u8,
    root: []const u8,
    headers: ?[]const u8 = null,
};

/// The paths an object's `sources` record lists, in the Jac root; none when
/// there is no record (checkObject refuses that directory).
pub fn loweredSources(io: Io, a: Allocator, dir: []const u8) ![]const []const u8 {
    const list = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ dir, "sources" }), a, .limited(4 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return &.{},
        else => return err,
    };
    var names: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, list, '\n');
    while (lines.next()) |raw| {
        const rel = std.mem.trim(u8, raw, " \r\t");
        if (rel.len > 0) try names.append(a, rel);
    }
    return names.items;
}

pub const ObjectCheck = union(enum) { adopted: ObjectManifest, refused: []const u8 };

fn refuse(a: Allocator, comptime fmt: []const u8, args: anytype) !ObjectCheck {
    return .{ .refused = try std.fmt.allocPrint(a, fmt, args) };
}

/// Whether the object in `dir` is the one this build would lower: for its
/// target, from the same sources by the same compiler, linking the same
/// generated modules. A refusal says what differs.
pub fn checkObject(io: Io, a: Allocator, dir: []const u8, expect: ObjectExpect) !ObjectCheck {
    const p = try platformOf(expect.platform);
    const regenerate = try std.fmt.allocPrint(a, "lower it from this checkout with `zig build jacpython-object -Dtarget-platform={s}`", .{expect.platform});
    const text = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ dir, "manifest.json" }), a, .limited(16 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return refuse(a, "{s} has no manifest.json: only a directory the native stage wrote can be adopted; {s}", .{ dir, regenerate }),
        else => return err,
    };
    const m = std.json.parseFromSliceLeaky(ObjectManifest, a, text, .{ .ignore_unknown_fields = true }) catch |err|
        return refuse(a, "{s}/manifest.json does not parse ({s}); {s}", .{ dir, @errorName(err), regenerate });
    if (!std.mem.eql(u8, m.platform, expect.platform) or !std.mem.eql(u8, m.triple, p.llvm_triple))
        return refuse(a, "the object in {s} was lowered for {s} ({s}); this build is for {s} ({s})", .{ dir, m.platform, m.triple, expect.platform, p.llvm_triple });
    const object = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ dir, "jacpython.o" }), a, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return refuse(a, "{s} has a manifest but no jacpython.o", .{dir}),
        else => return err,
    };
    const object_sha = sha256Hex(object);
    if (!std.mem.eql(u8, &object_sha, m.object))
        return refuse(a, "{s}/jacpython.o is not the object its manifest describes: its sha256 is {s}, the manifest records {s}", .{ dir, &object_sha, m.object });
    const recorded = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ dir, "sha256" }), a, .limited(128)) catch "";
    if (!std.mem.eql(u8, std.mem.trim(u8, recorded, " \r\n"), m.object))
        return refuse(a, "{s}/sha256 does not name the object in its manifest ({s})", .{ dir, m.object });
    const format = objectFormat(object);
    if (format == null or format.?.os != p.os or format.?.arch != p.arch)
        return refuse(a, "{s}/jacpython.o is {s} code; {s} needs {s}", .{ dir, describeFormat(format), expect.platform, describeFormat(.{ .os = p.os, .arch = p.arch }) });
    for ([_][2][]const u8{ .{ frozen_module, m.frozen }, .{ runtime_image_module, m.runtime_image } }) |shipped| {
        const generated = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ dir, shipped[0] }), a, .unlimited) catch |err| switch (err) {
            error.FileNotFound => return refuse(a, "{s} has no {s}, the module lowered into its object; {s}", .{ dir, shipped[0], regenerate }),
            else => return err,
        };
        if (!std.mem.eql(u8, &sha256Hex(generated), shipped[1]))
            return refuse(a, "{s}/{s} is not the module its manifest says was lowered into the object", .{ dir, shipped[0] });
    }

    const list = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(a, &.{ dir, "sources" }), a, .limited(4 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return refuse(a, "{s} has no sources record", .{dir}),
        else => return err,
    };
    const current = try sourceDigests(io, a, expect.root, list);
    if (current.names.len != m.sources.map.count())
        return refuse(a, "{s}/sources lists {d} sources and its manifest {d}", .{ dir, current.names.len, m.sources.map.count() });
    var changed: std.ArrayList([]const u8) = .empty;
    for (current.names, current.digests) |name, digest| {
        const lowered = m.sources.map.get(name) orelse
            return refuse(a, "{s}/sources lists {s}, which its manifest does not", .{ dir, name });
        if (!std.mem.eql(u8, lowered, digest)) try changed.append(a, name);
    }
    const inputs = objectInputs(expect.tools, current.names, current.digests);
    if (!std.mem.eql(u8, &inputs, m.inputs)) {
        // The tools digest leaves the lowered sources out, so each part of a
        // refusal names a separate change.
        var why: std.ArrayList(u8) = .empty;
        if (changed.items.len > 0) {
            try why.print(a, "{d} of the sources it was lowered from differ here:", .{changed.items.len});
            for (changed.items[0..@min(changed.items.len, 8)]) |name| try why.print(a, " {s}", .{name});
            if (changed.items.len > 8) try why.appendSlice(a, " ...");
        }
        if (!std.mem.eql(u8, m.tools, expect.tools)) {
            if (why.items.len > 0) try why.appendSlice(a, "; and ");
            try why.appendSlice(a, "what lowers it differs (the rest of the jaclang compiler tree, prepare_native.py, the frozen-module or _PyRuntime generators, the CPython or typeshed pin, or the LLVM shim's inputs)");
        }
        if (why.items.len == 0) try why.appendSlice(a, "its manifest's input digest does not follow from its own sources and tools");
        return refuse(a, "the object in {s} was not lowered from this checkout: {s}. {s}", .{ dir, why.items, regenerate });
    }
    if (expect.headers) |headers| if (!std.mem.eql(u8, headers, m.headers))
        return refuse(a, "the object in {s} was lowered against another pyconfig.h or Include/ (headers {s}, this build's {s}): the _PyRuntime image in it and the layouts it assumes would not match the C this build compiles. Lower it with this target's probes", .{ dir, m.headers, headers });
    return .{ .adopted = m };
}

/// The native stage, for an object lowered elsewhere: checked against this
/// checkout and this tree's headers, then put, with the modules lowered into
/// it, where the native stage writes.
fn adoptObject(c: *Ctx, dir: []const u8, native: []const u8) !void {
    const tools = try c.o.object_tools.?(c.io, c.a, c.o.root, try loweredSources(c.io, c.a, dir));
    const headers = try headersDigest(c);
    switch (try checkObject(c.io, c.a, dir, .{
        .platform = c.o.platform,
        .tools = &tools,
        .root = c.o.root,
        .headers = &headers,
    })) {
        .refused => |why| {
            c.print("build-python: refusing the prebuilt native object: {s}", .{why});
            return error.NativeObjectRefused;
        },
        .adopted => |m| {
            for (object_files) |name| {
                try Io.Dir.copyFile(.cwd(), c.path(&.{ dir, name }), .cwd(), c.path(&.{ native, name }), c.io, .{});
            }
            c.print("adopted jacpython.o {s} from {s}, lowered on {s}", .{ m.object, dir, m.lowered_on });
        },
    }
}

/// The sha256 of pyconfig.h and every file under Include/, by path: what
/// gen_runtime_image computes the _PyRuntime image from, and what the C
/// around the native object is compiled against.
fn headersDigest(c: *Ctx) ![64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("jacpython-object-headers\x00pyconfig.h\x00");
    hash.update(try readFile(c, c.path(&.{ c.src, "pyconfig.h" })));
    var include = try Io.Dir.cwd().openDir(c.io, c.path(&.{ c.src, "Include" }), .{ .iterate = true });
    defer include.close(c.io);
    var walker = try include.walk(c.a);
    defer walker.deinit();
    var paths: std.ArrayList([]const u8) = .empty;
    while (try walker.next(c.io)) |entry| {
        if (entry.kind == .file) try paths.append(c.a, try c.a.dupe(u8, entry.path));
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn less(_: void, l: []const u8, r: []const u8) bool {
            return std.mem.lessThan(u8, l, r);
        }
    }.less);
    for (paths.items) |rel| {
        hash.update("\x00Include/");
        hash.update(rel);
        hash.update("\x00");
        hash.update(try include.readFileAlloc(c.io, rel, c.a, .unlimited));
    }
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

// ------------------------------------------------------- getpath's locations

/// The C the build links for jacpy_getpath_macro(): Modules/getpath.c's
/// build inputs, which CPython's makefile passes as -D flags when it compiles
/// getpath.c. In order: PREFIX and EXEC_PREFIX (this build's install prefix),
/// PYTHONPATH and VPATH (empty, as for an in-tree build), and PLATLIBDIR
/// (what makefileVars installs). They are linked rather than lowered, so the
/// native object names no build path and another checkout can adopt it.
const getpath_source = "Python/jacpython_getpath.c";
const getpath_object = "Python/jacpython_getpath.o";

fn getpathConfig(a: Allocator, prefix: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(a, "/* Generated by build_jacpython.zig: getpath's configured locations. */\n#include <stdint.h>\n\nstatic const char *const values[] = {");
    for ([_][]const u8{ prefix, prefix, "", "", "lib" }, 0..) |value, i| {
        try out.appendSlice(a, if (i == 0) "\n    \"" else ",\n    \"");
        // Printable ASCII as itself; quotes, backslashes, '?' (trigraphs)
        // and every other byte as an octal escape.
        for (value) |byte| {
            if (byte >= 0x20 and byte < 0x7f and byte != '"' and byte != '\\' and byte != '?') {
                try out.append(a, byte);
            } else try out.print(a, "\\{o:0>3}", .{byte});
        }
        try out.append(a, '"');
    }
    try out.appendSlice(a, "\n};\n\nconst char *jacpy_getpath_macro(int64_t which) {\n    return which >= 0 && which < 5 ? values[which] : 0;\n}\n");
    return out.items;
}

test "getpath's locations are linked as C strings of the install prefix, whatever bytes it holds" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const text = try getpathConfig(arena.allocator(), "/w/\xc3\xa9\"\\?x");
    const values =
        \\static const char *const values[] = {
        \\    "/w/\303\251\042\134\077x",
        \\    "/w/\303\251\042\134\077x",
        \\    "",
        \\    "",
        \\    "lib"
        \\};
    ;
    try std.testing.expect(std.mem.indexOf(u8, text, values) != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "const char *jacpy_getpath_macro(int64_t which) {") != null);
}

// ---------------------------------------------------------------- pyconfig.h

fn writePyconfig(c: *Ctx) !void {
    c.probes = try pyconfig.run(c.io, c.a, .{
        .os = c.p.os,
        .arch = c.p.arch,
        .cc = c.cc,
        .deps = c.deps,
        .environ = &c.env,
    }, c.path(&.{ c.o.work, "probes" }), c.o.jobs);
    const text = try pyconfig.render(c.a, c.probes, c.o.platform);
    try Io.Dir.cwd().writeFile(c.io, .{ .sub_path = c.path(&.{ c.src, "pyconfig.h" }), .data = text });
    var it = c.probes.map.iterator();
    while (it.next()) |e| c.print("{s} = {s}", .{ e.key_ptr.*, if (e.value_ptr.len == 0) "(undefined)" else e.value_ptr.* });
    // Native Jac defines and reads objects through layouts.jac, and the
    // generated constant tables recorded configure features; the asserts in
    // these two files fail the build when this pyconfig.h disagrees.
    for ([_][]const u8{ "layouts_check.c", "features_check.c" }) |name| {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(c.a, c.cc);
        try argv.appendSlice(c.a, &.{ "-O3", "-fPIC", "-fno-semantic-interposition", "-DPy_BUILD_CORE", "-I.", "-IInclude", "-c", "-o", "/dev/null", c.path(&.{ c.o.recipe, name }) });
        try runArgv(c, argv.items, c.src);
    }
}

// ------------------------------------------------------------- compile, link

/// The flags CPython's makefile assembles, as configure sets them for this
/// build (Makefile.pre.in's PY_CFLAGS, PY_CFLAGS_NODIST, PY_CPPFLAGS ...).
const Flags = struct {
    base_cflags: []const u8,
    opt: []const u8,
    configure_cflags: []const u8,
    cflags_nodist: []const u8,
    ldflags_nodist: []const u8,
    ldflags_nolto: []const u8,
    ccshared: []const u8,
    linkforshared: []const u8,
    libs: []const u8,
    libm: []const u8,

    fn of(p: Platform) Flags {
        const common_nodist = "-std=c11 -Wextra -Wno-unused-parameter -Wno-missing-field-initializers -Wstrict-prototypes -Werror=implicit-function-declaration -fvisibility=hidden";
        return switch (p.os) {
            // ThinLTO through the bundled LLVM linker.
            .linux => .{
                .base_cflags = "-fno-strict-overflow -Wsign-compare -Wunreachable-code",
                .opt = "-DNDEBUG -g -O3 -Wall",
                .configure_cflags = "-O3 -fPIC -fno-semantic-interposition",
                .cflags_nodist = "-flto=thin -g " ++ common_nodist,
                .ldflags_nodist = "-flto=thin -g",
                .ldflags_nolto = "-flto=thin",
                .ccshared = "-fPIC",
                .linkforshared = "-Xlinker -export-dynamic",
                .libs = "-ldl",
                .libm = "-lm",
            },
            // Zig's Mach-O linker cannot consume LTO objects. configure
            // passes ld64 the 16 MiB main-thread stack it gives
            // THREAD_STACK_SIZE (written in hex: Zig's linker reads a bare
            // number as decimal).
            .macos => .{
                .base_cflags = "-fno-strict-overflow -Wsign-compare -Wunreachable-code",
                .opt = "-DNDEBUG -g -O3 -Wall",
                .configure_cflags = "-O3 -fPIC -fno-semantic-interposition",
                .cflags_nodist = common_nodist ++ " -Werror=unguarded-availability",
                .ldflags_nodist = "",
                .ldflags_nolto = "",
                .ccshared = "",
                .linkforshared = "-Wl,-stack_size,0x1000000 -framework CoreFoundation",
                .libs = "-ldl -framework CoreFoundation",
                .libm = "",
            },
        };
    }
};

fn appendWords(a: Allocator, out: *std.ArrayList([]const u8), text: []const u8) !void {
    var words = std.mem.tokenizeAny(u8, text, " \t");
    while (words.next()) |w| try out.append(a, w);
}

/// PY_STDMODULE_CFLAGS: PY_CFLAGS, PY_CFLAGS_NODIST, PY_CPPFLAGS and
/// CFLAGSFORSHARED, as the makefile orders them.
fn stdmoduleCflags(c: *Ctx, f: Flags) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    const a = c.a;
    // PY_CFLAGS = BASECFLAGS OPT CONFIGURE_CFLAGS CFLAGS (build.sh's CFLAGS
    // were in make's environment too).
    try appendWords(a, &out, f.base_cflags);
    try appendWords(a, &out, f.opt);
    try appendWords(a, &out, f.configure_cflags);
    try appendWords(a, &out, f.configure_cflags);
    try appendWords(a, &out, f.cflags_nodist);
    try out.appendSlice(a, &.{ "-I./Include/internal", "-I./Include/internal/mimalloc", "-I.", "-I./Include" });
    // CONFIGURE_CPPFLAGS and CPPFLAGS: the vendored headers.
    const deps_include = try std.fmt.allocPrint(a, "-I{s}/include", .{c.deps});
    try out.appendSlice(a, &.{ deps_include, deps_include });
    try appendWords(a, &out, f.ccshared);
    return out.items;
}

/// The object prepare_native.py lowers the Jac runtime into.
const native_object = "Python/jacpython.o";

/// LIBRARY_OBJS, what libpython and the interpreter hold: the native object
/// and getpath's configured locations.
fn libraryObjects(c: *Ctx) ![]const []const u8 {
    return c.a.dupe([]const u8, &.{ native_object, getpath_object });
}

fn compile(c: *Ctx) !void {
    const a = c.a;
    var src_dir = try Io.Dir.cwd().openDir(c.io, c.src, .{});
    defer src_dir.close(c.io);
    try src_dir.createDirPath(c.io, "Python");
    try Io.Dir.copyFile(.cwd(), c.path(&.{ c.o.work, "native/jacpython.o" }), src_dir, native_object, c.io, .{});
    try src_dir.writeFile(c.io, .{ .sub_path = getpath_source, .data = try getpathConfig(a, c.prefix) });

    // Programs/python.c and getpath are the only C left to compile: everything
    // else libpython holds is the native object.
    const stdmodule = try stdmoduleCflags(c, Flags.of(c.p));
    for ([_][2][]const u8{ .{ "./Programs/python.c", "Programs/python.o" }, .{ "./" ++ getpath_source, getpath_object } }) |pair| {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(a, c.cc);
        try argv.append(a, "-c");
        try argv.appendSlice(a, stdmodule);
        try argv.appendSlice(a, &.{ "-DPy_BUILD_CORE", "-o", pair[1], pair[0] });
        try runArgv(c, argv.items, c.src);
    }
}

/// MODLIBS: the foreign libraries jacpython-modules.txt lists for the native
/// modules, in its order. A vendored library links its archive, never the
/// system's copy; an OS-prefixed flag (linux:-lrt) applies only there.
fn modlibs(c: *Ctx) ![]const []const u8 {
    const a = c.a;
    const registry = try Io.Dir.cwd().readFileAlloc(c.io, c.path(&.{ c.o.recipe, "jacpython-modules.txt" }), a, .limited(1024 * 1024));
    const inittab = try Io.Dir.cwd().readFileAlloc(c.io, c.path(&.{ c.o.root, "jaclang/runtime/python/inittab.jac" }), a, .limited(16 * 1024 * 1024));
    var out: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, registry, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        var words = std.mem.tokenizeAny(u8, line, " \t");
        const module = words.next().?;
        const init_name = try std.fmt.allocPrint(a, "PyInit_{s}", .{module});
        if (std.mem.indexOf(u8, inittab, init_name) == null) {
            c.print("inittab.jac has no {s}; run scripts/jacpython/gen_inittab.jac", .{init_name});
            return error.ModuleNotRegistered;
        }
        _ = words.next(); // the upstream test modules
        while (words.next()) |word| {
            var flag = word;
            if (std.mem.indexOfScalar(u8, flag, ':')) |colon| {
                const os = flag[0..colon];
                if (!std.mem.eql(u8, os, @tagName(c.p.os))) continue;
                flag = flag[colon + 1 ..];
            }
            if (std.mem.startsWith(u8, flag, "-l")) {
                const archive = c.path(&.{ c.deps, "lib", try std.fmt.allocPrint(a, "lib{s}.a", .{flag[2..]}) });
                if (fileExists(c.io, archive)) flag = archive;
            }
            try out.append(a, flag);
        }
    }
    return out.items;
}

fn fileExists(io: Io, path: []const u8) bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

/// The interpreter in the build tree. macOS's file system ignores case, and
/// the tree's Python/ directory would take the name `python`, so there it is
/// `python.exe`, as Makefile.pre.in's BUILDEXE makes it.
fn buildExe(c: *Ctx) []const u8 {
    return if (c.p.os == .macos) "python.exe" else "python";
}

fn libraryName(c: *Ctx) []const u8 {
    return if (c.p.os == .linux) "libpython" ++ version ++ ".so" else "libpython" ++ version ++ ".dylib";
}

fn link(c: *Ctx) !void {
    const a = c.a;
    const f = Flags.of(c.p);
    const mods = try modlibs(c);
    const ldflags = try std.fmt.allocPrint(a, "-L{s}/lib", .{c.deps});
    // PY_CORE_LDFLAGS: CONFIGURE_LDFLAGS and LDFLAGS (the vendored archives),
    // then PY_LDFLAGS_NODIST.
    var core_ldflags: std.ArrayList([]const u8) = .empty;
    try core_ldflags.appendSlice(a, &.{ ldflags, ldflags });
    try appendWords(a, &core_ldflags, f.ldflags_nodist);

    // libpython: BLDSHARED with the library objects and every module library.
    var lib: std.ArrayList([]const u8) = .empty;
    try lib.appendSlice(a, c.cc);
    switch (c.p.os) {
        .linux => {
            try lib.append(a, "-shared");
            try lib.appendSlice(a, core_ldflags.items);
            try lib.appendSlice(a, &.{ "-Wl,-soname,libpython" ++ version ++ ".so", "-o", "libpython" ++ version ++ ".so" });
        },
        .macos => {
            // Relocatable, with the three-component versions Zig's Mach-O
            // linker requires. The modules' libraries link into the dylib, as
            // they do on Linux, instead of being left to dynamic lookup.
            try lib.append(a, "-dynamiclib");
            try lib.appendSlice(a, core_ldflags.items);
            try lib.appendSlice(a, &.{ "-undefined", "dynamic_lookup", "-Wl,-install_name,@rpath/libpython" ++ version ++ ".dylib", "-Wl,-compatibility_version," ++ version ++ ".0", "-Wl,-current_version," ++ version ++ ".0", "-o", "libpython" ++ version ++ ".dylib" });
        },
    }
    try lib.appendSlice(a, try libraryObjects(c));
    try lib.appendSlice(a, mods);
    try appendWords(a, &lib, f.libs);
    try appendWords(a, &lib, f.libm);
    try runArgv(c, lib.items, c.src);

    // The interpreter embeds the same objects: venv --copies must run without
    // a libpython next to the copied executable.
    var exe: std.ArrayList([]const u8) = .empty;
    try exe.appendSlice(a, c.cc);
    try exe.appendSlice(a, core_ldflags.items);
    try appendWords(a, &exe, f.linkforshared);
    try exe.appendSlice(a, &.{ "-o", buildExe(c), "Programs/python.o" });
    try exe.appendSlice(a, try libraryObjects(c));
    try appendWords(a, &exe, f.libs);
    try exe.appendSlice(a, mods);
    try appendWords(a, &exe, f.libm);
    try runArgv(c, exe.items, c.src);
}

// ------------------------------------------------------------------- install

/// Lib/ subdirectories `make libinstall` installs (Makefile.pre.in's
/// LIBSUBDIRS); TESTSUBDIRS are left out (--disable-test-modules).
const lib_subdirs = [_][]const u8{
    "asyncio",               "collections",        "compression",        "compression/_common",
    "compression/zstd",      "concurrent",         "concurrent/futures", "concurrent/interpreters",
    "csv",                   "ctypes",             "ctypes/macholib",    "curses",
    "dbm",                   "email",              "email/mime",         "encodings",
    "ensurepip",             "ensurepip/_bundled", "html",               "http",
    "idlelib",               "idlelib/Icons",      "importlib",          "importlib/resources",
    "importlib/metadata",    "json",               "logging",            "multiprocessing",
    "multiprocessing/dummy", "pathlib",            "pydoc_data",         "re",
    "site-packages",         "sqlite3",            "string",             "sysconfig",
    "tkinter",               "tomllib",            "turtledemo",         "unittest",
    "urllib",                "venv",               "venv/scripts",       "venv/scripts/common",
    "venv/scripts/posix",    "wsgiref",            "xml",                "xml/dom",
    "xml/etree",             "xml/parsers",        "xml/sax",            "xmlrpc",
    "zipfile",               "zipfile/_path",      "zoneinfo",           "_pyrepl",
    "__phello__",
};

const mode_data: std.posix.mode_t = 0o644;
const mode_exec: std.posix.mode_t = 0o755;

fn installFile(c: *Ctx, from: []const u8, to: []const u8, mode: std.posix.mode_t) !void {
    try Io.Dir.copyFile(.cwd(), from, .cwd(), to, c.io, .{ .permissions = .fromMode(mode), .make_path = true });
}

fn isExecutable(c: *Ctx, file_path: []const u8) !bool {
    const st = try Io.Dir.cwd().statFile(c.io, file_path, .{});
    return st.permissions.toMode() & 0o111 != 0;
}

/// install -m 644 / INSTALL_SCRIPT: an executable source keeps 755.
fn installAs(c: *Ctx, from: []const u8, to: []const u8) !void {
    try installFile(c, from, to, if (try isExecutable(c, from)) mode_exec else mode_data);
}

fn symlink(c: *Ctx, dir: []const u8, target: []const u8, name: []const u8) !void {
    const full = c.path(&.{ dir, name });
    Io.Dir.cwd().deleteFile(c.io, full) catch {};
    try Io.Dir.cwd().symLink(c.io, target, full, .{});
}

/// Files directly in `dir` (no subdirectories), sorted.
fn listFiles(c: *Ctx, dir: []const u8) ![]const []const u8 {
    var d = Io.Dir.cwd().openDir(c.io, dir, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return &.{},
        else => return err,
    };
    defer d.close(c.io);
    var names: std.ArrayList([]const u8) = .empty;
    var it = d.iterate();
    while (try it.next(c.io)) |entry| {
        if (entry.kind == .directory) continue;
        try names.append(c.a, try c.a.dupe(u8, entry.name));
    }
    std.mem.sort([]const u8, names.items, {}, struct {
        fn less(_: void, l: []const u8, r: []const u8) bool {
            return std.mem.lessThan(u8, l, r);
        }
    }.less);
    return names.items;
}

fn dirExists(c: *Ctx, dir: []const u8) bool {
    const st = Io.Dir.cwd().statFile(c.io, dir, .{}) catch return false;
    return st.kind == .directory;
}

const Layout = struct {
    bindir: []const u8,
    libdir: []const u8,
    libdest: []const u8,
    libpl: []const u8,
    libpc: []const u8,
    includepy: []const u8,
    exename: []const u8,
};

fn layout(c: *Ctx) Layout {
    const libdest = c.path(&.{ c.prefix, "lib/python" ++ version });
    return .{
        .bindir = c.path(&.{ c.prefix, "bin" }),
        .libdir = c.path(&.{ c.prefix, "lib" }),
        .libdest = libdest,
        .libpl = c.path(&.{ libdest, std.fmt.allocPrint(c.a, "config-" ++ version ++ "-{s}", .{c.p.triplet}) catch @panic("out of memory") }),
        .libpc = c.path(&.{ c.prefix, "lib/pkgconfig" }),
        .includepy = c.path(&.{ c.prefix, "include/python" ++ version }),
        .exename = c.path(&.{ c.prefix, "bin/python" ++ version }),
    };
}

fn install(c: *Ctx) !void {
    const l = layout(c);
    const io = c.io;
    for ([_][]const u8{ l.bindir, l.libdir, l.libdest, l.libpl, l.libpc, l.includepy, c.path(&.{ l.libdest, "lib-dynload" }) }) |dir| {
        try Io.Dir.cwd().createDirPath(io, dir);
    }
    // altbininstall: the interpreter and the shared library.
    try installFile(c, c.path(&.{ c.src, buildExe(c) }), l.exename, mode_exec);
    try installFile(c, c.path(&.{ c.src, libraryName(c) }), c.path(&.{ l.libdir, libraryName(c) }), mode_exec);

    // libinstall: Lib/*.py, then the files directly in each LIBSUBDIRS entry.
    const lib = c.path(&.{ c.src, "Lib" });
    for (try listFiles(c, lib)) |name| {
        if (!std.mem.endsWith(u8, name, ".py")) continue;
        try installAs(c, c.path(&.{ lib, name }), c.path(&.{ l.libdest, name }));
    }
    for (lib_subdirs) |sub| {
        const from = c.path(&.{ lib, sub });
        if (!dirExists(c, from)) continue;
        const to = c.path(&.{ l.libdest, sub });
        try Io.Dir.cwd().createDirPath(io, to);
        for (try listFiles(c, from)) |name| {
            if (std.mem.endsWith(u8, name, "CVS") or std.mem.endsWith(u8, name, ".pyc") or std.mem.endsWith(u8, name, ".pyo") or
                std.mem.endsWith(u8, name, ".orig") or std.mem.endsWith(u8, name, "~")) continue;
            try installAs(c, c.path(&.{ from, name }), c.path(&.{ to, name }));
        }
    }
    try installFile(c, c.path(&.{ c.src, "LICENSE" }), c.path(&.{ l.libdest, "LICENSE.txt" }), mode_data);

    // inclinstall: the public, cpython/ and internal/ headers, mimalloc's, and
    // pyconfig.h.
    const include = c.path(&.{ c.src, "Include" });
    for ([_][]const u8{ "", "cpython", "internal" }) |sub| {
        const from = c.path(&.{ include, sub });
        const to = c.path(&.{ l.includepy, sub });
        try Io.Dir.cwd().createDirPath(io, to);
        for (try listFiles(c, from)) |name| {
            if (!std.mem.endsWith(u8, name, ".h")) continue;
            try installFile(c, c.path(&.{ from, name }), c.path(&.{ to, name }), mode_data);
        }
    }
    try Io.Dir.cwd().createDirPath(io, c.path(&.{ l.includepy, "internal/mimalloc/mimalloc" }));
    try installFile(c, c.path(&.{ include, "internal/mimalloc/mimalloc.h" }), c.path(&.{ l.includepy, "internal/mimalloc/mimalloc.h" }), mode_data);
    for (try listFiles(c, c.path(&.{ include, "internal/mimalloc/mimalloc" }))) |name| {
        if (!std.mem.endsWith(u8, name, ".h")) continue;
        try installFile(c, c.path(&.{ include, "internal/mimalloc/mimalloc", name }), c.path(&.{ l.includepy, "internal/mimalloc/mimalloc", name }), mode_data);
    }
    try installFile(c, c.path(&.{ c.src, "pyconfig.h" }), c.path(&.{ l.includepy, "pyconfig.h" }), mode_data);
}

/// libainstall and bininstall, which make runs after libinstall has compiled
/// the library (so python-config.py gets no byte-code).
fn installTools(c: *Ctx) !void {
    const l = layout(c);
    // libainstall: pkg-config files, python-config, idle and pydoc.
    const subst = try substitutions(c);
    // The pkg-config files name their prefix relative to themselves
    // (<prefix>/lib/pkgconfig), so a relocated output tree stays usable.
    var pc_subst = try subst.clone(c.a);
    try pc_subst.put(c.a, "prefix", "${pcfiledir}/../..");
    try writeTemplate(c, c.path(&.{ c.src, "Misc/python.pc.in" }), c.path(&.{ l.libpc, "python-" ++ version ++ ".pc" }), pc_subst, mode_data);
    try writeTemplate(c, c.path(&.{ c.src, "Misc/python-embed.pc.in" }), c.path(&.{ l.libpc, "python-" ++ version ++ "-embed.pc" }), pc_subst, mode_data);
    const config_py = try std.mem.replaceOwned(u8, c.a, try readFile(c, c.path(&.{ c.src, "Misc/python-config.in" })), "@EXENAME@", l.exename);
    try writeFile(c, c.path(&.{ l.libpl, "python-config.py" }), config_py, mode_exec);
    // The shell python-config; on Darwin the Python one, which applies
    // _osx_support's compiler customizations.
    const config_sh = if (c.p.os == .macos) config_py else try makeToShell(c.a, try substitute(c.a, try readFile(c, c.path(&.{ c.src, "Misc/python-config.sh.in" })), subst));
    try writeFile(c, c.path(&.{ l.bindir, "python" ++ version ++ "-config" }), config_sh, mode_exec);
    for ([_][]const u8{ "idle3", "pydoc3" }) |script| {
        const text = try std.mem.replaceOwned(u8, c.a, try readFile(c, c.path(&.{ c.src, "Tools/scripts", script })), "/usr/bin/env python3", l.exename);
        const name = try std.fmt.allocPrint(c.a, "{s}.{s}", .{ script, version["3.".len..] });
        try writeFile(c, c.path(&.{ l.bindir, name }), text, mode_exec);
    }

    // bininstall: the unversioned names.
    try symlink(c, l.bindir, "python" ++ version, "python3");
    try symlink(c, l.bindir, "python" ++ version ++ "-config", "python3-config");
    try symlink(c, l.bindir, "idle" ++ version, "idle3");
    try symlink(c, l.bindir, "pydoc" ++ version, "pydoc3");
    try symlink(c, l.libpc, "python-" ++ version ++ ".pc", "python3.pc");
    try symlink(c, l.libpc, "python-" ++ version ++ "-embed.pc", "python3-embed.pc");
}

fn readFile(c: *Ctx, file_path: []const u8) ![]const u8 {
    return Io.Dir.cwd().readFileAlloc(c.io, file_path, c.a, .limited(64 * 1024 * 1024));
}

fn writeFile(c: *Ctx, file_path: []const u8, data: []const u8, mode: std.posix.mode_t) !void {
    if (std.fs.path.dirname(file_path)) |dir| try Io.Dir.cwd().createDirPath(c.io, dir);
    try Io.Dir.cwd().writeFile(c.io, .{ .sub_path = file_path, .data = data, .flags = .{ .permissions = .fromMode(mode) } });
}

const Subst = std.StringArrayHashMapUnmanaged([]const u8);

/// The values configure substitutes into Misc/*.in, in configure's form
/// (directories relative to ${prefix}, makefile references kept).
fn substitutions(c: *Ctx) !Subst {
    const a = c.a;
    const f = Flags.of(c.p);
    var s: Subst = .empty;
    try s.put(a, "prefix", c.prefix);
    try s.put(a, "exec_prefix", "${prefix}");
    try s.put(a, "libdir", "${exec_prefix}/lib");
    try s.put(a, "includedir", "${prefix}/include");
    try s.put(a, "VERSION", version);
    try s.put(a, "ABIFLAGS", "");
    try s.put(a, "LDVERSION", "$(VERSION)$(ABIFLAGS)");
    try s.put(a, "LIBPYTHON", "");
    try s.put(a, "LIBS", try std.fmt.allocPrint(a, "{s} ", .{f.libs}));
    try s.put(a, "LIBM", f.libm);
    try s.put(a, "LIBC", "");
    try s.put(a, "LIBPL", try std.fmt.allocPrint(a, "$(prefix)/lib/python" ++ version ++ "/config-$(VERSION)$(ABIFLAGS)-{s}", .{c.p.triplet}));
    try s.put(a, "CFLAGS", f.configure_cflags);
    try s.put(a, "BASECFLAGS", try std.fmt.allocPrint(a, " {s}", .{f.base_cflags}));
    try s.put(a, "OPT", f.opt);
    try s.put(a, "LDLIBRARY", if (c.p.os == .linux) "libpython$(LDVERSION).so" else "libpython$(LDVERSION).dylib");
    try s.put(a, "EXT_SUFFIX", try extSuffix(c));
    try s.put(a, "PY_ENABLE_SHARED", "1");
    try s.put(a, "PYTHONFRAMEWORK", "");
    return s;
}

fn extSuffix(c: *Ctx) ![]const u8 {
    return std.fmt.allocPrint(c.a, ".cpython-" ++ soabi_version ++ "-{s}.so", .{c.p.triplet});
}

fn substitute(a: Allocator, text: []const u8, s: Subst) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '@') {
            if (std.mem.indexOfScalarPos(u8, text, i + 1, '@')) |end| {
                if (s.get(text[i + 1 .. end])) |value| {
                    try out.appendSlice(a, value);
                    i = end + 1;
                    continue;
                }
            }
        }
        try out.append(a, text[i]);
        i += 1;
    }
    return out.toOwnedSlice(a);
}

/// The makefile's `sed 's,$(\([A-Za-z0-9_]*\)),${\1},g'` for python-config.
fn makeToShell(a: Allocator, text: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '$' and i + 1 < text.len and text[i + 1] == '(') {
            var j = i + 2;
            while (j < text.len and (std.ascii.isAlphanumeric(text[j]) or text[j] == '_')) j += 1;
            if (j < text.len and text[j] == ')') {
                try out.print(a, "${{{s}}}", .{text[i + 2 .. j]});
                i = j + 1;
                continue;
            }
        }
        try out.append(a, text[i]);
        i += 1;
    }
    return out.toOwnedSlice(a);
}

fn writeTemplate(c: *Ctx, from: []const u8, to: []const u8, s: Subst, mode: std.posix.mode_t) !void {
    try writeFile(c, to, try substitute(c.a, try readFile(c, from), s), mode);
}

// ----------------------------------------------------------------- sysconfig

/// The build's configuration as makefile variables: what sysconfig, python-config
/// and extension builds read. sysconfig parses it exactly as it parsed CPython's
/// makefile, and it is installed where that makefile was.
fn makefileVars(c: *Ctx) ![]const u8 {
    const a = c.a;
    const f = Flags.of(c.p);
    var mods: std.ArrayList(u8) = .empty;
    for (try modlibs(c), 0..) |flag, i| {
        if (i > 0) try mods.append(a, ' ');
        try mods.appendSlice(a, flag);
    }
    const linux = c.p.os == .linux;
    const host_type = try gnuType(c, c.p.os, c.p.arch);
    const build_type = if (c.o.cross) try gnuType(c, buildOs(), buildArch()) else host_type;
    var out: std.ArrayList(u8) = .empty;
    try out.print(a,
        \\# The configuration of the JacPython runtime, written by
        \\# bootstrap/build_jacpython.zig in the form of CPython's makefile.
        \\VERSION= {[version]s}
        \\srcdir=  .
        \\abs_srcdir= {[src]s}
        \\abs_builddir= {[src]s}
        \\CC=  cc
        \\CXX=  c++
        \\LINKCC=  $(PURIFY) $(CC)
        \\PURIFY=
        \\AR=  ar
        \\ARFLAGS= rcs
        \\RANLIB=  ranlib
        \\SOABI=  cpython-{[soabi]s}-{[triplet]s}
        \\ABIFLAGS=
        \\ABI_THREAD=
        \\LDVERSION= $(VERSION)$(ABIFLAGS)
        \\LIBPYTHON=
        \\GNULD=  {[gnuld]s}
        \\OPT=  {[opt]s}
        \\BASECFLAGS=  {[basecflags]s}
        \\BASECPPFLAGS=
        \\CONFIGURE_CFLAGS= {[configure_cflags]s}
        \\CONFIGURE_CFLAGS_NODIST= {[cflags_nodist]s}
        \\CONFIGURE_LDFLAGS_NODIST= {[ldflags_nodist]s}
        \\CONFIGURE_LDFLAGS_NOLTO={[ldflags_nolto]s}
        \\CONFIGURE_CPPFLAGS= -I{[deps]s}/include
        \\CONFIGURE_LDFLAGS= -L{[deps]s}/lib
        \\CFLAGS_NODIST=
        \\LDFLAGS_NODIST=
        \\EXTRA_CFLAGS=
        \\PY_CFLAGS= $(BASECFLAGS) $(OPT) $(CONFIGURE_CFLAGS) $(CFLAGS) $(EXTRA_CFLAGS)
        \\PY_CFLAGS_NODIST=$(CONFIGURE_CFLAGS_NODIST) $(CFLAGS_NODIST) -I$(srcdir)/Include/internal -I$(srcdir)/Include/internal/mimalloc
        \\PY_CPPFLAGS= $(BASECPPFLAGS) -I. -I$(srcdir)/Include $(CONFIGURE_CPPFLAGS) $(CPPFLAGS)
        \\PY_LDFLAGS= $(CONFIGURE_LDFLAGS) $(LDFLAGS)
        \\PY_LDFLAGS_NODIST=$(CONFIGURE_LDFLAGS_NODIST) $(LDFLAGS_NODIST)
        \\PY_LDFLAGS_NOLTO=$(PY_LDFLAGS) $(CONFIGURE_LDFLAGS_NOLTO) $(LDFLAGS_NODIST)
        \\NO_AS_NEEDED= {[no_as_needed]s}
        \\CCSHARED= {[ccshared]s}
        \\LINKFORSHARED= {[linkforshared]s}
        \\CFLAGSFORSHARED=$(CCSHARED)
        \\PY_STDMODULE_CFLAGS= $(PY_CFLAGS) $(PY_CFLAGS_NODIST) $(PY_CPPFLAGS) $(CFLAGSFORSHARED)
        \\PY_BUILTIN_MODULE_CFLAGS= $(PY_STDMODULE_CFLAGS) -DPy_BUILD_CORE_BUILTIN
        \\PY_CORE_CFLAGS= $(PY_STDMODULE_CFLAGS) -DPy_BUILD_CORE
        \\PY_CORE_LDFLAGS=$(PY_LDFLAGS) $(PY_LDFLAGS_NODIST)
        \\CFLAGS_ALIASING=
        \\CFLAGS_CEVAL=
        \\MACHDEP= {[machdep]s}
        \\MULTIARCH= {[triplet]s}
        \\MULTIARCH_CPPFLAGS = -DMULTIARCH=\"{[triplet]s}\"
        \\prefix=  {[prefix]s}
        \\exec_prefix= ${{prefix}}
        \\host_prefix=  ${{prefix}}
        \\host_exec_prefix=  ${{exec_prefix}}
        \\datarootdir=    ${{prefix}}/share
        \\BINDIR=  ${{exec_prefix}}/bin
        \\LIBDIR=  ${{exec_prefix}}/lib
        \\MANDIR=  ${{datarootdir}}/man
        \\INCLUDEDIR= ${{prefix}}/include
        \\CONFINCLUDEDIR= $(exec_prefix)/include
        \\PLATLIBDIR= lib
        \\SCRIPTDIR= $(prefix)/$(PLATLIBDIR)
        \\EXENAME= $(BINDIR)/python$(LDVERSION)$(EXE)
        \\WHEEL_PKG_DIR=
        \\BINLIBDEST= $(LIBDIR)/python$(VERSION)$(ABI_THREAD)
        \\LIBDEST= $(SCRIPTDIR)/python$(VERSION)$(ABI_THREAD)
        \\INCLUDEPY= $(INCLUDEDIR)/python$(LDVERSION)
        \\CONFINCLUDEPY= $(CONFINCLUDEDIR)/python$(LDVERSION)
        \\SHLIB_SUFFIX= .so
        \\EXT_SUFFIX= {[ext_suffix]s}
        \\LDSHARED= {[ldshared]s}
        \\BLDSHARED= {[bldshared]s}
        \\LDCXXSHARED= {[ldcxxshared]s}
        \\DESTSHARED= $(BINLIBDEST)/lib-dynload
        \\EXE=
        \\BUILDEXE= {[buildexe]s}
        \\PYTHONFRAMEWORK=
        \\PYTHONFRAMEWORKDIR= no-framework
        \\PYTHONFRAMEWORKPREFIX=
        \\PYTHONFRAMEWORKINSTALLDIR=
        \\PYTHONFRAMEWORKINSTALLNAMEPREFIX=
        \\MACOSX_DEPLOYMENT_TARGET={[deployment]s}
        \\IPHONEOS_DEPLOYMENT_TARGET=
        \\ENSUREPIP=      no
        \\HOST_GNU_TYPE= {[host_type]s}
        \\BUILD_GNU_TYPE= {[build_type]s}
        \\HOSTRUNNER=
        \\LIBRARY= libpython$(VERSION)$(ABIFLAGS).a
        \\LDLIBRARY=      {[ldlibrary]s}
        \\BLDLIBRARY=     -L. -lpython$(LDVERSION)
        \\PY3LIBRARY=     libpython3.so
        \\DLLLIBRARY=
        \\LDLIBRARYDIR=
        \\INSTSONAME= $(LDLIBRARY)
        \\LIBS=  {[libs]s}
        \\LIBM=  {[libm]s}
        \\LIBC=
        \\SYSLIBS= $(LIBM) $(LIBC)
        \\SHLIBS=  $(LIBS)
        \\LOCALMODLIBS= {[modlibs]s}
        \\BASEMODLIBS=
        \\MODLIBS= $(LOCALMODLIBS) $(BASEMODLIBS)
        \\PY_ENABLE_SHARED= 1
        \\STATIC_LIBPYTHON= 0
        \\TEST_MODULES= no
        \\TZPATH= /usr/share/zoneinfo:/usr/lib/zoneinfo:/usr/share/lib/zoneinfo:/etc/zoneinfo
        \\LIBPL=  $(prefix)/lib/python{[version]s}/config-$(VERSION)$(ABIFLAGS)-{[triplet]s}
        \\LIBPC=  $(LIBDIR)/pkgconfig
        \\BUILDPYTHON= python$(BUILDEXE)
        \\CONFIG_ARGS= {[config_args]s}
        \\MODBUILT_NAMES= {[built]s}
        \\MODSHARED_NAMES=
        \\MODDISABLED_NAMES= {[disabled]s}
        \\
    , .{
        .version = version,
        .soabi = soabi_version,
        .triplet = c.p.triplet,
        .src = c.src,
        .gnuld = if (linux) "yes" else "no",
        .opt = f.opt,
        .basecflags = f.base_cflags,
        .configure_cflags = f.configure_cflags,
        .cflags_nodist = f.cflags_nodist,
        .ldflags_nodist = f.ldflags_nodist,
        .ldflags_nolto = f.ldflags_nolto,
        .no_as_needed = if (linux) "-Wl,--no-as-needed" else "",
        .ccshared = f.ccshared,
        .linkforshared = f.linkforshared,
        .machdep = if (linux) "linux" else "darwin",
        .prefix = c.prefix,
        .ext_suffix = try extSuffix(c),
        .ldshared = if (linux) "$(CC) -shared $(PY_LDFLAGS)" else "$(CC) -shared -undefined dynamic_lookup",
        // sysconfig's generator, run from CPython's build tree, records
        // BLDSHARED as LDSHARED.
        .bldshared = if (linux) "$(CC) -shared $(PY_LDFLAGS)" else "$(CC) -shared -undefined dynamic_lookup",
        .ldcxxshared = if (linux) "$(CXX) -shared $(PY_LDFLAGS)" else "$(CXX) -bundle -undefined dynamic_lookup",
        .deployment = c.p.deployment_target orelse "",
        .host_type = host_type,
        .build_type = build_type,
        .buildexe = if (linux) "" else ".exe",
        .ldlibrary = if (linux) "libpython$(LDVERSION).so" else "libpython$(LDVERSION).dylib",
        .libs = f.libs,
        .libm = f.libm,
        .modlibs = mods.items,
        .config_args = try configArgs(c),
        .deps = c.deps,
        .built = try builtinModules(c),
        .disabled = "_tkinter  _testcapi  _testinternalcapi  _testlimitedcapi  _testclinic  _ctypes_test  _gdbm  _dbm  _curses  _curses_panel  readline",
    });
    return out.toOwnedSlice(a);
}

/// MODBUILT_NAMES: the modules inittab.jac builds in, without the core
/// entries Modules/config.c.in itself adds.
fn builtinModules(c: *Ctx) ![]const u8 {
    const inittab = try readFile(c, c.path(&.{ c.o.root, "jaclang/runtime/python/inittab.jac" }));
    const core = [_][]const u8{ "_ast", "_tokenize", "_symtable", "builtins", "sys", "gc", "_string" };
    var out: std.ArrayList(u8) = .empty;
    const marker = "name=ptr[u8](\"";
    var rest = inittab;
    outer: while (std.mem.indexOf(u8, rest, marker)) |at| {
        rest = rest[at + marker.len ..];
        const end = std.mem.indexOfScalar(u8, rest, '"') orelse break;
        const name = rest[0..end];
        for (core) |skip| if (std.mem.eql(u8, name, skip)) continue :outer;
        // makesetup's spacing.
        if (out.items.len > 0) try out.appendSlice(c.a, "  ");
        try out.appendSlice(c.a, name);
    }
    return out.toOwnedSlice(c.a);
}

/// The configure invocation this build stands for, as CONFIG_ARGS records it
/// (finalize.py strips the vendored include and library directories).
fn configArgs(c: *Ctx) ![]const u8 {
    const f = Flags.of(c.p);
    const d = c.deps;
    return std.fmt.allocPrint(c.a, "'--prefix={[prefix]s}' '--enable-shared' '--without-static-libpython' '--with-tail-call-interp' '{[lto]s}' '--disable-test-modules' '--with-ensurepip=no' '--with-pkg-config=no' '--with-openssl={[d]s}' '--with-openssl-rpath=no' '--with-system-expat' '--with-system-libmpdec' '--without-readline' '--without-remote-debug' 'PKG_CONFIG=false' 'PKG_CONFIG_PATH=' 'PKG_CONFIG_LIBDIR={[d]s}/lib/pkgconfig' 'CC=cc' 'CFLAGS={[cflags]s}' 'LDFLAGS=-L{[d]s}/lib' 'CPPFLAGS=-I{[d]s}/include' 'LIBFFI_CFLAGS=-I{[d]s}/include' 'LIBFFI_LIBS={[d]s}/lib/libffi.a' 'LIBMPDEC_CFLAGS=-I{[d]s}/include' 'LIBMPDEC_LIBS={[d]s}/lib/libmpdec.a -lm' 'LIBSQLITE3_CFLAGS=-I{[d]s}/include' 'LIBSQLITE3_LIBS={[d]s}/lib/libsqlite3.a -lm -lpthread' 'ZLIB_CFLAGS=-I{[d]s}/include' 'ZLIB_LIBS={[d]s}/lib/libz.a' 'BZIP2_CFLAGS=-I{[d]s}/include' 'BZIP2_LIBS={[d]s}/lib/libbz2.a' 'LIBLZMA_CFLAGS=-I{[d]s}/include' 'LIBLZMA_LIBS={[d]s}/lib/liblzma.a' 'LIBZSTD_CFLAGS=-I{[d]s}/include' 'LIBZSTD_LIBS={[d]s}/lib/libzstd.a'", .{
        .prefix = c.prefix,
        .lto = if (c.p.os == .linux) "--with-lto=thin" else "--without-lto",
        .d = d,
        .cflags = f.configure_cflags,
    });
}

/// config.guess's name for a machine of this OS and architecture. A macOS
/// name carries the running kernel's release, as config.guess reports it.
fn gnuType(c: *Ctx, os: pyconfig.Os, arch: pyconfig.Arch) ![]const u8 {
    return switch (os) {
        .linux => if (arch == .x86_64) "x86_64-pc-linux-gnu" else "aarch64-unknown-linux-gnu",
        .macos => blk: {
            const uts = std.posix.uname();
            const release = std.mem.sliceTo(&uts.release, 0);
            break :blk try std.fmt.allocPrint(c.a, "{s}-apple-darwin{s}", .{ @tagName(arch), release });
        },
    };
}

fn buildOs() pyconfig.Os {
    return if (builtin.os.tag == .macos) .macos else .linux;
}

fn buildArch() pyconfig.Arch {
    return if (builtin.cpu.arch == .aarch64) .aarch64 else .x86_64;
}

/// The sysconfig data CPython's `pybuilddir.txt` rule generates: the installed
/// interpreter parses the makefile variables and pyconfig.h with sysconfig's
/// own --generate-posix-vars, then build-details.json follows from it.
fn sysconfig(c: *Ctx) !void {
    const l = layout(c);
    try writeFile(c, c.path(&.{ l.libpl, "Makefile" }), try makefileVars(c), mode_data);
    const gen = c.path(&.{ c.o.work, "sysconfig" });
    try Io.Dir.cwd().createDirPath(c.io, gen);
    // As make runs it from the build tree, where sysconfig finds the
    // makefile and pyconfig.h without the data it is about to write, and
    // with the flags build.sh exported in the environment, which the
    // makefile's $(CFLAGS), $(CPPFLAGS) and $(LDFLAGS) read.
    const flags = Flags.of(c.p);
    try c.env.put("CFLAGS", flags.configure_cflags);
    try c.env.put("CPPFLAGS", try std.fmt.allocPrint(c.a, "-I{s}/include", .{c.deps}));
    try c.env.put("LDFLAGS", try std.fmt.allocPrint(c.a, "-L{s}/lib", .{c.deps}));
    const name = try std.fmt.allocPrint(c.a, "_sysconfigdata__{s}_{s}", .{ if (c.p.os == .linux) "linux" else "darwin", c.p.triplet });
    // Another platform's interpreter writes the target's data as CPython's
    // cross builds have their build Python write it: under the target's
    // platform and data name, with the prefixes from the makefile.
    const cross_env = [_][2][]const u8{
        .{ "_PYTHON_HOST_PLATFORM", c.p.sysconfig_platform },
        .{ "_PYTHON_SYSCONFIGDATA_NAME", name },
        .{ "_PYTHON_PROJECT_BASE", l.bindir },
    };
    if (c.o.cross) for (cross_env) |kv| try c.env.put(kv[0], kv[1]);
    defer for ([_][]const u8{ "CFLAGS", "CPPFLAGS", "LDFLAGS", cross_env[0][0] }) |key| {
        _ = c.env.swapRemove(key);
    };
    try runArgv(c, &.{
        try installedPython(c),            "-E",                                    "-S", "-c",
        \\import sys
        \\import sysconfig.__main__ as generator
        \\generator.get_makefile_filename = lambda: sys.argv[1]
        \\generator.get_config_h_filename = lambda: sys.argv[2]
        \\generator._generate_posix_vars()
        ,
        c.path(&.{ l.libpl, "Makefile" }), c.path(&.{ l.includepy, "pyconfig.h" }),
    }, gen);
    // The build-details generator reads only the target's platform from the
    // environment; on the host, the data name would hide the host's own.
    for (cross_env[1..]) |kv| _ = c.env.swapRemove(kv[0]);
    const builddir = std.mem.trim(u8, try readFile(c, c.path(&.{ gen, "pybuilddir.txt" })), " \r\n");
    const data = c.path(&.{ gen, builddir, try std.fmt.allocPrint(c.a, "{s}.py", .{name}) });
    const json_name = try std.fmt.allocPrint(c.a, "_sysconfig_vars__{s}_{s}.json", .{ if (c.p.os == .linux) "linux" else "darwin", c.p.triplet });
    const details = c.path(&.{ gen, builddir, "build-details.json" });
    // build-details.json (PEP 739); JacPython keeps no Tools/build: the
    // generator reads this build's sysconfig data.
    try generate(c, try installedPython(c), &.{ "gen_build_details", "--sysconfig", data, "--output", details });
    try installFile(c, data, c.path(&.{ l.libdest, try std.fmt.allocPrint(c.a, "{s}.py", .{name}) }), mode_data);
    try installFile(c, c.path(&.{ gen, builddir, json_name }), c.path(&.{ l.libdest, json_name }), mode_data);
    try installFile(c, details, c.path(&.{ l.libdest, "build-details.json" }), mode_data);
}

/// Byte-code for the three optimization levels, as libinstall compiles it.
fn compileall(c: *Ctx) !void {
    const l = layout(c);
    try c.env.put("PYTHONPATH", l.libdest);
    defer _ = c.env.swapRemove("PYTHONPATH");
    const jobs = try std.fmt.allocPrint(c.a, "-j{d}", .{c.o.jobs});
    const script = c.path(&.{ l.libdest, "compileall.py" });
    const python = try installedPython(c);
    try runArgv(c, &.{ python, "-E", "-Wi", script, "-o", "0", "-o", "1", "-o", "2", jobs, "-d", l.libdest, "-f", "-x", "bad_coding|badsyntax|site-packages", l.libdest }, null);
    const site = c.path(&.{ l.libdest, "site-packages" });
    try runArgv(c, &.{ python, "-E", "-Wi", script, "-o", "0", "-o", "1", "-o", "2", jobs, "-d", site, "-f", "-x", "badsyntax", site }, null);
}

// -------------------------------------------------------------------- copies

fn copyTree(c: *Ctx, from: []const u8, to: []const u8) !void {
    var src = try Io.Dir.cwd().openDir(c.io, from, .{ .iterate = true });
    defer src.close(c.io);
    try Io.Dir.cwd().createDirPath(c.io, to);
    var walker = try src.walk(c.a);
    defer walker.deinit();
    while (try walker.next(c.io)) |entry| {
        const dest = c.path(&.{ to, entry.path });
        switch (entry.kind) {
            .directory => try Io.Dir.cwd().createDirPath(c.io, dest),
            .file => try Io.Dir.copyFile(src, entry.path, .cwd(), dest, c.io, .{ .make_path = true }),
            else => {},
        }
    }
}

fn copyMatching(c: *Ctx, from: []const u8, to: []const u8, suffix: []const u8) !void {
    try Io.Dir.cwd().createDirPath(c.io, to);
    for (try listFiles(c, from)) |name| {
        if (!std.mem.endsWith(u8, name, suffix)) continue;
        try Io.Dir.copyFile(.cwd(), c.path(&.{ from, name }), .cwd(), c.path(&.{ to, name }), c.io, .{});
    }
}

/// The finished tree must not hold a path the source manifest takes out of
/// this build (build_python.zig writes the list), nor an object compiled from
/// one.
fn absentInputs(c: *Ctx) !void {
    const list = try readFile(c, c.path(&.{ c.o.work, "absent-inputs" }));
    var lines = std.mem.splitScalar(u8, list, '\n');
    while (lines.next()) |raw| {
        const rel = std.mem.trimEnd(u8, std.mem.trim(u8, raw, " \r"), "/");
        if (rel.len == 0) continue;
        const full = c.path(&.{ c.src, rel });
        var reappeared = fileExists(c.io, full);
        if (!reappeared and std.mem.endsWith(u8, rel, ".c")) {
            reappeared = fileExists(c.io, try std.fmt.allocPrint(c.a, "{s}.o", .{full[0 .. full.len - 2]}));
        }
        if (reappeared) {
            std.debug.print("Excluded build input reappeared: {s}\n", .{rel});
            return error.ExcludedInputReappeared;
        }
    }
}

test "configure's makefile references become shell references in python-config" {
    const a = std.testing.allocator;
    const out = try makeToShell(a, "LDLIBRARY=\"libpython$(LDVERSION).so\" $(1x) $ (A)");
    defer a.free(out);
    try std.testing.expectEqualStrings("LDLIBRARY=\"libpython${LDVERSION}.so\" ${1x} $ (A)", out);
}

test "template substitution leaves unknown markers alone" {
    const a = std.testing.allocator;
    var s: Subst = .empty;
    defer s.deinit(a);
    try s.put(a, "VERSION", "3.14");
    const out = try substitute(a, "v@VERSION@ @UNKNOWN@ a@b", s);
    defer a.free(out);
    try std.testing.expectEqualStrings("v3.14 @UNKNOWN@ a@b", out);
}

test "every release platform has a target and a triplet" {
    for ([_][]const u8{ "linux-x86_64", "linux-aarch64", "macos-x86_64", "macos-aarch64" }) |name| {
        const p = try platformOf(name);
        try std.testing.expect(p.target.len > 0 and p.triplet.len > 0 and p.sysconfig_platform.len > 0);
        try std.testing.expectEqual(p.os == .macos, p.deployment_target != null);
    }
    try std.testing.expectError(error.UnsupportedPlatform, platformOf("windows-x86_64"));
}

test "the build entry point is analyzed" {
    _ = &build;
}
