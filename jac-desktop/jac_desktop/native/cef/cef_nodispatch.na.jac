"""Minimal Jac nacompile test: call cef_initialize directly without libcef_dispatch.so.
If this works, the Jac runtime is fine and the issue is in the dispatch library.
If this fails, the Jac runtime itself is interfering with CEF.
"""

import from "libcef.so" {
    def cef_execute_process(args: int, app: int, sandbox: int) -> i32;  def cef_initialize(
        args: int, settings: int, app: int, sandbox: int
    ) -> i32;  def cef_string_utf8_to_utf16(
        src: str, src_len: int, output: int
    ) -> i32;  obj cef_app_t {
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
    }  obj cef_settings_t {
        has size: int = 0,
            no_sandbox: i32 = 0,
            _p0: i32 = 0,
            browser_subprocess_path_str: int = 0,
            browser_subprocess_path_len: int = 0,
            browser_subprocess_path_dtor: int = 0,
            framework_dir_path_str: int = 0,
            framework_dir_path_len: int = 0,
            framework_dir_path_dtor: int = 0,
            main_bundle_path_str: int = 0,
            main_bundle_path_len: int = 0,
            main_bundle_path_dtor: int = 0,
            chrome_runtime: i32 = 0,
            multi_threaded: i32 = 0,
            ext_msg_pump: i32 = 0,
            windowless: i32 = 0,
            cmdline_disabled: i32 = 0,
            _p1: i32 = 0,
            cache_path_str: int = 0,
            cache_path_len: int = 0,
            cache_path_dtor: int = 0,
            root_cache_path_str: int = 0,
            root_cache_path_len: int = 0,
            root_cache_path_dtor: int = 0,
            persist_sess: i32 = 0,
            persist_user: i32 = 0,
            user_agent_str: int = 0,
            user_agent_len: int = 0,
            user_agent_dtor: int = 0,
            user_agent_product_str: int = 0,
            user_agent_product_len: int = 0,
            user_agent_product_dtor: int = 0,
            locale_str: int = 0,
            locale_len: int = 0,
            locale_dtor: int = 0,
            log_file_str: int = 0,
            log_file_len: int = 0,
            log_file_dtor: int = 0,
            log_severity: i32 = 0,
            log_items: i32 = 0,
            javascript_flags_str: int = 0,
            javascript_flags_len: int = 0,
            javascript_flags_dtor: int = 0,
            resources_dir_path_str: int = 0,
            resources_dir_path_len: int = 0,
            resources_dir_path_dtor: int = 0,
            locales_dir_path_str: int = 0,
            locales_dir_path_len: int = 0,
            locales_dir_path_dtor: int = 0,
            pack_disabled: i32 = 0,
            remote_dbg: i32 = 0,
            uncaught_exc: i32 = 0,
            bg_color: i32 = 0,
            accept_language_list_str: int = 0,
            accept_language_list_len: int = 0,
            accept_language_list_dtor: int = 0,
            cookieable_schemes_list_str: int = 0,
            cookieable_schemes_list_len: int = 0,
            cookieable_schemes_list_dtor: int = 0,
            cs_excl: i32 = 0,
            _p2: i32 = 0,
            chrome_policy_id_str: int = 0,
            chrome_policy_id_len: int = 0,
            chrome_policy_id_dtor: int = 0;
    }  obj cef_main_args_t {
        has argc: i32 = 0,
            _pad: i32 = 0,
            argv: int = 0;
    }  obj cef_ptr_wrap_t {
        has p0: int = 0,
            p1: int = 0;
    }  obj cef_string_t {
        has ptr: int = 0,
            len: int = 0,
            dtor: int = 0;
    }
}

import from "libc.so.6" {
    def write(fd: i32, buf: str, count: int) -> int;  def sleep(seconds: i32) -> i32;  def getpid -> i32;  def open(
        path: str, flags: i32
    ) -> i32;  def read(fd: i32, buf: int, count: int) -> int;  def close(
        fd: i32
    ) -> i32;  def readlink(path: str, buf: int, bufsiz: int) -> int;  def calloc(
        n: int, size: int
    ) -> int;  def free(ptr: int) -> None;  def memset(s: int, c: i32, n: int) -> int;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def strlen(s: str) -> int;  def strrchr(s: int, c: i32) -> int;  def strcpy(
        dst: int, src: str
    ) -> int;  def strcat(dst: int, src: str) -> int;  def setenv(
        name: str, value: str, overwrite: i32
    ) -> i32;  def signal(signum: i32, handler: int) -> int;
}

import from "libdl.so.2" {
    def dlopen(path: str, flags: i32) -> int;  def dlsym(
        handle: int, symbol: str
    ) -> int;
}

import from "libjac_diag.so" {
    def dump_settings_ptr(s: int) -> None;  def dump_app_ptr(s: int) -> None;  def dump_args_ptr(
        s: int
    ) -> None;
}

import sys;

glob g_app: cef_app_t = cef_app_t(),
     g_args: cef_main_args_t = cef_main_args_t(),
     g_settings: cef_settings_t = cef_settings_t(),
     g_cmdline_buf: int = 0,
     g_argv_arr: int = 0,
     g_exe_dir_buf: int = 0;

def _log(msg: str) {
    prefix: str = "[nd] ";
    nl: str = "\n";
    write(2, prefix, strlen(prefix));
    write(2, msg, strlen(msg));
    write(2, nl, 1);
}

def _add_ref(self: int) { }
def _release(self: int) -> int {
    return 0;
}

def _has_one_ref(self: int) -> int {
    return 1;
}

def _on_cmdline(self: int, process_type: int, cmdline: int) {
    _log("cmdline cb called");
}

def _build_args {
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
    memset(buf + n, 0, 2);
    g_cmdline_buf = buf;
    argc: int = 0;
    pos: int = 0;
    done: int = 0;
    while pos < n && done == 0 {
        al: int = strlen(buf + pos);
        if al == 0 {
            done = 1;
        } else {
            pos = pos + al + 1;
            argc = argc + 1;
        }
    }
    if argc == 0 {
        return;
    }
    argv_arr: int = calloc(argc + 1, 8);
    g_argv_arr = argv_arr;
    memset(argv_arr + argc * 8, 0, 8);
    pos = 0;
    i: int = 0;
    pw: cef_ptr_wrap_t = cef_ptr_wrap_t();
    while i < argc {
        pw.p0 = buf + pos;
        memcpy(argv_arr + i * 8, pw, 8);
        al: int = strlen(buf + pos);
        pos = pos + al + 1;
        i = i + 1;
    }
    g_args.argc = argc;
    g_args.argv = argv_arr;
}

def _init_exe_dir {
    global g_exe_dir_buf;
    if g_exe_dir_buf != 0 {
        return;
    }
    buf: int = calloc(1, 4096);
    n: int = readlink("/proc/self/exe", buf, 4095);
    if n <= 0 {
        g_exe_dir_buf = buf;
        return;
    }
    memset(buf + n, 0, 1);
    slash: int = strrchr(buf, 47);
    if slash != 0 {
        memset(slash, 0, 1);
    }
    g_exe_dir_buf = buf;
}

with entry {
    _init_exe_dir();
    setenv("NO_AT_BRIDGE", "1", 1);
    signal(17, 0);  # SIGCHLD = SIG_DFL

    _build_args();
    _log("args built");
}

glob g_app = cef_app_t(
         size=80,
         add_ref=_add_ref,
         release=_release,
         has_one_ref=_has_one_ref,
         has_at_least_one_ref=_has_one_ref,
         on_before_command_line_processing=_on_cmdline,
     ),
     code: i32 = cef_execute_process(g_args, g_app, 0);

with entry {
    _log("execute_process done");
    if code >= 0 {
        sys.exit(code);
    }

    # Build minimal settings
    g_settings.size = 440;
    g_settings.no_sandbox = 1;
    g_settings.log_severity = 3;  # LOGSEVERITY_WARNING
}

# Set browser_subprocess_path
glob sub_path_buf: int = calloc(1, 4096);

with entry {
    if g_exe_dir_buf != 0 {
        strcpy(sub_path_buf, g_exe_dir_buf);
        strcat(sub_path_buf, "/cef-subprocess");
    }
}

glob s1: cef_string_t = cef_string_t();

with entry {
    cef_string_utf8_to_utf16(sub_path_buf, strlen(sub_path_buf), s1);
    g_settings.browser_subprocess_path_str = s1.ptr;
    g_settings.browser_subprocess_path_len = s1.len;
    g_settings.browser_subprocess_path_dtor = s1.dtor;
}

# Set resources_dir_path
glob s2: cef_string_t = cef_string_t();

with entry {
    cef_string_utf8_to_utf16(g_exe_dir_buf, strlen(g_exe_dir_buf), s2);
    g_settings.resources_dir_path_str = s2.ptr;
    g_settings.resources_dir_path_len = s2.len;
    g_settings.resources_dir_path_dtor = s2.dtor;
}

# Set locales_dir_path
glob loc_buf: int = calloc(1, 4096);

with entry {
    if g_exe_dir_buf != 0 {
        strcpy(loc_buf, g_exe_dir_buf);
        strcat(loc_buf, "/locales");
    }
}

glob s3: cef_string_t = cef_string_t();

with entry {
    cef_string_utf8_to_utf16(loc_buf, strlen(loc_buf), s3);
    g_settings.locales_dir_path_str = s3.ptr;
    g_settings.locales_dir_path_len = s3.len;
    g_settings.locales_dir_path_dtor = s3.dtor;

    dump_args_ptr(g_args);
    dump_settings_ptr(g_settings);
    dump_app_ptr(g_app);
    _log("calling cef_initialize");
}

glob rc: i32 = cef_initialize(g_args, g_settings, g_app, 0);

with entry {
    _log("cef_initialize returned");
    if rc == 1 {
        _log("cef_initialize ok!");
    } else {
        _log("cef_initialize failed");
    }
    free(sub_path_buf);
    free(loc_buf);
}
