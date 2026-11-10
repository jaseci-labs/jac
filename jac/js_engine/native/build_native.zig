//! The JavaScript engine's foreign code, built from the build.zig.zon pins
//! into `libjs_native.so`, which ships beside `libjs_engine.so`:
//!
//!   * `libjs_native.so`, compiled here: the engine's C shims -- Node-API
//!     (`napi/shim`), TZif (`tz_shim`) and ECMA-402 over ICU (`icu_shim`) --
//!     plus PCRE2 (RegExp), libuv (event loop), nghttp2 (http2), llhttp
//!     (http/1 parser), brotli, ICU with its data linked in, and mimalloc
//!     (the allocator, see addMimalloc);
//! Sources are compiled straight into the library, so every object is kept;
//! the version script exports only the C APIs the engine imports plus the
//! Node-API surface native addons resolve against, and keeps ICU and the C++
//! runtime private. OpenSSL, zlib and zstd are not here: the engine links
//! them statically from the source-built CPython's archives.

const std = @import("std");

const ICU_DATA_SYMBOL = "icudt74_dat";
const ICU_DATA_FILE = "source/data/in/icudt74l.dat";

pub const JsNative = struct { native: std.Build.LazyPath };

/// Null until the lazy dependencies are fetched, and on targets the engine
/// does not support yet (it is Linux x86_64 only).
pub fn addJsNative(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) ?JsNative {
    if (target.result.os.tag != .linux or target.result.cpu.arch != .x86_64) return null;
    // Ask for every package before giving up on any, so one configure pass
    // fetches them all.
    const deps = .{
        b.lazyDependency("pcre2", .{
            .target = target,
            .optimize = optimize,
            .linkage = std.builtin.LinkMode.static,
        }),
        b.lazyDependency("libuv", .{}),
        b.lazyDependency("nghttp2", .{}),
        b.lazyDependency("brotli", .{}),
        b.lazyDependency("llhttp", .{}),
        b.lazyDependency("node_api_headers", .{}),
        b.lazyDependency("icu4c", .{}),
        b.lazyDependency("mimalloc", .{}),
    };
    inline for (deps) |dep| if (dep == null) return null;
    const pcre2, const libuv, const nghttp2, const brotli, const llhttp, const napi_headers, const icu, const mimalloc = .{
        deps[0].?, deps[1].?, deps[2].?, deps[3].?, deps[4].?, deps[5].?, deps[6].?, deps[7].?,
    };

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
        .pic = true,
        .strip = true,
    });
    for ([_][]const u8{ "pthread", "dl", "m" }) |lib| mod.linkSystemLibrary(lib, .{});

    mod.addImport("pcre2", pcre2.artifact("pcre2-8").root_module);
    addLibuv(mod, libuv);
    addNghttp2(mod, nghttp2);
    addBrotli(mod, brotli);
    mod.addIncludePath(llhttp.path("include"));
    mod.addCSourceFiles(.{ .root = llhttp.path("src"), .files = &.{ "api.c", "http.c", "llhttp.c" } });
    addIcu(b, mod, icu);
    addMimalloc(mod, mimalloc);

    mod.addIncludePath(napi_headers.path("include"));
    mod.addIncludePath(b.path("js_engine/native/tz_shim"));
    mod.addIncludePath(b.path("js_engine/native/icu_shim"));
    mod.addCSourceFiles(.{
        .root = b.path("js_engine"),
        .files = &.{ "napi/shim/napi_shim.c", "native/tz_shim/tz_shim.c", "native/icu_shim/icu_shim.c" },
        .flags = &.{"-DU_STATIC_IMPLEMENTATION"},
    });

    const lib = b.addLibrary(.{ .name = "js_native", .linkage = .dynamic, .root_module = mod });
    lib.setVersionScript(b.path("js_engine/native/js_native.ver"));
    return .{ .native = lib.getEmittedBin() };
}

/// mimalloc in override mode: the library defines malloc, free and the rest of
/// the C allocation API, and js_native.ver exports them. They are the
/// process's allocator when libjs_native.so is loaded ahead of libc -- linked
/// by the executable that runs the engine, or preloaded -- and every object
/// the engine allocates then comes from mimalloc's size-class pages instead
/// of glibc's malloc. Loaded after libc (as a dependency of a dlopen'ed
/// libjs_engine.so) the process keeps glibc's malloc; only the C++ operators,
/// kept local by the version script, still use mimalloc inside this library.
/// The flags are mimalloc's own release build of the override library.
fn addMimalloc(mod: *std.Build.Module, dep: *std.Build.Dependency) void {
    mod.addIncludePath(dep.path("include"));
    mod.addCSourceFiles(.{
        .root = dep.path("src"),
        .files = &.{"static.c"},
        .flags = &.{
            "-DMI_MALLOC_OVERRIDE",
            "-DNDEBUG",
            "-fvisibility=hidden",
            "-ftls-model=initial-exec",
            "-fno-builtin-malloc",
            "-Wno-unknown-pragmas",
        },
    });
}

fn addLibuv(mod: *std.Build.Module, dep: *std.Build.Dependency) void {
    mod.addIncludePath(dep.path("include"));
    mod.addIncludePath(dep.path("src"));
    // CMakeLists.txt's Linux source set and defines.
    mod.addCSourceFiles(.{
        .root = dep.path("src"),
        .files = &.{
            "fs-poll.c",               "idna.c",                     "inet.c",
            "random.c",                "strscpy.c",                  "strtok.c",
            "thread-common.c",         "threadpool.c",               "timer.c",
            "uv-common.c",             "uv-data-getter-setters.c",   "version.c",
            "unix/async.c",            "unix/core.c",                "unix/dl.c",
            "unix/fs.c",               "unix/getaddrinfo.c",         "unix/getnameinfo.c",
            "unix/loop-watcher.c",     "unix/loop.c",                "unix/pipe.c",
            "unix/poll.c",             "unix/process.c",             "unix/random-devurandom.c",
            "unix/signal.c",           "unix/stream.c",              "unix/tcp.c",
            "unix/thread.c",           "unix/tty.c",                 "unix/udp.c",
            "unix/proctitle.c",        "unix/linux.c",               "unix/procfs-exepath.c",
            "unix/random-getrandom.c", "unix/random-sysctl-linux.c",
        },
        .flags = &.{
            "-D_GNU_SOURCE",       "-D_POSIX_C_SOURCE=200112", "-D_FILE_OFFSET_BITS=64",
            "-D_LARGEFILE_SOURCE", "-fno-strict-aliasing",
        },
    });
}

fn addNghttp2(mod: *std.Build.Module, dep: *std.Build.Dependency) void {
    mod.addIncludePath(dep.path("lib/includes"));
    mod.addCSourceFiles(.{
        .root = dep.path("lib"),
        .files = &.{
            "nghttp2_alpn.c",    "nghttp2_buf.c",           "nghttp2_callbacks.c",
            "nghttp2_debug.c",   "nghttp2_extpri.c",        "nghttp2_frame.c",
            "nghttp2_hd.c",      "nghttp2_hd_huffman.c",    "nghttp2_hd_huffman_data.c",
            "nghttp2_helper.c",  "nghttp2_http.c",          "nghttp2_map.c",
            "nghttp2_mem.c",     "nghttp2_option.c",        "nghttp2_outbound_item.c",
            "nghttp2_pq.c",      "nghttp2_priority_spec.c", "nghttp2_queue.c",
            "nghttp2_ratelim.c", "nghttp2_rcbuf.c",         "nghttp2_session.c",
            "nghttp2_stream.c",  "nghttp2_submit.c",        "nghttp2_time.c",
            "nghttp2_version.c", "sfparse.c",
        },
        .flags = &.{
            "-DBUILDING_NGHTTP2",   "-DHAVE_ARPA_INET_H",            "-DHAVE_NETINET_IN_H",
            "-DHAVE_CLOCK_GETTIME", "-DHAVE_DECL_CLOCK_MONOTONIC=1",
        },
    });
}

fn addBrotli(mod: *std.Build.Module, dep: *std.Build.Dependency) void {
    mod.addIncludePath(dep.path("c/include"));
    mod.addCSourceFiles(.{
        .root = dep.path("c"),
        .files = &.{
            "common/constants.c",      "common/context.c",                 "common/dictionary.c",
            "common/platform.c",       "common/shared_dictionary.c",       "common/transform.c",
            "dec/bit_reader.c",        "dec/decode.c",                     "dec/huffman.c",
            "dec/state.c",             "enc/backward_references.c",        "enc/backward_references_hq.c",
            "enc/bit_cost.c",          "enc/block_splitter.c",             "enc/brotli_bit_stream.c",
            "enc/cluster.c",           "enc/command.c",                    "enc/compound_dictionary.c",
            "enc/compress_fragment.c", "enc/compress_fragment_two_pass.c", "enc/dictionary_hash.c",
            "enc/encode.c",            "enc/encoder_dict.c",               "enc/entropy_encode.c",
            "enc/fast_log.c",          "enc/histogram.c",                  "enc/literal_cost.c",
            "enc/memory.c",            "enc/metablock.c",                  "enc/static_dict.c",
            "enc/utf8_util.c",
        },
    });
}

/// ICU's common + i18n libraries, statically, with the release's prebuilt
/// little-endian data file linked in as the `icudt74_dat` entry point the
/// static build resolves its data through (what `genccode` would emit).
fn addIcu(b: *std.Build, mod: *std.Build.Module, dep: *std.Build.Dependency) void {
    mod.addIncludePath(dep.path("source/common"));
    mod.addIncludePath(dep.path("source/i18n"));
    const shared_flags = [_][]const u8{
        "-std=c++17",          "-DU_STATIC_IMPLEMENTATION", "-DU_ATTRIBUTE_DEPRECATED=",
        "-DU_HAVE_STRTOD_L=1", "-fno-exceptions",
    };
    inline for (.{ .{ "common", "-DU_COMMON_IMPLEMENTATION" }, .{ "i18n", "-DU_I18N_IMPLEMENTATION" } }) |part| {
        mod.addCSourceFiles(.{
            .root = dep.path("source/" ++ part[0]),
            .files = cppFilesIn(b, dep, "source/" ++ part[0]),
            .flags = &(shared_flags ++ [_][]const u8{part[1]}),
        });
    }
    const data_asm = b.addWriteFiles().add("icudata.S", b.fmt(
        \\    .section .rodata
        \\    .balign 16
        \\    .globl {0s}
        \\    .type {0s}, @object
        \\{0s}:
        \\    .incbin "{1s}"
        \\    .size {0s}, . - {0s}
        \\    .section .note.GNU-stack,"",@progbits
        \\
    , .{ ICU_DATA_SYMBOL, dep.path(ICU_DATA_FILE).getPath(b) }));
    mod.addAssemblyFile(data_asm);
}

fn cppFilesIn(b: *std.Build, dep: *std.Build.Dependency, sub: []const u8) []const []const u8 {
    const io = b.graph.io;
    var dir = dep.builder.build_root.handle.openDir(io, sub, .{ .iterate = true }) catch |err|
        std.debug.panic("js_native: cannot open icu4c/{s}: {s}", .{ sub, @errorName(err) });
    defer dir.close(io);
    var files: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (it.next(io) catch @panic("js_native: icu4c iterate failed")) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".cpp"))
            files.append(b.allocator, b.dupe(entry.name)) catch @panic("OOM");
    }
    std.mem.sort([]const u8, files.items, {}, struct {
        fn lt(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.lessThan(u8, x, y);
        }
    }.lt);
    return files.items;
}
