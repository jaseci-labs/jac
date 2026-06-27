const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime.zig");
const Io = std.Io;

extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;

pub const py_ver = "3.14";

pub const lib_basename = switch (builtin.os.tag) {
    .macos => "libpython" ++ py_ver ++ ".dylib",
    else => "libpython" ++ py_ver ++ ".so",
};

pub const Py_Initialize_t = *const fn () callconv(.c) void;
pub const Py_DecodeLocale_t = *const fn (arg: [*:0]const u8, size: ?*usize) callconv(.c) ?*anyopaque;
pub const Py_SetProgramName_t = *const fn (name: ?*anyopaque) callconv(.c) void;
pub const PySys_SetArgvEx_t = *const fn (argc: c_int, argv: ?[*]?*anyopaque, updatepath: c_int) callconv(.c) void;
pub const PyMem_RawFree_t = *const fn (p: ?*anyopaque) callconv(.c) void;
pub const PyRun_SimpleString_t = *const fn (cmd: [*:0]const u8) callconv(.c) c_int;
pub const Py_FinalizeEx_t = *const fn () callconv(.c) c_int;
pub const Py_BytesMain_t = *const fn (argc: c_int, argv: [*c][*c]u8) callconv(.c) c_int;

pub const Error = error{
    PathTooLong,
    EnvSetupFailed,
    DlopenFailed,
    MissingSymbol,
};

const MAX_PATH = Io.Dir.max_path_bytes;

pub const Embed = struct {
    handle: *anyopaque,
    rt: []const u8,

    pub fn sym(self: *const Embed, comptime T: type, comptime name: [:0]const u8) ?T {
        const p = std.c.dlsym(self.handle, name) orelse return null;
        return @ptrCast(@alignCast(p));
    }

    pub fn symOrErr(self: *const Embed, comptime T: type, comptime name: [:0]const u8) Error!T {
        return self.sym(T, name) orelse Error.MissingSymbol;
    }

    pub fn setProgramName(self: *const Embed, exe_z: [*:0]const u8) Error!void {
        const Py_DecodeLocale = try self.symOrErr(Py_DecodeLocale_t, "Py_DecodeLocale");
        const Py_SetProgramName = try self.symOrErr(Py_SetProgramName_t, "Py_SetProgramName");
        const wexe = Py_DecodeLocale(exe_z, null) orelse return Error.EnvSetupFailed;
        Py_SetProgramName(wexe);
    }
};

pub fn open(
    io: Io,
    gpa: std.mem.Allocator,
    exe_path: []const u8,
    exe_z: [*:0]const u8,
    xdg_cache_home: ?[]const u8,
    home: ?[]const u8,
    tmpdir: ?[]const u8,
    uid: u32,
    pid: i32,
    rt_out: []u8,
) !Embed {
    const rt = try runtime.materialize(
        io,
        gpa,
        exe_path,
        xdg_cache_home,
        home,
        tmpdir,
        uid,
        pid,
        rt_out,
    );

    var b_home: [MAX_PATH]u8 = undefined;
    var b_pp: [2 * MAX_PATH]u8 = undefined;
    var b_lib: [MAX_PATH]u8 = undefined;
    const pyhome = std.fmt.bufPrintZ(&b_home, "{s}/python", .{rt}) catch return Error.PathTooLong;
    const pythonpath = std.fmt.bufPrintZ(&b_pp, "{s}/site:{s}/python/lib/python" ++ py_ver ++ "/lib-dynload", .{ rt, rt }) catch return Error.PathTooLong;
    const libpath = std.fmt.bufPrintZ(&b_lib, "{s}/python/lib/{s}", .{ rt, lib_basename }) catch return Error.PathTooLong;

    if (setenv("PYTHONHOME", pyhome, 1) != 0) return Error.EnvSetupFailed;
    if (setenv("PYTHONPATH", pythonpath, 1) != 0) return Error.EnvSetupFailed;
    _ = setenv("PYTHONUTF8", "1", 1);
    _ = setenv("PYTHONIOENCODING", "utf-8", 1);
    _ = setenv("PYTHONDONTWRITEBYTECODE", "1", 1);
    _ = setenv("PYTHONNOUSERSITE", "1", 1);
    _ = setenv("JAC_STANDALONE", "1", 1);
    _ = setenv("JAC_EXECUTABLE", exe_z, 1);

    const handle = std.c.dlopen(libpath.ptr, .{ .NOW = true, .GLOBAL = true }) orelse
        return Error.DlopenFailed;

    return .{ .handle = handle, .rt = rt };
}
