/* cef_shim.c — C bridge between Jac native FFI and CEF's C API.
 *
 * CEF requires client-side vtable structs (cef_app_t, cef_client_t,
 * cef_life_span_handler_t) with refcount callbacks and precise layout.
 * Jac FFI handles scalars and strings cleanly but cannot express these
 * vtables. This shim owns all CEF callback machinery and exposes a small
 * scalar API that cef.na.jac binds against (same pattern as webview).
 *
 * Pinned to CEF 119.x (pre-Universal C API). CEF 137+ uses Universal C API
 * with version checks that fail on Spotify CDN builds (cef_api_version=-1).
 *
 * Build: build_cef_shim.sh (links against libcef.so from cef_dist/).
 */

/* Expose POSIX readlink() */
#define _POSIX_C_SOURCE 200809L

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_browser_capi.h"
#include "include/capi/cef_browser_process_handler_capi.h"
#include "include/capi/cef_command_line_capi.h"
#include "include/capi/cef_client_capi.h"
#include "include/capi/cef_display_handler_capi.h"
#include "include/capi/cef_frame_capi.h"
#include "include/capi/cef_life_span_handler_capi.h"
#include "include/capi/cef_load_handler_capi.h"
#include "include/capi/cef_render_process_handler_capi.h"
#include "include/capi/cef_v8_capi.h"
#include "include/internal/cef_string.h"
#include "include/internal/cef_types.h"

#if defined(__linux__)
#include "include/internal/cef_types_linux.h"
#endif

/* --- Refcount stubs for client-side static vtables ------------------------- */

static void shim_add_ref(cef_base_ref_counted_t* self) {
    (void)self;
}

static int shim_release(cef_base_ref_counted_t* self) {
    (void)self;
    return 0;
}

static int shim_has_one_ref(cef_base_ref_counted_t* self) {
    (void)self;
    return 1;
}

static int shim_has_at_least_one_ref(cef_base_ref_counted_t* self) {
    (void)self;
    return 1;
}

/* --- Life-span handler: quit message loop when the last browser closes ------ */

static void CEF_CALLBACK shim_on_after_created(cef_life_span_handler_t* self,
                                               cef_browser_t* browser) {
    (void)self;
    (void)browser;
    fprintf(stderr, "[cef] browser after-created\n");
    fflush(stderr);
}

static void shim_on_before_close(cef_life_span_handler_t* self,
                                 cef_browser_t* browser) {
    (void)self;
    (void)browser;
    cef_quit_message_loop();
}

static cef_life_span_handler_t g_life_span_handler;
static cef_load_handler_t g_load_handler;
static cef_display_handler_t g_display_handler;
static cef_browser_process_handler_t g_browser_process_handler;

static struct {
    int pending;
    char url[512];
    char title[256];
    int width;
    int height;
} g_pending_browser;

static int g_context_ready;

static cef_life_span_handler_t* shim_get_life_span_handler(cef_client_t* self) {
    (void)self;
    return &g_life_span_handler;
}

static void CEF_CALLBACK shim_on_load_start(cef_load_handler_t* self,
                                            cef_browser_t* browser,
                                            cef_frame_t* frame,
                                            cef_transition_type_t transition_type) {
    (void)self;
    (void)browser;
    (void)transition_type;
    if (frame && frame->is_main(frame)) {
        fprintf(stderr, "[cef] main frame load started\n");
        fflush(stderr);
    }
}

static void CEF_CALLBACK shim_on_load_end(cef_load_handler_t* self,
                                          cef_browser_t* browser,
                                          cef_frame_t* frame,
                                          int http_status_code) {
    (void)self;
    (void)browser;
    if (frame && frame->is_main(frame)) {
        fprintf(stderr, "[cef] main frame loaded (HTTP %d)\n", http_status_code);
        fflush(stderr);
    }
}

static void CEF_CALLBACK shim_on_load_error(cef_load_handler_t* self,
                                            cef_browser_t* browser,
                                            cef_frame_t* frame,
                                            cef_errorcode_t error_code,
                                            const cef_string_t* error_text,
                                            const cef_string_t* failed_url) {
    (void)self;
    (void)browser;
    (void)error_text;
    (void)failed_url;
    if (frame && frame->is_main(frame)) {
        fprintf(stderr, "[cef] main frame load error: %d\n", (int)error_code);
        fflush(stderr);
    }
}

static cef_load_handler_t* shim_get_load_handler(cef_client_t* self) {
    (void)self;
    return &g_load_handler;
}

static int CEF_CALLBACK shim_on_console_message(
    cef_display_handler_t* self,
    cef_browser_t* browser,
    cef_log_severity_t level,
    const cef_string_t* message,
    const cef_string_t* source,
    int line) {
    cef_string_utf8_t msg = {0};
    cef_string_utf8_t src = {0};
    (void)self;
    (void)browser;
    (void)level;
    if (message) {
        cef_string_utf16_to_utf8(message->str, message->length, &msg);
    }
    if (source) {
        cef_string_utf16_to_utf8(source->str, source->length, &src);
    }
    fprintf(stderr, "[cef:js] %s (%s:%d)\n",
            msg.str ? msg.str : "", src.str ? src.str : "", line);
    fflush(stderr);
    cef_string_utf8_clear(&msg);
    cef_string_utf8_clear(&src);
    return 0;
}

static cef_display_handler_t* shim_get_display_handler(cef_client_t* self) {
    (void)self;
    return &g_display_handler;
}

/* --- Render process handler: inject window.__JAC_DESKTOP__ at doc-start -- */

static cef_render_process_handler_t g_render_process_handler;

static void CEF_CALLBACK shim_on_context_created(
    cef_render_process_handler_t* self,
    cef_browser_t* browser,
    cef_frame_t* frame,
    struct _cef_v8context_t* context) {
    struct _cef_v8value_t* global;
    struct _cef_v8value_t* val;
    cef_string_t key;

    (void)self;
    (void)browser;

    /* Only inject in the main frame (not iframes / web workers). */
    if (!frame || !frame->is_main(frame)) return;
    if (!context) return;

    global = context->get_global(context);
    if (!global) return;

    /* window.__JAC_DESKTOP__ = true */
    memset(&key, 0, sizeof(key));
    cef_string_utf8_to_utf16("__JAC_DESKTOP__", 16, &key);
    val = cef_v8value_create_bool(1);
    if (val) {
        global->set_value_bykey(global, &key, val, V8_PROPERTY_ATTRIBUTE_DONTDELETE);
        val->base.release(&val->base);
    }
    cef_string_utf16_clear(&key);

    /* window.__JAC_BROKER__ = "/__jac" */
    memset(&key, 0, sizeof(key));
    cef_string_utf8_to_utf16("__JAC_BROKER__", 14, &key);
    {
        cef_string_t broker_val;
        memset(&broker_val, 0, sizeof(broker_val));
        cef_string_utf8_to_utf16("/__jac", 6, &broker_val);
        val = cef_v8value_create_string(&broker_val);
        cef_string_utf16_clear(&broker_val);
    }
    if (val) {
        global->set_value_bykey(global, &key, val, V8_PROPERTY_ATTRIBUTE_DONTDELETE);
        val->base.release(&val->base);
    }
    cef_string_utf16_clear(&key);

    fprintf(stderr, "[cef:render] bootstrap globals injected\n");
    fflush(stderr);

    global->base.release(&global->base);
}

static cef_render_process_handler_t* CEF_CALLBACK
shim_get_render_process_handler(cef_app_t* self) {
    (void)self;
    return &g_render_process_handler;
}

static cef_client_t g_client;
static cef_app_t g_app;

/* Stored main_args for reuse in cef_initialize. */
static cef_main_args_t g_main_args;

static void CEF_CALLBACK shim_on_context_initialized(
    cef_browser_process_handler_t* self);
static cef_browser_process_handler_t* CEF_CALLBACK
shim_get_browser_process_handler(cef_app_t* self);
static void CEF_CALLBACK shim_on_before_command_line_processing(
    cef_app_t* self,
    const cef_string_t* process_type,
    cef_command_line_t* command_line);
static intptr_t shim_do_create_browser(const char* url, const char* title,
                                       int width, int height);

static void shim_get_exe_dir(char* buf, size_t buflen) {
    ssize_t n = readlink("/proc/self/exe", buf, buflen - 1);
    if (n <= 0) {
        buf[0] = '\0';
        return;
    }
    buf[n] = '\0';
    {
        char* slash = strrchr(buf, '/');
        if (slash) {
            *slash = '\0';
        }
    }
}

static void shim_append_argv(const char* arg) {
    int argc = g_main_args.argc;
    char** argv = g_main_args.argv;
    char** next = (char**)realloc(argv, (size_t)(argc + 2) * sizeof(char*));
    if (!next) {
        return;
    }
    next[argc] = strdup(arg);
    next[argc + 1] = NULL;
    g_main_args.argc = argc + 1;
    g_main_args.argv = next;
}

static void shim_init_vtables(void) {
    static int initialized = 0;
    if (initialized) {
        return;
    }
    initialized = 1;

    memset(&g_life_span_handler, 0, sizeof(g_life_span_handler));
    g_life_span_handler.base.size = sizeof(cef_life_span_handler_t);
    g_life_span_handler.base.add_ref = shim_add_ref;
    g_life_span_handler.base.release = shim_release;
    g_life_span_handler.base.has_one_ref = shim_has_one_ref;
    g_life_span_handler.base.has_at_least_one_ref = shim_has_at_least_one_ref;
    g_life_span_handler.on_after_created = shim_on_after_created;
    g_life_span_handler.on_before_close = shim_on_before_close;

    memset(&g_client, 0, sizeof(g_client));
    g_client.base.size = sizeof(cef_client_t);
    g_client.base.add_ref = shim_add_ref;
    g_client.base.release = shim_release;
    g_client.base.has_one_ref = shim_has_one_ref;
    g_client.base.has_at_least_one_ref = shim_has_at_least_one_ref;
    g_client.get_life_span_handler = shim_get_life_span_handler;
    g_client.get_load_handler = shim_get_load_handler;
    g_client.get_display_handler = shim_get_display_handler;

    memset(&g_display_handler, 0, sizeof(g_display_handler));
    g_display_handler.base.size = sizeof(cef_display_handler_t);
    g_display_handler.base.add_ref = shim_add_ref;
    g_display_handler.base.release = shim_release;
    g_display_handler.base.has_one_ref = shim_has_one_ref;
    g_display_handler.base.has_at_least_one_ref = shim_has_at_least_one_ref;
    g_display_handler.on_console_message = shim_on_console_message;

    memset(&g_load_handler, 0, sizeof(g_load_handler));
    g_load_handler.base.size = sizeof(cef_load_handler_t);
    g_load_handler.base.add_ref = shim_add_ref;
    g_load_handler.base.release = shim_release;
    g_load_handler.base.has_one_ref = shim_has_one_ref;
    g_load_handler.base.has_at_least_one_ref = shim_has_at_least_one_ref;
    g_load_handler.on_load_start = shim_on_load_start;
    g_load_handler.on_load_end = shim_on_load_end;
    g_load_handler.on_load_error = shim_on_load_error;

    /* Render process handler: inject __JAC_DESKTOP__ before page scripts. */
    memset(&g_render_process_handler, 0, sizeof(g_render_process_handler));
    g_render_process_handler.base.size = sizeof(cef_render_process_handler_t);
    g_render_process_handler.base.add_ref = shim_add_ref;
    g_render_process_handler.base.release = shim_release;
    g_render_process_handler.base.has_one_ref = shim_has_one_ref;
    g_render_process_handler.base.has_at_least_one_ref = shim_has_at_least_one_ref;
    g_render_process_handler.on_context_created = shim_on_context_created;

    memset(&g_app, 0, sizeof(g_app));
    g_app.base.size = sizeof(cef_app_t);
    g_app.base.add_ref = shim_add_ref;
    g_app.base.release = shim_release;
    g_app.base.has_one_ref = shim_has_one_ref;
    g_app.base.has_at_least_one_ref = shim_has_at_least_one_ref;
    g_app.on_before_command_line_processing =
        shim_on_before_command_line_processing;
    g_app.get_render_process_handler = shim_get_render_process_handler;

    memset(&g_browser_process_handler, 0, sizeof(g_browser_process_handler));
    g_browser_process_handler.base.size = sizeof(cef_browser_process_handler_t);
    g_browser_process_handler.base.add_ref = shim_add_ref;
    g_browser_process_handler.base.release = shim_release;
    g_browser_process_handler.base.has_one_ref = shim_has_one_ref;
    g_browser_process_handler.base.has_at_least_one_ref = shim_has_at_least_one_ref;
    g_browser_process_handler.on_context_initialized = shim_on_context_initialized;

    g_app.get_browser_process_handler = shim_get_browser_process_handler;
}

/* --- String helpers -------------------------------------------------------- */

static void shim_set_cef_string_utf8(cef_string_t* out, const char* src) {
    if (out == NULL) {
        return;
    }
    cef_string_utf8_to_utf16(src, src ? (size_t)strlen(src) : 0, out);
}

static void shim_cmd_append_switch(cef_command_line_t* cmd, const char* name) {
    cef_string_t sw;
    if (cmd == NULL || name == NULL) {
        return;
    }
    memset(&sw, 0, sizeof(sw));
    shim_set_cef_string_utf8(&sw, name);
    cmd->append_switch(cmd, &sw);
    cef_string_utf16_clear(&sw);
}

static void shim_cmd_append_switch_value(cef_command_line_t* cmd,
                                         const char* name,
                                         const char* value) {
    cef_string_t n;
    cef_string_t v;
    if (cmd == NULL || name == NULL || value == NULL) {
        return;
    }
    memset(&n, 0, sizeof(n));
    memset(&v, 0, sizeof(v));
    shim_set_cef_string_utf8(&n, name);
    shim_set_cef_string_utf8(&v, value);
    cmd->append_switch_with_value(cmd, &n, &v);
    cef_string_utf16_clear(&n);
    cef_string_utf16_clear(&v);
}

/* Software rendering flags for all CEF subprocesses (browser/GPU/renderer). */
static void shim_apply_linux_gpu_flags(cef_command_line_t* command_line) {
    if (command_line == NULL) {
        return;
    }
    /* Prefer native X11 GL; ANGLE/Vulkan SwiftShader often fails on Linux. */
    shim_cmd_append_switch_value(command_line, "ozone-platform", "x11");
    shim_cmd_append_switch_value(command_line, "use-gl", "desktop");
    shim_cmd_append_switch(command_line, "disable-gpu-sandbox");
    shim_cmd_append_switch(command_line, "disable-dev-shm-usage");
    if (getenv("JAC_CEF_DISABLE_GPU") != NULL) {
        shim_cmd_append_switch(command_line, "disable-gpu");
        shim_cmd_append_switch(command_line, "disable-gpu-compositing");
        shim_cmd_append_switch(command_line, "enable-software-rasterizer");
    }
    if (getenv("JAC_CEF_SINGLE_PROCESS") != NULL) {
        shim_cmd_append_switch(command_line, "single-process");
    }
}

static void CEF_CALLBACK shim_on_before_command_line_processing(
    cef_app_t* self,
    const cef_string_t* process_type,
    cef_command_line_t* command_line) {
    (void)self;
    (void)process_type;
    shim_apply_linux_gpu_flags(command_line);
}

static intptr_t shim_do_create_browser(const char* url, const char* title,
                                       int width, int height) {
    cef_window_info_t window_info;
    cef_browser_settings_t browser_settings;
    cef_string_t url_str;

    memset(&window_info, 0, sizeof(window_info));
    shim_set_cef_string_utf8(&window_info.window_name, title);
    window_info.bounds.x = 0;
    window_info.bounds.y = 0;
    window_info.bounds.width = width > 0 ? width : 800;
    window_info.bounds.height = height > 0 ? height : 600;
    window_info.parent_window = 0;
    window_info.windowless_rendering_enabled = 0;

    memset(&browser_settings, 0, sizeof(browser_settings));
    browser_settings.size = sizeof(cef_browser_settings_t);
    browser_settings.local_storage = 1;
    browser_settings.javascript = 1;

    memset(&url_str, 0, sizeof(url_str));
    shim_set_cef_string_utf8(&url_str, url != NULL ? url : "about:blank");

    fprintf(stderr, "[cef] creating browser: %s\n",
            url != NULL ? url : "about:blank");
    fflush(stderr);

    /* Async create (required when called from on_context_initialized). */
    {
        int ok = cef_browser_host_create_browser(
            &window_info, &g_client, &url_str, &browser_settings, NULL, NULL);
        cef_string_utf16_clear(&url_str);
        cef_string_utf16_clear(&window_info.window_name);
        if (!ok) {
            fprintf(stderr, "[cef] browser creation failed\n");
            fflush(stderr);
            return 0;
        }
        return 1;
    }
}

static void CEF_CALLBACK shim_on_context_initialized(
    cef_browser_process_handler_t* self) {
    (void)self;
    g_context_ready = 1;
    fprintf(stderr, "[cef] context initialized\n");
    fflush(stderr);
    if (g_pending_browser.pending) {
        shim_do_create_browser(
            g_pending_browser.url, g_pending_browser.title,
            g_pending_browser.width, g_pending_browser.height);
        g_pending_browser.pending = 0;
    }
}

static cef_browser_process_handler_t* CEF_CALLBACK
shim_get_browser_process_handler(cef_app_t* self) {
    (void)self;
    return &g_browser_process_handler;
}

/* --- Exported Jac FFI surface (libcef_shim.so) --------------------------- */

/*
 * cef_execute_process wrapper. Returns -1 for the main browser process
 * (caller should continue), or a subprocess exit code (caller should exit).
 */
/* Read /proc/self/cmdline to reconstruct argc/argv.
   CEF re-execs the binary with --type=renderer etc. and needs to see those
   flags to distinguish main vs subprocess. /proc/self/cmdline preserves
   the full command line including CEF's added flags. */
static void shim_read_cmdline(cef_main_args_t* out) {
    FILE* f;
    char buf[8192];
    char** argv;
    int argc, i;
    size_t n;
    char* p;

    f = fopen("/proc/self/cmdline", "rb");
    if (!f) {
        /* Fallback: use /proc/self/exe as argv[0] */
        char* fallback = (char*)malloc(4096);
        if (fallback) {
            ssize_t len = readlink("/proc/self/exe", fallback, 4095);
            fallback[len > 0 ? len : 0] = '\0';
        }
        static char* fb_ptr;
        fb_ptr = fallback;
        out->argc = 1;
        out->argv = &fb_ptr;
        return;
    }

    n = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);
    buf[n] = '\0';

    /* Count arguments (NUL-separated) */
    argc = 0;
    p = buf;
    while (p < buf + n) {
        argc++;
        p += strlen(p) + 1;
    }

    /* Build argv array */
    argv = (char**)malloc((argc + 1) * sizeof(char*));
    p = buf;
    for (i = 0; i < argc; i++) {
        argv[i] = strdup(p);
        p += strlen(p) + 1;
    }
    argv[argc] = NULL;

    out->argc = argc;
    out->argv = argv;
}

int jac_cef_execute_process(void) {
    shim_init_vtables();
    shim_read_cmdline(&g_main_args);
    return cef_execute_process(&g_main_args, &g_app, NULL);
}

/*
 * Initialize CEF on the main process. cache_path may be "" for defaults.
 * no_sandbox: 1 disables the renderer sandbox (common on dev Linux).
 * Returns 1 on success.
 */
int jac_cef_initialize(const char* cache_path, int no_sandbox) {
    cef_settings_t settings;
    char exe_dir[4096];
    char locales_dir[4096];

    memset(&settings, 0, sizeof(settings));
    settings.size = sizeof(cef_settings_t);
    settings.no_sandbox = no_sandbox ? 1 : 0;
    settings.multi_threaded_message_loop = 0;
    settings.windowless_rendering_enabled = 0;
    if (cache_path != NULL && cache_path[0] != '\0') {
        shim_set_cef_string_utf8(&settings.cache_path, cache_path);
    }

    shim_get_exe_dir(exe_dir, sizeof(exe_dir));
    if (exe_dir[0] != '\0') {
        shim_set_cef_string_utf8(&settings.resources_dir_path, exe_dir);
        snprintf(locales_dir, sizeof(locales_dir), "%s/locales", exe_dir);
        shim_set_cef_string_utf8(&settings.locales_dir_path, locales_dir);
    }

    return cef_initialize(&g_main_args, &settings, &g_app, NULL);
}

void jac_cef_shutdown(void) {
    cef_shutdown();
}

void jac_cef_run_message_loop(void) {
    cef_run_message_loop();
}

void jac_cef_quit_message_loop(void) {
    cef_quit_message_loop();
}

/*
 * Create a browser window synchronously. Returns an opaque browser handle
 * (cef_browser_t* cast to intptr_t), or 0 on failure.
 */
intptr_t jac_cef_create_browser(const char* url, const char* title, int width,
                                int height) {
    const char* u = url != NULL ? url : "about:blank";
    const char* t = title != NULL ? title : "Jac Desktop";

    strncpy(g_pending_browser.url, u, sizeof(g_pending_browser.url) - 1);
    g_pending_browser.url[sizeof(g_pending_browser.url) - 1] = '\0';
    strncpy(g_pending_browser.title, t, sizeof(g_pending_browser.title) - 1);
    g_pending_browser.title[sizeof(g_pending_browser.title) - 1] = '\0';
    g_pending_browser.width = width;
    g_pending_browser.height = height;
    g_pending_browser.pending = 1;
    return 1;
}

/* Navigate the main frame of an existing browser to url. */
void jac_cef_navigate(intptr_t browser_handle, const char* url) {
    cef_browser_t* browser = (cef_browser_t*)browser_handle;
    cef_frame_t* frame;
    cef_string_t url_str;

    if (browser == NULL || url == NULL) {
        return;
    }
    frame = browser->get_main_frame(browser);
    if (frame == NULL || frame->load_url == NULL) {
        return;
    }
    memset(&url_str, 0, sizeof(url_str));
    shim_set_cef_string_utf8(&url_str, url);
    frame->load_url(frame, &url_str);
    cef_string_utf16_clear(&url_str);
}
