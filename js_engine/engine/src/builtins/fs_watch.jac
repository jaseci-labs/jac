"""
fs.watch backend — uv_fs_event_t + fired callback queue.

Pushes JS bridge callbacks onto the same queue used by async fs I/O
(fs_fired_* in fs.na.jac) so el_tick drains them on the main thread.
"""

import from engine.src.ffi.libuv {
    UVLoop,
    UVHandle,
    uv_fsevent_create,
    uv_fsevent_start,
    uv_fsevent_stop,
    uv_fsevent_close,
    uvhandle_ref,
    uvhandle_unref,
    UV_FS_EVENT_RENAME,
    UV_FS_EVENT_CHANGE,
    UV_FS_EVENT_RECURSIVE_FLAG,
    uv_default_loop
}
import from engine.src.ffi.libc { calloc }
import from engine.src.runtime.mem { read_byte, byte_chr }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_true,
    js_false,
    jsv_is_string_cell,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_is_int32,
    jsv_to_int32,
    jsv_is_bool,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_from_string_id
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_set,
    js_object_get
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.builtins.fs { fs_push_watch_callback, fs_init_loop_ptr }

obj FsWatchEntry {
    has id: int = 0,
        handle: UVHandle = UVHandle(),
        handle_ptr: int = 0,
        path: str = "",
        bridge: JSValue = 0,
        persistent: bool = True,
        refd: bool = True,
        closed: bool = False;
}

glob _FS_WATCH_ENTRIES: list[FsWatchEntry] = [],
     _FS_WATCH_NEXT_ID: int = 1,
     _FS_WATCH_LOOP_PTR: int = 0;

def:pub fs_watch_module_init(loop_ptr: int) {
    _FS_WATCH_LOOP_PTR = loop_ptr;
    fs_init_loop_ptr(loop_ptr);
}

def _cstr_from_ptr(ptr: int) -> str {
    if ptr == 0 {
        return "";
    }
    out: str = "";
    i: int = 0;
    while i < 4096 {
        b: int = read_byte(ptr, i);
        if b == 0 {
            return out;
        }
        out = out + byte_chr(b);
        i = i + 1;
    }
    return out;
}

def _find_entry_by_handle(handle_ptr: int) -> FsWatchEntry {
    i: int = 0;
    while i < len(_FS_WATCH_ENTRIES) {
        e: FsWatchEntry = _FS_WATCH_ENTRIES[i];
        if e.handle_ptr == handle_ptr and not e.closed {
            return e;
        }
        i = i + 1;
    }
    e0: FsWatchEntry = FsWatchEntry();
    e0.id = -1;
    return e0;
}

def _fs_watch_uv_code(status: int) -> str {
    if status == -2 {
        return "ENOENT";
    }
    if status == -13 {
        return "EACCES";
    }
    if status == -20 {
        return "ENOTDIR";
    }
    if status == -28 {
        return "ENOSPC";
    }
    if status == -22 {
        return "EINVAL";
    }
    return "UNKNOWN";
}

def _fs_watch_make_error(status: int, path: str) -> JSValue {
    code_s: str = _fs_watch_uv_code(status);
    err: JSValue = js_object_create_null();
    js_object_set(err, str_intern("code"), jsv_from_string_id(str_intern(code_s)));
    js_object_set(err, str_intern("errno"), js_int(-status));
    js_object_set(err, str_intern("syscall"), jsv_from_string_id(str_intern("watch")));
    js_object_set(err, str_intern("path"), jsv_from_string_id(str_intern(path)));
    msg: str = code_s + ", watch '" + path + "'";
    js_object_set(err, str_intern("message"), jsv_from_string_id(str_intern(msg)));
    return err;
}

def _fs_watch_remove_entry(wid: int) {
    kept: list[FsWatchEntry] = [];
    i: int = 0;
    while i < len(_FS_WATCH_ENTRIES) {
        e: FsWatchEntry = _FS_WATCH_ENTRIES[i];
        if e.id != wid {
            kept.append(e);
        }
        i = i + 1;
    }
    _FS_WATCH_ENTRIES = kept;
}

def _find_entry_by_id(wid: int) -> FsWatchEntry {
    i: int = 0;
    while i < len(_FS_WATCH_ENTRIES) {
        e: FsWatchEntry = _FS_WATCH_ENTRIES[i];
        if e.id == wid {
            return e;
        }
        i = i + 1;
    }
    e0: FsWatchEntry = FsWatchEntry();
    e0.id = -1;
    return e0;
}

def _fs_watch_emit_bridge(
    went: FsWatchEntry, event_name: str, a1: JSValue, a2: JSValue
) -> None {
    if went.closed {
        return;
    }
    if jsv_is_undefined(went.bridge) {
        return;
    }
    cb_args: list[JSValue] = [];
    cb_args.append(js_int(went.id));
    cb_args.append(jsv_from_string_id(str_intern(event_name)));
    cb_args.append(a1);
    cb_args.append(a2);
    fs_push_watch_callback(went.bridge, cb_args);
}

def _fs_watch_event_cb(
    handle_ptr: int, filename_ptr: int, events: int, status: int
) -> None {
    went: FsWatchEntry = _find_entry_by_handle(handle_ptr);
    if went.id < 0 {
        return;
    }
    if went.closed {
        return;
    }

    if status < 0 {
        err: JSValue = _fs_watch_make_error(status, went.path);
        _fs_watch_emit_bridge(went, "error", err, js_undefined());
        return;
    }

    ev_type: str = "change";
    if (events & UV_FS_EVENT_RENAME) != 0 {
        ev_type = "rename";
    }

    fn_arg: JSValue = js_undefined();
    if filename_ptr != 0 {
        fn_s: str = _cstr_from_ptr(filename_ptr);
        if fn_s != "" {
            fn_arg = jsv_from_string_id(str_intern(fn_s));
        }
    }

    _fs_watch_emit_bridge(
        went, "change", jsv_from_string_id(str_intern(ev_type)), fn_arg
    );
}

def _path_from_arg(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_object_cell(v) {
        href_v: JSValue = js_object_get(v, str_intern("href"));
        if jsv_is_string_cell(href_v) {
            p: str = str_from_id(jsv_to_table_id(href_v));
            if len(p) >= 7 and p[0:7] == "file://" {
                return p[7:];
            }
            return p;
        }
    }
    return "";
}

"""Start native directory watch. Returns watcher handle object or undefined."""
def:pub fs_watch_start(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    path: str = _path_from_arg(args[0]);
    bridge: JSValue = args[1];
    if path == "" or jsv_is_undefined(bridge) {
        return js_undefined();
    }

    recursive: bool = False;
    persistent: bool = True;
    if len(args) >= 3 and jsv_is_bool(args[2]) {
        recursive = jsv_to_bool(args[2]);
    }
    if len(args) >= 4 and jsv_is_bool(args[3]) {
        persistent = jsv_to_bool(args[3]);
    }

    lp: UVLoop = UVLoop();
    lp.loop_ptr = _FS_WATCH_LOOP_PTR;
    if lp.loop_ptr == 0 {
        lp.loop_ptr = uv_default_loop();
    }

    h: UVHandle = uv_fsevent_create(lp);
    flags: int = 0;
    if recursive {
        flags = UV_FS_EVENT_RECURSIVE_FLAG;
    }

    st: int = uv_fsevent_start(h, _fs_watch_event_cb, path, flags);
    if st != 0 {
        uv_fsevent_close(h);
        bad: JSValue = js_object_create_null();
        js_object_set(bad, str_intern("_watchError"), _fs_watch_make_error(st, path));
        return bad;
    }

    if not persistent {
        uvhandle_unref(h);
    }

    wid: int = _FS_WATCH_NEXT_ID;
    _FS_WATCH_NEXT_ID = _FS_WATCH_NEXT_ID + 1;

    went: FsWatchEntry = FsWatchEntry();
    went.id = wid;
    went.handle = h;
    went.handle_ptr = h.handle_ptr;
    went.path = path;
    went.bridge = bridge;
    went.persistent = persistent;
    went.refd = persistent;
    went.closed = False;
    _FS_WATCH_ENTRIES.append(went);

    handle_obj: JSValue = js_object_create_null();
    js_object_set(handle_obj, str_intern("_watchId"), js_int(wid));
    return handle_obj;
}

def:pub fs_watch_close(this_val: JSValue, args: list[JSValue]) -> JSValue {
    wid2: int = 0;
    id_cell: JSValue = js_object_get(this_val, str_intern("_watchId"));
    if jsv_is_undefined(id_cell) {
        return this_val;
    }
    if jsv_is_int32(id_cell) {
        wid2 = jsv_to_int32(id_cell);
    }

    went: FsWatchEntry = _find_entry_by_id(wid2);
    if went.id < 0 {
        return this_val;
    }
    if not went.closed {
        went.closed = True;
        uv_fsevent_close(went.handle);
        _fs_watch_remove_entry(wid2);
    }
    return this_val;
}

def:pub fs_watch_ref(this_val: JSValue, args: list[JSValue]) -> JSValue {
    id_cell: JSValue = js_object_get(this_val, str_intern("_watchId"));
    if jsv_is_undefined(id_cell) {
        return this_val;
    }
    if not jsv_is_int32(id_cell) {
        return this_val;
    }
    went: FsWatchEntry = _find_entry_by_id(jsv_to_int32(id_cell));
    if went.id >= 0 and not went.closed and not went.refd {
        went.refd = True;
        uvhandle_ref(went.handle);
    }
    return this_val;
}

def:pub fs_watch_unref(this_val: JSValue, args: list[JSValue]) -> JSValue {
    id_cell: JSValue = js_object_get(this_val, str_intern("_watchId"));
    if jsv_is_undefined(id_cell) {
        return this_val;
    }
    if not jsv_is_int32(id_cell) {
        return this_val;
    }
    went: FsWatchEntry = _find_entry_by_id(jsv_to_int32(id_cell));
    if went.id >= 0 and not went.closed and went.refd {
        went.refd = False;
        uvhandle_unref(went.handle);
    }
    return this_val;
}
