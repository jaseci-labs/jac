impl _log(msg: str) {
    prefix: str = "[cef] ";
    newline: str = "\n";
    write(2, prefix, strlen(prefix));
    write(2, msg, strlen(msg));
    write(2, newline, 1);
}

impl cef_dispatch_get_exe_dir -> str {
    _init_exe_dir();

    exe_dir: any = g_exe_dir_buf;
    return exe_dir;
}

impl _init_exe_dir {
    if g_exe_dir_buf != 0 {
        return;
    }
    buf: int = calloc(1, 4096);
    n: int = readlink("/proc/self/exe", buf, 4095);
    if n <= 0 {
        g_exe_dir_buf = buf;
        g_exe_path_buf = buf;
        return;
    }
    memset(buf + n, 0, 1);
    g_exe_path_buf = calloc(1, 4096);
    memcpy(g_exe_path_buf, buf, n + 1);
    slash: int = strrchr(buf, 47);
    if slash != 0 {
        memset(slash, 0, 1);
    }
    g_exe_dir_buf = buf;
}

impl cef_platform_bootstrap {
    _init_exe_dir();

    setenv("NO_AT_BRIDGE", "1", 0);

    fc_val: int = getenv("FONTCONFIG_FILE");
    if fc_val == 0 and g_exe_dir_buf != 0 {
        fc_buf: int = calloc(1, 4096);
        strcpy(fc_buf, g_exe_dir_buf);
        strcat(fc_buf, "/minimal-fonts.conf");
        if access(fc_buf, 4) == 0 {
            setenv("FONTCONFIG_FILE", fc_buf, 0);
            _log("bootstrap: set FONTCONFIG_FILE");
        }
        free(fc_buf);
    }
}

impl cef_dispatch_getenv_set(name: str) -> i32 {
    v: int = getenv(name);
    if v == 0 {
        return 0;
    }
    return 1;
}

impl cef_dispatch_log(msg: str) {
    _log(msg);
}

impl _on_before_close(self: int, browser: int) {
    _log("browser before-close");
    cef_quit_message_loop();
}

impl _on_after_created(self: int, browser: int) {
    g_browser = browser;
    b: cef_browser_t = browser;
    host: int = b.get_host(b);
    if host == 0 {
        _log("after-created: no browser host");
        return;
    }
    h: cef_browser_host_t = host;
    g_browser_xid = h.get_window_handle(h);
    _log("after-created: captured X11 window handle");
}

impl _get_life_span_handler(self: int) -> int {
    return g_lsh;
}

impl _get_browser_process_handler(self: int) -> int {
    return g_bph;
}

impl _get_render_process_handler(self: int) -> int {
    return g_rph;
}

impl _on_context_initialized(self: int) {
    _log("context initialized");
    if g_browser_pending == 0 {
        return;
    }
    wi: int = cef_dispatch_window_info_create(
        g_pending_title, g_pending_w, g_pending_h
    );
    bs: int = cef_dispatch_browser_settings_create();
    ok: i32 = cef_dispatch_create_browser(wi, g_cli, g_pending_url, bs);
    _log("context initialized: browser created");
    g_browser_pending = 0;
}

impl _on_context_created(self: int, browser: int, frame: int, context: int) {
    if cef_dispatch_frame_is_main(frame) == 0 {
        return;
    }
    cef_dispatch_frame_execute_js(frame, BOOTSTRAP_JS, "jac://bootstrap", 0);
    _log("render: bootstrap injected");
}

impl _on_before_cmdline(self: int, process_type: int, command_line: int) {
    _log("cmdline: no platform flag (auto-detect)");
    if cef_dispatch_getenv_set("JAC_CEF_SINGLE_PROCESS") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "single-process");
    }
    if cef_dispatch_getenv_set("JAC_CEF_HEADLESS") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "headless");
        cef_dispatch_cmdline_append_switch(command_line, "disable-gpu");
    }

    if cef_dispatch_getenv_set("JAC_CEF_DISABLE_GPU") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "disable-gpu");
        cef_dispatch_cmdline_append_switch(command_line, "disable-gpu-compositing");
    }
    if cef_dispatch_getenv_set("JAC_CEF_IN_PROCESS_GPU") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "in-process-gpu");
    }

    if cef_dispatch_getenv_set("JAC_CEF_VERBOSE") != 0 {
        cef_dispatch_cmdline_append_switch_value(
            command_line, "enable-logging", "stderr"
        );
        cef_dispatch_cmdline_append_switch_value(command_line, "v", "1");
    }

    ud_val: int = getenv("JAC_CEF_USER_DATA_DIR");
    if ud_val != 0 and strlen(ud_val) > 0 {
        ud_str: any = ud_val;
        cef_dispatch_cmdline_append_switch_value(command_line, "user-data-dir", ud_str);
    }
    _log("cmdline: done");
}

impl _init_vtables {
    if g_vtables_ready != 0 {
        return;
    }
    g_lsh = cef_life_span_handler_t(
        size=80,
        add_ref=cef_stub_add_ref,
        release=cef_stub_release,
        has_one_ref=cef_stub_has_one_ref,
        has_at_least_one_ref=cef_stub_has_at_least_one_ref,
        on_after_created=_on_after_created,
        on_before_close=_on_before_close,
    );
    g_bph = cef_browser_process_handler_t(
        size=80,
        add_ref=cef_stub_add_ref,
        release=cef_stub_release,
        has_one_ref=cef_stub_has_one_ref,
        has_at_least_one_ref=cef_stub_has_at_least_one_ref,
        on_context_initialized=_on_context_initialized,
    );
    g_rph = cef_render_process_handler_t(
        size=112,
        add_ref=cef_stub_add_ref,
        release=cef_stub_release,
        has_one_ref=cef_stub_has_one_ref,
        has_at_least_one_ref=cef_stub_has_at_least_one_ref,
        on_context_created=_on_context_created,
    );
    g_cli = cef_client_t(
        size=192,
        add_ref=cef_stub_add_ref,
        release=cef_stub_release,
        has_one_ref=cef_stub_has_one_ref,
        has_at_least_one_ref=cef_stub_has_at_least_one_ref,
        get_life_span_handler=_get_life_span_handler,
    );
    g_dispatch_app = cef_app_t(
        size=80,
        add_ref=cef_stub_add_ref,
        release=cef_stub_release,
        has_one_ref=cef_stub_has_one_ref,
        has_at_least_one_ref=cef_stub_has_at_least_one_ref,
        on_before_command_line_processing=_on_before_cmdline,
        get_browser_process_handler=_get_browser_process_handler,
        get_render_process_handler=_get_render_process_handler,
    );
    g_stub_app = cef_app_t(
        size=80,
        add_ref=cef_stub_add_ref,
        release=cef_stub_release,
        has_one_ref=cef_stub_has_one_ref,
        has_at_least_one_ref=cef_stub_has_at_least_one_ref,
    );
    g_vtables_ready = 1;
}

impl cef_dispatch_main_args_create -> int {
    args: int = cef_main_args_create();
    if args != 0 {
        _log("args: using cmdline");
        return args;
    }
    _init_exe_dir();
    if g_exe_path_buf != 0 {
        _log("args: using exe_path fallback");
    } else {
        _log("args: exe_path MISSING");
    }
    argv_one: cef_ptr_wrap_t = cef_ptr_wrap_t();
    argv_one.p0 = g_exe_path_buf;
    argv_one.p1 = 0;
    buf2: int = calloc(1, 16);
    memset(buf2, 1, 1);
    memcpy(buf2 + 8, argv_one, 8);
    return buf2;
}

impl cef_dispatch_settings_create(no_sandbox: i32, cache_path: str) -> int {
    _init_exe_dir();
    g_settings.size = 440;
    g_settings.no_sandbox = no_sandbox;
    g_settings.multi_threaded = 0;
    g_settings.log_severity = 3;

    if strlen(cache_path) > 0 {
        s: cef_string_t = cef_string_t();
        cef_string_utf8_to_utf16(cache_path, strlen(cache_path), s);
        g_settings.cp_ptr = s.ptr;
        g_settings.cp_len = s.len;
        g_settings.cp_dtor = s.dtor;
    }

    if g_exe_dir_buf != 0 {
        rlen: int = strlen(g_exe_dir_buf);
        if rlen > 0 {
            s2: cef_string_t = cef_string_t();
            cef_string_utf8_to_utf16(g_exe_dir_buf, rlen, s2);
            g_settings.rdp_ptr = s2.ptr;
            g_settings.rdp_len = s2.len;
            g_settings.rdp_dtor = s2.dtor;
            sub_buf: int = calloc(1, 4096);
            strcpy(sub_buf, g_exe_dir_buf);
            strcat(sub_buf, "/cef-subprocess");
            if access(sub_buf, 1) == 0 {
                s3: cef_string_t = cef_string_t();
                cef_string_utf8_to_utf16(sub_buf, strlen(sub_buf), s3);
                g_settings.bsp_ptr = s3.ptr;
                g_settings.bsp_len = s3.len;
                g_settings.bsp_dtor = s3.dtor;
                _log("settings: browser_subprocess_path set");
            }
            free(sub_buf);
            locales_buf: int = calloc(1, 4096);
            strcpy(locales_buf, g_exe_dir_buf);
            strcat(locales_buf, "/locales");
            s4: cef_string_t = cef_string_t();
            cef_string_utf8_to_utf16(locales_buf, strlen(locales_buf), s4);
            g_settings.ldp_ptr = s4.ptr;
            g_settings.ldp_len = s4.len;
            g_settings.ldp_dtor = s4.dtor;
            free(locales_buf);
        }
    }
    return g_settings;
}

impl cef_dispatch_window_info_create(title: str, width: int, height: int) -> int {
    g_wi.wn_ptr = 0;
    g_wi.wn_len = 0;
    g_wi.wn_dtor = 0;
    if strlen(title) > 0 {
        s: cef_string_t = cef_string_t();
        cef_string_utf8_to_utf16(title, strlen(title), s);
        g_wi.wn_ptr = s.ptr;
        g_wi.wn_len = s.len;
        g_wi.wn_dtor = s.dtor;
    }
    g_wi.bounds_x = 100;
    g_wi.bounds_y = 100;
    if width > 0 {
        g_wi.bounds_w = i32(width);
    } else {
        g_wi.bounds_w = 800;
    }
    if height > 0 {
        g_wi.bounds_h = i32(height);
    } else {
        g_wi.bounds_h = 600;
    }
    return g_wi;
}

impl cef_dispatch_browser_settings_create -> int {
    buf: int = calloc(1, 264);

    memset(buf, 8, 1);
    memset(buf + 1, 1, 1);

    memset(buf + 204, 1, 1);

    memset(buf + 236, 1, 1);
    return buf;
}

impl cef_dispatch_set_pending_browser(url: str, title: str, width: int, height: int) {
    g_pending_url = url;
    g_pending_title = title;
    if width > 0 {
        g_pending_w = width;
    } else {
        g_pending_w = 800;
    }
    if height > 0 {
        g_pending_h = height;
    } else {
        g_pending_h = 600;
    }
    g_browser_pending = 1;
}

impl cef_dispatch_open_browser(url: str, title: str, width: int, height: int) {
    cef_dispatch_set_pending_browser(url, title, width, height);
    _init_vtables();
    wi: int = cef_dispatch_window_info_create(title, width, height);
    bs: int = cef_dispatch_browser_settings_create();
    ok: i32 = cef_dispatch_create_browser(wi, g_cli, url, bs);
    _log("open_browser: done");
    free(bs);
    g_browser_pending = 0;
}

impl cef_dispatch_execute_process -> i32 {
    _assert_cef_abi();
    cef_platform_bootstrap();
    _init_vtables();
    _log("execute_process");
    g_cached_args = cef_dispatch_main_args_create();
    code: i32 = cef_execute_process(g_cached_args, g_stub_app, 0);
    if code >= 0 {
        _log("execute_process: subprocess exit");
        free(g_cached_args);
        g_cached_args = 0;
        return code;
    }
    _log("execute_process: main process");

    return code;
}

impl cef_dispatch_startup(cache_path: str, no_sandbox: int) -> i32 {
    _assert_cef_abi();
    cef_platform_bootstrap();
    _init_vtables();
    _log("startup: initializing CEF");
    settings: int = cef_dispatch_settings_create(i32(no_sandbox), cache_path);

    if g_cached_args == 0 {
        g_cached_args = cef_dispatch_main_args_create();
    }

    old_sigchld: int = signal(17, 0);
    _log("startup: calling cef_initialize");
    rc: i32 = cef_initialize(g_cached_args, settings, g_dispatch_app, 0);
    _log("startup: cef_initialize returned");
    free(g_cached_args);
    g_cached_args = 0;
    _log("startup: free args");
    if rc == 1 {
        _log("startup: cef_initialize ok");
    } else {
        _log("startup: cef_initialize failed");
    }
    return rc;
}

impl cef_dispatch_browser_get_main_frame(browser: int) -> int {
    b: cef_browser_t = browser;
    return b.get_main_frame(b);
}

impl cef_dispatch_frame_is_main(frame: int) -> i32 {
    f: cef_frame_t = frame;
    return f.is_main(f);
}

impl cef_dispatch_frame_load_url(frame: int, url: str) {
    f: cef_frame_t = frame;
    s: cef_string_t = cef_string_t();
    cef_string_utf8_to_utf16(url, strlen(url), s);
    f.load_url(f, s);
    cef_string_utf16_clear(s);
}

impl cef_dispatch_frame_execute_js(
    frame: int, code: str, script_url: str, start_line: i32
) {
    f: cef_frame_t = frame;
    js: cef_string_t = cef_string_t();
    su: cef_string_t = cef_string_t();
    cef_string_utf8_to_utf16(code, strlen(code), js);
    cef_string_utf8_to_utf16(script_url, strlen(script_url), su);
    f.execute_java_script(f, js, su, start_line);
    cef_string_utf16_clear(js);
    cef_string_utf16_clear(su);
}

impl cef_dispatch_cmdline_append_switch(cmd: int, sw: str) {
    c: cef_command_line_t = cmd;
    s: cef_string_t = cef_string_t();
    cef_string_utf8_to_utf16(sw, strlen(sw), s);
    c.append_switch(c, s);
    cef_string_utf16_clear(s);
}

impl cef_dispatch_cmdline_append_switch_value(cmd: int, name: str, value: str) {
    c: cef_command_line_t = cmd;
    sn: cef_string_t = cef_string_t();
    sv: cef_string_t = cef_string_t();
    cef_string_utf8_to_utf16(name, strlen(name), sn);
    cef_string_utf8_to_utf16(value, strlen(value), sv);
    c.append_switch_with_value(c, sn, sv);
    cef_string_utf16_clear(sn);
    cef_string_utf16_clear(sv);
}

impl cef_dispatch_base_release(handle: int) {}

impl cef_dispatch_create_browser(
    window_info: int, client: int, url: str, settings: int
) -> i32 {
    url_str: cef_string_t = cef_string_t();
    cef_string_utf8_to_utf16(url, strlen(url), url_str);
    result: i32 = cef_browser_host_create_browser(
        window_info, client, url_str, settings, 0, 0
    );
    cef_string_utf16_clear(url_str);
    return result;
}

impl _x11_parent(dpy: int, w: int) -> int {
    root_b: int = calloc(1, 8);
    par_b: int = calloc(1, 8);
    ch_b: int = calloc(1, 8);
    n_b: int = calloc(1, 8);
    rc: i32 = XQueryTree(dpy, w, root_b, par_b, ch_b, n_b);
    parent: int = 0;
    if rc != 0 {
        pv: cef_ptr_wrap_t = par_b;
        parent = pv.p0;
        cv: cef_ptr_wrap_t = ch_b;
        if cv.p0 != 0 {
            XFree(cv.p0);
        }
    }
    free(root_b);
    free(par_b);
    free(ch_b);
    free(n_b);
    return parent;
}

impl _x11_has_prop(dpy: int, w: int, prop: int) -> i32 {
    if prop == 0 {
        return 0;
    }
    at_b: int = calloc(1, 8);
    af_b: int = calloc(1, 8);
    ni_b: int = calloc(1, 8);
    ba_b: int = calloc(1, 8);
    pr_b: int = calloc(1, 8);
    rc: i32 = XGetWindowProperty(
        dpy, w, prop, 0, 0, 0, 0, at_b, af_b, ni_b, ba_b, pr_b
    );
    found: i32 = 0;
    if rc == 0 {
        av: cef_ptr_wrap_t = at_b;
        if av.p0 != 0 {
            found = 1;
        }
        pv: cef_ptr_wrap_t = pr_b;
        if pv.p0 != 0 {
            XFree(pv.p0);
        }
    }
    free(at_b);
    free(af_b);
    free(ni_b);
    free(ba_b);
    free(pr_b);
    return found;
}

impl _x11_toplevel(dpy: int, xid: int) -> int {
    root_win: int = XDefaultRootWindow(dpy);
    wm_state: int = XInternAtom(dpy, "WM_STATE", 1);
    cur: int = xid;
    i: int = 0;
    while i < 24 {
        if cur == 0 {
            return xid;
        }
        if cur == root_win {
            return xid;
        }
        if _x11_has_prop(dpy, cur, wm_state) != 0 {
            return cur;
        }
        parent: int = _x11_parent(dpy, cur);
        if parent == 0 {
            return cur;
        }
        if parent == root_win {
            return cur;
        }
        cur = parent;
        i = i + 1;
    }
    return cur;
}

impl cef_dispatch_window_set_title(title: int) -> i32 {
    if g_browser_xid == 0 {
        return 0;
    }
    dpy: int = XOpenDisplay(0);
    if dpy == 0 {
        return 0;
    }
    top: int = _x11_toplevel(dpy, g_browser_xid);
    if top == 0 {
        XCloseDisplay(dpy);
        return 0;
    }

    XStoreName(dpy, top, title);

    netname: int = XInternAtom(dpy, "_NET_WM_NAME", 0);
    utf8: int = XInternAtom(dpy, "UTF8_STRING", 0);
    if netname != 0 and utf8 != 0 {
        XChangeProperty(dpy, top, netname, utf8, 8, 0, title, i32(strlen(title)));
    }
    XFlush(dpy);
    XCloseDisplay(dpy);
    return 1;
}

impl cef_dispatch_window_set_size(w: int, h: int) -> i32 {
    if g_browser_xid == 0 {
        return 0;
    }
    if w <= 0 {
        return 0;
    }
    if h <= 0 {
        return 0;
    }
    dpy: int = XOpenDisplay(0);
    if dpy == 0 {
        return 0;
    }
    top: int = _x11_toplevel(dpy, g_browser_xid);
    if top == 0 {
        XCloseDisplay(dpy);
        return 0;
    }
    XResizeWindow(dpy, top, w, h);
    XFlush(dpy);
    XCloseDisplay(dpy);
    return 1;
}
