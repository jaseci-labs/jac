const std = @import("std");
const builtin = @import("builtin");
const embed = @import("embed.zig");

const MAX_PATH = std.Io.Dir.max_path_bytes;

const PyFinalize_t = *const fn () callconv(.c) void;
const PyRunSimpleString_t = *const fn (cmd: [*:0]const u8) callconv(.c) c_int;
const PyImportAddModule_t = *const fn (name: [*:0]const u8) callconv(.c) ?*anyopaque;
const PyModuleGetDict_t = *const fn (m: ?*anyopaque) callconv(.c) ?*anyopaque;
const PyRunString_t = *const fn (s: [*:0]const u8, start: c_int, g: ?*anyopaque, l: ?*anyopaque) callconv(.c) ?*anyopaque;
const PyLongAsLong_t = *const fn (o: ?*anyopaque) callconv(.c) c_long;
const PyEvalSaveThread_t = *const fn () callconv(.c) ?*anyopaque;
const PyEvalRestoreThread_t = *const fn (s: ?*anyopaque) callconv(.c) void;
const PyGILStateEnsure_t = *const fn () callconv(.c) c_int;
const PyGILStateRelease_t = *const fn (s: c_int) callconv(.c) void;
const PyObjectCallOneArg_t = *const fn (callable: ?*anyopaque, arg: ?*anyopaque) callconv(.c) ?*anyopaque;
const PyUnicodeFromString_t = *const fn (s: [*:0]const u8) callconv(.c) ?*anyopaque;
const PyUnicodeAsUTF8_t = *const fn (o: ?*anyopaque) callconv(.c) ?[*:0]const u8;
const PyDecRef_t = *const fn (o: ?*anyopaque) callconv(.c) void;

var rt_buf: [MAX_PATH]u8 = undefined;
var booted: bool = false;

var p_finalize: PyFinalize_t = undefined;
var p_run_simple: PyRunSimpleString_t = undefined;
var p_add_module: PyImportAddModule_t = undefined;
var p_get_dict: PyModuleGetDict_t = undefined;
var p_run_string: PyRunString_t = undefined;
var p_long_aslong: PyLongAsLong_t = undefined;
var p_save_thread: PyEvalSaveThread_t = undefined;
var p_restore_thread: PyEvalRestoreThread_t = undefined;
var p_gil_ensure: PyGILStateEnsure_t = undefined;
var p_gil_release: PyGILStateRelease_t = undefined;
var p_call_one: PyObjectCallOneArg_t = undefined;
var p_uni_from: PyUnicodeFromString_t = undefined;
var p_uni_utf8: PyUnicodeAsUTF8_t = undefined;
var p_decref: PyDecRef_t = undefined;

fn fail(comptime msg: []const u8) c_int {
    std.debug.print("libjacpyembed: {s}\n", .{msg});
    return 1;
}

export fn jac_engine_boot() c_int {
    if (booted) return 0;

    const gpa = std.heap.c_allocator;
    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();

    var exe_buf: [MAX_PATH]u8 = undefined;
    const exe_len = std.process.executablePath(io, &exe_buf) catch return fail("cannot resolve executable path");
    const exe_path = exe_buf[0..exe_len];
    var exe_zbuf: [MAX_PATH]u8 = undefined;
    const exe_z = std.fmt.bufPrintZ(&exe_zbuf, "{s}", .{exe_path}) catch return fail("executable path too long");

    const emb = embed.open(
        io,
        gpa,
        exe_path,
        exe_z,
        envOpt("XDG_CACHE_HOME"),
        envOpt("HOME"),
        envOpt("TMPDIR"),
        @intCast(std.c.getuid()),
        @intCast(std.c.getpid()),
        &rt_buf,
    ) catch return fail("runtime bring-up failed (trailer payload not materialized?)");

    emb.setProgramName(exe_z) catch return fail("failed to pin program name");
    const py_init = emb.symOrErr(embed.Py_Initialize_t, "Py_Initialize") catch return fail("libpython missing symbol: Py_Initialize");
    py_init();

    p_finalize = emb.symOrErr(PyFinalize_t, "Py_Finalize") catch return fail("missing Py_Finalize");
    p_run_simple = emb.symOrErr(PyRunSimpleString_t, "PyRun_SimpleString") catch return fail("missing PyRun_SimpleString");
    p_add_module = emb.symOrErr(PyImportAddModule_t, "PyImport_AddModule") catch return fail("missing PyImport_AddModule");
    p_get_dict = emb.symOrErr(PyModuleGetDict_t, "PyModule_GetDict") catch return fail("missing PyModule_GetDict");
    p_run_string = emb.symOrErr(PyRunString_t, "PyRun_String") catch return fail("missing PyRun_String");
    p_long_aslong = emb.symOrErr(PyLongAsLong_t, "PyLong_AsLong") catch return fail("missing PyLong_AsLong");
    p_save_thread = emb.symOrErr(PyEvalSaveThread_t, "PyEval_SaveThread") catch return fail("missing PyEval_SaveThread");
    p_restore_thread = emb.symOrErr(PyEvalRestoreThread_t, "PyEval_RestoreThread") catch return fail("missing PyEval_RestoreThread");
    p_gil_ensure = emb.symOrErr(PyGILStateEnsure_t, "PyGILState_Ensure") catch return fail("missing PyGILState_Ensure");
    p_gil_release = emb.symOrErr(PyGILStateRelease_t, "PyGILState_Release") catch return fail("missing PyGILState_Release");
    p_call_one = emb.symOrErr(PyObjectCallOneArg_t, "PyObject_CallOneArg") catch return fail("missing PyObject_CallOneArg");
    p_uni_from = emb.symOrErr(PyUnicodeFromString_t, "PyUnicode_FromString") catch return fail("missing PyUnicode_FromString");
    p_uni_utf8 = emb.symOrErr(PyUnicodeAsUTF8_t, "PyUnicode_AsUTF8") catch return fail("missing PyUnicode_AsUTF8");
    p_decref = emb.symOrErr(PyDecRef_t, "Py_DecRef") catch return fail("missing Py_DecRef");

    booted = true;
    return 0;
}

fn envOpt(name: [:0]const u8) ?[]const u8 {
    const v = std.c.getenv(name.ptr) orelse return null;
    return std.mem.span(v);
}

export fn jpy_Py_Finalize() void {
    p_finalize();
}
export fn jpy_PyRun_SimpleString(cmd: [*:0]const u8) c_int {
    return p_run_simple(cmd);
}
export fn jpy_PyImport_AddModule(name: [*:0]const u8) ?*anyopaque {
    return p_add_module(name);
}
export fn jpy_PyModule_GetDict(m: ?*anyopaque) ?*anyopaque {
    return p_get_dict(m);
}
export fn jpy_PyRun_String(s: [*:0]const u8, start: c_int, g: ?*anyopaque, l: ?*anyopaque) ?*anyopaque {
    return p_run_string(s, start, g, l);
}
export fn jpy_PyLong_AsLong(o: ?*anyopaque) c_long {
    return p_long_aslong(o);
}
export fn jpy_PyEval_SaveThread() ?*anyopaque {
    return p_save_thread();
}
export fn jpy_PyEval_RestoreThread(s: ?*anyopaque) void {
    p_restore_thread(s);
}
export fn jpy_PyGILState_Ensure() c_int {
    return p_gil_ensure();
}
export fn jpy_PyGILState_Release(s: c_int) void {
    p_gil_release(s);
}
export fn jpy_PyObject_CallOneArg(callable: ?*anyopaque, arg: ?*anyopaque) ?*anyopaque {
    return p_call_one(callable, arg);
}
export fn jpy_PyUnicode_FromString(s: [*:0]const u8) ?*anyopaque {
    return p_uni_from(s);
}
export fn jpy_PyUnicode_AsUTF8(o: ?*anyopaque) ?[*:0]const u8 {
    return p_uni_utf8(o);
}
export fn jpy_Py_DecRef(o: ?*anyopaque) void {
    p_decref(o);
}
