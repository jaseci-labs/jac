import from "libcef.so" {
    def cef_version_info(which: i32) -> i32;  obj cef_ptr_wrap_t {
        has p0: int = 0,
            p1: int = 0;
    }
}

import from "libc.so.6" {
    def calloc(n: int, size: int) -> int;  def free(ptr: int) -> None;  def memset(
        s: int, c: i32, n: int
    ) -> int;  def memcpy(dst: int, src: int, n: int) -> int;  def open(
        path: str, flags: i32
    ) -> i32;  def read(fd: i32, buf: int, count: int) -> int;  def close(
        fd: i32
    ) -> i32;  def strlen(s: str) -> int;  def write(
        fd: i32, buf: int, count: int
    ) -> int;  def abort -> None;
}

impl _eprint(msg: str) {
    write(2, msg, strlen(msg));
}

impl _write_uint(n: int) {
    if n < 0 {
        return;
    }
    if n >= 10 {
        _write_uint(n // 10);
    }
    digit_buf: int = calloc(1, 2);
    memset(digit_buf, i32(48 + (n % 10)), 1);
    write(2, digit_buf, 1);
    free(digit_buf);
}

impl _assert_cef_abi {
    if g_abi_checked != 0 {
        return;
    }
    g_abi_checked = 1;
    maj: int = cef_version_info(0);
    minr: int = cef_version_info(1);
    pat: int = cef_version_info(2);
    if maj == CEF_ABI_MAJOR and minr == CEF_ABI_MINOR and pat == CEF_ABI_PATCH {
        return;
    }
    _eprint("[cef] FATAL: loaded libcef.so does not match the verified CEF ABI.\n");
    _eprint(
        "[cef]   struct/vtable offsets are pinned to CEF 119.4.7 (see cef_sums.lock).\n"
    );
    _eprint("[cef]   loaded libcef reports CEF ");
    _write_uint(maj);
    _eprint(".");
    _write_uint(minr);
    _eprint(".");
    _write_uint(pat);
    _eprint("\n");
    _eprint("[cef]   re-stage the pinned CEF runtime with a fresh cef build.\n");
    abort();
}

impl cef_stub_add_ref(self: int) {}

impl cef_stub_release(self: int) -> int {
    return 0;
}

impl cef_stub_has_one_ref(self: int) -> int {
    return 1;
}

impl cef_stub_has_at_least_one_ref(self: int) -> int {
    return 1;
}

impl cef_main_args_create -> int {
    pw: cef_ptr_wrap_t = cef_ptr_wrap_t();
    argv_wrap: cef_ptr_wrap_t = cef_ptr_wrap_t();
    fd: i32 = open("/proc/self/cmdline", 0);
    if fd >= 0 {
        buf: int = calloc(1, 65536);
        n: int = read(fd, buf, 65535);
        close(fd);
        if n > 0 {
            memset(buf + n, 0, 2);
            g_cmdline_buf = buf;
            argc: int = 0;
            pos: int = 0;
            done: int = 0;
            while pos < n and done == 0 {
                arg_len: int = strlen(buf + pos);
                if arg_len == 0 {
                    done = 1;
                } else {
                    pos = pos + arg_len + 1;
                    argc = argc + 1;
                }
            }
            if argc > 0 {
                argv_arr: int = calloc(argc + 1, 8);
                g_argv_arr = argv_arr;
                memset(argv_arr + argc * 8, 0, 8);
                pos = 0;
                i: int = 0;
                while i < argc {
                    pw.p0 = buf + pos;
                    memcpy(argv_arr + i * 8, pw, 8);
                    ailen: int = strlen(buf + pos);
                    pos = pos + ailen + 1;
                    i = i + 1;
                }
                result: int = calloc(1, 16);
                pw.p0 = argc;
                memcpy(result, pw, 4);
                argv_wrap.p0 = argv_arr;
                memcpy(result + 8, argv_wrap, 8);
                return result;
            }
        } else {
            free(buf);
        }
    }
    return 0;
}
