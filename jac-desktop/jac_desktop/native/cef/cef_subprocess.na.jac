"""Jac-native replacement for cef_subprocess.c.

Compile to cef-subprocess binary:
  jac nacompile cef_subprocess.na.jac -o cef-subprocess

Minimal CEF subprocess entry point - handles renderer/GPU child processes
spawned by the main host binary.
"""

import sys;

import from "libcef.so" {
    def cef_execute_process(args: int, app: int, sandbox: int) -> i32;
}

import from "libc.so.6" {
    def readlink(path: str, buf: int, bufsiz: int) -> int;  def strrchr(
        s: int, c: i32
    ) -> int;  def strcpy(dst: int, src: str) -> int;  def strcat(
        dst: int, src: str
    ) -> int;  def strlen(s: str) -> int;  def access(path: str, mode: i32) -> i32;  def setenv(
        name: str, value: str, overwrite: i32
    ) -> i32;  def calloc(n: int, size: int) -> int;  def free(ptr: int) -> None;  def memset(
        s: int, c: i32, n: int
    ) -> int;  def memcpy(dst: int, src: int, n: int) -> int;  def open(
        path: str, flags: i32
    ) -> i32;  def read(fd: i32, buf: int, count: int) -> int;  def close(
        fd: i32
    ) -> i32;
}

import from "libcef.so" {
    """cef_app_t - 80 bytes (base 40 + 5 function pointer slots)"""
    obj cef_app_t {
        has size: int = 0,
            add_ref: int = 0,
            release: int = 0,
            has_one_ref: int = 0,
            has_at_least_one_ref: int = 0,
            on_before_command_line_processing: int = 0,
            on_register_custom_schemes: int = 0,
            get_resource_bundle_handler: int = 0,
            get_browser_process_handler: int = 0,
            get_render_process_handler: int = 0;
    }  """cef_main_args_t - 16 bytes: argc(i32 at 0), pad(i32 at 4), argv(int at 8)"""
    obj cef_main_args_t {
        has argc: i32 = 0,
            _pad: i32 = 0,
            argv: int = 0;
    }  """Two-field helper obj for storing/copying a pointer value via memcpy."""
    obj cef_ptr_wrap_t {
        has p0: int = 0,
            p1: int = 0;
    }
}

def _sp_add_ref(self: int) { }
def _sp_release(self: int) -> int {
    return 0;
}

def _sp_has_one_ref(self: int) -> int {
    return 1;
}

def _sp_has_at_least_one_ref(self: int) -> int {
    return 1;
}

glob g_app: cef_app_t = cef_app_t(
         size=80,
         add_ref=_sp_add_ref,
         release=_sp_release,
         has_one_ref=_sp_has_one_ref,
         has_at_least_one_ref=_sp_has_at_least_one_ref,
     ),
     g_args: cef_main_args_t = cef_main_args_t,
     g_cmdline_buf: int = 0,
     g_argv_arr: int = 0;

def _subprocess_bootstrap {
    buf: int = calloc(1, 4096);
    n: int = readlink("/proc/self/exe", buf, 4095);
    if n <= 0 {
        free(buf);
        return;
    }
    memset(buf + n, 0, 1);
    slash: int = strrchr(buf, 47);  # 47 = '/'
    if slash == 0 {
        free(buf);
        return;
    }
    memset(slash, 0, 1);
    fc_buf: int = calloc(1, 4096);
    strcpy(fc_buf, buf);
    strcat(fc_buf, "/minimal-fonts.conf");
    if access(fc_buf, 4) == 0 {
        setenv("FONTCONFIG_FILE", fc_buf, 0);  # no-op if already set (overwrite=0)
    }
    free(fc_buf);
    free(buf);
}

"""Read /proc/self/cmdline and build a proper cef_main_args_t in g_args.

/proc/self/cmdline contains null-separated argument strings.
"""
def _build_main_args {
    global g_cmdline_buf,g_argv_arr,g_args;
    fd: i32 = open("/proc/self/cmdline", 0);
    if fd < 0 {
        return;
    }
    buf: int = calloc(1, 65536);
    n: int = read(fd, buf, 65535);
    close(fd);
    if n <= 0 {
        free(buf);
        return;
    }
    memset(buf + n, 0, 2);  # double-null sentinel at end
    g_cmdline_buf = buf;
    # Count argc: each non-empty null-separated token is one arg
    argc: int = 0;
    pos: int = 0;
    done: int = 0;
    while pos < n && done == 0 {
        arg_len: int = strlen(buf + pos);
        if arg_len == 0 {
            done = 1;
        } else {
            pos = pos + arg_len + 1;
            argc = argc + 1;
        }
    }
    if argc == 0 {
        return;
    }
    # Build argv[] - array of (argc+1) pointers, NULL-terminated
    argv_arr: int = calloc(argc + 1, 8);
    g_argv_arr = argv_arr;
    memset(argv_arr + argc * 8, 0, 8);  # NULL terminator
    pos = 0;
    i: int = 0;
    pw: cef_ptr_wrap_t = cef_ptr_wrap_t;
    while i < argc {
        # Store pointer value (buf+pos) into argv_arr[i] via a Jac obj
        pw.p0 = buf + pos;
        memcpy(argv_arr + i * 8, pw, 8);
        arg_len: int = strlen(buf + pos);
        pos = pos + arg_len + 1;
        i = i + 1;
    }
    g_args.argc = argc;
    g_args.argv = argv_arr;
}

def _finish_subprocess {
    code: i32 = cef_execute_process(g_args, g_app, 0);
    if code >= 0 {
        sys.exit(code);
    }
}

with entry {
    _subprocess_bootstrap();
    _build_main_args();
    _finish_subprocess();
}
