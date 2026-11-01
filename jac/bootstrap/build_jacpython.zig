//! The JacPython runtime, built without autoconf or make. build_python.zig has
//! extracted the pruned CPython tree; this lowers the native Jac object with
//! the build-only host, writes pyconfig.h from compiler probes, compiles the C
//! that remains with the flags CPython's makefile uses, links libpython and the
//! interpreter, and installs the tree `make install` installs. The build-only
//! host keeps CPython's own configure and make (build.sh).
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const Environ = std.process.Environ;
const pyconfig = @import("pyconfig.zig");

pub const Options = struct {
    platform: []const u8,
    /// The build tree: src/cpython (extracted), and the install prefix
    /// python/install, as build.sh lays it out for the host.
    work: []const u8,
    zig: []const u8,
    /// bootstrap/python.
    recipe: []const u8,
    /// The build output the build runs on: the bootstrap host, or a previous
    /// JacPython runtime (its python/install, python/build and python/licenses).
    host: []const u8,
    /// The Jac root (jac/).
    root: []const u8,
    jobs: usize,
    environ: *const Environ.Map,
};

const version = "3.14";
const soabi_version = "314";

const Platform = struct {
    os: pyconfig.Os,
    arch: pyconfig.Arch,
    /// zig cc -target.
    target: []const u8,
    /// PLATFORM_TRIPLET: the sysconfigdata name, SOABI and LIBPL suffix.
    triplet: []const u8,
    deployment_target: ?[]const u8 = null,
};

fn platformOf(name: []const u8) !Platform {
    if (std.mem.eql(u8, name, "linux-x86_64")) return .{ .os = .linux, .arch = .x86_64, .target = "x86_64-linux-gnu.2.17", .triplet = "x86_64-linux-gnu" };
    if (std.mem.eql(u8, name, "linux-aarch64")) return .{ .os = .linux, .arch = .aarch64, .target = "aarch64-linux-gnu.2.17", .triplet = "aarch64-linux-gnu" };
    if (std.mem.eql(u8, name, "macos-x86_64")) return .{ .os = .macos, .arch = .x86_64, .target = "x86_64-macos.12.0", .triplet = "darwin", .deployment_target = "12.0" };
    if (std.mem.eql(u8, name, "macos-aarch64")) return .{ .os = .macos, .arch = .aarch64, .target = "aarch64-macos.11.0", .triplet = "darwin", .deployment_target = "11.0" };
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
    for ([_][]const u8{ "CFLAGS", "CPPFLAGS", "LDFLAGS", "CXXFLAGS", "CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "LIBRARY_PATH", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "PYTHONPATH", "PYTHONHOME" }) |name| {
        _ = c.env.swapRemove(name);
    }
    // Transient compiler caches stay in the build tree, as for the host.
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

    // The host's vendored libraries and their notices.
    const host_build = c.path(&.{ o.host, "python/build" });
    try copyTree(&c, c.path(&.{ host_build, "include" }), c.path(&.{ c.deps, "include" }));
    try copyMatching(&c, c.path(&.{ host_build, "lib" }), c.path(&.{ c.deps, "lib" }), ".a");
    try copyTree(&c, c.path(&.{ o.host, "python/licenses" }), c.path(&.{ o.work, "python/licenses" }));

    try step(&c, "pyconfig", writePyconfig, .{&c});

    // The frozen modules (importlib's bootstrap, zipimport, getpath.py and the
    // startup stdlib), compiled and marshalled by the host as
    // _freeze_module.py would, with getpath's build inputs, and written as one
    // Jac module the native object links. _PyRuntime's initializer, which
    // only the C preprocessor builds from pycore_runtime_init.h, compiled for
    // this target against this tree's pyconfig.h and written as the C data of
    // another. Then the native object itself.
    const native = c.path(&.{ o.work, "native" });
    const frozen = c.path(&.{ native, "frozen_modules.jac" });
    const runtime_image = c.path(&.{ native, "runtime_image.jac" });
    try Io.Dir.cwd().createDirPath(io, native);
    try step(&c, "frozen", generate, .{ &c, try getpathArgs(&c, frozen) });
    try step(&c, "runtime_image", generate, .{ &c, try runtimeImageArgs(&c, runtime_image) });
    try step(&c, "native", runArgv, .{ &c, &[_][]const u8{ hostPython(&c), "-I", c.path(&.{ o.recipe, "prepare_native.py" }), o.root, native, o.platform, frozen, runtime_image }, null });

    try step(&c, "compile", compile, .{&c});
    try step(&c, "link", link, .{&c});
    try step(&c, "install", install, .{&c});
    try step(&c, "sysconfig", sysconfig, .{&c});
    try step(&c, "compileall", compileall, .{&c});
    try step(&c, "install-tools", installTools, .{&c});
    try absentInputs(&c);

    try step(&c, "finalize", runArgv, .{ &c, &[_][]const u8{ c.path(&.{ c.prefix, "bin/python" ++ version }), "-I", c.path(&.{ o.recipe, "finalize.py" }) }, null });
    const build_dir = c.path(&.{ o.work, "python/build" });
    try Io.Dir.cwd().createDirPath(io, c.path(&.{ build_dir, "lib" }));
    try copyMatching(&c, c.path(&.{ c.deps, "lib" }), c.path(&.{ build_dir, "lib" }), ".a");
    // The headers too: with the archives, they let this runtime be the next
    // build's host without the bootstrap host that built them.
    try copyTree(&c, c.path(&.{ c.deps, "include" }), c.path(&.{ build_dir, "include" }));
    try Io.Dir.copyFile(.cwd(), c.path(&.{ host_build, "cacert.pem" }), .cwd(), c.path(&.{ build_dir, "cacert.pem" }), io, .{});
    try Io.Dir.copyFile(.cwd(), c.path(&.{ native, "sha256" }), .cwd(), c.path(&.{ build_dir, "jacpython-native-sha256" }), io, .{});
    try Io.Dir.copyFile(.cwd(), c.path(&.{ native, "sources" }), .cwd(), c.path(&.{ build_dir, "jacpython-native-sources" }), io, .{});
    try Io.Dir.cwd().deleteTree(io, native);
    try c.env.put("PYTHONFAULTHANDLER", "1");
    try step(&c, "smoke", runArgv, .{ &c, &[_][]const u8{ c.path(&.{ c.prefix, "bin/python" ++ version }), "-X", "faulthandler", "-I", c.path(&.{ o.recipe, "smoke.py" }), "jacpython" }, null });
    // No compiled test modules, docs, or configuration machinery in the runtime.
    for ([_][]const u8{ "share", "lib/python" ++ version ++ "/test", "lib/python" ++ version ++ "/idlelib", "lib/python" ++ version ++ "/tkinter", "lib/python" ++ version ++ "/turtledemo" }) |rel| {
        try Io.Dir.cwd().deleteTree(io, c.path(&.{ c.prefix, rel }));
    }
    std.debug.print("build-python: runtime and native archives ready\n", .{});
}

fn hostPython(c: *Ctx) []const u8 {
    return c.path(&.{ c.o.host, "python/install/bin/python" ++ version });
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

/// Run commands `jobs` at a time; every one must succeed.
fn runAll(c: *Ctx, commands: []const []const []const u8, cwd: ?[]const u8) !void {
    var start: usize = 0;
    var failed = false;
    while (start < commands.len) {
        const end = @min(commands.len, start + @max(c.o.jobs, 1));
        var children: std.ArrayList(std.process.Child) = .empty;
        for (commands[start..end]) |argv| try children.append(c.a, try spawn(c, argv, cwd));
        for (children.items) |*child| {
            const term = try child.wait(c.io);
            if (term != .exited or term.exited != 0) failed = true;
        }
        if (failed) return error.CommandFailed;
        start = end;
    }
}

/// One of scripts/jacpython's generators, run by the build-only host with the
/// checkout's jaclang on its path; the generator's main() takes the arguments.
fn generate(c: *Ctx, args: []const []const u8) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(c.a, &.{
        hostPython(c), "-I",                                           "-c",
        \\import importlib, sys
        \\sys.path[:0] = sys.argv[1:3]
        \\import jaclang
        \\importlib.import_module(sys.argv[3]).main(sys.argv[4:])
        ,
        c.o.root,      c.path(&.{ c.o.root, "../scripts/jacpython" }),
    });
    try argv.appendSlice(c.a, args);
    try runArgv(c, argv.items, null);
}

/// gen_frozen's arguments: the frozen modules and getpath's configured
/// locations, the values CPython's makefile passes to Modules/getpath.c
/// (makefileVars installs the same PLATLIBDIR; an in-tree build has an empty
/// VPATH).
fn getpathArgs(c: *Ctx, output: []const u8) ![]const []const u8 {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(c.a, &.{ "gen_frozen", "--source", c.src, "--output", output });
    try argv.appendSlice(c.a, &.{ "--prefix", c.prefix, "--exec-prefix", c.prefix });
    try argv.appendSlice(c.a, &.{ "--pythonpath", "", "--vpath", "", "--platlibdir", "lib" });
    return argv.items;
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

const Object = struct {
    source: []const u8,
    object: []const u8,
    /// Extra flags before or after the common ones, as the makefile rule has them.
    before: []const []const u8 = &.{},
    after: []const []const u8 = &.{},
    hacl: bool = false,
};

/// HACL*'s vectorized BLAKE2 objects, when the target can compile them.
fn haclSimd(c: *Ctx) struct { v128: bool, v256: bool, universal2: bool } {
    return .{
        .v128 = c.probes.defined("_Py_HACL_CAN_COMPILE_VEC128"),
        .v256 = c.probes.defined("_Py_HACL_CAN_COMPILE_VEC256"),
        // configure picks the universal2 wrappers when building on Apple silicon.
        .universal2 = c.p.os == .macos and c.p.arch == .aarch64,
    };
}

const hacl_dir = "Modules/_hacl";

/// The HACL* archives the native modules link (jacpython-modules.txt names
/// them) and the objects each holds, as the makefile groups them.
const Archive = struct { name: []const u8, objects: []const []const u8 };

fn haclArchives(c: *Ctx) ![]const Archive {
    const a = c.a;
    const simd = haclSimd(c);
    var blake2: std.ArrayList([]const u8) = .empty;
    try blake2.appendSlice(a, &.{ hacl_dir ++ "/Hacl_Hash_Blake2s.o", hacl_dir ++ "/Hacl_Hash_Blake2b.o", hacl_dir ++ "/Lib_Memzero0.o" });
    if (simd.v128) try blake2.append(a, if (simd.universal2) hacl_dir ++ "/Hacl_Hash_Blake2s_Simd128_universal2.o" else hacl_dir ++ "/Hacl_Hash_Blake2s_Simd128.o");
    if (simd.v256) try blake2.append(a, if (simd.universal2) hacl_dir ++ "/Hacl_Hash_Blake2b_Simd256_universal2.o" else hacl_dir ++ "/Hacl_Hash_Blake2b_Simd256.o");
    const md5 = &[_][]const u8{hacl_dir ++ "/Hacl_Hash_MD5.o"};
    const sha1 = &[_][]const u8{hacl_dir ++ "/Hacl_Hash_SHA1.o"};
    const sha2 = &[_][]const u8{hacl_dir ++ "/Hacl_Hash_SHA2.o"};
    const sha3 = &[_][]const u8{hacl_dir ++ "/Hacl_Hash_SHA3.o"};
    var hmac: std.ArrayList([]const u8) = .empty;
    try hmac.appendSlice(a, &.{ hacl_dir ++ "/Hacl_HMAC.o", hacl_dir ++ "/Hacl_Streaming_HMAC.o" });
    try hmac.appendSlice(a, md5);
    try hmac.appendSlice(a, sha1);
    try hmac.appendSlice(a, sha2);
    try hmac.appendSlice(a, sha3);
    try hmac.appendSlice(a, blake2.items);
    return try a.dupe(Archive, &.{
        .{ .name = hacl_dir ++ "/libHacl_Hash_MD5.a", .objects = md5 },
        .{ .name = hacl_dir ++ "/libHacl_Hash_SHA1.a", .objects = sha1 },
        .{ .name = hacl_dir ++ "/libHacl_Hash_SHA2.a", .objects = sha2 },
        .{ .name = hacl_dir ++ "/libHacl_Hash_SHA3.a", .objects = sha3 },
        .{ .name = hacl_dir ++ "/libHacl_Hash_BLAKE2.a", .objects = blake2.items },
        .{ .name = hacl_dir ++ "/libHacl_HMAC.a", .objects = hmac.items },
    });
}

/// The object prepare_native.py lowers the Jac runtime into.
const native_object = "Python/jacpython.o";

/// LIBRARY_OBJS, what libpython and the interpreter hold: the native object.
fn libraryObjects(c: *Ctx) ![]const []const u8 {
    return c.a.dupe([]const u8, &.{native_object});
}

fn compile(c: *Ctx) !void {
    const a = c.a;
    var src_dir = try Io.Dir.cwd().openDir(c.io, c.src, .{});
    defer src_dir.close(c.io);
    try src_dir.createDirPath(c.io, "Python");
    try Io.Dir.copyFile(.cwd(), c.path(&.{ c.o.work, "native/jacpython.o" }), src_dir, native_object, c.io, .{});

    const f = Flags.of(c.p);
    const stdmodule = try stdmoduleCflags(c, f);
    var objects: std.ArrayList(Object) = .empty;
    try objects.append(a, .{ .source = "./Programs/python.c", .object = "Programs/python.o" });
    const simd = haclSimd(c);
    const hacl = [_][]const u8{ "Lib_Memzero0", "Hacl_Hash_MD5", "Hacl_Hash_SHA1", "Hacl_Hash_SHA2", "Hacl_Hash_SHA3", "Hacl_Hash_Blake2s", "Hacl_Hash_Blake2b", "Hacl_HMAC" };
    for (hacl) |name| {
        try objects.append(a, .{ .source = try std.fmt.allocPrint(a, "./" ++ hacl_dir ++ "/{s}.c", .{name}), .object = try std.fmt.allocPrint(a, hacl_dir ++ "/{s}.o", .{name}), .hacl = true });
    }
    try objects.append(a, .{ .source = "./" ++ hacl_dir ++ "/Hacl_Streaming_HMAC.c", .object = hacl_dir ++ "/Hacl_Streaming_HMAC.o", .before = &.{"-Wno-unused-variable"}, .hacl = true });
    const simd128 = &[_][]const u8{ "-msse", "-msse2", "-msse3", "-msse4.1", "-msse4.2", "-DHACL_CAN_COMPILE_VEC128" };
    const simd256 = &[_][]const u8{ "-mavx2", "-DHACL_CAN_COMPILE_VEC256" };
    if (simd.v128) {
        const name = if (simd.universal2) "Hacl_Hash_Blake2s_Simd128_universal2" else "Hacl_Hash_Blake2s_Simd128";
        try objects.append(a, .{ .source = try std.fmt.allocPrint(a, "./" ++ hacl_dir ++ "/{s}.c", .{name}), .object = try std.fmt.allocPrint(a, hacl_dir ++ "/{s}.o", .{name}), .after = simd128, .hacl = true });
    }
    if (simd.v256) {
        const name = if (simd.universal2) "Hacl_Hash_Blake2b_Simd256_universal2" else "Hacl_Hash_Blake2b_Simd256";
        try objects.append(a, .{ .source = try std.fmt.allocPrint(a, "./" ++ hacl_dir ++ "/{s}.c", .{name}), .object = try std.fmt.allocPrint(a, hacl_dir ++ "/{s}.o", .{name}), .after = simd256, .hacl = true });
    }

    // LIBHACL_CFLAGS: HACL*'s include paths and feature macros, glibc's lack of
    // explicit_bzero before 2.25, then PY_STDMODULE_CFLAGS and CCSHARED.
    var hacl_flags: std.ArrayList([]const u8) = .empty;
    try hacl_flags.appendSlice(a, &.{ "-I./" ++ hacl_dir, "-I./" ++ hacl_dir ++ "/include", "-D_BSD_SOURCE", "-D_DEFAULT_SOURCE" });
    if (c.p.os == .linux and !c.probes.defined("HAVE_EXPLICIT_BZERO")) try hacl_flags.append(a, "-DLINUX_NO_EXPLICIT_BZERO");
    try hacl_flags.appendSlice(a, stdmodule);
    try appendWords(a, &hacl_flags, f.ccshared);

    var commands: std.ArrayList([]const []const u8) = .empty;
    for (objects.items) |obj| {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(a, c.cc);
        try argv.appendSlice(a, obj.before);
        try argv.append(a, "-c");
        if (obj.hacl) {
            try argv.appendSlice(a, hacl_flags.items);
        } else {
            try argv.appendSlice(a, stdmodule);
            try argv.append(a, "-DPy_BUILD_CORE");
        }
        try argv.appendSlice(a, obj.after);
        try argv.appendSlice(a, &.{ "-o", obj.object, obj.source });
        try commands.append(a, argv.items);
    }
    try runAll(c, commands.items, c.src);

    for (try haclArchives(c)) |archive| {
        src_dir.deleteFile(c.io, archive.name) catch {};
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(a, &.{ c.o.zig, "ar", "rcs", archive.name });
        try argv.appendSlice(a, archive.objects);
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
    const host_type = try hostType(c);
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
        \\BUILD_GNU_TYPE= {[host_type]s}
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

/// config.guess's name for the build machine.
fn hostType(c: *Ctx) ![]const u8 {
    return switch (c.p.os) {
        .linux => if (c.p.arch == .x86_64) "x86_64-pc-linux-gnu" else "aarch64-unknown-linux-gnu",
        .macos => blk: {
            const uts = std.posix.uname();
            const release = std.mem.sliceTo(&uts.release, 0);
            break :blk try std.fmt.allocPrint(c.a, "{s}-apple-darwin{s}", .{ @tagName(c.p.arch), release });
        },
    };
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
    defer for ([_][]const u8{ "CFLAGS", "CPPFLAGS", "LDFLAGS" }) |name| {
        _ = c.env.swapRemove(name);
    };
    try runArgv(c, &.{
        l.exename,                         "-E",                                    "-S", "-c",
        \\import sys
        \\import sysconfig.__main__ as generator
        \\generator.get_makefile_filename = lambda: sys.argv[1]
        \\generator.get_config_h_filename = lambda: sys.argv[2]
        \\generator._generate_posix_vars()
        ,
        c.path(&.{ l.libpl, "Makefile" }), c.path(&.{ l.includepy, "pyconfig.h" }),
    }, gen);
    const builddir = std.mem.trim(u8, try readFile(c, c.path(&.{ gen, "pybuilddir.txt" })), " \r\n");
    const name = try std.fmt.allocPrint(c.a, "_sysconfigdata__{s}_{s}", .{ if (c.p.os == .linux) "linux" else "darwin", c.p.triplet });
    const data = c.path(&.{ gen, builddir, try std.fmt.allocPrint(c.a, "{s}.py", .{name}) });
    const json_name = try std.fmt.allocPrint(c.a, "_sysconfig_vars__{s}_{s}.json", .{ if (c.p.os == .linux) "linux" else "darwin", c.p.triplet });
    const details = c.path(&.{ gen, builddir, "build-details.json" });
    // build-details.json (PEP 739); JacPython keeps no Tools/build: the
    // generator reads this build's sysconfig data.
    try generate(c, &.{ "gen_build_details", "--sysconfig", data, "--output", details });
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
    try runArgv(c, &.{ l.exename, "-E", "-Wi", script, "-o", "0", "-o", "1", "-o", "2", jobs, "-d", l.libdest, "-f", "-x", "bad_coding|badsyntax|site-packages", l.libdest }, null);
    const site = c.path(&.{ l.libdest, "site-packages" });
    try runArgv(c, &.{ l.exename, "-E", "-Wi", script, "-o", "0", "-o", "1", "-o", "2", jobs, "-d", site, "-f", "-x", "badsyntax", site }, null);
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
        try std.testing.expect(p.target.len > 0 and p.triplet.len > 0);
        try std.testing.expectEqual(p.os == .macos, p.deployment_target != null);
    }
    try std.testing.expectError(error.UnsupportedPlatform, platformOf("windows-x86_64"));
}

test "the build entry point is analyzed" {
    _ = &build;
}
