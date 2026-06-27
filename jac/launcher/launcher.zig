const std = @import("std");
const builtin = @import("builtin");
const embed = @import("embed.zig");

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
    std.process.exit(70);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const env = init.environ_map;

    var exe_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_len = std.process.executablePath(io, &exe_buf) catch die("cannot resolve executable path");
    const exe_path = exe_buf[0..exe_len];

    var b_exe: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_z = std.fmt.bufPrintZ(&b_exe, "{s}", .{exe_path}) catch die("path too long");

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
    if (isPythonInvocation(init)) {
        const Py_BytesMain = emb.symOrErr(embed.Py_BytesMain_t, "Py_BytesMain") catch die("libpython missing symbol: Py_BytesMain");
        var argv_storage: [4096][*c]u8 = undefined;
        var n: usize = 0;
        var wit = init.minimal.args.iterate();
        while (wit.next()) |arg| {
            if (n >= argv_storage.len - 1) die("too many arguments");
            argv_storage[n] = @constCast(arg.ptr);
            n += 1;
        }
        argv_storage[n] = null;
        const code = Py_BytesMain(@intCast(n), @ptrCast(&argv_storage));
        return @truncate(@as(u32, @bitCast(code)));
    }

    const Py_Initialize = emb.symOrErr(embed.Py_Initialize_t, "Py_Initialize") catch die("libpython missing symbol: Py_Initialize");
    const Py_DecodeLocale = emb.symOrErr(embed.Py_DecodeLocale_t, "Py_DecodeLocale") catch die("libpython missing symbol: Py_DecodeLocale");
    const PySys_SetArgvEx = emb.symOrErr(embed.PySys_SetArgvEx_t, "PySys_SetArgvEx") catch die("libpython missing symbol: PySys_SetArgvEx");
    const PyMem_RawFree = emb.symOrErr(embed.PyMem_RawFree_t, "PyMem_RawFree") catch die("libpython missing symbol: PyMem_RawFree");
    const PyRun_SimpleString = emb.symOrErr(embed.PyRun_SimpleString_t, "PyRun_SimpleString") catch die("libpython missing symbol: PyRun_SimpleString");
    const Py_FinalizeEx = emb.symOrErr(embed.Py_FinalizeEx_t, "Py_FinalizeEx") catch die("libpython missing symbol: Py_FinalizeEx");

    emb.setProgramName(exe_z) catch die("failed to pin program name");

    Py_Initialize();

    var wargv: [4096]?*anyopaque = undefined;
    var argc: usize = 0;
    var it = init.minimal.args.iterate();
    while (it.next()) |arg| {
        if (argc >= wargv.len) die("too many arguments");
        wargv[argc] = Py_DecodeLocale(arg.ptr, null) orelse {
            for (wargv[0..argc]) |w| PyMem_RawFree(w);
            die("failed to decode argument");
        };
        argc += 1;
    }
    PySys_SetArgvEx(@intCast(argc), &wargv, 0);
    for (wargv[0..argc]) |w| PyMem_RawFree(w);

    const rc = PyRun_SimpleString(BOOT_SRC);
    _ = Py_FinalizeEx();
    return if (rc == 0) 0 else 1;
}

fn isPythonInvocation(init: std.process.Init) bool {
    var it = init.minimal.args.iterate();
    _ = it.next();
    if (it.next()) |a| {
        return a.len >= 1 and a[0] == '-' and (a.len == 1 or a[1] != '-');
    }
    return false;
}

test {
    std.testing.refAllDecls(@import("runtime.zig"));
    std.testing.refAllDecls(embed);
}
