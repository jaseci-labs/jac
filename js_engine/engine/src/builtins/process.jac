"""
process Object Implementation.

Provides the Node.js-compatible `process` global object:
  - process.version, process.platform, process.arch
  - process.pid                    (libc getpid)
  - process.argv                   (populated from entry point)
  - process.env                    (populated from entry point)
  - process.exit(code?)            (libc _exit)
  - process.stdout.write(str)      (libc write fd 1)
  - process.stderr.write(str)      (libc write fd 2)
  - process.hrtime([prev])         (uv_hrtime → [sec, ns])
  - process.cwd()                  (libc getcwd)
  - process.nextTick(fn, ...args)  (wired in )

Bun Zig mapping:
  bun/src/bun.js/api/BunObject.zig      — process property
  bun/src/bun.js/bindings/ZigGlobalObject.zig — processObject
Node.js spec: https://nodejs.org/api/process.html
"""

# ── C library imports ────────────────────────────────────────────────────────

import from engine.src.ffi.libc {
    getpid,
    getppid,
    _exit,
    abort,
    write,
    getcwd,
    chdir,
    getenv,
    kill,
    fflush,
    umask,
    getuid,
    getgid,
    geteuid,
    getegid,
    setuid,
    setgid,
    seteuid,
    setegid,
    getgroups,
    sysconf,
    fopen,
    fread,
    fclose,
    calloc,
    free,
    getrusage
}

import from engine.src.ffi.libuv { uvhrtime }
import from engine.src.pm.fsx { fsx_readlink }
import from engine.src.builtins.env_file { env_file_pending_vars }

import from engine.src.runtime.mem { Ptr, io_alloc, read_byte, write_byte, read_u64 }

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_false,
    js_int,
    js_number,
    jsv_from_double,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_is_string_cell,
    jsv_is_any_object,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_from_cell_kind,
    JS_CELL_KIND_BIGINT
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_set,
    js_object_get,
    obj_stats_report
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.error { make_type_error, make_error, vm_throw_native }
import from engine.src.builtins.modules { module_require_builtin }
import from engine.src.builtins.module_registry { is_builtin_module }
import from engine.src.builtins.array { js_array_create, _KEY_IS_ARRAY }
import from engine.src.builtins.path_utils { path_abspath }
import from engine.src.vm.timers { timer_active_resource_types }
import from napi.src.napi_binary { napi_binary_flush_finalizers }

# ── Module globals ───────────────────────────────────────────────────────────

"""OS argv[0] and resolved executable path (populated before el_run)."""
glob _PROC_BOOTSTRAP_ARGV0: str = "js_engine";
glob _PROC_EXEC_PATH: str = "js_engine";

"""CLI options captured by main.na.jac before el_run (Node-compatible)."""
glob _PROC_EXEC_ARGV: list[str] = [];
glob _PROC_INPUT_TYPE: str = "",
     _PROC_EVAL_PRINT: bool = False,
     _PROC_NO_WARNINGS: bool = False;  # "" | "module" | "commonjs"

import from engine.src.builtins.markers { _KEY_IS_ENV_OBJ }
import from engine.src.runtime.gc_pin { gc_pin_value }

"""Pre-populated process.env object. Lazily created on first access to avoid
glob init ordering crash (jsobject property pool not yet initialized)."""
glob:pub _PROC_ENV: JSValue = js_undefined();
glob _PROC_ENV_INIT: bool = False;

"""Ensure _PROC_ENV is initialized (lazy init pattern)."""
def _ensure_env {
    if not _PROC_ENV_INIT {
        _PROC_ENV = js_object_create_null();
        gc_pin_value(_PROC_ENV);  # glob-held singleton — invisible to the GC root walk
        js_object_set(_PROC_ENV, _KEY_IS_ENV_OBJ, js_true());
        _PROC_ENV_INIT = True;
    }
}

# ── Buffer helper ────────────────────────────────────────────────────────────

"""Copy n bytes from buf (io_alloc pointer) into a new null-terminated Jac str."""
def _proc_buf_to_str(buf: Ptr, n: int) -> str {
    out: Ptr = io_alloc(n + 1);
    if n > 0 {
        bi: int = 0;
        while bi < n {
            write_byte(out, bi, read_byte(buf, bi));
            bi = bi + 1;
        }
    }
    write_byte(out, n, 0);
    result: str = out;  # jac:ignore[E1001] pointer reinterpret
    return result;
}

# ── Environment helpers ──────────────────────────────────────────────────────

"""Add a single key=value pair to the process.env object.
Called from the Python entry point (with entry) before el_run."""
def:pub process_add_env(key: str, val: str) {
    _ensure_env();
    jsval: JSValue = jsv_from_string_id(str_intern(val));
    js_object_set(_PROC_ENV, str_intern(key), jsval);
}

"""Try to read an env var via libc getenv() and add it to _PROC_ENV."""
def _try_add_env(name: str) {
    _ensure_env();
    val: str = getenv(name);
    if val {
        jsval: JSValue = jsv_from_string_id(str_intern(val));
        js_object_set(_PROC_ENV, str_intern(name), jsval);
    }
}

"""Populate process.env with ALL environment variables by reading
/proc/self/environ (Linux). Each entry is null-byte-terminated KEY=VALUE.
Falls back to a hardcoded list of common vars if /proc is unavailable."""
def:pub process_populate_env -> None {
    BUF_SIZE: int = 131072;  # 128 KB — enough for any realistic environ
    fp: Ptr = fopen("/proc/self/environ", "rb");
    if fp != 0 {
        buf: Ptr = io_alloc(BUF_SIZE);
        n: int = fread(buf, 1, BUF_SIZE - 1, fp);
        fclose(fp);
        # /proc/self/environ: KEY=VALUE\0KEY2=VALUE2\0...
        pos: int = 0;
        while pos < n {
            # Find '=' (0x3D = 61)
            eq: int = pos;
            while eq < n and read_byte(buf, eq) != 61 {
                eq = eq + 1;
            }
            if eq >= n {
                break;
            }
            # Find '\0' (0x00) after the value
            nul: int = eq + 1;
            while nul < n and read_byte(buf, nul) != 0 {
                nul = nul + 1;
            }
            key_len: int = eq - pos;
            val_len: int = nul - (eq + 1);
            if key_len > 0 {
                key: str = _proc_buf_to_str(buf + pos, key_len);
                val: str = _proc_buf_to_str(buf + (eq + 1), val_len);
                process_add_env(key, val);
            }
            pos = nul + 1;
        }
        return;
    }
    # Fallback: hardcoded common names via getenv()
    _try_add_env("PATH");
    _try_add_env("HOME");
    _try_add_env("USER");
    _try_add_env("SHELL");
    _try_add_env("TERM");
    _try_add_env("LANG");
    _try_add_env("NODE_ENV");
    _try_add_env("PWD");
    _try_add_env("HOSTNAME");
    _try_add_env("EDITOR");
    _try_add_env("TMPDIR");
    _try_add_env("TZ");
    _try_add_env("LOGNAME");
}

"""Return the pre-populated process.env object."""
def:pub process_get_env -> JSValue {
    _ensure_env();
    return _PROC_ENV;
}

# ── PID ──────────────────────────────────────────────────────────────────────

"""Return the current process ID as an int."""
def:pub process_get_pid -> int {
    return getpid();
}

"""Return the parent process ID as an int."""
def:pub process_get_ppid -> int {
    return getppid();
}

"""Call libc abort() — raises SIGABRT and generates a core dump."""
def:pub process_do_abort {
    abort();
}

"""Change the current working directory. Returns 0 on success, -1 on error."""
def:pub process_do_chdir(args: list[JSValue]) -> JSValue {
    if len(args) == 0 or not jsv_is_string_cell(args[0]) {
        err0: JSValue = make_type_error(
            "The \"path\" argument must be of type string."
        );
        js_object_set(
            err0,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
        );
        vm_throw_native(err0);
        return js_undefined();
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    rc: int = chdir(path);
    if rc != 0 {
        err1: JSValue = make_type_error("ENOENT: no such file or directory, chdir");
        js_object_set(
            err1, str_intern("code"), jsv_from_string_id(str_intern("ENOENT"))
        );
        vm_throw_native(err1);
        return js_undefined();
    }
    return js_undefined();
}

"""Send a signal to a process. Defaults to SIGTERM (15)."""
def:pub process_do_kill(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        err0: JSValue = make_type_error("The \"pid\" argument must be of type number.");
        js_object_set(
            err0,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
        );
        vm_throw_native(err0);
        return js_undefined();
    }
    pid: int = 0;
    if jsv_is_int32(args[0]) {
        pid = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        pid = int(jsv_to_double(args[0]));
    }
    sig: int = 15;  # SIGTERM default
    if len(args) >= 2 and (jsv_is_int32(args[1]) or jsv_is_double(args[1])) {
        if jsv_is_int32(args[1]) {
            sig = jsv_to_int32(args[1]);
        } else {
            sig = int(jsv_to_double(args[1]));
        }
    }
    rc: int = kill(pid, sig);
    if rc != 0 {
        err1: JSValue = make_type_error("kill ESRCH");
        js_object_set(
            err1, str_intern("code"), jsv_from_string_id(str_intern("ESRCH"))
        );
        vm_throw_native(err1);
    }
    return js_undefined();
}

"""Return the real user ID of the calling process."""
def:pub process_getuid -> JSValue {
    return js_int(getuid());
}

"""Return the real group ID of the calling process."""
def:pub process_getgid -> JSValue {
    return js_int(getgid());
}

"""Return the effective user ID of the calling process."""
def:pub process_geteuid -> JSValue {
    return js_int(geteuid());
}

"""Return the effective group ID of the calling process."""
def:pub process_getegid -> JSValue {
    return js_int(getegid());
}

# ── exit ─────────────────────────────────────────────────────────────────────

"""Terminate the process immediately with the given exit code.
Flushes all stdio buffers then calls libc _exit()."""
def:pub process_do_exit(code: int) {
    # docs/OBJECT_FOOTPRINT_PLAN.md Phase 0: dump the live-object structural
    # inventory at exit when JAC_OBJ_STATS is set (zero cost otherwise).
    if getenv("JAC_OBJ_STATS") != None {
        obj_stats_report();
    }
    # Release addon-owned external-buffer memory (napi finalize callbacks)
    # before teardown — with GC disabled (default) this is the only point
    # the finalizers can run; Node fires them at env teardown the same way.
    napi_binary_flush_finalizers();
    fflush(0);
    _exit(code);
}

# ── stdout / stderr write ────────────────────────────────────────────────────

"""Write a string to stdout (fd 1). Returns true on success."""
def:pub process_stdout_write(args: list[JSValue]) -> JSValue {
    if len(args) > 0 and jsv_is_string_cell(args[0]) {
        s: str = str_from_id(jsv_to_table_id(args[0]));
        slen: int = len(s);
        write(1, s, slen);
        return js_true();
    }
    return js_false();
}

"""Write a string to stderr (fd 2). Returns true on success."""
def:pub process_stderr_write(args: list[JSValue]) -> JSValue {
    if len(args) > 0 and jsv_is_string_cell(args[0]) {
        s: str = str_from_id(jsv_to_table_id(args[0]));
        slen: int = len(s);
        write(2, s, slen);
        return js_true();
    }
    return js_false();
}

# ── hrtime ───────────────────────────────────────────────────────────────────

"""Return [seconds, nanoseconds] array from uv_hrtime().
If called with a previous hrtime result (array), returns the difference."""
def:pub process_hrtime(args: list[JSValue]) -> JSValue {
    ns: int = uvhrtime();
    sec: int = ns // 1000000000;
    rem: int = ns - sec * 1000000000;

    # If prev argument supplied, validate (Node: must be a prior hrtime tuple) and diff
    if len(args) > 0 {
        a0: JSValue = args[0];
        ok_prev: bool = False;
        prev_sec: int = 0;
        prev_ns: int = 0;
        if jsv_is_object_cell(a0) {
            marr: JSValue = js_object_get(a0, _KEY_IS_ARRAY);
            is_arr: bool = jsv_is_bool(marr) and jsv_to_bool(marr);
            if is_arr {
                sec_v: JSValue = js_object_get(a0, str_intern("0"));
                nsv_v: JSValue = js_object_get(a0, str_intern("1"));
                s_ok: bool = jsv_is_int32(sec_v) or jsv_is_double(sec_v);
                n_ok2: bool = jsv_is_int32(nsv_v) or jsv_is_double(nsv_v);
                if s_ok and n_ok2 {
                    if jsv_is_int32(sec_v) {
                        prev_sec = jsv_to_int32(sec_v);
                    } else {
                        prev_sec = int(jsv_to_double(sec_v));
                    }
                    if jsv_is_int32(nsv_v) {
                        prev_ns = jsv_to_int32(nsv_v);
                    } else {
                        prev_ns = int(jsv_to_double(nsv_v));
                    }
                    ok_prev = True;
                }
            }
        }
        if not ok_prev {
            err0: JSValue = make_type_error(
                "The \"time\" argument must be a previous value returned by process.hrtime()"
            );
            js_object_set(
                err0,
                str_intern("code"),
                jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
            );
            vm_throw_native(err0);
            return js_undefined();
        }
        diff_ns: int = ns - (prev_sec * 1000000000 + prev_ns);
        sec = diff_ns // 1000000000;
        rem = diff_ns - sec * 1000000000;
        if rem < 0 {
            sec = sec - 1;
            rem = rem + 1000000000;
        }
    }

    result: list[JSValue] = [];
    result.append(js_int(sec));
    result.append(js_int(rem));
    return js_array_create(result);
}

# ── cwd ──────────────────────────────────────────────────────────────────────

"""Return the current working directory as a JS string.
Uses libc getcwd(NULL, 0) GNU extension which auto-allocates."""
def:pub process_get_cwd -> JSValue {
    # getcwd(0, 0) — GNU extension: allocates buffer automatically
    path: str = getcwd(0, 4096);
    return jsv_from_string_id(str_intern(path));
}

# ── hrtime.bigint / uptime ───────────────────────────────────────────────────

"""Monotonic start timestamp captured at process bootstrap (nanoseconds)."""
glob _PROC_START_NS: int = 0;
glob _PROC_START_INIT: bool = False;

"""Initialize the process start timestamp (call once from process setup)."""
def:pub process_init_start_time {
    if not _PROC_START_INIT {
        _PROC_START_NS = uvhrtime();
        _PROC_START_INIT = True;
    }
}

"""Return monotonic nanoseconds as a BigInt JSValue (process.hrtime.bigint())."""
def:pub process_hrtime_bigint(args: list[JSValue]) -> JSValue {
    ns: int = uvhrtime();
    id: int = str_intern(str(ns));
    return jsv_from_cell_kind(id, JS_CELL_KIND_BIGINT);
}

"""Return seconds elapsed since process start as a float (process.uptime())."""
def:pub process_uptime(args: list[JSValue]) -> JSValue {
    if not _PROC_START_INIT {
        process_init_start_time();
    }
    elapsed_ns: int = uvhrtime() - _PROC_START_NS;
    elapsed_sec: float = float(elapsed_ns) / 1000000000.0;
    return js_number(elapsed_sec);
}

# ── Source maps toggle (Vite V-03 — no-op compatibility) ─────────────────────

"""Stored flag from process.setSourceMapsEnabled(); no stack rewriting yet."""
glob _PROC_SOURCE_MAPS_ENABLED: bool = False;

"""
process.setSourceMapsEnabled(enabled) -> undefined

Node.js accepts a boolean and records whether source maps are enabled for the
process. js_engine stores the flag only (no V8-style source map integration).
"""
def:pub process_set_source_maps_enabled(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        err0: JSValue = make_type_error(
            'The "enabled" argument must be of type boolean. Received undefined'
        );
        js_object_set(
            err0,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
        );
        vm_throw_native(err0);
        return js_undefined();
    }
    if not jsv_is_bool(args[0]) {
        err1: JSValue = make_type_error(
            'The "enabled" argument must be of type boolean'
        );
        js_object_set(
            err1,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
        );
        vm_throw_native(err1);
        return js_undefined();
    }
    _PROC_SOURCE_MAPS_ENABLED = jsv_to_bool(args[0]);
    return js_undefined();
}

# ── process.getBuiltinModule (Node 22+ / Vite importMetaResolver) ─────────────

"""
process.getBuiltinModule(id) -> module exports

Returns a built-in module by id (with or without node: prefix).
Returns undefined when the id is not a built-in (Node 22+ parity).
"""
def:pub process_get_builtin_module(
    args: list[JSValue], globals_ref: dict[str, JSValue]
) -> JSValue {
    if len(args) < 1 or not jsv_is_string_cell(args[0]) {
        err0: JSValue = make_type_error('The "id" argument must be of type string.');
        js_object_set(
            err0,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
        );
        vm_throw_native(err0);
        return js_undefined();
    }
    spec: str = str_from_id(jsv_to_table_id(args[0]));
    bare: str = spec;
    if len(spec) > 5
        and spec[0] == "n"
        and spec[1] == "o"
        and spec[2] == "d"
        and spec[3] == "e"
        and spec[4] == ":" {
        bare = spec[5:];
    }
    check_name: str = bare;
    if not is_builtin_module(check_name) {
        check_name = "node:" + bare;
    }
    if not is_builtin_module(check_name) {
        return js_undefined();
    }
    exports: JSValue = module_require_builtin(bare, "", globals_ref);
    if jsv_is_undefined(exports) {
        exports = module_require_builtin("node:" + bare, "", globals_ref);
    }
    if jsv_is_undefined(exports) {
        return js_undefined();
    }
    return exports;
}

# ── EventEmitter surface ─────────────────────────────────────────────────────

"""Per-event listener tables (JSValue = int).  'once' wrappers use the same
   list; they are removed by emit after first call."""
glob _PROC_LISTENERS_WARNING: list[int] = [];
glob _PROC_LISTENERS_EXIT: list[int] = [],
     _PROC_LISTENERS_UNCAUGHT: list[int] = [],
     _PROC_LISTENERS_UNHANDLED_REJECTION: list[int] = [],
     _PROC_LISTENERS_BEFORE_EXIT: list[int] = [],
     _PROC_LISTENERS_REJECTION_HANDLED: list[int] = [],
     _PROC_ONCE_WARNING: list[int] = [],
     _PROC_ONCE_EXIT: list[int] = [],
     _PROC_ONCE_UNCAUGHT: list[int] = [],
     _PROC_ONCE_UNHANDLED_REJECTION: list[int] = [],
     _PROC_ONCE_BEFORE_EXIT: list[int] = [],
     _PROC_ONCE_REJECTION_HANDLED: list[int] = [],
     _PROC_LISTENERS_GENERIC: dict[str, list[int]] = {},
     _PROC_ONCE_GENERIC: dict[str, list[int]] = {};

# once-flag parallel arrays: 1 = fire once then remove

# Generic catch-all for user-defined events (process.on('myevent', fn))
def _proc_ev_lists(event: str) -> int {
    # Returns 0=warning 1=exit 2=uncaught 3=unhandledRejection 4=beforeExit 5=rejectionHandled -1=unknown
    if event == "warning" {
        return 0;
    } elif event == "exit" {
        return 1;
    } elif event == "uncaughtException" {
        return 2;
    } elif event == "unhandledRejection" {
        return 3;
    } elif event == "beforeExit" {
        return 4;
    } elif event == "rejectionHandled" {
        return 5;
    }
    return -1;
}

def:pub process_on(args: list[JSValue], once_flag: int) -> int {
    if len(args) < 2 {
        return js_undefined();
    }
    ev: str = str_from_id(jsv_to_table_id(args[0]));
    fn: int = args[1];
    eid: int = _proc_ev_lists(ev);
    if eid == 0 {
        _PROC_LISTENERS_WARNING.append(fn);
        _PROC_ONCE_WARNING.append(once_flag);
    } elif eid == 1 {
        _PROC_LISTENERS_EXIT.append(fn);
        _PROC_ONCE_EXIT.append(once_flag);
    } elif eid == 2 {
        _PROC_LISTENERS_UNCAUGHT.append(fn);
        _PROC_ONCE_UNCAUGHT.append(once_flag);
    } elif eid == 3 {
        _PROC_LISTENERS_UNHANDLED_REJECTION.append(fn);
        _PROC_ONCE_UNHANDLED_REJECTION.append(once_flag);
    } elif eid == 4 {
        _PROC_LISTENERS_BEFORE_EXIT.append(fn);
        _PROC_ONCE_BEFORE_EXIT.append(once_flag);
    } elif eid == 5 {
        _PROC_LISTENERS_REJECTION_HANDLED.append(fn);
        _PROC_ONCE_REJECTION_HANDLED.append(once_flag);
    } else {
        # Generic user-defined event
        if ev not in _PROC_LISTENERS_GENERIC {
            _PROC_LISTENERS_GENERIC[ev] = [];
            _PROC_ONCE_GENERIC[ev] = [];
        }
        _PROC_LISTENERS_GENERIC[ev].append(fn);
        _PROC_ONCE_GENERIC[ev].append(once_flag);
    }
    return js_undefined();
}

def:pub process_off(args: list[JSValue]) -> int {
    if len(args) < 2 {
        return js_undefined();
    }
    ev: str = str_from_id(jsv_to_table_id(args[0]));
    fn_target: int = args[1];
    eid: int = _proc_ev_lists(ev);
    idx: int = 0;
    if eid == 0 {
        while idx < len(_PROC_LISTENERS_WARNING) {
            if _PROC_LISTENERS_WARNING[idx] == fn_target {
                del _PROC_LISTENERS_WARNING[idx];
                del _PROC_ONCE_WARNING[idx];
                return js_undefined();
            }
            idx = idx + 1;
        }
    } elif eid == 1 {
        while idx < len(_PROC_LISTENERS_EXIT) {
            if _PROC_LISTENERS_EXIT[idx] == fn_target {
                del _PROC_LISTENERS_EXIT[idx];
                del _PROC_ONCE_EXIT[idx];
                return js_undefined();
            }
            idx = idx + 1;
        }
    } elif eid == 2 {
        while idx < len(_PROC_LISTENERS_UNCAUGHT) {
            if _PROC_LISTENERS_UNCAUGHT[idx] == fn_target {
                del _PROC_LISTENERS_UNCAUGHT[idx];
                del _PROC_ONCE_UNCAUGHT[idx];
                return js_undefined();
            }
            idx = idx + 1;
        }
    } elif eid == 3 {
        while idx < len(_PROC_LISTENERS_UNHANDLED_REJECTION) {
            if _PROC_LISTENERS_UNHANDLED_REJECTION[idx] == fn_target {
                del _PROC_LISTENERS_UNHANDLED_REJECTION[idx];
                del _PROC_ONCE_UNHANDLED_REJECTION[idx];
                return js_undefined();
            }
            idx = idx + 1;
        }
    } elif eid == 4 {
        while idx < len(_PROC_LISTENERS_BEFORE_EXIT) {
            if _PROC_LISTENERS_BEFORE_EXIT[idx] == fn_target {
                del _PROC_LISTENERS_BEFORE_EXIT[idx];
                del _PROC_ONCE_BEFORE_EXIT[idx];
                return js_undefined();
            }
            idx = idx + 1;
        }
    } elif eid == 5 {
        while idx < len(_PROC_LISTENERS_REJECTION_HANDLED) {
            if _PROC_LISTENERS_REJECTION_HANDLED[idx] == fn_target {
                del _PROC_LISTENERS_REJECTION_HANDLED[idx];
                del _PROC_ONCE_REJECTION_HANDLED[idx];
                return js_undefined();
            }
            idx = idx + 1;
        }
    } else {
        if ev in _PROC_LISTENERS_GENERIC {
            gl: list[int] = _PROC_LISTENERS_GENERIC[ev];
            go: list[int] = _PROC_ONCE_GENERIC[ev];
            while idx < len(gl) {
                if gl[idx] == fn_target {
                    del gl[idx];
                    del go[idx];
                    return js_undefined();
                }
                idx = idx + 1;
            }
        }
    }
    return js_undefined();
}

def:pub process_remove_all(args: list[JSValue]) -> int {
    if len(args) < 1 {
        return js_undefined();
    }
    ev: str = str_from_id(jsv_to_table_id(args[0]));
    eid: int = _proc_ev_lists(ev);
    # Assign empty lists — O(1) vs O(n^2) repeated `del [0]` while clearing.
    empty_i: list[int] = [];
    if eid == 0 {
        _PROC_LISTENERS_WARNING = empty_i;
        _PROC_ONCE_WARNING = [];
    } elif eid == 1 {
        _PROC_LISTENERS_EXIT = empty_i;
        _PROC_ONCE_EXIT = [];
    } elif eid == 2 {
        _PROC_LISTENERS_UNCAUGHT = empty_i;
        _PROC_ONCE_UNCAUGHT = [];
    } elif eid == 3 {
        _PROC_LISTENERS_UNHANDLED_REJECTION = empty_i;
        _PROC_ONCE_UNHANDLED_REJECTION = [];
    } elif eid == 4 {
        _PROC_LISTENERS_BEFORE_EXIT = empty_i;
        _PROC_ONCE_BEFORE_EXIT = [];
    } elif eid == 5 {
        _PROC_LISTENERS_REJECTION_HANDLED = empty_i;
        _PROC_ONCE_REJECTION_HANDLED = [];
    }
    return js_undefined();
}

"""Get the warning listeners list (for dispatch use)."""
def:pub process_get_warning_listeners -> list[int] {
    return _PROC_LISTENERS_WARNING;
}

"""Get the exit listeners list (for dispatch use)."""
def:pub process_get_exit_listeners -> list[int] {
    return _PROC_LISTENERS_EXIT;
}

"""Get once flags for exit listeners."""
def:pub process_get_exit_once -> list[int] {
    return _PROC_ONCE_EXIT;
}

"""Get once flags for warning listeners."""
def:pub process_get_warning_once -> list[int] {
    return _PROC_ONCE_WARNING;
}

"""Get the unhandledRejection listeners list (for dispatch use)."""
def:pub process_get_unhandled_rejection_listeners -> list[int] {
    return _PROC_LISTENERS_UNHANDLED_REJECTION;
}

"""Get once flags for unhandledRejection listeners."""
def:pub process_get_unhandled_rejection_once -> list[int] {
    return _PROC_ONCE_UNHANDLED_REJECTION;
}

"""Get the uncaughtException listeners list (for dispatch use)."""
def:pub process_get_uncaught_listeners -> list[int] {
    return _PROC_LISTENERS_UNCAUGHT;
}

"""Get once flags for uncaughtException listeners."""
def:pub process_get_uncaught_once -> list[int] {
    return _PROC_ONCE_UNCAUGHT;
}

"""Get the beforeExit listeners list (for el_run use)."""
def:pub process_get_before_exit_listeners -> list[int] {
    return _PROC_LISTENERS_BEFORE_EXIT;
}

"""Fire rejectionHandled listeners for a promise that was previously unhandled.
Called from vm.na.jac whenever promise_unmark_unhandled fires on a promise
that was already dispatched as unhandled."""
def:pub process_queue_rejection_handled(promise: JSValue) {
    rh_fns: list[int] = _PROC_LISTENERS_REJECTION_HANDLED;
    rh_fi: int = 0;
    while rh_fi < len(rh_fns) {
        rh_fn: JSValue = rh_fns[rh_fi];
        _PROC_RH_QUEUE_FNS.append(rh_fn);
        _PROC_RH_QUEUE_PROMISES.append(promise);
        rh_fi = rh_fi + 1;
    }
}

# Pending rejectionHandled calls (fn, promise) — drained by el_tick via event_loop.
glob _PROC_RH_QUEUE_FNS: list[int] = [],
     _PROC_RH_QUEUE_PROMISES: list[int] = [];

"""Return count of pending rejectionHandled events."""
def:pub process_rejection_handled_count -> int {
    return len(_PROC_RH_QUEUE_FNS);
}

"""Return the fn at index i in the rejectionHandled queue."""
def:pub process_rejection_handled_fn(i: int) -> JSValue {
    return _PROC_RH_QUEUE_FNS[i];
}

"""Return the promise at index i in the rejectionHandled queue."""
def:pub process_rejection_handled_promise(i: int) -> JSValue {
    return _PROC_RH_QUEUE_PROMISES[i];
}

"""Clear the first n entries from the rejectionHandled queue.

O(remaining) rebuild instead of repeated `del [0]` (O(n^2) batch drain)."""
def:pub process_rejection_handled_clear(n: int) -> None {
    if n <= 0 {
        return;
    }
    rh_fn_kept: list[int] = [];
    rh_p_kept: list[int] = [];
    rh_i: int = n;
    rh_len: int = len(_PROC_RH_QUEUE_FNS);
    while rh_i < rh_len {
        rh_fn_kept.append(_PROC_RH_QUEUE_FNS[rh_i]);
        rh_p_kept.append(_PROC_RH_QUEUE_PROMISES[rh_i]);
        rh_i = rh_i + 1;
    }
    _PROC_RH_QUEUE_FNS = rh_fn_kept;
    _PROC_RH_QUEUE_PROMISES = rh_p_kept;
}

"""Get generic (user-defined event) listeners for an event name."""
def:pub process_get_generic_listeners(ev: str) -> list[int] {
    if ev in _PROC_LISTENERS_GENERIC {
        return _PROC_LISTENERS_GENERIC[ev];
    }
    empty: list[int] = [];
    return empty;
}

"""Get once flags for generic listeners for an event name."""
def:pub process_get_generic_once(ev: str) -> list[int] {
    if ev in _PROC_ONCE_GENERIC {
        return _PROC_ONCE_GENERIC[ev];
    }
    empty: list[int] = [];
    return empty;
}

def:pub process_build_warning_obj(msg: str, warn_type: str) -> int {
    warn_obj: int = js_object_create_null();
    js_object_set(warn_obj, str_intern("message"), jsv_from_string_id(str_intern(msg)));
    js_object_set(
        warn_obj, str_intern("name"), jsv_from_string_id(str_intern(warn_type))
    );
    js_object_set(warn_obj, str_intern("stack"), js_undefined());
    return warn_obj;
}

"""process.memoryUsage() — reads /proc/self/statm for real RSS.
statm format: size resident shared text lib data dt (all in pages).
Page size is read via sysconf(_SC_PAGE_SIZE=30) at call time."""
def:pub process_memory_usage(args: list[JSValue]) -> int {
    mem_obj: int = js_object_create_null();
    pg: int = sysconf(_PROC_SC_PAGE_SIZE);
    if pg <= 0 {
        pg = 4096;
    }
    rss: int = 4 * 1024 * 1024;  # default fallback = 4 MB
    heap_total: int = rss;
    fp: Ptr = fopen("/proc/self/statm", "r");
    if fp != 0 {
        buf: Ptr = io_alloc(128);
        n: int = fread(buf, 1, 127, fp);
        fclose(fp);
        write_byte(buf, n, 0);
        # Field 0: size (total virtual pages), Field 1: resident pages
        i: int = 0;
        field: int = 0;
        while i < n {
            b: int = read_byte(buf, i);
            if b == 32 or b == 9 {  # space or tab = field separator
                field = field + 1;
                i = i + 1;
            } elif b >= 48 and b <= 57 {  # digit
                num: int = 0;
                while i < n {
                    b2: int = read_byte(buf, i);
                    if b2 >= 48 and b2 <= 57 {
                        num = num * 10 + (b2 - 48);
                        i = i + 1;
                    } else {
                        break;
                    }
                }
                if field == 0 {
                    heap_total = num * pg;
                } elif field == 1 {
                    rss = num * pg;
                    break;
                }
            } else {
                i = i + 1;
            }
        }
    }
    js_object_set(mem_obj, str_intern("rss"), js_int(rss));
    js_object_set(mem_obj, str_intern("heapTotal"), js_int(heap_total));
    js_object_set(mem_obj, str_intern("heapUsed"), js_int(0));  # Boehm GC exposes no heap-used stat
    js_object_set(mem_obj, str_intern("external"), js_int(0));
    js_object_set(mem_obj, str_intern("arrayBuffers"), js_int(0));
    return mem_obj;
}

"""process.cpuUsage([previousValue]) — returns {user, system} in microseconds.
Uses getrusage(RUSAGE_SELF) to read actual CPU time.
struct rusage layout on Linux x86-64:
  offset 0:  ru_utime.tv_sec  (8 bytes)
  offset 8:  ru_utime.tv_usec (8 bytes)
  offset 16: ru_stime.tv_sec  (8 bytes)
  offset 24: ru_stime.tv_usec (8 bytes)"""
def:pub process_cpu_usage(args: list[JSValue]) -> int {
    cpu_obj: int = js_object_create_null();
    user_us: int = 0;
    sys_us: int = 0;
    ru_buf: Ptr = calloc(1, 152);  # sizeof(struct rusage) = 144; extra safety
    if ru_buf != 0 {
        rc: int = getrusage(0, ru_buf);  # RUSAGE_SELF = 0
        if rc == 0 {
            u_sec: int = read_u64(ru_buf, 0);
            u_usec: int = read_u64(ru_buf, 8);
            s_sec: int = read_u64(ru_buf, 16);
            s_usec: int = read_u64(ru_buf, 24);
            user_us = u_sec * 1000000 + u_usec;
            sys_us = s_sec * 1000000 + s_usec;
        }
        free(ru_buf);
    }
    # Subtract previous value if provided
    if len(args) >= 1 and jsv_is_any_object(args[0]) {
        prev_user: int = 0;
        prev_sys: int = 0;
        pu: JSValue = js_object_get(args[0], str_intern("user"));
        ps: JSValue = js_object_get(args[0], str_intern("system"));
        if jsv_is_int32(pu) {
            prev_user = jsv_to_int32(pu);
        } elif jsv_is_double(pu) {
            prev_user = int(jsv_to_double(pu));
        }
        if jsv_is_int32(ps) {
            prev_sys = jsv_to_int32(ps);
        } elif jsv_is_double(ps) {
            prev_sys = int(jsv_to_double(ps));
        }
        user_us = user_us - prev_user;
        sys_us = sys_us - prev_sys;
    }
    js_object_set(cpu_obj, str_intern("user"), js_int(user_us));
    js_object_set(cpu_obj, str_intern("system"), js_int(sys_us));
    return cpu_obj;
}

"""process.umask([mask]) - get or set file creation mask."""
def:pub process_umask(args: list[JSValue]) -> int {
    if len(args) >= 1 {
        if not jsv_is_undefined(args[0]) {
            new_mask: int = jsv_to_int32(args[0]);
            old_mask: int = umask(new_mask);
            return js_int(old_mask);
        }
    }
    # query: call umask(0) then restore
    old_mask: int = umask(0);
    umask(old_mask);
    return js_int(old_mask);
}

# ── argv ─────────────────────────────────────────────────────────────────────

# ── Phase E: extended POSIX methods ──────────────────────────────────────────

# process.memoryUsage.rss() — returns just the RSS as a Number (bytes)
# SC_PAGE_SIZE = 30 on Linux x86-64
glob _PROC_SC_PAGE_SIZE: int = 30;

def:pub process_memory_usage_rss -> JSValue {
    rss: int = 4 * 1024 * 1024;
    fp: Ptr = fopen("/proc/self/statm", "r");
    if fp != 0 {
        buf: Ptr = io_alloc(64);
        n: int = fread(buf, 1, 63, fp);
        fclose(fp);
        write_byte(buf, n, 0);
        # statm: vmsize resident ... all in pages
        # skip past first field to find resident pages
        i: int = 0;
        while i < n and read_byte(buf, i) != 32 {
            i = i + 1;
        }
        i = i + 1;  # skip space
        res_pages: int = 0;
        while i < n and read_byte(buf, i) >= 48 and read_byte(buf, i) <= 57 {
            res_pages = res_pages * 10 + (read_byte(buf, i) - 48);
            i = i + 1;
        }
        pg: int = sysconf(_PROC_SC_PAGE_SIZE);
        if pg > 0 {
            rss = res_pages * pg;
        } else {
            rss = res_pages * 4096;
        }
    }
    return js_int(rss);
}

# _SC_AVPHYS_PAGES = 85, _SC_PAGE_SIZE = 30 on Linux x86-64
glob _PROC_SC_AVPHYS_PAGES: int = 85;

# process.availableMemory() — free physical pages * page_size (bytes)
# Primary: sysconf(_SC_AVPHYS_PAGES=85) * sysconf(_SC_PAGE_SIZE=30)
# Fallback: parse MemAvailable from /proc/meminfo (kB * 1024)
def:pub process_available_memory -> JSValue {
    avail_pages: int = sysconf(_PROC_SC_AVPHYS_PAGES);
    pg: int = sysconf(_PROC_SC_PAGE_SIZE);
    if avail_pages > 0 and pg > 0 {
        return jsv_from_double(float(avail_pages) * float(pg));
    }
    # fallback: /proc/meminfo MemAvailable line (value in kB)
    fp2: Ptr = fopen("/proc/meminfo", "r");
    if fp2 != 0 {
        mem_buf: Ptr = io_alloc(4096);
        mem_n: int = fread(mem_buf, 1, 4095, fp2);
        fclose(fp2);
        write_byte(mem_buf, mem_n, 0);
        # scan for "MemAvailable:" prefix
        mem_i: int = 0;
        while mem_i < mem_n - 13 {
            # check M(77) at 0, A(65) at +3, v(118) at +4 — rules out MemActive/MemAnon/etc.
            if read_byte(mem_buf, mem_i) == 77
                and read_byte(mem_buf, mem_i + 3) == 65
                and read_byte(mem_buf, mem_i + 4) == 118 {
                # skip "MemAvailable:" and whitespace
                mem_j: int = mem_i + 13;
                while mem_j < mem_n and read_byte(mem_buf, mem_j) == 32 {
                    mem_j = mem_j + 1;
                }
                avail_kb: int = 0;
                while mem_j < mem_n
                    and read_byte(mem_buf, mem_j) >= 48
                    and read_byte(mem_buf, mem_j) <= 57 {
                    avail_kb = avail_kb * 10 + (read_byte(mem_buf, mem_j) - 48);
                    mem_j = mem_j + 1;
                }
                if avail_kb > 0 {
                    return jsv_from_double(float(avail_kb) * 1024.0);
                }
                break;
            }
            mem_i = mem_i + 1;
        }
    }
    return jsv_from_double(0.0);
}

# process.resourceUsage() — full struct rusage mapped to Node.js field names
# struct rusage layout on Linux x86-64 (all fields 8 bytes):
#   0:  ru_utime.tv_sec,  8:  ru_utime.tv_usec
#  16:  ru_stime.tv_sec, 24:  ru_stime.tv_usec
#  32:  ru_maxrss  (KB on Linux)
#  40:  ru_ixrss,  48:  ru_idrss,  56:  ru_isrss
#  64:  ru_minflt, 72:  ru_majflt, 80:  ru_nswap
#  88:  ru_inblock, 96:  ru_oublock
# 104:  ru_msgsnd, 112:  ru_msgrcv
# 120:  ru_nsignals
# 128:  ru_nvcsw,  136:  ru_nivcsw
"""process.getActiveResourcesInfo() — thin timer-backed implementation.
Returns type-name strings ("Timeout", "Immediate", …) for active resources.
Full handle-object tracking (_getActiveHandles) is deferred.
"""
def:pub process_get_active_resources_info -> JSValue {
    types: list[str] = timer_active_resource_types();
    elems: list[JSValue] = [];
    i: int = 0;
    while i < len(types) {
        elems.append(jsv_from_string_id(str_intern(types[i])));
        i = i + 1;
    }
    return js_array_create(elems);
}

def:pub process_resource_usage -> JSValue {
    ru_obj: int = js_object_create_null();
    ru_buf: Ptr = calloc(1, 152);
    if ru_buf != 0 {
        rc: int = getrusage(0, ru_buf);
        if rc == 0 {
            u_sec: int = read_u64(ru_buf, 0);
            u_usec: int = read_u64(ru_buf, 8);
            s_sec: int = read_u64(ru_buf, 16);
            s_usec: int = read_u64(ru_buf, 24);
            js_object_set(
                ru_obj, str_intern("userCPUTime"), js_int(u_sec * 1000000 + u_usec)
            );
            js_object_set(
                ru_obj, str_intern("systemCPUTime"), js_int(s_sec * 1000000 + s_usec)
            );
            js_object_set(ru_obj, str_intern("maxRSS"), js_int(read_u64(ru_buf, 32)));
            js_object_set(
                ru_obj, str_intern("sharedMemorySize"), js_int(read_u64(ru_buf, 40))
            );
            js_object_set(
                ru_obj, str_intern("unsharedDataSize"), js_int(read_u64(ru_buf, 48))
            );
            js_object_set(
                ru_obj, str_intern("unsharedStackSize"), js_int(read_u64(ru_buf, 56))
            );
            js_object_set(
                ru_obj, str_intern("minorPageFault"), js_int(read_u64(ru_buf, 64))
            );
            js_object_set(
                ru_obj, str_intern("majorPageFault"), js_int(read_u64(ru_buf, 72))
            );
            js_object_set(
                ru_obj, str_intern("swappedOut"), js_int(read_u64(ru_buf, 80))
            );
            js_object_set(ru_obj, str_intern("fsRead"), js_int(read_u64(ru_buf, 88)));
            js_object_set(ru_obj, str_intern("fsWrite"), js_int(read_u64(ru_buf, 96)));
            js_object_set(ru_obj, str_intern("ipcSent"), js_int(read_u64(ru_buf, 104)));
            js_object_set(
                ru_obj, str_intern("ipcReceived"), js_int(read_u64(ru_buf, 112))
            );
            js_object_set(
                ru_obj, str_intern("signalsCount"), js_int(read_u64(ru_buf, 120))
            );
            js_object_set(
                ru_obj,
                str_intern("voluntaryContextSwitches"),
                js_int(read_u64(ru_buf, 128))
            );
            js_object_set(
                ru_obj,
                str_intern("involuntaryContextSwitches"),
                js_int(read_u64(ru_buf, 136))
            );
        }
        free(ru_buf);
    }
    return ru_obj;
}

# process.getgroups() — return array of supplementary group IDs
def:pub process_getgroups -> JSValue {
    # call getgroups(0, NULL) to find count
    n: int = getgroups(0, 0);
    if n < 0 {
        return js_array_create([]);
    }
    buf: Ptr = calloc(n + 1, 4);  # gid_t = 4 bytes on Linux
    count: int = getgroups(n, buf);
    elems: list[JSValue] = [];
    if count > 0 {
        gi: int = 0;
        while gi < count {
            # read 4-byte little-endian gid_t from buf[gi*4]
            b0: int = read_byte(buf, gi * 4);
            b1: int = read_byte(buf, gi * 4 + 1);
            b2: int = read_byte(buf, gi * 4 + 2);
            b3: int = read_byte(buf, gi * 4 + 3);
            gid: int = b0 + b1 * 256 + b2 * 65536 + b3 * 16777216;
            elems.append(js_int(gid));
            gi = gi + 1;
        }
    }
    free(buf);
    return js_array_create(elems);
}

# process.setuid/setgid/seteuid/setegid — POSIX identity setters (require root)
def:pub process_setuid(args: list[JSValue]) -> JSValue {
    if len(args) >= 1 {
        uid: int = jsv_to_int32(args[0]);
        rc: int = setuid(uid);
        if rc != 0 {
            err_su: JSValue = make_type_error("Operation not permitted");
            vm_throw_native(err_su);
        }
    }
    return js_undefined();
}

def:pub process_setgid(args: list[JSValue]) -> JSValue {
    if len(args) >= 1 {
        gid: int = jsv_to_int32(args[0]);
        rc: int = setgid(gid);
        if rc != 0 {
            err_sg: JSValue = make_type_error("Operation not permitted");
            vm_throw_native(err_sg);
        }
    }
    return js_undefined();
}

def:pub process_seteuid(args: list[JSValue]) -> JSValue {
    if len(args) >= 1 {
        uid: int = jsv_to_int32(args[0]);
        rc: int = seteuid(uid);
        if rc != 0 {
            err_seu: JSValue = make_type_error("Operation not permitted");
            vm_throw_native(err_seu);
        }
    }
    return js_undefined();
}

def:pub process_setegid(args: list[JSValue]) -> JSValue {
    if len(args) >= 1 {
        gid: int = jsv_to_int32(args[0]);
        rc: int = setegid(gid);
        if rc != 0 {
            err_seg: JSValue = make_type_error("Operation not permitted");
            vm_throw_native(err_seg);
        }
    }
    return js_undefined();
}

# process.loadEnvFile(path) — parse a .env file and merge into process.env
# Format: KEY=VALUE\n  (lines starting with # are comments; blank lines skipped)
def:pub process_load_env_file(args: list[JSValue]) -> JSValue {
    if len(args) < 1 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    path_id: int = jsv_to_table_id(args[0]);
    path_str: str = str_from_id(path_id);
    fp: Ptr = fopen(path_str, "r");
    if fp == 0 {
        return js_undefined();
    }
    BUF: int = 65536;
    buf: Ptr = io_alloc(BUF);
    n: int = fread(buf, 1, BUF - 1, fp);
    fclose(fp);
    write_byte(buf, n, 0);
    pos: int = 0;
    while pos < n {
        # skip blank lines and comment lines
        ch: int = read_byte(buf, pos);
        if ch == 10 or ch == 13 {  # \n or \r
            pos = pos + 1;
            continue;
        }
        if ch == 35 {  # '#'
            while pos < n and read_byte(buf, pos) != 10 {
                pos = pos + 1;
            }
            continue;
        }
        # find '='
        eq: int = pos;
        while eq < n and read_byte(buf, eq) != 61 and read_byte(buf, eq) != 10 {
            eq = eq + 1;
        }
        if eq >= n or read_byte(buf, eq) != 61 {
            # no '=' found on this line — skip
            while pos < n and read_byte(buf, pos) != 10 {
                pos = pos + 1;
            }
            pos = pos + 1;
            continue;
        }
        key_len: int = eq - pos;
        # find end of line
        eol: int = eq + 1;
        while eol < n and read_byte(buf, eol) != 10 {
            eol = eol + 1;
        }
        val_len: int = eol - (eq + 1);
        # strip trailing \r from value
        if val_len > 0 and read_byte(buf, eq + 1 + val_len - 1) == 13 {
            val_len = val_len - 1;
        }
        if key_len > 0 {
            key: str = _proc_buf_to_str(buf + pos, key_len);
            val: str = _proc_buf_to_str(buf + (eq + 1), val_len);
            process_add_env(key, val);
        }
        pos = eol + 1;
    }
    return js_undefined();
}

# ── Bootstrap paths (argv0 / execPath) ───────────────────────────────────────

"""Set process.argv0 and process.execPath from the OS argv[0] before el_run."""
def:pub process_set_bootstrap_paths(argv0: str) -> None {
    if argv0 == "" {
        return;
    }
    _PROC_BOOTSTRAP_ARGV0 = argv0;
    if argv0.find("/") < 0 {
        # Exec'd through PATH (a bare argv0, e.g. when a lifecycle script runs us
        # as `node` via the package manager's shim): the cwd says nothing about
        # where the binary lives, so resolve the real executable — like node's
        # process.execPath — and derive the engine root from that.
        real_exe: str = fsx_readlink("/proc/self/exe");
        if real_exe != "" {
            _PROC_EXEC_PATH = real_exe;
            return;
        }
    }
    # Use GNU extension (buf=0, size=0) — getcwd self-allocates the buffer.
    # The calloc+free pattern corrupts the returned str via FFI pointer aliasing.
    cwd: str = getcwd(0, 0);
    if cwd == "" {
        _PROC_EXEC_PATH = argv0;
    } else {
        _PROC_EXEC_PATH = path_abspath(argv0, cwd);
    }
}

def:pub process_get_argv0 -> str {
    return _PROC_BOOTSTRAP_ARGV0;
}

def:pub process_get_exec_path -> str {
    return _PROC_EXEC_PATH;
}

# ── argv ─────────────────────────────────────────────────────────────────────

"""Build process.argv array: [argv0, script_name, ...extra_args].
Called from el_run after init_global.
For --eval/--print (script_name is \"<eval>\" or \"[eval]\"), Node omits the
script slot so argv is [argv0, ...extra_args]."""
def:pub process_build_argv(script_name: str, extra_args: list[str]) -> JSValue {
    elems: list[JSValue] = [];
    elems.append(jsv_from_string_id(str_intern(_PROC_BOOTSTRAP_ARGV0)));
    is_eval: bool = script_name == "<eval>" or script_name == "[eval]";
    if not is_eval {
        elems.append(jsv_from_string_id(str_intern(script_name)));
    }
    idx: int = 0;
    while idx < len(extra_args) {
        elems.append(jsv_from_string_id(str_intern(extra_args[idx])));
        idx = idx + 1;
    }
    return js_array_create(elems);
}

"""Store Node-compatible process.execArgv (engine flags before the script)."""
def:pub process_set_exec_argv(flags: list[str]) {
    _PROC_EXEC_ARGV = flags;
}

def:pub process_build_exec_argv -> JSValue {
    elems: list[JSValue] = [];
    i: int = 0;
    while i < len(_PROC_EXEC_ARGV) {
        elems.append(jsv_from_string_id(str_intern(_PROC_EXEC_ARGV[i])));
        i = i + 1;
    }
    return js_array_create(elems);
}

def:pub process_set_input_type(t: str) {
    _PROC_INPUT_TYPE = t;
}

def:pub process_get_input_type -> str {
    return _PROC_INPUT_TYPE;
}

def:pub process_set_eval_print(v: bool) {
    _PROC_EVAL_PRINT = v;
}

def:pub process_get_eval_print -> bool {
    return _PROC_EVAL_PRINT;
}

def:pub process_set_no_warnings(v: bool) {
    _PROC_NO_WARNINGS = v;
}

def:pub process_get_no_warnings -> bool {
    return _PROC_NO_WARNINGS;
}

# ── Runtime flags from the command line (main.jac / pm/cli.jac) ──────────────
glob _PROC_TITLE: str = "js_engine",
     _PROC_NO_DEPRECATION: bool = False,
     _PROC_THROW_DEPRECATION: bool = False,
     _PROC_UNHANDLED_REJECTIONS: str = "throw",
     _PROC_REJECTION_ERROR_CODE: bool = False,
     _PROC_PRELOADS: list[str] = [],
     _PROC_EXPOSE_GC: bool = False;

# strict | throw | warn | none | warn-with-error-code
# warn-with-error-code saw a rejection
"""--title: the initial process.title."""
def:pub process_set_title(t: str) {
    _PROC_TITLE = t;
}

def:pub process_get_title -> str {
    return _PROC_TITLE;
}

"""--no-deprecation / --throw-deprecation (process.noDeprecation / process.throwDeprecation)."""
def:pub process_set_no_deprecation(v: bool) {
    _PROC_NO_DEPRECATION = v;
}

def:pub process_get_no_deprecation -> bool {
    return _PROC_NO_DEPRECATION;
}
def:pub process_set_throw_deprecation(v: bool) {
    _PROC_THROW_DEPRECATION = v;
}
def:pub process_get_throw_deprecation -> bool {
    return _PROC_THROW_DEPRECATION;
}

"""--unhandled-rejections=<mode>; "throw" is Node's default."""
def:pub process_set_unhandled_rejections(mode: str) {
    _PROC_UNHANDLED_REJECTIONS = mode;
}

def:pub process_get_unhandled_rejections -> str {
    return _PROC_UNHANDLED_REJECTIONS;
}
def:pub process_unhandled_rejections_mode_valid(mode: str) -> bool {
    return mode == "strict"
        or mode == "throw"
        or mode == "warn"
        or mode == "none"
        or mode == "warn-with-error-code";
}

"""warn-with-error-code: a warned rejection turns a natural exit 0 into 1."""
def:pub process_set_rejection_error_code {
    _PROC_REJECTION_ERROR_CODE = True;
}

def:pub process_get_rejection_error_code -> bool {
    return _PROC_REJECTION_ERROR_CODE;
}

"""-r/--require/--import/--preload: modules loaded before the entry point, in order."""
def:pub process_add_preload(spec: str) {
    _PROC_PRELOADS.append(spec);
}

def:pub process_get_preloads -> list[str] {
    return _PROC_PRELOADS;
}

"""--expose-gc: define a global gc()."""
def:pub process_set_expose_gc(v: bool) {
    _PROC_EXPOSE_GC = v;
}

def:pub process_get_expose_gc -> bool {
    return _PROC_EXPOSE_GC;
}

"""--env-file variables that were not already in the environment (recorded by
env_file.jac). process.env is built from /proc/self/environ — the startup block,
which setenv does not touch — so they are added right after process_populate_env."""
def:pub process_apply_env_file_vars {
    pending: list[str] = env_file_pending_vars();
    k: int = 0;
    while k + 1 < len(pending) {
        process_add_env(pending[k], pending[k + 1]);
        k = k + 2;
    }
}

# Node --preserve-symlinks / --preserve-symlinks-main
glob _PROC_PRESERVE_SYMLINKS: bool = False,
     _PROC_PRESERVE_SYMLINKS_MAIN: bool = False,
     _PROC_REQUIRE_ESM: bool = True;

# Node require(esm): enabled by default (Node 22+); disabled by
# --no-experimental-require-module.
def:pub process_set_preserve_symlinks(v: bool) {
    _PROC_PRESERVE_SYMLINKS = v;
}

def:pub process_get_preserve_symlinks -> bool {
    if _PROC_PRESERVE_SYMLINKS {
        return True;
    }
    i2: int = 0;
    while i2 < len(_PROC_EXEC_ARGV) {
        if _PROC_EXEC_ARGV[i2] == "--preserve-symlinks" {
            return True;
        }
        i2 = i2 + 1;
    }
    return False;
}

def:pub process_set_preserve_symlinks_main(v: bool) {
    _PROC_PRESERVE_SYMLINKS_MAIN = v;
}

def:pub process_get_preserve_symlinks_main -> bool {
    return _PROC_PRESERVE_SYMLINKS_MAIN;
}

def:pub process_set_require_esm(v: bool) {
    _PROC_REQUIRE_ESM = v;
}

def:pub process_get_require_esm -> bool {
    # Prefer execArgv scan — more reliable across early CLI / late VM reads.
    i: int = 0;
    while i < len(_PROC_EXEC_ARGV) {
        a: str = _PROC_EXEC_ARGV[i];
        if a == "--no-experimental-require-module" or a == "--no-require-module" {
            return False;
        }
        i = i + 1;
    }
    return _PROC_REQUIRE_ESM;
}
