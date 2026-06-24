"""Jac-native CEF dispatch helper compiled to libcef_dispatch.so.

Wraps the parts of the CEF C API that Jac FFI cannot express directly:
calling methods on CEF-returned objects through their vtable pointers, and
allocating data structs with mixed-size fields.

Compile to libcef_dispatch.so:
  jac nacompile --shared cef_dispatch.na.jac -o libcef_dispatch.so

All :pub symbols match the C-ABI surface imported by cef.na.jac.
"""

import from "libcef.so" {
    def cef_execute_process(args: int, app: int, sandbox: int) -> i32;  def cef_initialize(
        args: int, settings: int, app: int, sandbox: int
    ) -> i32;  def cef_quit_message_loop -> None;  def cef_string_utf8_to_utf16(
        src: str, src_len: int, output: int
    ) -> i32;  def cef_string_utf16_clear(s: int) -> None;  def cef_browser_host_create_browser(
        wi: int, client: int, url: int, settings: int, extra_info: int, req_ctx: int
    ) -> i32;  def cef_version_info(which: i32) -> i32;
}

import from "libc.so.6" {
    def setenv(name: str, value: str, overwrite: i32) -> i32;  def getenv(
        name: str
    ) -> int;  def readlink(path: str, buf: int, bufsiz: int) -> int;  def access(
        path: str, mode: i32
    ) -> i32;  def strlen(s: str) -> int;  def strcpy(dst: int, src: str) -> int;  def strcat(
        dst: int, src: str
    ) -> int;  def strrchr(s: int, c: i32) -> int;  def calloc(
        n: int, size: int
    ) -> int;  def malloc(size: int) -> int;  def free(ptr: int) -> None;  def write(
        fd: i32, buf: int, count: int
    ) -> int;  def memset(s: int, c: i32, n: int) -> int;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def strncpy(dst: int, src: str, n: int) -> int;  def abort -> None;  def signal(
        signum: i32, handler: int
    ) -> int;  def open(path: str, flags: i32) -> i32;  def read(
        fd: i32, buf: int, count: int
    ) -> int;  def close(fd: i32) -> i32;
}

import from "libdl.so.2" { def dlsym(handle: int, symbol: str) -> int;  }

import from "libX11.so.6" {
    """Native window control for WindowPlugin (set_title / set_size). Title/size
    are X11 operations on Linux -- CEF native windows have no set-title C API and
    the WM owns the frame. These run on the broker (CPython) thread; we open a
    fresh Display per call (Xlib is not thread-safe across one connection, and the
    CEF UI thread keeps its own). All char* args are passed as int pointers."""
    def XOpenDisplay(name: int) -> int;  def XCloseDisplay(dpy: int) -> i32;  def XDefaultRootWindow(
        dpy: int
    ) -> int;  def XQueryTree(
        dpy: int, w: int, root_ret: int, parent_ret: int, children_ret: int, n_ret: int
    ) -> i32;  def XInternAtom(dpy: int, name: str, only_if_exists: i32) -> int;  def XGetWindowProperty(
        dpy: int,
        w: int,
        prop: int,
        long_off: int,
        long_len: int,
        delete: i32,
        req_type: int,
        actual_type_ret: int,
        actual_format_ret: int,
        nitems_ret: int,
        bytes_after_ret: int,
        prop_ret: int
    ) -> i32;  def XStoreName(dpy: int, w: int, name: int) -> i32;  def XChangeProperty(
        dpy: int,
        w: int,
        prop: int,
        type: int,
        format: i32,
        mode: i32,
        data: int,
        nelements: i32
    ) -> i32;  def XResizeWindow(dpy: int, w: int, width: int, height: int) -> i32;  def XFlush(
        dpy: int
    ) -> i32;  def XFree(ptr: int) -> i32;
}

import from "libcef.so" {
    """cef_string_t - 24 bytes: ptr(8), len(8), dtor(8)"""
    obj cef_string_t {
        has ptr: int = 0,
            len: int = 0,
            dtor: int = 0;
    }  """cef_settings_t - 440 bytes (verified with offsetof)"""
    obj cef_settings_t {
        has size: int = 0,  # 0
            no_sandbox: i32 = 0,  # 8
            _s_pad0: i32 = 0,  # 12
            bsp_ptr: int = 0,  # 16  browser_subprocess_path.ptr
            bsp_len: int = 0,  # 24
            bsp_dtor: int = 0,  # 32
            fdp_ptr: int = 0,  # 40  framework_dir_path
            fdp_len: int = 0,  # 48
            fdp_dtor: int = 0,  # 56
            mbp_ptr: int = 0,  # 64  main_bundle_path
            mbp_len: int = 0,  # 72
            mbp_dtor: int = 0,  # 80
            chrome_runtime: i32 = 0,  # 88
            multi_threaded: i32 = 0,  # 92  multi_threaded_message_loop
            ext_msg_pump: i32 = 0,  # 96
            windowless: i32 = 0,  # 100
            cmdline_disabled: i32 = 0,  # 104
            _s_pad1: i32 = 0,  # 108
            cp_ptr: int = 0,  # 112  cache_path.ptr
            cp_len: int = 0,  # 120
            cp_dtor: int = 0,  # 128
            rcp_ptr: int = 0,  # 136  root_cache_path
            rcp_len: int = 0,  # 144
            rcp_dtor: int = 0,  # 152
            persist_sess: i32 = 0,  # 160
            persist_user: i32 = 0,  # 164
            ua_ptr: int = 0,  # 168  user_agent
            ua_len: int = 0,  # 176
            ua_dtor: int = 0,  # 184
            uap_ptr: int = 0,  # 192  user_agent_product
            uap_len: int = 0,  # 200
            uap_dtor: int = 0,  # 208
            locale_ptr: int = 0,  # 216
            locale_len: int = 0,  # 224
            locale_dtor: int = 0,  # 232
            lf_ptr: int = 0,  # 240  log_file
            lf_len: int = 0,  # 248
            lf_dtor: int = 0,  # 256
            log_severity: i32 = 0,  # 264
            log_items: i32 = 0,  # 268
            jsf_ptr: int = 0,  # 272  javascript_flags
            jsf_len: int = 0,  # 280
            jsf_dtor: int = 0,  # 288
            rdp_ptr: int = 0,  # 296  resources_dir_path.ptr
            rdp_len: int = 0,  # 304
            rdp_dtor: int = 0,  # 312
            ldp_ptr: int = 0,  # 320  locales_dir_path.ptr
            ldp_len: int = 0,  # 328
            ldp_dtor: int = 0,  # 336
            pack_disabled: i32 = 0,  # 344
            remote_dbg: i32 = 0,  # 348
            uncaught_exc: i32 = 0,  # 352
            bg_color: i32 = 0,  # 356
            al_ptr: int = 0,  # 360  accept_language_list
            al_len: int = 0,  # 368
            al_dtor: int = 0,  # 376
            csl_ptr: int = 0,  # 384  cookieable_schemes_list
            csl_len: int = 0,  # 392
            csl_dtor: int = 0,  # 400
            cs_excl: i32 = 0,  # 408
            _s_pad2: i32 = 0,  # 412
            cpid_ptr: int = 0,  # 416  chrome_policy_id
            cpid_len: int = 0,  # 424
            cpid_dtor: int = 0;  # 432  (end at 440)
    }  """cef_window_info_t - 72 bytes (verified with offsetof)"""
    obj cef_window_info_t {
        has wn_ptr: int = 0,  # 0   window_name.ptr
            wn_len: int = 0,  # 8
            wn_dtor: int = 0,  # 16
            bounds_x: i32 = 0,  # 24  bounds.x
            bounds_y: i32 = 0,  # 28
            bounds_w: i32 = 0,  # 32
            bounds_h: i32 = 0,  # 36
            parent: int = 0,  # 40  parent_window
            windowless: i32 = 0,  # 48
            shared_tex: i32 = 0,  # 52
            ext_begin: i32 = 0,  # 56
            _wi_pad: i32 = 0,  # 60
            window: int = 0;  # 64  (end at 72)
    }  """cef_life_span_handler_t - 80 bytes"""
    obj cef_life_span_handler_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_before_popup:
                Callable[
                    [int, int, int, int, int, int, int, int, int, int, int, int, int],
                    int
                ] = 0,
            on_before_dev_tools_popup:
                Callable[[int, int, int, int, int, int, int], None] = 0,
            on_after_created: Callable[[int, int], None] = 0,
            do_close: Callable[[int, int], int] = 0,
            on_before_close: Callable[[int, int], None] = 0;
    }  """cef_browser_process_handler_t - 80 bytes"""
    obj cef_browser_process_handler_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_register_custom_preferences: Callable[[int, i32, int], None] = 0,
            on_context_initialized: Callable[[int], None] = 0,
            on_before_child_process_launch: Callable[[int, int], None] = 0,
            on_schedule_message_pump_work: Callable[[int, int], None] = 0,
            get_default_client: Callable[[int], int] = 0;
    }  """cef_render_process_handler_t - 112 bytes"""
    obj cef_render_process_handler_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_web_kit_initialized: Callable[[int], None] = 0,
            on_browser_created: Callable[[int, int, int], None] = 0,
            on_browser_destroyed: Callable[[int, int], None] = 0,
            get_load_handler: Callable[[int], int] = 0,
            on_context_created: Callable[[int, int, int, int], None] = 0,
            on_context_released: Callable[[int, int, int, int], None] = 0,
            on_uncaught_exception: Callable[[int, int, int, int, int, int], None] = 0,
            on_focused_node_changed: Callable[[int, int, int, int], None] = 0,
            on_process_message_received: Callable[[int, int, int, i32, int], int] = 0;
    }  """cef_client_t - 192 bytes"""
    obj cef_client_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            get_audio_handler: Callable[[int], int] = 0,
            get_command_handler: Callable[[int], int] = 0,
            get_context_menu_handler: Callable[[int], int] = 0,
            get_dialog_handler: Callable[[int], int] = 0,
            get_display_handler: Callable[[int], int] = 0,
            get_download_handler: Callable[[int], int] = 0,
            get_drag_handler: Callable[[int], int] = 0,
            get_find_handler: Callable[[int], int] = 0,
            get_focus_handler: Callable[[int], int] = 0,
            get_frame_handler: Callable[[int], int] = 0,
            get_permission_handler: Callable[[int], int] = 0,
            get_jsdialog_handler: Callable[[int], int] = 0,
            get_keyboard_handler: Callable[[int], int] = 0,
            get_life_span_handler: Callable[[int], int] = 0,
            get_load_handler: Callable[[int], int] = 0,
            get_print_handler: Callable[[int], int] = 0,
            get_render_handler: Callable[[int], int] = 0,
            get_request_handler: Callable[[int], int] = 0,
            on_process_message_received: Callable[[int, int, int, i32, int], int] = 0;
    }  """Two-field helper for argv / pointer packing via memcpy."""
    obj cef_ptr_wrap_t {
        has p0: int = 0,
            p1: int = 0;
    }  """cef_app_t - 80 bytes (CEF capi cef_app_t).

    MUST stay field-compatible with the copy in cef_subprocess.na.jac:
    same field order + 80-byte size. This copy types the handler fields as
    Callable because it assigns real dispatch callbacks; the subprocess copy
    only assigns cef_stub_* and types them as int. nacompile cannot yet share
    a struct decl across the spliced modules — keep the two in sync by hand."""
    obj cef_app_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_before_command_line_processing: Callable[[int, int, int], None] = 0,
            on_register_custom_schemes: Callable[[int, int], None] = 0,
            get_resource_bundle_handler: Callable[[int], int] = 0,
            get_browser_process_handler: Callable[[int], int] = 0,
            get_render_process_handler: Callable[[int], int] = 0;
    }  """cef_frame_t vtable - 240 bytes (dispatch targets). No defaults: only used as a local view via f: cef_frame_t = frame_int"""
    obj cef_frame_t {
        has _f0: int,  # base.size       0
            _f1: int,  # add_ref         8
            _f2: int,  # release         16
            _f3: int,  # has_one_ref     24
            _f4: int,  # has_at_least    32
            _f5: int,  # is_valid        40
            _f6: int,  # undo            48
            _f7: int,  # redo            56
            _f8: int,  # cut             64
            _f9: int,  # copy            72
            _f10: int,  # paste           80
            _f11: int,  # del             88
            _f12: int,  # select_all      96
            _f13: int,  # view_source     104
            _f14: int,  # get_source      112
            _f15: int,  # get_text        120
            _f16: int,  # load_request    128
            load_url: Callable[[int, int], None],  # 136
            execute_java_script: Callable[[int, int, int, i32], None],  # 144
            is_main: Callable[[int], i32],  # 152
            _f20: int,  # is_focused      160
            _f21: int,  # get_name        168
            _f22: int,  # get_identifier  176
            _f23: int,  # get_parent      184
            _f24: int,  # get_url         192
            _f25: int,  # get_browser     200
            _f26: int,  # get_v8context   208
            _f27: int,  # visit_dom       216
            _f28: int,  # create_urlreq   224
            _f29: int;  # send_msg        232
    }  """cef_browser_t vtable - 208 bytes. No defaults: only used as a local view via b: cef_browser_t = browser_int"""
    obj cef_browser_t {
        has _b0: int,  # base.size     0
            _b1: int,  # add_ref       8
            _b2: int,  # release       16
            _b3: int,  # has_one_ref   24
            _b4: int,  # has_at_least  32
            _b5: int,  # is_valid      40
            get_host: Callable[[int], int],  # get_host      48
            _b7: int,  # can_go_back   56
            _b8: int,  # go_back       64
            _b9: int,  # can_fwd       72
            _b10: int,  # go_forward    80
            _b11: int,  # is_loading    88
            _b12: int,  # reload        96
            _b13: int,  # reload_ic     104
            _b14: int,  # stop_load     112
            _b15: int,  # get_id        120
            _b16: int,  # is_same       128
            _b17: int,  # is_popup      136
            _b18: int,  # has_doc       144
            get_main_frame: Callable[[int], int],  # 152
            _b20: int,  # get_focused   160
            _b21: int,  # get_byident   168
            _b22: int,  # get_frame     176
            _b23: int,  # get_count     184
            _b24: int,  # get_idents    192
            _b25: int;  # get_names     200
    }  """cef_browser_host_t vtable - only get_window_handle (offset 72) is
    called. Field order/offsets verified against CEF 119.4.7 capi
    (cef_browser_capi.h): base(0-32), get_browser(40), close_browser(48),
    try_close_browser(56), set_focus(64), get_window_handle(72). No defaults:
    used as a local view via h: cef_browser_host_t = host_int."""
    obj cef_browser_host_t {
        has _bh0: int,  # base.size            0
            _bh1: int,  # add_ref              8
            _bh2: int,  # release             16
            _bh3: int,  # has_one_ref         24
            _bh4: int,  # has_at_least_one    32
            _bh5: int,  # get_browser         40
            _bh6: int,  # close_browser       48
            _bh7: int,  # try_close_browser   56
            _bh8: int,  # set_focus           64
            get_window_handle: Callable[[int], int];  # get_window_handle  72
    }  """cef_command_line_t vtable - 200 bytes. No defaults: only used as a local view via c: cef_command_line_t = cmd_int"""
    obj cef_command_line_t {
        has _c0: int,  # base.size         0
            _c1: int,  # add_ref           8
            _c2: int,  # release           16
            _c3: int,  # has_one_ref       24
            _c4: int,  # has_at_least      32
            _c5: int,  # is_valid          40
            _c6: int,  # is_read_only      48
            _c7: int,  # copy              56
            _c8: int,  # init_from_argv    64
            _c9: int,  # init_from_string  72
            _c10: int,  # reset             80
            _c11: int,  # get_argv          88
            _c12: int,  # get_cmd_string    96
            _c13: int,  # get_program       104
            _c14: int,  # set_program       112
            _c15: int,  # has_switches      120
            _c16: int,  # has_switch        128
            _c17: int,  # get_switch_val    136
            _c18: int,  # get_switches      144
            append_switch: Callable[[int, int], None],  # 152
            append_switch_with_value: Callable[[int, int, int], None],  # 160
            _c21: int,  # has_arguments     168
            _c22: int,  # get_arguments     176
            _c23: int,  # append_argument   184
            _c24: int;  # prepend_wrapper   192
    }
}  # import from libcef.so

# PLATFORM
glob g_pending_url: str = "",
     g_pending_title: str = "",
     g_pending_w: int = 800,
     g_pending_h: int = 600,
     g_browser_pending: int = 0,
     # Captured once on the CEF UI thread in _on_after_created; read (only) by the
     # broker-thread window-control calls below. g_browser_xid is the X11 window id.
     g_browser: int = 0,
     g_browser_xid: int = 0,
     g_vtables_ready: int = 0,
     g_exe_dir_buf: int = 0,
     g_exe_path_buf: int = 0,
     g_cached_args: int = 0,
     # Static vtable instances
     g_lsh: cef_life_span_handler_t = cef_life_span_handler_t(),
     g_bph: cef_browser_process_handler_t = cef_browser_process_handler_t(),
     g_rph: cef_render_process_handler_t = cef_render_process_handler_t(),
     g_cli: cef_client_t = cef_client_t(),
     g_dispatch_app: cef_app_t = cef_app_t(),
     g_stub_app: cef_app_t = cef_app_t(),
     # Reusable data structs (single-threaded CEF lifecycle)
     g_settings: cef_settings_t = cef_settings_t(),
     g_wi: cef_window_info_t = cef_window_info_t();

# JS injected at document start in the render process. Three parts:
#   1. the __jac_invoke fetch shim (CEF's render process can't bind into the host
#      in-process, so it POSTs the wire array to the loopback /__jac/invoke route);
#   2. the window.__jac SDK -- the single source of truth for the desktop JS
#      bootstrap. The native/webview target does NOT keep its own copy: it slices
#      this SDK back out of this glob at build time (desktop_build._jac_sdk_js via
#      _cef_bootstrap_js). Edit the SDK here; the native target follows. The SDK
#      IIFE must start with `(function(){var _l={}` and the EventSource pump below
#      with `(function(){try{` -- those are the extraction boundaries.
#   3. an EventSource on /__jac/events that drives host->JS pushes: {eval} runs
#      JS (WindowPlugin), {event,payload} fans out to __jac.__emit__ (on()).
# Uses only single quotes so it embeds cleanly in this double-quoted glob.
glob BOOTSTRAP_JS: str = "window.__jac_invoke=function(p,c,a){return fetch('/__jac/invoke',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify([p,c,a||{}])}).then(function(r){return r.text();});};(function(){var _l={};window.__jac={invoke:function(p,c,a){return window.__jac_invoke(p,c,a||{}).then(function(r){if(typeof r==='string')r=JSON.parse(r);if(r.ok)return r.data;var e=new Error(r.error.message);e.code=r.error.code;throw e;});},on:function(ev,cb){(_l[ev]=_l[ev]||[]).push(cb);return function(){var a=_l[ev]||[];var i=a.indexOf(cb);if(i!==-1)a.splice(i,1);};},__emit__:function(ev,p){(_l[ev]||[]).forEach(function(h){try{h(p);}catch(_){}});}};window.__JAC_DESKTOP__=true;window.__JAC_BROKER__='/__jac';})();(function(){try{var es=new EventSource('/__jac/events');es.onmessage=function(m){try{var d=JSON.parse(m.data);if(d.eval){(0,eval)(d.eval);}else if(d.event){window.__jac.__emit__(d.event,d.payload);}}catch(_){}};}catch(_){}})();";

def _log(msg: str) {
    prefix: str = "[cef] ";
    newline: str = "\n";
    write(2, prefix, strlen(prefix));
    write(2, msg, strlen(msg));
    write(2, newline, 1);
}

def:pub cef_dispatch_get_exe_dir -> str {
    _init_exe_dir();
    return g_exe_dir_buf;
}

def _init_exe_dir {
    global g_exe_dir_buf,g_exe_path_buf;
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

def:pub cef_platform_bootstrap {
    _init_exe_dir();
    # Disable AT-SPI2 D-Bus accessibility probe (causes cef_initialize hang on Arch/Wayland)
    setenv("NO_AT_BRIDGE", "1", 0);
    # Point fontconfig at the bundled minimal config to avoid Arch 48-guessfamily.conf stall
    fc_val: int = getenv("FONTCONFIG_FILE");
    if fc_val == 0 && g_exe_dir_buf != 0 {
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

def:pub cef_dispatch_getenv_set(name: str) -> i32 {
    v: int = getenv(name);
    if v == 0 {
        return 0;
    }
    return 1;
}

def:pub cef_dispatch_log(msg: str) {
    _log(msg);
}

def _on_before_close(self: int, browser: int) {
    _log("browser before-close");
    cef_quit_message_loop();
}

"""Capture the browser + its X11 window id for native window control.

Runs on the CEF UI thread (only safe place to touch browser/host vtables). We
read the immutable window id once here so the broker thread never has to call
CEF off-thread -- it does pure X11 against this id (see the window-control
section at the bottom of this file)."""
def _on_after_created(self: int, browser: int) {
    global g_browser,g_browser_xid;
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

def _get_life_span_handler(self: int) -> int {
    return g_lsh;
}

def _get_browser_process_handler(self: int) -> int {
    return g_bph;
}

def _get_render_process_handler(self: int) -> int {
    return g_rph;
}

def _on_context_initialized(self: int) {
    global g_browser_pending;
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

def _on_context_created(self: int, browser: int, frame: int, context: int) {
    if cef_dispatch_frame_is_main(frame) == 0 {
        return;
    }
    cef_dispatch_frame_execute_js(frame, BOOTSTRAP_JS, "jac://bootstrap", 0);
    _log("render: bootstrap injected");
}

def _on_before_cmdline(self: int, process_type: int, command_line: int) {
    # ozone-platform intentionally omitted: C test without it works; CEF auto-detects from DISPLAY
    _log("cmdline: no platform flag (auto-detect)");
    if cef_dispatch_getenv_set("JAC_CEF_SINGLE_PROCESS") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "single-process");
    }
    if cef_dispatch_getenv_set("JAC_CEF_HEADLESS") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "headless");
        cef_dispatch_cmdline_append_switch(command_line, "disable-gpu");
    }
    # JAC_CEF_DISABLE_GPU: documented GPU fallback (QA.md §3/§5, notes-app
    # README). Without this branch the env var was a silent no-op and the GPU
    # process still spawned, crashing on hosts with no usable GL.
    if cef_dispatch_getenv_set("JAC_CEF_DISABLE_GPU") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "disable-gpu");
        cef_dispatch_cmdline_append_switch(command_line, "disable-gpu-compositing");
    }
    if cef_dispatch_getenv_set("JAC_CEF_IN_PROCESS_GPU") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "in-process-gpu");
    }
    # Verbose Chromium logging when JAC_CEF_VERBOSE is set
    if cef_dispatch_getenv_set("JAC_CEF_VERBOSE") != 0 {
        cef_dispatch_cmdline_append_switch_value(
            command_line, "enable-logging", "stderr"
        );
        cef_dispatch_cmdline_append_switch_value(command_line, "v", "1");
    }
    # Use a unique user-data-dir to avoid singleton lock conflicts
    ud_val: int = getenv("JAC_CEF_USER_DATA_DIR");
    if ud_val != 0 && strlen(ud_val) > 0 {
        cef_dispatch_cmdline_append_switch_value(command_line, "user-data-dir", ud_val);
    }
    _log("cmdline: done");
}

def _init_vtables {
    global g_lsh,g_bph,g_rph,g_cli,g_dispatch_app,g_stub_app,g_vtables_ready;
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


def:pub cef_dispatch_main_args_create -> int {
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

def:pub cef_dispatch_settings_create(no_sandbox: i32, cache_path: str) -> int {
    _init_exe_dir();
    g_settings.size = 440;
    g_settings.no_sandbox = no_sandbox;
    g_settings.multi_threaded = 0;
    g_settings.log_severity = 3;  # LOGSEVERITY_WARNING (1=VERBOSE exits, 2=INFO may log to file)
    # cache_path (Jac str from host — safe across the FFI boundary)
    if strlen(cache_path) > 0 {
        s: cef_string_t = cef_string_t();
        cef_string_utf8_to_utf16(cache_path, strlen(cache_path), s);
        g_settings.cp_ptr = s.ptr;
        g_settings.cp_len = s.len;
        g_settings.cp_dtor = s.dtor;
    }
    # resources_dir_path + locales_dir_path from exe dir (C char* only — do not
    # pass int pointers as Jac `str` across function calls; nacompile mis-marshals).
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

def:pub cef_dispatch_window_info_create(title: str, width: int, height: int) -> int {
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
        g_wi.bounds_w = width;
    } else {
        g_wi.bounds_w = 800;
    }
    if height > 0 {
        g_wi.bounds_h = height;
    } else {
        g_wi.bounds_h = 600;
    }
    return g_wi;
}

def:pub cef_dispatch_browser_settings_create -> int {
    # Allocate 264-byte zeroed block (cef_browser_settings_t is 264 bytes)
    buf: int = calloc(1, 264);
    # size at offset 0 (i64): 264 = 0x0108 in little-endian bytes [8, 1, 0, ...]
    memset(buf, 8, 1);
    memset(buf + 1, 1, 1);
    # javascript at offset 204 (i32): 1 = [1, 0, 0, 0]
    memset(buf + 204, 1, 1);
    # local_storage at offset 236 (i32): 1 = [1, 0, 0, 0]
    memset(buf + 236, 1, 1);
    return buf;
}

def:pub cef_dispatch_set_pending_browser(
    url: str, title: str, width: int, height: int
) {
    global g_pending_url,g_pending_title,g_pending_w,g_pending_h,g_browser_pending;
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

def:pub cef_dispatch_open_browser(url: str, title: str, width: int, height: int) {
    global g_browser_pending;
    cef_dispatch_set_pending_browser(url, title, width, height);
    _init_vtables();
    wi: int = cef_dispatch_window_info_create(title, width, height);
    bs: int = cef_dispatch_browser_settings_create();
    ok: i32 = cef_dispatch_create_browser(wi, g_cli, url, bs);
    _log("open_browser: done");
    free(bs);
    g_browser_pending = 0;
}

def:pub cef_dispatch_execute_process -> i32 {
    global g_cached_args;
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
    # Keep g_cached_args alive - reused in cef_dispatch_startup
    return code;
}

def:pub cef_dispatch_startup(cache_path: str, no_sandbox: int) -> i32 {
    _assert_cef_abi();
    cef_platform_bootstrap();
    _init_vtables();
    _log("startup: initializing CEF");
    settings: int = cef_dispatch_settings_create(no_sandbox, cache_path);
    # Reuse args from execute_process (same pointer = same memory CEF registered)
    global g_cached_args;
    if g_cached_args == 0 {
        g_cached_args = cef_dispatch_main_args_create();
    }
    # Reset SIGCHLD to SIG_DFL (=0) in case Jac runtime changed it
    old_sigchld: int = signal(17, 0);
    _log("startup: calling cef_initialize");
    rc: int = cef_initialize(g_cached_args, settings, g_dispatch_app, 0);
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

def:pub cef_dispatch_browser_get_main_frame(browser: int) -> int {
    b: cef_browser_t = browser;
    return b.get_main_frame(b);
}

def:pub cef_dispatch_frame_is_main(frame: int) -> i32 {
    f: cef_frame_t = frame;
    return f.is_main(f);
}

def:pub cef_dispatch_frame_load_url(frame: int, url: str) {
    f: cef_frame_t = frame;
    s: cef_string_t = cef_string_t();
    cef_string_utf8_to_utf16(url, strlen(url), s);
    f.load_url(f, s);
    cef_string_utf16_clear(s);
}

def:pub cef_dispatch_frame_execute_js(
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

def:pub cef_dispatch_cmdline_append_switch(cmd: int, sw: str) {
    c: cef_command_line_t = cmd;
    s: cef_string_t = cef_string_t();
    cef_string_utf8_to_utf16(sw, strlen(sw), s);
    c.append_switch(c, s);
    cef_string_utf16_clear(s);
}

def:pub cef_dispatch_cmdline_append_switch_value(cmd: int, name: str, value: str) {
    c: cef_command_line_t = cmd;
    sn: cef_string_t = cef_string_t();
    sv: cef_string_t = cef_string_t();
    cef_string_utf8_to_utf16(name, strlen(name), sn);
    cef_string_utf8_to_utf16(value, strlen(value), sv);
    c.append_switch_with_value(c, sn, sv);
    cef_string_utf16_clear(sn);
    cef_string_utf16_clear(sv);
}

def:pub cef_dispatch_base_release(handle: int) { }

def:pub cef_dispatch_create_browser(
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

# --- Native window control (X11) -------------------------------------------
# WindowPlugin.set_title / set_size call cef_dispatch_window_set_* below from the
# broker (CPython) thread via ctypes. The browser's X11 window id was captured on
# the UI thread in _on_after_created; here we only do pure X11 (stable ABI) on a
# fresh per-call Display connection -- so no CEF UI-thread marshalling and no
# shared-Xlib-connection races between concurrent broker request threads. Every
# op is best-effort: a 0 window id or missing $DISPLAY (headless) is a silent
# no-op that returns 0, and the Python side then falls back to a renderer-side
# document.title / window.resizeTo via the SSE eval channel.
"""Parent window id of w (0 on failure); frees the child list XQueryTree allocs."""
def _x11_parent(dpy: int, w: int) -> int {
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

"""1 if window w carries property `prop` (used to find the WM_STATE top-level)."""
def _x11_has_prop(dpy: int, w: int, prop: int) -> i32 {
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

"""Walk up from the captured (possibly nested) window to the WM-managed
top-level -- the ancestor carrying WM_STATE. Falls back to the highest non-root
ancestor when WM_STATE is absent (e.g. before the window is mapped)."""
def _x11_toplevel(dpy: int, xid: int) -> int {
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

"""Set the OS window title. `title` is a UTF-8 char* passed as a pointer from the
CPython broker via ctypes c_char_p -- NOT a Jac str (whose ABI differs). Returns
1 if applied, 0 if there is no window / no X display."""
def:pub cef_dispatch_window_set_title(title: int) -> i32 {
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
    # WM_NAME (legacy XA_STRING) for older WMs ...
    XStoreName(dpy, top, title);
    # ... and _NET_WM_NAME (UTF8_STRING) which modern WMs prefer.
    netname: int = XInternAtom(dpy, "_NET_WM_NAME", 0);
    utf8: int = XInternAtom(dpy, "UTF8_STRING", 0);
    if netname != 0 && utf8 != 0 {
        XChangeProperty(dpy, top, netname, utf8, 8, 0, title, strlen(title));
    }
    XFlush(dpy);
    XCloseDisplay(dpy);
    return 1;
}

"""Resize the OS top-level window. Returns 1 if applied, 0 if there is no
window / no X display. The WM may clamp the request."""
def:pub cef_dispatch_window_set_size(w: int, h: int) -> i32 {
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
