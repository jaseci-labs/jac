/* cef_dispatch.c — thin vtable dispatch wrappers for CEF C API objects.
 *
 * Jac's clib FFI can create vtable structs and pass them to CEF, but cannot
 * call methods on CEF-returned objects through their vtable pointers.  This
 * file provides scalar wrappers for those vtable dispatch calls and for
 * creating CEF data structs whose layouts involve mixed-size fields and
 * cef_string_t (UTF-16) conversions that are impractical to express in
 * flat Jac clib structs.
 *
 * All exported functions take/return intptr_t (i64 in Jac) so the Jac side
 * treats every CEF object as an opaque integer handle.
 */

#define _POSIX_C_SOURCE 200809L

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_browser_capi.h"
#include "include/capi/cef_browser_process_handler_capi.h"
#include "include/capi/cef_command_line_capi.h"
#include "include/capi/cef_display_handler_capi.h"
#include "include/capi/cef_frame_capi.h"
#include "include/capi/cef_life_span_handler_capi.h"
#include "include/capi/cef_load_handler_capi.h"
#include "include/capi/cef_render_process_handler_capi.h"
#include "include/capi/cef_v8_capi.h"
#include "include/internal/cef_string.h"
#include "include/internal/cef_types.h"

/* --- CEF object method dispatch (vtable indirection) ---------------------- */

intptr_t cef_dispatch_browser_get_main_frame(intptr_t browser) {
    cef_browser_t* b = (cef_browser_t*)browser;
    return (intptr_t)b->get_main_frame(b);
}

int cef_dispatch_frame_is_main(intptr_t frame) {
    cef_frame_t* f = (cef_frame_t*)frame;
    return f->is_main(f);
}

void cef_dispatch_frame_load_url(intptr_t frame, const char* url) {
    cef_frame_t* f = (cef_frame_t*)frame;
    cef_string_t s = {0};
    cef_string_utf8_to_utf16(url, strlen(url), &s);
    f->load_url(f, &s);
    cef_string_utf16_clear(&s);
}

void cef_dispatch_frame_execute_js(intptr_t frame, const char* code,
                                   const char* url, int start_line) {
    cef_frame_t* f = (cef_frame_t*)frame;
    cef_string_t js = {0}, su = {0};
    cef_string_utf8_to_utf16(code, strlen(code), &js);
    cef_string_utf8_to_utf16(url, strlen(url), &su);
    f->execute_java_script(f, &js, &su, start_line);
    cef_string_utf16_clear(&js);
    cef_string_utf16_clear(&su);
}

void cef_dispatch_cmdline_append_switch(intptr_t cmd, const char* sw) {
    cef_command_line_t* c = (cef_command_line_t*)cmd;
    cef_string_t s = {0};
    cef_string_utf8_to_utf16(sw, strlen(sw), &s);
    c->append_switch(c, &s);
    cef_string_utf16_clear(&s);
}

void cef_dispatch_cmdline_append_switch_value(intptr_t cmd,
                                               const char* name,
                                               const char* value) {
    cef_command_line_t* c = (cef_command_line_t*)cmd;
    cef_string_t n = {0}, v = {0};
    cef_string_utf8_to_utf16(name, strlen(name), &n);
    cef_string_utf8_to_utf16(value, strlen(value), &v);
    c->append_switch_with_value(c, &n, &v);
    cef_string_utf16_clear(&n);
    cef_string_utf16_clear(&v);
}

void cef_dispatch_base_release(intptr_t handle) {
    cef_base_ref_counted_t* b = (cef_base_ref_counted_t*)handle;
    b->release(b);
}

int cef_dispatch_create_browser(intptr_t window_info, intptr_t client,
                                 const char* url, intptr_t settings) {
    cef_string_t url_str = {0};
    cef_string_utf8_to_utf16(url, strlen(url), &url_str);
    int result = cef_browser_host_create_browser(
        (cef_window_info_t*)window_info, (cef_client_t*)client,
        &url_str, (cef_browser_settings_t*)settings, NULL, NULL);
    cef_string_utf16_clear(&url_str);
    return result;
}

const char* cef_dispatch_get_exe_dir(void) {
    static char buf[4096];
    ssize_t n = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
    if (n <= 0) { buf[0] = '\0'; return buf; }
    buf[n] = '\0';
    char* slash = strrchr(buf, '/');
    if (slash) *slash = '\0';
    return buf;
}

/* --- Data struct allocation ----------------------------------------------- */

intptr_t cef_dispatch_settings_create(int no_sandbox,
                                       const char* cache_path,
                                       const char* resources_dir,
                                       const char* locales_dir) {
    cef_settings_t* s = (cef_settings_t*)calloc(1, sizeof(cef_settings_t));
    s->size = sizeof(cef_settings_t);
    s->no_sandbox = no_sandbox;
    if (cache_path && cache_path[0])
        cef_string_utf8_to_utf16(cache_path, strlen(cache_path), &s->cache_path);
    if (resources_dir && resources_dir[0])
        cef_string_utf8_to_utf16(resources_dir, strlen(resources_dir),
                                  &s->resources_dir_path);
    if (locales_dir && locales_dir[0])
        cef_string_utf8_to_utf16(locales_dir, strlen(locales_dir),
                                  &s->locales_dir_path);
    return (intptr_t)s;
}

intptr_t cef_dispatch_window_info_create(const char* title,
                                          int width, int height) {
    cef_window_info_t* w = (cef_window_info_t*)calloc(1, sizeof(cef_window_info_t));
    if (title)
        cef_string_utf8_to_utf16(title, strlen(title), &w->window_name);
    w->bounds.width = width > 0 ? width : 800;
    w->bounds.height = height > 0 ? height : 600;
    return (intptr_t)w;
}

intptr_t cef_dispatch_browser_settings_create(void) {
    cef_browser_settings_t* s = (cef_browser_settings_t*)calloc(
        1, sizeof(cef_browser_settings_t));
    s->size = sizeof(cef_browser_settings_t);
    s->local_storage = 1;
    s->javascript = 1;
    return (intptr_t)s;
}

intptr_t cef_dispatch_main_args_create(void) {
    cef_main_args_t* a = (cef_main_args_t*)calloc(1, sizeof(cef_main_args_t));
    FILE* f;
    char buf[8192];
    size_t n;
    char* p;
    int argc, i;
    char** argv;

    f = fopen("/proc/self/cmdline", "rb");
    if (!f) {
        a->argc = 0;
        a->argv = NULL;
        return (intptr_t)a;
    }
    n = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);
    buf[n] = '\0';

    argc = 0;
    p = buf;
    while (p < buf + n) { argc++; p += strlen(p) + 1; }

    argv = (char**)malloc((argc + 1) * sizeof(char*));
    p = buf;
    for (i = 0; i < argc; i++) { argv[i] = strdup(p); p += strlen(p) + 1; }
    argv[argc] = NULL;
    a->argc = argc;
    a->argv = argv;
    return (intptr_t)a;
}
