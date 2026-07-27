//! jaclang single-binary launcher (Zig) -- dlopen embed.
//!
//! This executable carries the jaclang runtime + a private CPython as a
//! zstd-compressed payload appended after the image (see `runtime.zig`). On
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
//! half (trailer parse, cache resolution, zstd+tar extract, GC) lives in
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
extern "c" fn unsetenv(name: [*:0]const u8) c_int;

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

    // Resolve a trailing `.jab` overlay ONCE, and branch the whole pre-Python
    // dispatch on it. An overlay means this is a `jac build --as binary` app
    // binary: the app owns ALL of argv, so the jac-CLI/editor/build verbs below
    // are NOT honored (running `myapp ninja` must reach the app, not the
    // editor), and we export the overlay's [offset,len] so the CPython boot
    // (cli_boot's _run_bundled_app) can slice its image out of this binary and
    // mount it. A plain jac (no overlay) honors those verbs and, crucially,
    // CLEARS any inherited JAC_APP_OVERLAY_* -- those vars inherit across
    // process boundaries, so an app binary that shells out to a plain jac would
    // otherwise leave the child with stale coordinates that make it mis-slice
    // its own binary (same discipline the interpreter config follows for
    // PYTHONHOME/PYTHONPATH, #7047). Worker mode (a python re-spawn) is still
    // selected later in boot(), independent of this branch.
    if (runtime.overlayForPath(io, exe_path)) |ovl| {
        var b_off: [24]u8 = undefined;
        var b_len: [24]u8 = undefined;
        const off_z = std.fmt.bufPrintZ(&b_off, "{d}", .{ovl.off}) catch die("overlay offset too long");
        const len_z = std.fmt.bufPrintZ(&b_len, "{d}", .{ovl.len}) catch die("overlay len too long");
        if (setenv("JAC_APP_OVERLAY_OFF", off_z.ptr, 1) != 0 or
            setenv("JAC_APP_OVERLAY_LEN", len_z.ptr, 1) != 0)
            die("app-overlay environment setup failed (setenv)");
    } else {
        _ = unsetenv("JAC_APP_OVERLAY_OFF");
        _ = unsetenv("JAC_APP_OVERLAY_LEN");

        // `jac ninja` is dispatched HERE, before any Python bring-up: the editor
        // is nvim statically linked into this stub, so it needs the payload only
        // for its runtime files (materialize, no dlopen) and boots with zero
        // interpreter cost. Python starts later only if the editor spawns
        // `jac lsp` as a child.
        //
        // The argv[0]=="nvim" route is load-bearing, not a convenience: nvim
        // 0.13's TUI is a CLIENT process that re-execs its own binary
        // (v:progpath == this jac binary) with {argv[0], "--embed", ...} as the
        // server -- that re-invocation must land back in nvim_main, never the
        // jac CLI. runNinja passes argv[0]="nvim" precisely so the server hop
        // routes here. It also makes a `nvim -> jac` symlink behave as plain nvim.
        if (isNvimArgv0(init)) runNinja(init, exe_path, exe_z, .verbatim);
        if (isNinjaInvocation(init)) runNinja(init, exe_path, exe_z, .ninja);

        // Build-time INTERNAL verbs, pure-Zig trailer surgery that `jac build
        // --as binary` (__appjab), the desktop builder (__graftrt), and the
        // eligibility pre-check (__hasruntime) shell out to. Keeping them in Zig
        // is what lets runtime.zig own the trailer format outright -- Python
        // never parses or writes a trailer.
        if (isInternalVerb(init, "__hasruntime")) std.process.exit(0);
        if (isInternalVerb(init, "__appjab")) runAppjab(init, exe_path);
        if (isInternalVerb(init, "__graftrt")) runGraftRt(init, exe_path);
    }

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

    // A non-null result means the interpreter handled a print-and-exit flag
    // (worker mode -h/-V/--help): exit with the code CPython requested, never the
    // boot path. Nothing was initialized, so there is nothing to run or finalize.
    if (emb.initInterpreter(exe_z, .{ .argv = argv, .parse_argv = worker }) catch
        die("interpreter initialization failed")) |exit_code|
    {
        return exit_code;
    }

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

/// True when argv[1] is exactly `verb` (an internal `__`-prefixed build verb).
fn isInternalVerb(init: std.process.Init, verb: []const u8) bool {
    var it = init.minimal.args.iterate();
    _ = it.next(); // skip argv[0]
    if (it.next()) |a| return std.mem.eql(u8, a, verb);
    return false;
}

fn diePackVerb(comptime verb: []const u8, e: anyerror) noreturn {
    std.debug.print("jac ({s}): {s}\n", .{ verb, @errorName(e) });
    std.process.exit(70); // EX_SOFTWARE
}

/// `jac __appjab <app.jab> <out>`: copy this binary verbatim and append the
/// `.jab` as an overlay, producing a self-contained app binary. Pure Zig, no
/// interpreter. The base is THIS running binary (guaranteed a bundled jac);
/// runtime.appendOverlay rejects a base that is not (a source/pip jac).
fn runAppjab(init: std.process.Init, exe_path: []const u8) noreturn {
    var it = init.minimal.args.iterate();
    _ = it.next(); // argv[0]
    _ = it.next(); // "__appjab"
    const jab = it.next() orelse die("__appjab: missing <app.jab>");
    const out = it.next() orelse die("__appjab: missing <out>");
    runtime.appendOverlay(init.io, init.gpa, exe_path, jab, out) catch |e| diePackVerb("__appjab", e);

    // Mark the produced binary executable (createFile made it 0644). Fail loud
    // rather than emit a success exit with a non-executable artifact.
    var b_out: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const out_z = std.fmt.bufPrintZ(&b_out, "{s}", .{out}) catch die("__appjab: path too long");
    if (std.c.chmod(out_z.ptr, 0o755) != 0) die("__appjab: could not mark the output executable");
    std.process.exit(0);
}

/// `jac __graftrt <host>`: append this binary's `[ payload ][ trailer ]` runtime
/// suffix onto `host` in place, fusing the bundled runtime into the desktop host
/// binary. Pure Zig, no interpreter.
fn runGraftRt(init: std.process.Init, exe_path: []const u8) noreturn {
    var it = init.minimal.args.iterate();
    _ = it.next(); // argv[0]
    _ = it.next(); // "__graftrt"
    const host = it.next() orelse die("__graftrt: missing <host>");
    runtime.graftRuntime(init.io, init.gpa, exe_path, host) catch |e| diePackVerb("__graftrt", e);
    std.process.exit(0);
}

/// True when we were invoked AS nvim (argv[0] basename == "nvim"): the TUI
/// client's --embed server re-invocation, or a `nvim -> jac` symlink.
fn isNvimArgv0(init: std.process.Init) bool {
    var it = init.minimal.args.iterate();
    const argv0 = it.next() orelse return false;
    return std.mem.eql(u8, std.fs.path.basename(argv0), "nvim");
}

/// True when a rival language toolchain is installed on `$PATH`. jac carries
/// its own Bun inside the payload, invoked by absolute path and never placed on
/// PATH -- so any of these names on PATH is a deliberately-installed competing
/// ecosystem, the antithesis of the one-binary promise. Existence (a successful
/// open) is the test; symlink shims (nvm/pyenv) resolve and count, as intended.
/// python3.14 is named exactly, not `python3`: distros own `python3` as an OS
/// dependency, but a fresh CPython 3.14 is a choice. Returns on the first hit.
fn ninjaCompetingToolchain(init: std.process.Init) bool {
    const banned = [_][]const u8{
        "node",       "npm", "pnpm", "yarn", "deno", // JS runtimes + package managers
        "python3.14", "pip", "pip3", // a deliberately-installed CPython + pip
    };
    const path = init.environ_map.get("PATH") orelse return false;
    var dirs = std.mem.tokenizeScalar(u8, path, ':');
    while (dirs.next()) |dir| {
        for (banned) |name| {
            var buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
            const candidate = std.fmt.bufPrint(&buf, "{s}/{s}", .{ dir, name }) catch continue;
            var f = std.Io.Dir.cwd().openFile(init.io, candidate, .{}) catch continue;
            f.close(init.io);
            return true;
        }
    }
    return false;
}

/// The unspoken override. A ninja wrongly flagged by a stray shim -- or one who
/// simply declines the ordeal -- enters with `jac ninja --imnotworthy`.
/// Deliberately undocumented: knowing the incantation is itself the credential.
fn ninjaIsUnworthyOverride(init: std.process.Init) bool {
    var it = init.minimal.args.iterate();
    while (it.next()) |a| {
        if (std.mem.eql(u8, a, "--imnotworthy")) return true;
    }
    return false;
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

    // The ninja is earned. Only the user-typed `jac ninja` path is gated --
    // never `.verbatim`, which is nvim's --embed server hopping back through the
    // launcher mid-session; gating that would kill the editor AFTER it opened.
    // A rival toolchain on PATH bars the door unless the invoker confesses with
    // the unspoken `--imnotworthy`.
    if (mode == .ninja and !ninjaIsUnworthyOverride(init) and ninjaCompetingToolchain(init)) {
        std.debug.print("You... are not ready.\n", .{});
        std.process.exit(1);
    }

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
                // The gate's confession is consumed here, not handed to nvim
                // (which would reject the unknown flag).
                if (std.mem.eql(u8, arg, "--imnotworthy")) continue;
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
/// `test`), long flags (`--version`), and the `-h` help alias keep the jac CLI.
/// This dispatch is a CONTRACT: the jac CLI must never accept a single-dash short
/// flag (other than `-h`) as its first argument, or execnet/xdist worker re-spawns
/// (`jac -u -c ...`) would be misrouted. See `isPythonFirstArg` for the rule.
fn isPythonInvocation(init: std.process.Init) bool {
    var it = init.minimal.args.iterate();
    _ = it.next(); // skip argv[0]
    if (it.next()) |a| return isPythonFirstArg(a);
    return false;
}

/// Pure classifier for `isPythonInvocation`'s first-arg decision (factored out so
/// the routing contract is unit-testable without a `std.process.Init`).
///
/// A bare `-` or any single-dash short flag (`-c`, `-u`, `-m`, ...) means "act
/// like python" (worker re-spawns). `-h` is the ONE exception: it is a jac CLI
/// help alias handled in cli.impl.jac (alongside `--help`), and a human types it
/// expecting jac's help, not the embedded interpreter's. No
/// execnet/xdist/multiprocessing worker ever re-spawns with `-h` (a print-and-exit
/// flag), so exempting it cannot misroute a worker. Without the exemption `-h`
/// routes to parse_argv worker mode, where CPython prints its own interpreter
/// usage and the config read requests a clean exit that the embed layer misreports
/// as an init failure (exit 70).
fn isPythonFirstArg(a: []const u8) bool {
    if (std.mem.eql(u8, a, "-h")) return false;
    return a.len >= 1 and a[0] == '-' and (a.len == 1 or a[1] != '-');
}

test "isPythonFirstArg routes worker flags to python, keeps jac verbs and -h" {
    const t = std.testing;
    // Worker re-spawn flags -> python.
    try t.expect(isPythonFirstArg("-c"));
    try t.expect(isPythonFirstArg("-u"));
    try t.expect(isPythonFirstArg("-m"));
    try t.expect(isPythonFirstArg("-")); // bare stdin marker
    // `-h` is a jac CLI help alias -> jac CLI, not python.
    try t.expect(!isPythonFirstArg("-h"));
    // Long flags and jac subcommands -> jac CLI.
    try t.expect(!isPythonFirstArg("--help"));
    try t.expect(!isPythonFirstArg("--version"));
    try t.expect(!isPythonFirstArg("run"));
    try t.expect(!isPythonFirstArg("test"));
}

test {
    std.testing.refAllDecls(@import("runtime.zig"));
    std.testing.refAllDecls(embed);
}
