"""Jac-native binding to Chromium Embedded Framework (CEF).

Expresses all CEF vtable structs (cef_app_t, cef_client_t,
cef_life_span_handler_t, etc.) as flat Jac clib structs with Callable
fields.  The three compiler features from #6574 / #6575 / #6576 enable:
  - Callable = 0  (null C function pointer defaults)
  - C-ABI trampolines when a Jac def is stored into a Callable slot
  - Flat calloc allocation with no RC header (CEF reads field 0 directly)

CEF exported functions are imported directly from libcef.so.  A thin
dispatch helper (libcef_dispatch.so) wraps the few remaining things that
Jac FFI cannot express: calling methods on CEF-returned objects through
their vtable pointers, and allocating data structs with mixed-size fields.
"""

import from "libcef.so" {
    def cef_execute_process(args: int, app: int, sandbox: int) -> i32;  def cef_initialize(
        args: int, settings: int, app: int, sandbox: int
    ) -> i32;  def cef_shutdown -> None;  def cef_run_message_loop -> None;  def cef_quit_message_loop -> None;
}

import from "libcef_dispatch.so" {
    def cef_dispatch_browser_get_main_frame(browser: int) -> int;  def cef_dispatch_frame_is_main(
        frame: int
    ) -> i32;  def cef_dispatch_frame_load_url(frame: int, url: str) -> None;  def cef_dispatch_frame_execute_js(
        frame: int, code: str, script_url: str, start_line: i32
    ) -> None;  def cef_dispatch_cmdline_append_switch(cmd: int, sw: str) -> None;  def cef_dispatch_cmdline_append_switch_value(
        cmd: int, name: str, value: str
    ) -> None;  def cef_dispatch_base_release(handle: int) -> None;  def cef_dispatch_settings_create(
        no_sandbox: i32, cache_path: str, resources_dir: str, locales_dir: str
    ) -> int;  def cef_dispatch_window_info_create(
        title: str, width: i32, height: i32
    ) -> int;  def cef_dispatch_browser_settings_create -> int;  def cef_dispatch_main_args_create -> int;  def cef_dispatch_create_browser(
        window_info: int, client: int, url: str, settings: int
    ) -> i32;  def cef_dispatch_get_exe_dir -> str;  def cef_dispatch_getenv_set(
        name: str
    ) -> i32;  def cef_dispatch_log(msg: str) -> None;
}

# ---------------------------------------------------------------------------
# CEF vtable structs — flat clib structs with inlined cef_base_ref_counted_t.
# size field must match sizeof(struct) in bytes on x86_64 Linux.
# ---------------------------------------------------------------------------
import from "libcef.so" {
    obj cef_life_span_handler_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_before_popup: int = 0,
            on_before_dev_tools_popup: int = 0,
            on_after_created: Callable[[int, int], None] = 0,
            do_close: int = 0,
            on_before_close: Callable[[int, int], None] = 0;
    }  obj cef_load_handler_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_loading_state_change: int = 0,
            on_load_start: Callable[[int, int, int, int], None] = 0,
            on_load_end: Callable[[int, int, int, int], None] = 0,
            on_load_error: Callable[[int, int, int, int, int, int], None] = 0;
    }  obj cef_display_handler_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_address_change: int = 0,
            on_title_change: int = 0,
            on_favicon_urlchange: int = 0,
            on_fullscreen_mode_change: int = 0,
            on_tooltip: int = 0,
            on_status_message: int = 0,
            on_console_message: Callable[[int, int, int, int, int, int], int] = 0,
            on_auto_resize: int = 0,
            on_loading_progress_change: int = 0,
            on_cursor_change: int = 0,
            on_media_access_change: int = 0;
    }  obj cef_browser_process_handler_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_register_custom_preferences: int = 0,
            on_context_initialized: Callable[[int], None] = 0,
            on_before_child_process_launch: int = 0,
            on_schedule_message_pump_work: int = 0,
            get_default_client: int = 0;
    }  obj cef_render_process_handler_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_web_kit_initialized: int = 0,
            on_browser_created: int = 0,
            on_browser_destroyed: int = 0,
            get_load_handler: int = 0,
            on_context_created: Callable[[int, int, int, int], None] = 0,
            on_context_released: int = 0,
            on_uncaught_exception: int = 0,
            on_focused_node_changed: int = 0,
            on_process_message_received: int = 0;
    }  obj cef_client_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            get_audio_handler: int = 0,
            get_command_handler: int = 0,
            get_context_menu_handler: int = 0,
            get_dialog_handler: int = 0,
            get_display_handler: Callable[[int], int] = 0,
            get_download_handler: int = 0,
            get_drag_handler: int = 0,
            get_find_handler: int = 0,
            get_focus_handler: int = 0,
            get_frame_handler: int = 0,
            get_permission_handler: int = 0,
            get_jsdialog_handler: int = 0,
            get_keyboard_handler: int = 0,
            get_life_span_handler: Callable[[int], int] = 0,
            get_load_handler: Callable[[int], int] = 0,
            get_print_handler: int = 0,
            get_render_handler: int = 0,
            get_request_handler: int = 0,
            on_process_message_received: int = 0;
    }  obj cef_app_t {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_before_command_line_processing: Callable[[int, int, int], None] = 0,
            on_register_custom_schemes: int = 0,
            get_resource_bundle_handler: int = 0,
            get_browser_process_handler: Callable[[int], int] = 0,
            get_render_process_handler: Callable[[int], int] = 0;
    }
}  # import from libcef.so

# ---------------------------------------------------------------------------
# Refcount stubs — CEF client-side vtables are static; refcount is a no-op.
# ---------------------------------------------------------------------------
def _cef_add_ref(self: int) { }
def _cef_release(self: int) -> int {
    return 0;
}

def _cef_has_one_ref(self: int) -> int {
    return 1;
}

def _cef_has_at_least_one_ref(self: int) -> int {
    return 1;
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
def _cef_log(msg: str) {
    cef_dispatch_log(msg);
}

# ---------------------------------------------------------------------------
# Pending browser state
# ---------------------------------------------------------------------------
glob g_pending_url: str = "",
     g_pending_title: str = "",
     g_pending_width: int = 0,
     g_pending_height: int = 0,
     g_browser_pending: int = 0,
     # ---------------------------------------------------------------------------
     # Static vtable instances (glob so addresses survive after init returns)
     # ---------------------------------------------------------------------------
     g_lsh: cef_life_span_handler_t = cef_life_span_handler_t(),
     g_lh: cef_load_handler_t = cef_load_handler_t(),
     g_dh: cef_display_handler_t = cef_display_handler_t(),
     g_bph: cef_browser_process_handler_t = cef_browser_process_handler_t(),
     g_rph: cef_render_process_handler_t = cef_render_process_handler_t(),
     g_cli: cef_client_t = cef_client_t(),
     g_app: cef_app_t = cef_app_t();

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------
def _on_after_created(self: int, browser: int) {
    _cef_log("browser after-created");
}

def _on_before_close(self: int, browser: int) {
    _cef_log("browser before-close");
    cef_quit_message_loop();
}

def _on_load_start(self: int, browser: int, frame: int, transition_type: int) {
    if cef_dispatch_frame_is_main(frame) != 0 {
        _cef_log("main frame load started");
    }
}

def _on_load_end(self: int, browser: int, frame: int, http_status: int) {
    if cef_dispatch_frame_is_main(frame) != 0 {
        _cef_log("main frame loaded");
    }
}

def _on_load_error(
    self: int,
    browser: int,
    frame: int,
    error_code: int,
    error_text: int,
    failed_url: int
) {
    if cef_dispatch_frame_is_main(frame) != 0 {
        _cef_log("main frame load error");
    }
}

def _on_console_message(
    self: int, browser: int, level: int, message: int, source: int, line: int
) -> int {
    _cef_log("js console message");
    return 0;
}

def _on_context_initialized(self: int) {
    _cef_log("context initialized");
    if g_browser_pending != 0 {
        wi = cef_dispatch_window_info_create(
            g_pending_title, g_pending_width, g_pending_height,
        );
        bs = cef_dispatch_browser_settings_create();
        cef_dispatch_create_browser(wi, g_cli, g_pending_url, bs);
        g_browser_pending = 0;
    }
}

glob BOOTSTRAP_JS: str = (
         "Object.defineProperty(window,'__JAC_DESKTOP__',"
         "{value:true,writable:false,configurable:false});"
         "Object.defineProperty(window,'__JAC_BROKER__',"
         "{value:'/__jac',writable:false,configurable:false});"
     );

def _on_context_created(self: int, browser: int, frame: int, context: int) -> None {
    if cef_dispatch_frame_is_main(frame) == 0 {
        return;
    }
    cef_dispatch_frame_execute_js(frame, BOOTSTRAP_JS, "jac://bootstrap", 0);
    _cef_log("render: bootstrap globals injected");
}

# Client handler getters — return clib vtable struct pointers as int.
# The compiler emits ptrtoint for clib struct → int coercion at call sites.
def _get_life_span_handler(self: int) -> int {
    return g_lsh;
}

def _get_load_handler(self: int) -> int {
    return g_lh;
}

def _get_display_handler(self: int) -> int {
    return g_dh;
}

def _get_browser_process_handler(self: int) -> int {
    return g_bph;
}

def _get_render_process_handler(self: int) -> int {
    return g_rph;
}

def _on_before_cmdline(self: int, process_type: int, command_line: int) {
    cef_dispatch_cmdline_append_switch_value(command_line, "ozone-platform", "x11");
    cef_dispatch_cmdline_append_switch_value(command_line, "use-gl", "desktop");
    cef_dispatch_cmdline_append_switch(command_line, "disable-gpu-sandbox");
    cef_dispatch_cmdline_append_switch(command_line, "disable-dev-shm-usage");
    if cef_dispatch_getenv_set("JAC_CEF_DISABLE_GPU") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "disable-gpu");
        cef_dispatch_cmdline_append_switch(command_line, "disable-gpu-compositing");
        cef_dispatch_cmdline_append_switch(command_line, "enable-software-rasterizer");
    }
    if cef_dispatch_getenv_set("JAC_CEF_SINGLE_PROCESS") != 0 {
        cef_dispatch_cmdline_append_switch(command_line, "single-process");
    }
}

# ---------------------------------------------------------------------------
# Vtable initialization
# ---------------------------------------------------------------------------
def _init_vtables {
    g_lsh = cef_life_span_handler_t(
        size=80,
        add_ref=_cef_add_ref,
        release=_cef_release,
        has_one_ref=_cef_has_one_ref,
        has_at_least_one_ref=_cef_has_at_least_one_ref,
        on_after_created=_on_after_created,
        on_before_close=_on_before_close,
    );
    g_lh = cef_load_handler_t(
        size=72,
        add_ref=_cef_add_ref,
        release=_cef_release,
        has_one_ref=_cef_has_one_ref,
        has_at_least_one_ref=_cef_has_at_least_one_ref,
        on_load_start=_on_load_start,
        on_load_end=_on_load_end,
        on_load_error=_on_load_error,
    );
    g_dh = cef_display_handler_t(
        size=128,
        add_ref=_cef_add_ref,
        release=_cef_release,
        has_one_ref=_cef_has_one_ref,
        has_at_least_one_ref=_cef_has_at_least_one_ref,
        on_console_message=_on_console_message,
    );
    g_bph = cef_browser_process_handler_t(
        size=80,
        add_ref=_cef_add_ref,
        release=_cef_release,
        has_one_ref=_cef_has_one_ref,
        has_at_least_one_ref=_cef_has_at_least_one_ref,
        on_context_initialized=_on_context_initialized,
    );
    g_rph = cef_render_process_handler_t(
        size=112,
        add_ref=_cef_add_ref,
        release=_cef_release,
        has_one_ref=_cef_has_one_ref,
        has_at_least_one_ref=_cef_has_at_least_one_ref,
        on_context_created=_on_context_created,
    );
    g_cli = cef_client_t(
        size=192,
        add_ref=_cef_add_ref,
        release=_cef_release,
        has_one_ref=_cef_has_one_ref,
        has_at_least_one_ref=_cef_has_at_least_one_ref,
        get_display_handler=_get_display_handler,
        get_life_span_handler=_get_life_span_handler,
        get_load_handler=_get_load_handler,
    );
    g_app = cef_app_t(
        size=80,
        add_ref=_cef_add_ref,
        release=_cef_release,
        has_one_ref=_cef_has_one_ref,
        has_at_least_one_ref=_cef_has_at_least_one_ref,
        on_before_command_line_processing=_on_before_cmdline,
        get_browser_process_handler=_get_browser_process_handler,
        get_render_process_handler=_get_render_process_handler,
    );
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
"""Chromium browser window powered by CEF."""
obj:pub CefBrowser {
    has browser_handle: int = 0;

    def title(_text: str) { }
    def size(_width: int, _height: int, _hint: int = 0) { }
    def navigate(url: str) {
        if self.browser_handle != 0 {
            frame = cef_dispatch_browser_get_main_frame(self.browser_handle);
            if frame != 0 {
                cef_dispatch_frame_load_url(frame, url);
            }
        }
    }

    def run {
        cef_run_message_loop();
    }

    def terminate {
        cef_quit_message_loop();
    }

    def destroy { }
}

"""Run CEF subprocess dispatch; return exit code (>= 0) or -1 for main process."""
def:pub cef_execute_subprocess -> i32 {
    _init_vtables();
    main_args = cef_dispatch_main_args_create();
    return cef_execute_process(main_args, g_app, 0);
}

"""Queue a browser window to open on on_context_initialized (before initialize)."""
def:pub cef_queue_browser(url: str, title: str, width: int, height: int) {
    g_pending_url = url;
    g_pending_title = title;
    g_pending_width = width;
    g_pending_height = height;
    g_browser_pending = 1;
}

"""Initialize CEF on the main process; returns 1 on success."""
def:pub cef_startup(cache_path: str, no_sandbox: int) -> i32 {
    main_args = cef_dispatch_main_args_create();
    exe_dir: str = cef_dispatch_get_exe_dir();
    locales_dir: str = f"{exe_dir}/locales";
    settings = cef_dispatch_settings_create(
        no_sandbox, cache_path, exe_dir, locales_dir,
    );
    return cef_initialize(main_args, settings, g_app, 0);
}

"""Run the CEF UI message loop (blocks until quit)."""
def:pub cef_run_loop {
    cef_run_message_loop();
}

"""Bootstrap CEF, initialize, and open a browser window."""
def:pub new_cef_browser(
    url: str,
    title: str,
    width: int,
    height: int,
    cache_path: str = "",
    no_sandbox: int = 1,
) -> CefBrowser {
    code: i32 = cef_execute_subprocess();
    if code >= 0 {
        return CefBrowser(browser_handle=0);
    }
    cef_queue_browser(url, title, width, height);
    rc: i32 = cef_startup(cache_path, no_sandbox);
    if rc != 1 {
        return CefBrowser(browser_handle=0);
    }
    return CefBrowser(browser_handle=1);
}

"""Shut down CEF after the message loop exits."""
def:pub cef_cleanup {
    cef_shutdown();
}
