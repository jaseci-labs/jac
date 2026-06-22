glob g_cmdline_buf: int = 0,
     g_argv_arr: int = 0;

def cef_stub_add_ref(self: int) { }
def cef_stub_release(self: int) -> int {
    return 0;
}

def cef_stub_has_one_ref(self: int) -> int {
    return 1;
}

def cef_stub_has_at_least_one_ref(self: int) -> int {
    return 1;
}

def cef_main_args_create -> int {
    global g_cmdline_buf,g_argv_arr;
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
            while pos < n && done == 0 {
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
