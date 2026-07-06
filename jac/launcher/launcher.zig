//! jaclang single-binary launcher (Zig) -- dlopen embed.
//!
//! This executable carries the jaclang runtime + a private CPython as a
//! gzip-compressed payload appended after the image (see `runtime.zig`). On
//! first run it materializes that payload into a versioned cache dir, then
//! **dlopens** the bundled shared libpython and drives it in-process. Nothing
//! Python is linked at build time -- the launcher links only libc/libdl, exactly
//! the way jac-native loads LLVM at runtime (the LLVMPY_* shim + ctypes).
//! No system Python, uv, or pip is required at install or runtime.
//!
//! The materialize + dlopen + config-init bring-up lives in `embed.zig`, shared
//! verbatim with the `na` desktop host (via the libjacpyembed shim). This file
//! is now just the *headless CLI frontend* over that shared core: worker mode
//! (drop-in `python`) and the jaclang CLI boot. The pure-Zig materialization
//! half (trailer parse, cache resolution, gzip+tar extract, GC) lives in
//! `runtime.zig` and is unit-tested separately.

const std = @import("std");
const builtin = @import("builtin");
const embed = @import("embed.zig");
const runtime = @import("runtime.zig");
const build_options = @import("build_options");

/// nvim's entry point, statically linked in from the pinned neovim fork
/// (jaseci-labs/neovim branch `jac`, built with -Dlib=true -> MAKE_LIB; see
/// jac/editor/PROVENANCE.md). Only referenced when the build bundles the
/// editor (build_options.ninja). argv follows the C main convention:
/// argv[argc] == NULL (libuv's uv_setup_args expects it).
extern fn nvim_main(argc: c_int, argv: [*]?[*:0]const u8) c_int;

// Same libc prototype embed.zig uses (std.c has no setenv in Zig 0.16).
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;

/// The validated boot dance: pin `sys.executable` to *this* binary, install the
/// lazy `.jac` finder, then hand off to the jaclang CLI, which reads `sys.argv`.
///
/// Pinning `sys.executable` is load-bearing: under embedding, getpath derives
/// `sys.executable` from the program name, and anything that re-spawns it must
/// come back through THIS binary -- worker mode below is what makes execnet /
/// pytest-xdist / multiprocessing re-spawns land on the right interpreter
/// instead of a foreign PATH `python3`.
/// The path is passed in via the JAC_EXECUTABLE env var (set by embed.open) to
/// avoid embedding a runtime path into this compile-time string.
const BOOT_SRC =
    "import sys, os\n" ++
    "_exe = os.environ.get('JAC_EXECUTABLE')\n" ++
    "if _exe:\n" ++
    "    sys.executable = _exe\n" ++
    "    sys._base_executable = _exe\n" ++
    "import _jac_finder as _jf\n" ++
    "_jf.apply_dev_source_override()\n" ++
    "_jf.install()\n" ++
    "from jaclang.jac0core.cli_boot import start_cli\n" ++
    "start_cli()\n";

fn die(comptime msg: []const u8) noreturn {
    std.debug.print("jac (launcher): {s}\n", .{msg});
    std.process.exit(70); // EX_SOFTWARE
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const env = init.environ_map;

    // 1. Resolve our own path (Linux /proc/self/exe, macOS _NSGetExecutablePath).
    var exe_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_len = std.process.executablePath(io, &exe_buf) catch die("cannot resolve executable path");
    const exe_path = exe_buf[0..exe_len];

    // NUL-terminated copy for the JAC_EXECUTABLE marker + the config's
    // program-name pin (initInterpreter below).
    var b_exe: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_z = std.fmt.bufPrintZ(&b_exe, "{s}", .{exe_path}) catch die("path too long");

    // `jac ninja` is dispatched HERE, before any Python bring-up: the editor
    // is nvim statically linked into this stub, so it needs the payload only
    // for its runtime files (materialize, no dlopen) and boots with zero
    // interpreter cost. Python starts later only if the editor spawns
    // `jac lsp` as a child.
    //
    // The argv[0]=="nvim" route is load-bearing, not a convenience: nvim 0.13's
    // TUI is a CLIENT process that re-execs its own binary (v:progpath == this
    // jac binary) with {argv[0], "--embed", ...} as the server -- that
    // re-invocation must land back in nvim_main, never the jac CLI. runNinja
    // passes argv[0]="nvim" precisely so the server hop routes here. It also
    // makes a `nvim -> jac` symlink behave as a plain nvim.
    if (isNvimArgv0(init)) runNinja(init, exe_path, exe_z, .verbatim);
    if (isNinjaInvocation(init)) runNinja(init, exe_path, exe_z, .ninja);

    // 2. Shared bring-up: materialize the runtime and dlopen the bundled
    //    libpython. Identical to what the desktop host does.
    //    `rt_buf` backs `emb.rt`, so it must outlive the boot below.
    var rt_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const emb = embed.open(
        io,
        init.gpa,
        exe_path,
        exe_z,
        env.get("XDG_CACHE_HOME"),
        env.get("HOME"),
        env.get("TMPDIR"),
        @intCast(std.c.getuid()),
        @intCast(std.c.getpid()),
        &rt_buf,
    ) catch die("runtime bring-up failed (payload not materialized?)");

    std.process.exit(boot(&emb, exe_z, init));
}

fn boot(emb: *const embed.Embed, exe_z: [*:0]const u8, init: std.process.Init) u8 {
    // Collect argv once; both modes hand it to the interpreter through the
    // init config (no locale-decode dance -- PEP 741 takes char* directly).
    var argv_storage: [4096][*:0]const u8 = undefined;
    var argc: usize = 0;
    var it = init.minimal.args.iterate();
    while (it.next()) |arg| {
        if (argc >= argv_storage.len) die("too many arguments");
        argv_storage[argc] = arg.ptr;
        argc += 1;
    }
    const argv = argv_storage[0..argc];

    // Worker mode: when re-invoked as a Python interpreter (execnet/xdist and
    // multiprocessing re-spawn `sys.executable` with flags like `-u -c ...`),
    // behave exactly like `python` (parse_argv) instead of booting the jac CLI.
    const worker = isPythonInvocation(init);

    emb.initInterpreter(exe_z, .{ .argv = argv, .parse_argv = worker }) catch
        die("interpreter initialization failed");

    if (worker) {
        const Py_RunMain = emb.symOrErr(embed.Py_RunMain_t, "Py_RunMain") catch die("libpython missing symbol: Py_RunMain");
        // Py_RunMain executes the parsed -c/-m/script and finalizes. Exit codes
        // are 8-bit (the OS masks them). Truncate rather than @intCast, which
        // panics on a negative/out-of-range c_int in checked builds.
        return @truncate(@as(u32, @bitCast(Py_RunMain())));
    }

    const PyRun_SimpleString = emb.symOrErr(embed.PyRun_SimpleString_t, "PyRun_SimpleString") catch die("libpython missing symbol: PyRun_SimpleString");
    const Py_FinalizeEx = emb.symOrErr(embed.Py_FinalizeEx_t, "Py_FinalizeEx") catch die("libpython missing symbol: Py_FinalizeEx");

    const rc = PyRun_SimpleString(BOOT_SRC);
    _ = Py_FinalizeEx();
    return if (rc == 0) 0 else 1;
}

/// True when argv[1] is exactly `ninja`. Checked before the Python bring-up,
/// so the jac CLI never sees this subcommand in binary mode.
fn isNinjaInvocation(init: std.process.Init) bool {
    var it = init.minimal.args.iterate();
    _ = it.next(); // skip argv[0]
    if (it.next()) |a| return std.mem.eql(u8, a, "ninja");
    return false;
}

/// True when we were invoked AS nvim (argv[0] basename == "nvim"): the TUI
/// client's --embed server re-invocation, or a `nvim -> jac` symlink.
fn isNvimArgv0(init: std.process.Init) bool {
    var it = init.minimal.args.iterate();
    const argv0 = it.next() orelse return false;
    return std.mem.eql(u8, std.fs.path.basename(argv0), "nvim");
}

const NinjaMode = enum {
    ninja, // `jac ninja [args...]` -> nvim -u <ninja>/init.lua [args...]
    verbatim, // argv[0]=="nvim" -> pass argv through untouched (--embed hop)
};

/// Boot the fused editor. Materializes the payload (for the nvim runtime
/// files + ninja config), exports the ninja environment, and calls
/// nvim_main() in-process. Never returns.
fn runNinja(init: std.process.Init, exe_path: []const u8, exe_z: [*:0]const u8, mode: NinjaMode) noreturn {
    if (!build_options.ninja) die("this jac build does not bundle the ninja editor (rebuild without -Dno-ninja)");

    const io = init.io;
    const env = init.environ_map;

    var rt_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const rt = runtime.materialize(
        io,
        init.gpa,
        exe_path,
        env.get("XDG_CACHE_HOME"),
        env.get("HOME"),
        env.get("TMPDIR"),
        @intCast(std.c.getuid()),
        @intCast(std.c.getpid()),
        &rt_buf,
    ) catch die("runtime bring-up failed (payload not materialized?)");

    // Environment for the editor + its children. JAC_BIN is what init.lua uses
    // to spawn `jac lsp` -- the same binary, so editor+parser+LSP stay one file.
    // Idempotent across the --embed server hop (same values recomputed).
    var b_vimruntime: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const vimruntime = std.fmt.bufPrintZ(&b_vimruntime, "{s}/nvim/runtime", .{rt}) catch die("path too long");
    var b_ninja: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const ninja_dir = std.fmt.bufPrintZ(&b_ninja, "{s}/nvim/ninja", .{rt}) catch die("path too long");
    // Editable dev loop for the ninja config layer, mirroring the compiler's
    // linked-source marker (site/jac_linked_source): a -Ddev / -Djaclang-dir
    // build bakes nvim/ninja_linked_source into the payload, pointing at the
    // source tree (<link-dir>/editor/ninja). When present and readable, serve
    // init.lua + lua/ live from there -- edit, relaunch, no zig rebuild. The
    // payload's own copy is still exported as JAC_NINJA_BASE so the
    // build-staged pieces (mini.nvim, the jac queries from tree-sitter-jac)
    // keep resolving. Falls back to the payload copy if the linked tree is
    // gone (e.g. the dev binary was copied to another machine).
    var b_dev: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const dev_dir: ?[:0]const u8 = blk: {
        // JAC_NO_DEV_SOURCE=1 forces dev sourcing off, exactly like it does
        // for the compiler's linked-source override.
        if (env.get("JAC_NO_DEV_SOURCE")) |v| {
            if (std.mem.eql(u8, v, "1")) break :blk null;
        }
        var b_marker: [std.Io.Dir.max_path_bytes]u8 = undefined;
        const marker_path = std.fmt.bufPrint(&b_marker, "{s}/nvim/ninja_linked_source", .{rt}) catch break :blk null;
        var f = std.Io.Dir.cwd().openFile(io, marker_path, .{}) catch break :blk null;
        defer f.close(io);
        var raw: [std.Io.Dir.max_path_bytes]u8 = undefined;
        const n = f.readPositionalAll(io, &raw, 0) catch break :blk null;
        const trimmed = std.mem.trim(u8, raw[0..n], " \r\n\t");
        if (trimmed.len == 0) break :blk null;
        // Only link a tree that actually exists. Best-effort by nature:
        // nvim re-resolves the PATH when sourcing init.lua, so a tree
        // vanishing between this check and the source (rename, unmount) can
        // still surface as nvim's own file-not-found -- holding the dir fd
        // open here would not close that window. Dev binaries only.
        var d = std.Io.Dir.cwd().openDir(io, trimmed, .{}) catch break :blk null;
        d.close(io);
        break :blk std.fmt.bufPrintZ(&b_dev, "{s}", .{trimmed}) catch break :blk null;
    };
    const active_ninja: [:0]const u8 = dev_dir orelse ninja_dir;

    // All of these are load-bearing (runtime files, config layer, LSP spawn,
    // state isolation) -- a setenv failure (OOM) must not limp into an
    // editor with silently missing pieces.
    if (setenv("VIMRUNTIME", vimruntime.ptr, 1) != 0 or
        setenv("JAC_NINJA_DIR", active_ninja.ptr, 1) != 0 or
        setenv("JAC_NINJA_BASE", ninja_dir.ptr, 1) != 0 or
        setenv("JAC_BIN", exe_z, 1) != 0 or
        // Isolate shada/swap/undo/log under ~/.local/{share,state}/jac-ninja
        // and keep the user's own nvim config dirs out of play entirely.
        setenv("NVIM_APPNAME", "jac-ninja", 1) != 0)
    {
        die("ninja environment setup failed (setenv)");
    }

    var argv_storage: [4096]?[*:0]const u8 = undefined;
    var argc: usize = 0;
    var it = init.minimal.args.iterate();
    // Backs the -u path in argv_storage; must outlive the switch (nvim_main
    // reads argv after it).
    var b_init: [std.Io.Dir.max_path_bytes]u8 = undefined;

    switch (mode) {
        .verbatim => {
            // The --embed server hop (or an nvim symlink): argv is already a
            // complete nvim command line -- pass it through untouched.
            while (it.next()) |arg| {
                if (argc >= argv_storage.len - 1) die("too many arguments");
                argv_storage[argc] = arg.ptr;
                argc += 1;
            }
        },
        .ninja => {
            // jac ninja [args...] -> nvim -u <ninja>/init.lua [args...]
            const init_lua = std.fmt.bufPrintZ(&b_init, "{s}/init.lua", .{active_ninja}) catch die("path too long");
            argv_storage[argc] = "nvim";
            argc += 1;
            argv_storage[argc] = "-u";
            argc += 1;
            argv_storage[argc] = init_lua.ptr;
            argc += 1;
            _ = it.next(); // argv[0]
            _ = it.next(); // "ninja"
            while (it.next()) |arg| {
                // jac-level flags, consumed here (nvim never sees them):
                // --easy / --no-easy toggle the VSCode-style input layer
                // (ninja/lua/ninja/easy.lua reads the env and persists).
                if (std.mem.eql(u8, arg, "--easy")) {
                    if (setenv("JAC_NINJA_EASY", "1", 1) != 0) die("ninja environment setup failed (setenv)");
                    continue;
                }
                if (std.mem.eql(u8, arg, "--no-easy")) {
                    if (setenv("JAC_NINJA_EASY", "0", 1) != 0) die("ninja environment setup failed (setenv)");
                    continue;
                }
                if (argc >= argv_storage.len - 1) die("too many arguments");
                argv_storage[argc] = arg.ptr;
                argc += 1;
            }
        },
    }
    argv_storage[argc] = null; // C argv convention: argv[argc] == NULL

    if (build_options.ninja) {
        std.process.exit(@truncate(@as(u32, @bitCast(nvim_main(@intCast(argc), &argv_storage)))));
    }
    unreachable;
}

/// True if argv[1] is a Python interpreter short flag (`-c`, `-u`, `-m`, `-`,
/// ...). Single-dash short flags mean "act like python"; jac subcommands (`run`,
/// `test`) and long flags (`--version`) keep the jac CLI. This dispatch is a
/// CONTRACT: the jac CLI must never accept a single-dash short flag as its
/// first argument, or execnet/xdist worker re-spawns (`jac -u -c ...`) would
/// be misrouted.
fn isPythonInvocation(init: std.process.Init) bool {
    var it = init.minimal.args.iterate();
    _ = it.next(); // skip argv[0]
    if (it.next()) |a| {
        return a.len >= 1 and a[0] == '-' and (a.len == 1 or a[1] != '-');
    }
    return false;
}

test {
    std.testing.refAllDecls(@import("runtime.zig"));
    std.testing.refAllDecls(embed);
}
