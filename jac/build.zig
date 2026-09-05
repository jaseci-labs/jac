//! Build the self-contained `jac` binary.
//!
//! The binary is `[ launcher stub ][ runtime.tar.zst payload ][ trailer ]`.
//! Both halves are produced by Jac:
//!
//!   * the launcher stub is `launcher/launcher.jac` over the fused-runtime
//!     library (`jaclang/dist/fused`), compiled by the in-checkout
//!     compiler with `jac build --as native` (the Jac-native linkers; no
//!     external toolchain) -- it links only libc/libdl and dlopens the bundled
//!     CPython at runtime;
//!   * the payload tool is `jaclang.dist.payload`, Python-tier Jac that fetches the
//!     vendored inputs, stages the runtime tree, packs it, and appends it to the
//!     stub with the trailer.
//!
//! Both run on the pbs CPython the build fetches first (through JACBOOT_SRC
//! below), and both must be COMPILED before they run, which needs the vendored
//! typeshed stdlib -- type inference is on the critical path of every
//! compilation. So the two things that must exist before any Jac does are the
//! Zig seeds `bootstrap/fetch_pbs.zig` and `bootstrap/fetch_typeshed.zig`; a
//! Jac tool can never be the thing that fetches either, or the bootstrap has a
//! cycle in it (#8785). Zig is otherwise the C/C++ cross-compiler: the LLVMPY_*
//! shim (`zig c++`), the static-musl harvest, and the wasm32 libc bitcode.
//!
//!   zig build test                 # bootstrap unit tests
//!   zig build stub                 # just the launcher stub (no payload)
//!   zig build                      # the full jac binary -> zig-out/bin/jac
//!   zig build -Ddev                # FAST dev binary: don't bundle the compiler,
//!                                  #   link it live from the build root instead
//!   zig build -Djaclang-dir=PATH   # like -Ddev but link an explicit compiler dir
//!   zig build -Dpayload=PATH       # pack a prebuilt payload (skip fetch+mkpayload)
//!   zig build -Dpayload-progress   # stream the payload build live (no caching)
//!   zig build -Dtarget=aarch64-macos
//!
//! Build-time host tools: just `zig` and a network connection. The payload tool
//! shells out only to the freshly-fetched pbs python (pip + JIR precompile),
//! which provides its own pip, and -- best-effort, optional -- to `strip` to
//! shrink the unstripped pbs libpython; without `strip` the build still works,
//! the binary is just larger. The shipped binary needs none of these.

const std = @import("std");
// Pinned toolchain inputs (pbs, LLVM slices), read from bootstrap/pins.json --
// the single source of truth shared with the Jac payload tool.
const pins = @import("bootstrap/pins.zig");

// Where `zig build fetch-llvm` extracts the pinned LLVM -- one dir per platform.
// Used as the default -Dllvm-dir for the jacllvm shim. Returns null for
// platforms we don't pin a release for, so addLlvmShim degrades gracefully
// (the build then fails at mkpayload with a "run `zig build fetch-llvm`"
// message).
const LLVM_CACHE_BASE = ".llvm-build";
fn llvmCacheDir(b: *std.Build, target: std.Build.ResolvedTarget) ?[]const u8 {
    const rel = pins.llvmRelease(b, osArchString(target.result)) orelse return null;
    return b.fmt("{s}/{s}", .{ LLVM_CACHE_BASE, rel.dirname });
}

// The built LLVMPY_* shim: `bin` is bundled into the payload (--shim); `place`
// writes it into the source tree for the editable dev loop. `bin` is a LazyPath
// (not a *Compile) so the Linux `zig c++` path and the macOS system-`c++`
// link path can both feed it through the same mkpayload/place plumbing.
const Shim = struct { bin: std.Build.LazyPath, place: *std.Build.Step };

/// The Python that boots the in-checkout compiler on the pbs CPython. `zig
/// build` fetches python-build-standalone first (bootstrap/fetch_pbs.zig, the
/// one step that runs before any Python exists) and then drives every other
/// build step through this program, so the build tooling is Jac
/// (`jaclang.dist.payload`) and needs no prior jac binary:
///
///     <pbs-python> -I -c JACBOOT <root> payload <subcommand> [args...]   # jaclang.dist.payload.cli
///     <pbs-python> -I -c JACBOOT <root> jac <jac-cli-args...>             # the jac CLI itself
///
/// `-I` keeps the interpreter isolated from the ambient environment; the
/// checkout root is put on sys.path explicitly and the lazy `.jac` finder
/// installed, which is all importing the compiler from source takes (jaclang
/// has no third-party runtime dependencies). JAC_NO_DEV_SOURCE pins the build
/// to this checkout: it must never be rerouted to a dev-source tree or a
/// project venv, because this checkout IS the source being built.
const JACBOOT_SRC =
    "import os, sys\n" ++
    "root, mode, argv = sys.argv[1], sys.argv[2], sys.argv[3:]\n" ++
    "sys.path.insert(0, root)\n" ++
    "os.environ['JAC_NO_DEV_SOURCE'] = '1'\n" ++
    "os.environ['JAC_STUBCAT_BUILDING'] = '1'\n" ++
    "import _jac_finder\n" ++
    "_jac_finder.install()\n" ++
    "if mode == 'payload':\n" ++
    "    from jaclang.dist.payload.cli import main\n" ++
    "    sys.exit(int(main(argv) or 0))\n" ++
    "sys.argv = ['jac'] + argv\n" ++
    "from jaclang.cli.cli_boot import start_cli\n" ++
    "start_cli()\n";

/// The Jac build tooling, as a runnable. Every run depends on BOTH seed
/// fetches, which is what keeps the bootstrap acyclic: the callee imports the
/// compiler from this checkout and compiling anything at all needs the pbs
/// CPython to run on and the vendored typeshed to type-check against, so a Jac
/// tool run can never be the thing that puts either of them in place (#8785).
/// Callers that cache on inputs must also declare the jaclang tree
/// (addTreeInputs).
const JacTool = struct {
    b: *std.Build,
    python: []const u8,
    root: []const u8,
    fetch_pbs: *std.Build.Step,
    fetch_typeshed: *std.Build.Step,

    fn run(self: JacTool, mode: []const u8, args: []const []const u8) *std.Build.Step.Run {
        const cmd = self.b.addSystemCommand(&.{ self.python, "-I", "-c", JACBOOT_SRC, self.root, mode });
        cmd.addArgs(args);
        cmd.step.dependOn(self.fetch_pbs);
        cmd.step.dependOn(self.fetch_typeshed);
        return cmd;
    }
};

pub fn build(b: *std.Build) void {
    // Build for a BASELINE CPU of the host arch, not the build machine's native
    // CPU. The `jac` binary is distributed -- and in CI it is built once then
    // run on other runners via the setup-jac output cache. If an explicit
    // `-Dtarget=` is passed we honor it as-is; otherwise we pin the host
    // arch/os to a baseline CPU. (The Jac-compiled stub is already emitted for
    // the generic CPU of its triple; this pin governs the C/C++ shim.)
    const target = if (b.user_input_options.contains("target"))
        b.standardTargetOptions(.{})
    else
        b.resolveTargetQuery(.{ .cpu_model = .baseline });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    // --- LLVMPY_* shim: compile jac/native/*.cpp + statically link host LLVM ---
    // Replaces the bundled libllvmlite.so (llvmlite wheel). Gated on -Dllvm-dir
    // (an extracted LLVM 22.1.x prebuilt) or the fetch-llvm cache; without
    // either the step is unavailable. See jac/native/README.md, #6925.
    const jacllvm = addLlvmShim(b, target, optimize);

    // --- unit tests (the Zig bootstrap seed) -------------------------------
    addTests(b, target, optimize);

    // --- Stage 0: the two inputs that must exist before any Jac compiles -----
    // The pbs CPython the Jac tooling runs ON, and the typeshed stdlib stubs it
    // type-checks AGAINST. Type inference is on the critical path of every
    // compilation, so both are hard prerequisites of compiling even the build
    // tooling itself -- which is why both are fetched by Zig seeds and not by
    // the Jac payload tool (#8785). Both are idempotent: a no-op when the tree
    // is already there, so a cache hit costs a file probe.
    const host_osarch = osArchString(b.graph.host.result) orelse {
        // Unsupported build host: only the shim/test steps are available.
        return;
    };
    const seed_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/fetch_pbs.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    const seed = b.addExecutable(.{ .name = "fetch_pbs", .root_module = seed_mod });
    const pins_path = b.pathFromRoot(pins.PINS_PATH);
    const host_pbs_dir = b.pathFromRoot(b.fmt(".pbs-build/{s}", .{host_osarch}));
    const fetch_host = b.addRunArtifact(seed);
    fetch_host.addArgs(&.{ host_osarch, host_pbs_dir, pins_path });
    fetch_host.has_side_effects = true;
    const root = b.pathFromRoot(".");

    // The typeshed seed reads its pin (PIN + TARBALL_SHA256) out of the vendor
    // dir it fills, the same two files the payload tool's own fetch-typeshed
    // reads, so the two fetchers can never disagree.
    const ts_seed_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/fetch_typeshed.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    const ts_seed = b.addExecutable(.{ .name = "fetch_typeshed", .root_module = ts_seed_mod });
    const fetch_ts = b.addRunArtifact(ts_seed);
    fetch_ts.addArg(b.pathFromRoot("jaclang/vendor/typeshed"));
    // has_side_effects: the output lands in the source tree, not the cache, so
    // the step must run even when its (unchanging) argv would otherwise cache
    // it away -- a clean checkout has to materialize the stubs.
    fetch_ts.has_side_effects = true;
    fetch_ts.addFileInput(b.path("jaclang/vendor/typeshed/PIN"));
    fetch_ts.addFileInput(b.path("jaclang/vendor/typeshed/TARBALL_SHA256"));

    const tool = JacTool{
        .b = b,
        .python = b.fmt("{s}/python/install/bin/python{s}", .{ host_pbs_dir, pins.pyMinor(b) }),
        .root = root,
        .fetch_pbs = &fetch_host.step,
        .fetch_typeshed = &fetch_ts.step,
    };

    // Standalone step: materialize the gitignored typeshed stdlib stubs at the
    // pinned commit, without building a binary. Used by CI (test-binary) and
    // local dev to enable from-source `jac check` / the test suite. Pure Zig, so
    // it works on a checkout where nothing can compile yet -- which is exactly
    // the state the error messages that point here describe.
    b.step("fetch-typeshed", "Fetch the pinned typeshed stdlib stubs into the checkout")
        .dependOn(&fetch_ts.step);

    // Standalone: fetch the pinned LLVM subset the jacllvm shim needs into
    // .llvm-build/ (one-time, ~84 MB range-fetched from the llvm-slice zip). After
    // this, a plain `zig build` picks it up via llvmCacheDir and ships the
    // wheel-free binary.
    {
        const fetch_llvm = tool.run("payload", &.{ "fetch-llvm", b.pathFromRoot(LLVM_CACHE_BASE) });
        fetch_llvm.has_side_effects = true;
        b.step("fetch-llvm", "Range-fetch the pinned LLVM subset for the wheel-free jacllvm shim")
            .dependOn(&fetch_llvm.step);
    }

    // Standalone: place the pinned, contained bun runtime into the source tree at
    // jaclang/client/_bun/ for the HOST. Editable/source checkouts,
    // the test suite, and -Ddev linked binaries resolve it there via get_bun()'s
    // __file__-relative lookup. (Normal/release builds instead bundle a
    // target-matched bun into the payload; see the payload block below.)
    {
        const fetch_bun = tool.run("payload", &.{ "fetch-bun", host_osarch, b.pathFromRoot("jaclang/client/_bun") });
        fetch_bun.has_side_effects = true;
        b.step("fetch-bun", "Place the pinned bun into the source tree (editable/dev + tests)")
            .dependOn(&fetch_bun.step);
    }

    // Standalone: harvest a static-musl runtime (libc.a + libzigc.a + compiler-rt
    // + crt) from the bundled Zig toolchain into .pbs-build/<osarch>/musl/lib, so
    // `jac nacompile` can fully static-link Linux executables against musl with
    // NO external toolchain at compile time. Idempotent; Linux only.
    if (std.mem.startsWith(u8, host_osarch, "linux-")) {
        const vendor_musl = tool.run("payload", &.{ "build-musl", host_osarch, b.pathFromRoot(b.fmt(".pbs-build/{s}/musl/lib", .{host_osarch})), b.graph.zig_exe });
        vendor_musl.has_side_effects = true;
        b.step("vendor-musl", "Harvest a static-musl runtime from Zig into .pbs-build/<osarch>/musl/lib")
            .dependOn(&vendor_musl.step);
    }

    // Arch-parameterized variants: `zig cc -target <arch>-linux-musl` cross-
    // compiles musl from any host, so a cross `jac nacompile` and the aarch64 CI
    // lane can static-link without target hardware (#7626 C1).
    inline for ([_][]const u8{ "linux-x86_64", "linux-aarch64" }) |cross_osarch| {
        const vendor_musl_cross = tool.run("payload", &.{ "build-musl", cross_osarch, b.pathFromRoot(b.fmt(".pbs-build/{s}/musl/lib", .{cross_osarch})), b.graph.zig_exe });
        vendor_musl_cross.has_side_effects = true;
        b.step(b.fmt("vendor-musl-{s}", .{cross_osarch}), b.fmt("Harvest a static-musl runtime for {s} (cross-capable) into .pbs-build/{s}/musl/lib", .{ cross_osarch, cross_osarch }))
            .dependOn(&vendor_musl_cross.step);
    }

    // Standalone: compile the in-repo wasm_rt libc (vendored musl/wasi-libc
    // subset + jac allocator/io/abi adapters) to wasm32 LLVM bitcode under
    // .pbs-build/wasm32/libc, so na->wasm builds link libc INTO the module
    // (#7048). Target-independent, so it runs everywhere.
    {
        const vendor_wasm_libc = tool.run("payload", &.{
            "build-wasm-libc",
            b.pathFromRoot("jaclang/compiler/backends/native/wasm_rt"),
            b.pathFromRoot(".pbs-build/wasm32/libc"),
            b.graph.zig_exe,
        });
        vendor_wasm_libc.has_side_effects = true;
        b.step("vendor-wasm-libc", "Compile the wasm_rt libc to bitcode into .pbs-build/wasm32/libc")
            .dependOn(&vendor_wasm_libc.step);
    }

    const osarch = osArchString(target.result) orelse {
        // Unsupported target for a full binary; the standalone steps still work.
        return;
    };

    // The TARGET's pbs tree: the payload input, and the C floor archives
    // (libzstd.a, libcrypto.a, ...) the stub static-links. Same tree as the
    // host's whenever host == target, which is every CI lane.
    const pbs_dir = b.pathFromRoot(b.fmt(".pbs-build/{s}", .{osarch}));
    const pbs_python = b.fmt("{s}/python", .{pbs_dir});
    const fetch_target: *std.Build.Step = if (std.mem.eql(u8, osarch, host_osarch)) &fetch_host.step else blk: {
        const fetch = b.addRunArtifact(seed);
        fetch.addArgs(&.{ osarch, pbs_dir, pins_path });
        fetch.has_side_effects = true;
        break :blk &fetch.step;
    };

    // --- launcher stub: the in-checkout compiler compiles launcher/ natively --
    // `--strict` makes any native-seam demotion in the stub's closure a hard
    // error: a function demoted to Python-only cannot run before CPython
    // exists. (The whole-program type-check gate is not used here: it cannot
    // see the bundled per-OS native floors the launcher imports.) Needs the
    // LLVMPY_* shim placed in-tree and the target's C floor archives.
    const build_stub = tool.run("jac", &.{ "nacompile", "--strict" });
    build_stub.addFileArg(b.path("launcher/launcher.jac"));
    build_stub.addArg("-o");
    const stub = build_stub.addOutputFileArg("jac-stub");
    build_stub.setCwd(b.path("launcher"));
    build_stub.step.dependOn(fetch_target);
    if (jacllvm) |shim| build_stub.step.dependOn(shim.place);
    addTreeInputs(b, build_stub, "jaclang");
    build_stub.addFileInput(b.path("launcher/launcher.jac"));
    b.step("stub", "Build just the launcher stub (no payload)")
        .dependOn(&b.addInstallBinFile(stub, "jac").step);

    // --- runtime payload: -Dpayload override, else mkpayload ---------------
    // The stub catalog (pre-resolved typeshed types) is a second mkpayload
    // output that `pack` places as its own page-aligned region of the binary;
    // a prebuilt -Dpayload carries the same catalog as a file inside it.
    var stubcat_region: ?std.Build.LazyPath = null;
    const payload: std.Build.LazyPath = if (b.option([]const u8, "payload", "Path to a prebuilt runtime payload .tar.zst")) |p|
        .{ .cwd_relative = p }
    else payload: {
        // Assemble the payload. Cacheable (output-file arg), so Zig CAPTURES
        // its stdio and prints it only on failure -- the "==>" logs stay hidden.
        // `-Dpayload-progress` flips stdio to .inherit so the build streams live;
        // the tradeoff is .inherit marks the step as having side-effects, so it
        // ALWAYS repacks (no caching) while the flag is on.
        const mk = tool.run("payload", &.{ "mkpayload", pbs_python, root });
        if (b.option(bool, "payload-progress", "Stream the payload build (mkpayload) live; disables its caching") orelse false) {
            mk.stdio = .inherit;
        }
        mk.step.dependOn(fetch_target);
        const out = mk.addOutputFileArg("payload.tar.zst");
        stubcat_region = mk.addPrefixedOutputFileArg("--stubcat-out=", "stubcat.bin");
        if (b.option(bool, "skip-stubcat", "mkpayload: skip the stub catalog build (the type checker builds it on first use)") orelse false) {
            mk.addArg("--skip-stubcat");
        }
        // Optional trailing flags (parsed after the positional pbs/root/out):
        // --shim ships the Zig-built LLVMPY_* shim; --skip-precompile drops the
        // JIR precompile (fast link validation; first run compiles on demand).
        if (jacllvm) |shim| {
            mk.addPrefixedFileArg("--shim=", shim.bin);
            // A plain `zig build` also drops the shim into the source tree so the
            // editable dev loop works without any manual step.
            b.getInstallStep().dependOn(shim.place);
        }
        const skip_precompile = b.option(bool, "skip-precompile", "mkpayload: skip the JIR precompile (faster link validation)") orelse false;
        if (skip_precompile) {
            mk.addArg("--skip-precompile");
        }
        // Editable dev binary: ship a payload WITHOUT the bundled compiler and
        // reroute `import jaclang` to a live source dir at startup (see
        // _jac_finder.py apply_dev_source_override). Skips the tree copy AND
        // the JIR precompile, so the build is much faster. The resulting binary
        // is NOT distributable: it hard-depends on `link_dir`. It needs no
        // kernel step either: the shim placed by `shim.place` is enough, and
        // the first parse derives libjac_compiler beside native_compiler.jac
        // through the link plan (compiler/backends/native/kernel_resolve.jac),
        // relinking only when the plan digest over the scope units moves.
        //   -Ddev            link the build root (jaclang/ in THIS tree)
        //   -Djaclang-dir=P  link an explicit dir containing jaclang/
        const opt_jaclang_dir = b.option([]const u8, "jaclang-dir", "Editable dev binary: link the compiler from this dir (containing jaclang/) instead of bundling it");
        const opt_dev = b.option(bool, "dev", "Editable dev binary: link the compiler from the build root instead of bundling it (implies skip-precompile)") orelse false;
        const link_dir: ?[]const u8 = if (opt_jaclang_dir) |d|
            (if (std.fs.path.isAbsolute(d)) d else b.pathFromRoot(d))
        else if (opt_dev)
            root
        else
            null;
        if (link_dir) |d| {
            mk.addArg(b.fmt("--link-source={s}", .{d}));
        }
        // Persistent JIR precompile cache: seeds site/jaclang/_precompiled
        // before the precompile and is refreshed after, so only changed modules
        // recompile. Content-keyed per module, so a stale dir can never change
        // the payload -- only how fast it builds. NOT a tracked input.
        mk.addArg(b.fmt("--precompiled-cache={s}", .{b.pathFromRoot(".precompiled-build")}));
        // Persistent compressed-frame cache for the payload's deps layer: the
        // level-19 zstd frame over the rarely-changing deps tree is reused when
        // its content is unchanged. Verified by decompress + compare on reuse,
        // so it can never change the payload either.
        mk.addArg(b.fmt("--layer-cache={s}", .{b.pathFromRoot(".payload-layers")}));

        // Seal the runtime (issue #7135): a bundled release payload boots from
        // the JIR image + frozen jac0core bootstrap. This is the ONLY bundled
        // shape; it just needs a real bundled precompile, so it is inert under
        // -Ddev/-Djaclang-dir (link-source) and -Dskip-precompile.
        const debug_src = b.option(bool, "debug-src", "Sealed build: embed source text in JIR so tracebacks show source lines (larger payload)") orelse false;
        if (link_dir == null and !skip_precompile) {
            mk.addArg("--seal");
            if (debug_src) mk.addArg("--debug-src");
        }

        // Contained bun runtime: fetch the pinned bun for the target and bundle
        // it inside the client package via --bun. In linked-source/dev mode
        // there is no bundled copy to fall back on -- get_bun() resolves from
        // the linked tree -- so place bun INTO that tree instead.
        if (link_dir == null) {
            const bun_dir = b.pathFromRoot(b.fmt(".bun-build/{s}", .{osarch}));
            const fetch_bun = tool.run("payload", &.{ "fetch-bun", osarch, bun_dir });
            fetch_bun.has_side_effects = true;
            mk.step.dependOn(&fetch_bun.step);
            mk.addArg(b.fmt("--bun={s}/bun", .{bun_dir}));
        } else {
            const fetch_bun = tool.run("payload", &.{ "fetch-bun", host_osarch, b.fmt("{s}/jaclang/client/_bun", .{link_dir.?}) });
            fetch_bun.has_side_effects = true;
            mk.step.dependOn(&fetch_bun.step);
        }

        // Linux: harvest a static-musl runtime for the target and bundle it so
        // the shipped binary can fully static-link Linux executables against
        // musl at nacompile time -- no glibc/loader dep.
        if (link_dir == null and std.mem.startsWith(u8, osarch, "linux-")) {
            const musl_lib = b.pathFromRoot(b.fmt(".pbs-build/{s}/musl/lib", .{osarch}));
            const vendor_musl = tool.run("payload", &.{ "build-musl", osarch, musl_lib, b.graph.zig_exe });
            vendor_musl.has_side_effects = true;
            mk.step.dependOn(&vendor_musl.step);
            mk.addArg(b.fmt("--musl={s}", .{musl_lib}));
        }

        // Wasm32 libc bitcode: runs for EVERY build, dev included (a -Ddev
        // binary reads .pbs-build/wasm32/libc directly); only the bundling
        // stays conditional -- a linked binary has no payload to carry it in.
        {
            const wasm_libc = b.pathFromRoot(".pbs-build/wasm32/libc");
            const vendor_wasm = tool.run("payload", &.{
                "build-wasm-libc",
                b.pathFromRoot("jaclang/compiler/backends/native/wasm_rt"),
                wasm_libc,
                b.graph.zig_exe,
            });
            // has_side_effects: the output lives outside the cache, so the step
            // must run even when inputs are unchanged (a deleted .pbs-build has
            // to repopulate). The tool itself skips up-to-date per-file work.
            vendor_wasm.has_side_effects = true;
            addTreeInputs(b, vendor_wasm, "jaclang/compiler/backends/native/wasm_rt");
            mk.step.dependOn(&vendor_wasm.step);
            if (link_dir == null) {
                mk.addArg(b.fmt("--wasm-libc={s}", .{wasm_libc}));
            }
        }

        // Track the payload's real inputs so it repacks when any source changes.
        // NOTE: addDirectoryArg hashes only the directory PATH, not its
        // contents. addFileInput content-hashes each file, so enumerate the
        // tree. In linked-source mode none of jaclang/typeshed is bundled, so
        // tracking it would only force needless repacks -- skip it; the
        // --link-source arg itself is the cache key for that mode.
        if (link_dir == null) {
            addTreeInputs(b, mk, "jaclang");
            mk.addFileInput(b.path("jaclang/vendor/typeshed/PIN"));
            mk.addFileInput(b.path("jaclang/vendor/typeshed/TARBALL_SHA256"));
        }
        mk.addFileInput(b.path("_jac_finder.py"));
        mk.addFileInput(b.path("sitecustomize.py"));
        // The project manifest (version stamped into dist-info) lives at the
        // repo root, one level above this build root.
        mk.addFileInput(.{ .cwd_relative = b.pathFromRoot("../jac.toml") });
        // The pins (pbs/bun/LLVM) and the tool itself; a bump must repack.
        mk.addFileInput(b.path(pins.PINS_PATH));
        break :payload out;
    };

    // --- final binary: stub + payload + trailer ----------------------------
    const pack = tool.run("payload", &.{"pack"});
    pack.addFileArg(stub);
    pack.addFileArg(payload);
    const jac = pack.addOutputFileArg("jac");
    if (stubcat_region) |region| {
        pack.addFileArg(region);
    }
    b.getInstallStep().dependOn(&b.addInstallBinFile(jac, "jac").step);
}

/// Register every bundled source file under `sub_path` as a content-hashed input
/// of `run`, so the step re-runs when any of them changes. `addDirectoryArg` only
/// hashes the directory path string, so it cannot stand in for this. Skips
/// `__pycache__`/`*.pyc` (stripped by mkpayload) and `node_modules` (regenerated
/// from the lockfile, which is itself tracked), keeping the input set to real
/// source + vendored data.
fn addTreeInputs(b: *std.Build, run: *std.Build.Step.Run, sub_path: []const u8) void {
    const io = b.graph.io;
    var dir = b.build_root.handle.openDir(io, sub_path, .{ .iterate = true }) catch |err|
        std.debug.panic("tree inputs: cannot open {s}: {s}", .{ sub_path, @errorName(err) });
    defer dir.close(io);
    var walker = dir.walk(b.allocator) catch @panic("OOM");
    defer walker.deinit();
    while (walker.next(io) catch @panic("tree inputs: walk failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.indexOf(u8, entry.path, "__pycache__") != null) continue;
        if (std.mem.indexOf(u8, entry.path, "node_modules") != null) continue;
        if (std.mem.endsWith(u8, entry.path, ".pyc")) continue;
        run.addFileInput(b.path(b.fmt("{s}/{s}", .{ sub_path, entry.path })));
    }
}

fn addTests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const test_step = b.step("test", "Run the bootstrap unit tests (no network/pbs needed)");
    const seed_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/fetch_pbs.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const seed_tests = b.addTest(.{ .name = "fetch-pbs-tests", .root_module = seed_mod });
    test_step.dependOn(&b.addRunArtifact(seed_tests).step);

    const ts_mod = b.createModule(.{
        .root_source_file = b.path("bootstrap/fetch_typeshed.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const ts_tests = b.addTest(.{ .name = "fetch-typeshed-tests", .root_module = ts_mod });
    test_step.dependOn(&b.addRunArtifact(ts_tests).step);
}

/// Map a target to the os-arch token the fetch-pbs subcommand understands,
/// or null for targets we don't ship a binary for yet.
fn osArchString(t: std.Target) ?[]const u8 {
    return switch (t.os.tag) {
        .macos => switch (t.cpu.arch) {
            .aarch64 => "macos-aarch64",
            .x86_64 => "macos-x86_64",
            else => null,
        },
        .linux => switch (t.cpu.arch) {
            .x86_64 => "linux-x86_64",
            .aarch64 => "linux-aarch64",
            else => null,
        },
        else => null,
    };
}
fn addLlvmShim(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) ?Shim {
    const shim_file = switch (target.result.os.tag) {
        .windows => "jacllvm.dll",
        .macos => "libjacllvm.dylib",
        else => "libjacllvm.so",
    };

    // -Dshim-bin: bundle a PREBUILT shim (path relative to jac/ or absolute),
    // skipping the LLVM fetch and the static link entirely -- the shim is the
    // single most expensive compile artifact (it links ~0.5 GB of LLVM archives)
    // and depends only on native/**, this file, and the pinned slice, NOT on
    // jaclang/**. CI (setup-jac) uses this to reuse a shim across compiler-only
    // changes, keyed on exactly those inputs; the -Dpayload option is the same
    // idea one level up. Invalidation is the CALLER's responsibility -- a plain
    // `zig build` (no option) always links from source.
    if (b.option([]const u8, "shim-bin", "Prebuilt LLVMPY_* shim to bundle (skips the LLVM fetch + link)")) |p| {
        const bin: std.Build.LazyPath = .{ .cwd_relative = p };
        const place = b.addUpdateSourceFiles();
        place.addCopyFileToSource(bin, b.fmt("jaclang/compiler/backends/native/llvm/{s}", .{shim_file}));
        const jacllvm_step = b.step("jacllvm", "Build the LLVMPY_* shim (jac/native), static-link LLVM, place it in-tree");
        jacllvm_step.dependOn(&b.addInstallLibFile(bin, shim_file).step);
        jacllvm_step.dependOn(&place.step);
        return .{ .bin = bin, .place = &place.step };
    }

    // -Dllvm-dir wins; otherwise use the fetch-llvm cache (.llvm-build). If
    // neither has LLVM, return null and the build fails at mkpayload with a
    // "run `zig build fetch-llvm`" message (so fetch-llvm itself still configures
    // before LLVM exists). The shim is required -- there is no wheel fallback.
    const llvm_dir = b.option([]const u8, "llvm-dir", "Extracted LLVM 22.1.x dir (default: the fetch-llvm cache .llvm-build/...)") orelse
        (llvmCacheDir(b, target) orelse return null);
    const io = b.graph.io;
    const libdir = b.fmt("{s}/lib", .{llvm_dir});
    var dir = b.build_root.handle.openDir(io, libdir, .{ .iterate = true }) catch return null;
    defer dir.close(io);

    // The shim wraps LLVM's C++ API; CMake builds it C++17, no-RTTI/exceptions.
    // (jac/native/CMakeLists.txt: add_library(llvmlite SHARED ...)).
    const shim_srcs = [_][]const u8{
        "assembly.cpp",        "bitcode.cpp",       "config.cpp",
        "core.cpp",            "custom_passes.cpp", "dylib.cpp",
        "executionengine.cpp", "initfini.cpp",      "linker.cpp",
        "memorymanager.cpp",   "module.cpp",        "newpassmanagers.cpp",
        "object_file.cpp",     "orcjit.cpp",        "targets.cpp",
        "type.cpp",            "value.cpp",
    };
    // -Wno-deprecated-declarations: the vendored llvmlite shim still calls a few
    // APIs LLVM 22 marks deprecated (e.g. LLVMGetGlobalContext); the warning to
    // stderr otherwise trips the system-compiler Run step's clean-stderr caching.
    const shim_flags = [_][]const u8{ "-std=c++17", "-fno-rtti", "-fno-exceptions", "-DNDEBUG", "-Wno-deprecated-declarations" };

    // Both platforms link the shim with the SYSTEM C++ compiler, matching the C++
    // standard library the official LLVM release was built against -- this is what
    // llvmlite does. macOS: Apple clang/libc++ (the macOS release is libc++; also
    // lowers ThinLTO bitcode via libLTO). Linux: g++/libstdc++ -- the LLVM 22 Linux
    // release switched from libc++ (LLVM 20) to libstdc++, so a Zig `link_libcpp`
    // (libc++) shim leaves LLVM's `std::__1::*` API calls unresolved against the
    // release's `std::__cxx11::*` archives (#6925 follow-up).
    const bin: std.Build.LazyPath = if (target.result.os.tag == .macos)
        macosShim(b, target, optimize, &dir, llvm_dir, libdir, &shim_srcs, &shim_flags)
    else
        linuxShim(b, target, optimize, &dir, llvm_dir, libdir, &shim_srcs, &shim_flags);

    // Also write the built shim back into the source tree (gitignored) so the
    // editable dev loop -- which runs jaclang from source, not from the binary's
    // payload -- finds it via ffi.jac's __file__-relative lookup. Mirrors how
    // fetch-typeshed materializes gitignored stubs into the tree. mkpayload's
    // jaclang copy skips this file (it ships the shim via --shim instead).
    const place = b.addUpdateSourceFiles();
    place.addCopyFileToSource(bin, b.fmt("jaclang/compiler/backends/native/llvm/{s}", .{shim_file}));

    const jacllvm_step = b.step("jacllvm", "Build the LLVMPY_* shim (jac/native), static-link LLVM, place it in-tree");
    jacllvm_step.dependOn(&b.addInstallLibFile(bin, shim_file).step);
    jacllvm_step.dependOn(&place.step);
    return .{ .bin = bin, .place = &place.step };
}

/// Linux link path for the LLVMPY_* shim. Which path a target takes is decided by
/// the C++ runtime of its pinned slice (pins.isLibcxx), not the arch, so
/// flipping a target to the libc++/zig path is a table edit in llvm_release.zig.
///
/// A `*-libcxx` slice (jaseci-labs/llvm-slice, a stock LLVM built
/// `-DLLVM_ENABLE_LIBCXX=ON`) links with `zig c++`: zig uses libc++, so its
/// `std::__1::*` ABI matches the slice's archives, and `-target <triple>` pins
/// BOTH the C++ runtime and the glibc floor (e.g. 2.17 via -Dtarget) for the
/// shim's own TUs -- the slice's archives are already floored at the same 2.17 by
/// the identical zig pin used to build them. zig links libc++/compiler-rt
/// statically (no -static-libstdc++ needed), and the libc++ slice is configured
/// with zlib/zstd/libxml2 OFF, so the shim references only the libc trio. This is
/// what drops libjacllvm.so from requiring GLIBC_2.38 to a clean 2.17 floor
/// (#7082). Both Linux targets (x86_64, aarch64) use libc++ slices today.
///
/// A stock (libstdc++) slice takes the system g++/libstdc++ path: it must be
/// compiled + linked with g++ to match the archives' `std::__cxx11::*` ABI (a
/// libc++ build leaves LLVM's API calls unresolved), `-static-libstdc++
/// -static-libgcc` bundles the C++ runtime, and the stock archives still
/// reference zlib/zstd/libxml2. No pinned Linux target uses this path anymore;
/// it is kept for linking official LLVM releases (e.g. a new platform before its
/// libc++ slice exists). Returns the emitted .so as a LazyPath.
fn linuxShim(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dir: *std.Io.Dir,
    llvm_dir: []const u8,
    libdir: []const u8,
    shim_srcs: []const []const u8,
    shim_flags: []const []const u8,
) std.Build.LazyPath {
    const io = b.graph.io;
    // libc++ slice -> `zig c++` (libc++ ABI + glibc floor from -Dtarget); stock
    // slice -> system g++/libstdc++. An explicit -Dllvm-dir still follows the
    // pinned slice's runtime for its target (there is no other signal for the
    // custom dir's ABI, and matching the pin is the only supported layout).
    const rel = pins.llvmRelease(b, osArchString(target.result));
    const use_zig = if (rel) |r| pins.isLibcxx(r) else false;
    const cc = if (use_zig)
        b.addSystemCommand(&.{ b.graph.zig_exe, "c++" })
    else
        b.addSystemCommand(&.{"c++"});
    if (use_zig) {
        // One flag pins both the C++ runtime (zig's libc++, matching the libc++
        // slice's std::__1::*) and the glibc floor (e.g. x86_64-linux-gnu.2.17),
        // exactly the same `-target` the slice itself was built with.
        const triple = target.query.zigTriple(b.allocator) catch @panic("jacllvm: zigTriple failed");
        cc.addArgs(&.{ "-target", triple });
        // The -target triple does NOT carry the CPU: zig cc treats a host-equal
        // triple (e.g. plain x86_64-linux-gnu when no -Dtarget is passed, as in
        // the test-binary CI) as native and emits the BUILD machine's ISA
        // extensions (AVX-512 on newer runners) into the shim -- which then
        // SIGILLs when the cached binary runs on an older CPU. Pin baseline,
        // mirroring the launcher's baseline-CPU rationale at the top of build();
        // an explicit -Dcpu still wins.
        switch (target.query.cpu_model) {
            .explicit => |m| cc.addArg(b.fmt("-mcpu={s}", .{m.name})),
            else => cc.addArg("-mcpu=baseline"),
        }
    }
    cc.addArgs(&.{ "-shared", "-fPIC" });
    cc.addArg(switch (optimize) {
        .Debug => "-O0",
        .ReleaseSafe => "-O2",
        .ReleaseFast => "-O3",
        .ReleaseSmall => "-Oz",
    });
    // Hide everything; the LLVMPY_* API is annotated default-visibility (native/
    // core.h API_EXPORT) so it stays exported. --exclude-libs,ALL keeps the static
    // LLVM + C++ runtime symbols out of the dynamic table (no clash with a host LLVM).
    cc.addArgs(&.{ "-fvisibility=hidden", "-fvisibility-inlines-hidden" });
    cc.addArgs(shim_flags); // -std=c++17 -fno-rtti -fno-exceptions -DNDEBUG
    // zig links its libc++/compiler-rt statically already; the system path needs the
    // GNU runtime bundled explicitly so the shipped shim has no host libstdc++.so dep.
    if (!use_zig) cc.addArgs(&.{ "-static-libstdc++", "-static-libgcc" });
    cc.addArg(b.fmt("-I{s}/include", .{llvm_dir}));
    // Shim sources passed directly (not as a .a) so their LLVMPY_* symbols survive.
    for (shim_srcs) |f| cc.addFileArg(b.path(b.fmt("native/{s}", .{f})));
    // zig/2.17 path only: fold in the glibc-floor compat TU (weak rseq
    // descriptors) so the libc++ LLVM archives' newer-glibc refs resolve without
    // raising the floor above 2.17 (#7082). Harmless if unreferenced (weak, hidden).
    if (use_zig) cc.addFileArg(b.path("native/glibc_compat.cpp"));
    // Link every LLVM static archive inside a group (their refs are circular); the
    // linker drops what the shim never references.
    cc.addArg("-Wl,--start-group");
    var it = dir.iterate();
    while (it.next(io) catch @panic("jacllvm: lib iterate failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, "libLLVM") and std.mem.endsWith(u8, entry.name, ".a")) {
            cc.addFileArg(.{ .cwd_relative = b.fmt("{s}/{s}", .{ libdir, entry.name }) });
        }
    }
    cc.addArg("-Wl,--end-group");
    // LLVM's system deps. The libc++ slice is built with zlib/zstd/libxml2 OFF, so the
    // zig path needs only the libc trio; the stock slice still references them.
    if (use_zig)
        cc.addArgs(&.{ "-lpthread", "-ldl", "-lm" })
    else
        cc.addArgs(&.{ "-lz", "-lxml2", "-lzstd", "-lpthread", "-ldl", "-lm" });
    // Keep the static LLVM/C++ symbols out of the dynamic table. zig's linker-arg
    // allowlist rejects -Wl,--exclude-libs, so the zig path uses a version script
    // that exports only the LLVMPY_* C ABI (matching the macOS -exported_symbol
    // path); the system-c++ path keeps --exclude-libs,ALL.
    if (use_zig)
        cc.addPrefixedFileArg("-Wl,--version-script,", b.path("native/jacllvm.exports"))
    else
        cc.addArg("-Wl,--exclude-libs,ALL");
    cc.addArg("-o");
    return cc.addOutputFileArg("libjacllvm.so");
}

/// macOS link path for the LLVMPY_* shim. Zig 0.16 cannot link LLVM's official
/// macOS-ARM64 release archives: its self-hosted Mach-O linker rejects edge-case
/// object members ("unknown cpu architecture: 0") and it has no LLD Mach-O
/// backend ("using LLD to link macho files is unsupported"). So link with Apple
/// `clang++` / `ld64` -- the toolchain those archives were built with, exactly as
/// llvmlite does (jac/native/CMakeLists.txt). Compile + link in one `c++` system
/// command: the shim .cpp are passed directly (so ld64 keeps their LLVMPY_*
/// symbols rather than pruning them as it would from an archive), then
/// `-exported_symbol,_LLVMPY_*` restricts the dylib's export list to the shim API
/// (matching the CMake APPLE branch). Returns the emitted dylib as a LazyPath.
fn macosShim(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dir: *std.Io.Dir,
    llvm_dir: []const u8,
    libdir: []const u8,
    shim_srcs: []const []const u8,
    shim_flags: []const []const u8,
) std.Build.LazyPath {
    const io = b.graph.io;
    // Upstream slice (repackaged official release) vs from-source llvm-slice
    // build: decides the ThinLTO/libLTO plumbing and the external -l deps
    // below. A custom -Dllvm-dir on an unpinned platform gets the upstream
    // treatment (official releases are the only other supported layout).
    const rel = pins.llvmRelease(b, osArchString(target.result));
    const upstream = if (rel) |r| r.upstream else true;
    const cc = b.addSystemCommand(&.{"c++"});
    cc.addArg("-dynamiclib");
    // Target the resolved arch explicitly rather than the host c++'s default, so a
    // Rosetta/emulated shell can't produce an x86_64 dylib against arm64 archives.
    cc.addArgs(&.{ "-arch", switch (target.result.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("jacllvm: unsupported macOS arch for the c++ shim link"),
    } });
    // Pin the shim's minos to the resolved target's floor, exactly like the
    // zig-built launcher: with -Dtarget=x86_64-macos.12.0 the whole shipped
    // binary floors at 12.0 instead of the build runner's macOS. Host-native
    // builds resolve to the host version, matching clang's own default.
    const macos_min = target.result.os.version_range.semver.min;
    cc.addArg(b.fmt("-mmacosx-version-min={d}.{d}", .{ macos_min.major, macos_min.minor }));
    // Respect -Doptimize the way the Linux (Zig addLibrary) path does.
    cc.addArg(switch (optimize) {
        .Debug => "-O0",
        .ReleaseSafe => "-O2",
        .ReleaseFast => "-O3",
        .ReleaseSmall => "-Oz",
    });
    // Match the CMake visibility preset: hide everything, the LLVMPY_* API is
    // annotated default-visibility (native/core.h API_EXPORT) so it stays exported.
    cc.addArgs(&.{ "-fvisibility=hidden", "-fvisibility-inlines-hidden" });
    cc.addArgs(shim_flags);
    cc.addArg(b.fmt("-I{s}/include", .{llvm_dir}));
    // Shim sources passed directly (not as a .a) so ld64 keeps every LLVMPY_*.
    for (shim_srcs) |f| cc.addFileArg(b.path(b.fmt("native/{s}", .{f})));
    // Link every LLVM static archive; ld64 drops what the shim never references.
    var it = dir.iterate();
    while (it.next(io) catch @panic("jacllvm: lib iterate failed")) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, "libLLVM") and std.mem.endsWith(u8, entry.name, ".a")) {
            cc.addFileArg(.{ .cwd_relative = b.fmt("{s}/{s}", .{ libdir, entry.name }) });
        }
    }
    // Upstream slices only: the official release archives are ThinLTO bitcode,
    // so ld64 must lower them to native code at link time via libLTO. Apple's
    // bundled libLTO tracks Xcode and is too old on the CI runners ("Invalid
    // summary version 12, should be in [1-10]" -> segfault), so point ld64 at
    // the release's OWN libLTO.dylib (kept by payload.zig fetchLlvmSlice) -- it
    // matches the bitcode it produced. This is link-time only; the output dylib
    // gains no libLTO runtime dep.
    //
    // The path MUST be absolute: ld64 silently falls back to its default libLTO
    // when -lto_library can't be resolved, and a relative path is not reliably
    // resolved from ld's cwd. Set LIBLTO_PATH too -- the env override ld honors
    // most reliably across ld64 / ld-prime.
    //
    // A from-source slice (macos-x86_64) is plain native Mach-O built with
    // zlib/zstd/libxml2 OFF: no libLTO to point at, and no external -l deps
    // either -- which keeps the shipped dylib free of Homebrew load commands.
    if (upstream) {
        const lto_dylib = b.fmt("{s}/lib/libLTO.dylib", .{llvm_dir});
        const lto_abs = if (std.fs.path.isAbsolute(lto_dylib)) lto_dylib else b.pathFromRoot(lto_dylib);
        cc.setEnvironmentVariable("LIBLTO_PATH", lto_abs);
        cc.addPrefixedFileArg("-Wl,-lto_library,", .{ .cwd_relative = lto_abs });
        // LLVM's system deps. zstd comes from Homebrew (not on the default search
        // path); z/xml2 are in the macOS SDK, and clang++ links libc++ itself.
        cc.addArgs(&.{ "-lz", "-lxml2" });
        // Homebrew's prefix is /opt/homebrew on Apple Silicon, /usr/local on Intel;
        // HOMEBREW_PREFIX overrides both for a custom install.
        const brew = b.graph.environ_map.get("HOMEBREW_PREFIX") orelse
            (if (target.result.cpu.arch == .aarch64) "/opt/homebrew" else "/usr/local");
        cc.addArgs(&.{ b.fmt("-I{s}/opt/zstd/include", .{brew}), b.fmt("-L{s}/opt/zstd/lib", .{brew}), "-lzstd" });
    }
    cc.addArgs(&.{ "-Wl,-exported_symbol,_LLVMPY_*", "-Wl,-install_name,@rpath/libjacllvm.dylib" });
    cc.addArg("-o");
    return cc.addOutputFileArg("libjacllvm.dylib");
}
