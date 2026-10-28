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
    obj cef_string_t {
        has ptr: int = 0,
            len: int = 0,
            dtor: int = 0;
    }  obj cef_settings_t {
        has size: int = 0,
            no_sandbox: i32 = 0,
            _s_pad0: i32 = 0,
            bsp_ptr: int = 0,
            bsp_len: int = 0,
            bsp_dtor: int = 0,
            fdp_ptr: int = 0,
            fdp_len: int = 0,
            fdp_dtor: int = 0,
            mbp_ptr: int = 0,
            mbp_len: int = 0,
            mbp_dtor: int = 0,
            chrome_runtime: i32 = 0,
            multi_threaded: i32 = 0,
            ext_msg_pump: i32 = 0,
            windowless: i32 = 0,
            cmdline_disabled: i32 = 0,
            _s_pad1: i32 = 0,
            cp_ptr: int = 0,
            cp_len: int = 0,
            cp_dtor: int = 0,
            rcp_ptr: int = 0,
            rcp_len: int = 0,
            rcp_dtor: int = 0,
            persist_sess: i32 = 0,
            persist_user: i32 = 0,
            ua_ptr: int = 0,
            ua_len: int = 0,
            ua_dtor: int = 0,
            uap_ptr: int = 0,
            uap_len: int = 0,
            uap_dtor: int = 0,
            locale_ptr: int = 0,
            locale_len: int = 0,
            locale_dtor: int = 0,
            lf_ptr: int = 0,
            lf_len: int = 0,
            lf_dtor: int = 0,
            log_severity: i32 = 0,
            log_items: i32 = 0,
            jsf_ptr: int = 0,
            jsf_len: int = 0,
            jsf_dtor: int = 0,
            rdp_ptr: int = 0,
            rdp_len: int = 0,
            rdp_dtor: int = 0,
            ldp_ptr: int = 0,
            ldp_len: int = 0,
            ldp_dtor: int = 0,
            pack_disabled: i32 = 0,
            remote_dbg: i32 = 0,
            uncaught_exc: i32 = 0,
            bg_color: i32 = 0,
            al_ptr: int = 0,
            al_len: int = 0,
            al_dtor: int = 0,
            csl_ptr: int = 0,
            csl_len: int = 0,
            csl_dtor: int = 0,
            cs_excl: i32 = 0,
            _s_pad2: i32 = 0,
            cpid_ptr: int = 0,
            cpid_len: int = 0,
            cpid_dtor: int = 0;
    }  obj cef_window_info_t {
        has wn_ptr: int = 0,
            wn_len: int = 0,
            wn_dtor: int = 0,
            bounds_x: i32 = 0,
            bounds_y: i32 = 0,
            bounds_w: i32 = 0,
            bounds_h: i32 = 0,
            parent: int = 0,
            windowless: i32 = 0,
            shared_tex: i32 = 0,
            ext_begin: i32 = 0,
            _wi_pad: i32 = 0,
            window: int = 0;
    }  obj cef_life_span_handler_t {
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
    }  obj cef_browser_process_handler_t {
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
    }  obj cef_render_process_handler_t {
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
    }  obj cef_client_t {
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
    }  obj cef_ptr_wrap_t {
        has p0: int = 0,
            p1: int = 0;
    }  obj cef_app_t {
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
    }  obj cef_frame_t {
        has _f0: int,
            _f1: int,
            _f2: int,
            _f3: int,
            _f4: int,
            _f5: int,
            _f6: int,
            _f7: int,
            _f8: int,
            _f9: int,
            _f10: int,
            _f11: int,
            _f12: int,
            _f13: int,
            _f14: int,
            _f15: int,
            _f16: int,
            load_url: Callable[[int, int], None],
            execute_java_script: Callable[[int, int, int, i32], None],
            is_main: Callable[[int], i32],
            _f20: int,
            _f21: int,
            _f22: int,
            _f23: int,
            _f24: int,
            _f25: int,
            _f26: int,
            _f27: int,
            _f28: int,
            _f29: int;
    }  obj cef_browser_t {
        has _b0: int,
            _b1: int,
            _b2: int,
            _b3: int,
            _b4: int,
            _b5: int,
            get_host: Callable[[int], int],
            _b7: int,
            _b8: int,
            _b9: int,
            _b10: int,
            _b11: int,
            _b12: int,
            _b13: int,
            _b14: int,
            _b15: int,
            _b16: int,
            _b17: int,
            _b18: int,
            get_main_frame: Callable[[int], int],
            _b20: int,
            _b21: int,
            _b22: int,
            _b23: int,
            _b24: int,
            _b25: int;
    }  obj cef_browser_host_t {
        has _bh0: int,
            _bh1: int,
            _bh2: int,
            _bh3: int,
            _bh4: int,
            _bh5: int,
            _bh6: int,
            _bh7: int,
            _bh8: int,
            get_window_handle: Callable[[int], int];
    }  obj cef_command_line_t {
        has _c0: int,
            _c1: int,
            _c2: int,
            _c3: int,
            _c4: int,
            _c5: int,
            _c6: int,
            _c7: int,
            _c8: int,
            _c9: int,
            _c10: int,
            _c11: int,
            _c12: int,
            _c13: int,
            _c14: int,
            _c15: int,
            _c16: int,
            _c17: int,
            _c18: int,
            append_switch: Callable[[int, int], None],
            append_switch_with_value: Callable[[int, int, int], None],
            _c21: int,
            _c22: int,
            _c23: int,
            _c24: int;
    }
}

glob g_pending_url: str = "",
     g_pending_title: str = "",
     g_pending_w: int = 800,
     g_pending_h: int = 600,
     g_browser_pending: int = 0,
     g_browser: int = 0,
     g_browser_xid: int = 0,
     g_vtables_ready: int = 0,
     g_exe_dir_buf: int = 0,
     g_exe_path_buf: int = 0,
     g_cached_args: int = 0,
     g_lsh: cef_life_span_handler_t = cef_life_span_handler_t(),
     g_bph: cef_browser_process_handler_t = cef_browser_process_handler_t(),
     g_rph: cef_render_process_handler_t = cef_render_process_handler_t(),
     g_cli: cef_client_t = cef_client_t(),
     g_dispatch_app: cef_app_t = cef_app_t(),
     g_stub_app: cef_app_t = cef_app_t(),
     g_settings: cef_settings_t = cef_settings_t(),
     g_wi: cef_window_info_t = cef_window_info_t();

glob BOOTSTRAP_JS: str = "window.__jac_invoke=function(p,c,a){return fetch('/__jac/invoke',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify([p,c,a||{}])}).then(function(r){return r.text();});};(function(){var _l={};window.__jac={invoke:function(p,c,a){return window.__jac_invoke(p,c,a||{}).then(function(r){if(typeof r==='string')r=JSON.parse(r);if(r.ok)return r.data;var e=new Error(r.error.message);e.code=r.error.code;throw e;});},on:function(ev,cb){(_l[ev]=_l[ev]||[]).push(cb);return function(){var a=_l[ev]||[];var i=a.indexOf(cb);if(i!==-1)a.splice(i,1);};},__emit__:function(ev,p){(_l[ev]||[]).forEach(function(h){try{h(p);}catch(_){}});}};window.__JAC_DESKTOP__=true;window.__JAC_BROKER__='/__jac';})();(function(){try{var es=new EventSource('/__jac/events');es.onmessage=function(m){try{var d=JSON.parse(m.data);if(d.eval){(0,eval)(d.eval);}else if(d.event){window.__jac.__emit__(d.event,d.payload);}}catch(_){}};}catch(_){}})();";

def _log(msg: str);

def:pub cef_dispatch_get_exe_dir -> str;

def _init_exe_dir;

def:pub cef_platform_bootstrap;

def:pub cef_dispatch_getenv_set(name: str) -> i32;

def:pub cef_dispatch_log(msg: str);

def _on_before_close(self: int, browser: int);

def _on_after_created(self: int, browser: int);

def _get_life_span_handler(self: int) -> int;

def _get_browser_process_handler(self: int) -> int;

def _get_render_process_handler(self: int) -> int;

def _on_context_initialized(self: int);

def _on_context_created(self: int, browser: int, frame: int, context: int);

def _on_before_cmdline(self: int, process_type: int, command_line: int);

def _init_vtables;


def:pub cef_dispatch_main_args_create -> int;

def:pub cef_dispatch_settings_create(no_sandbox: i32, cache_path: str) -> int;

def:pub cef_dispatch_window_info_create(title: str, width: int, height: int) -> int;

def:pub cef_dispatch_browser_settings_create -> int;

def:pub cef_dispatch_set_pending_browser(
    url: str, title: str, width: int, height: int
);

def:pub cef_dispatch_open_browser(url: str, title: str, width: int, height: int);

def:pub cef_dispatch_execute_process -> i32;

def:pub cef_dispatch_startup(cache_path: str, no_sandbox: int) -> i32;

def:pub cef_dispatch_browser_get_main_frame(browser: int) -> int;

def:pub cef_dispatch_frame_is_main(frame: int) -> i32;

def:pub cef_dispatch_frame_load_url(frame: int, url: str);

def:pub cef_dispatch_frame_execute_js(
    frame: int, code: str, script_url: str, start_line: i32
);

def:pub cef_dispatch_cmdline_append_switch(cmd: int, sw: str);

def:pub cef_dispatch_cmdline_append_switch_value(cmd: int, name: str, value: str);

def:pub cef_dispatch_base_release(handle: int);

def:pub cef_dispatch_create_browser(
    window_info: int, client: int, url: str, settings: int
) -> i32;

def _x11_parent(dpy: int, w: int) -> int;

def _x11_has_prop(dpy: int, w: int, prop: int) -> i32;

def _x11_toplevel(dpy: int, xid: int) -> int;

def:pub cef_dispatch_window_set_title(title: int) -> i32;

def:pub cef_dispatch_window_set_size(w: int, h: int) -> i32;
