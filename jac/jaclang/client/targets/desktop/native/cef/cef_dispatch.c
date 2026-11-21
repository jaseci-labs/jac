// CEF glue for Jac desktop apps, built against the C API headers of the
// pinned CEF distribution. The host calls the exported cef_dispatch_* functions.

#define _GNU_SOURCE
#include <dlfcn.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_browser_capi.h"
#include "include/capi/cef_browser_process_handler_capi.h"
#include "include/capi/cef_client_capi.h"
#include "include/capi/cef_command_line_capi.h"
#include "include/capi/cef_frame_capi.h"
#include "include/capi/cef_life_span_handler_capi.h"
#include "include/capi/cef_render_process_handler_capi.h"

#include "bootstrap_js.h"

#define JAC_EXPORT __attribute__((visibility("default")))

static int g_argc;
static char** g_argv;
static char g_exe_dir[PATH_MAX];
static cef_browser_t* g_browser;
static char* g_pending_url;
static char* g_pending_title;
static long g_pending_width;
static long g_pending_height;

__attribute__((constructor)) static void capture_args(int argc, char** argv) {
  g_argc = argc;
  g_argv = argv;
}

static void jac_log(const char* msg) {
  fprintf(stderr, "[cef] %s\n", msg);
}

static void set_string(cef_string_t* out, const char* utf8) {
  cef_string_from_utf8(utf8, strlen(utf8), out);
}

static int exe_path(char* out, const char* name) {
  int n = snprintf(out, PATH_MAX, "%s/%s", g_exe_dir, name);
  return n > 0 && n < PATH_MAX;
}

static void bootstrap(void) {
  if (g_exe_dir[0] == '\0') {
    ssize_t n = readlink("/proc/self/exe", g_exe_dir, sizeof(g_exe_dir) - 1);
    if (n > 0) {
      g_exe_dir[n] = '\0';
      char* slash = strrchr(g_exe_dir, '/');
      if (slash != NULL) {
        *slash = '\0';
      }
    }
  }
  setenv("NO_AT_BRIDGE", "1", 0);
  char fonts[PATH_MAX];
  if (exe_path(fonts, "minimal-fonts.conf") && access(fonts, R_OK) == 0) {
    setenv("FONTCONFIG_FILE", fonts, 0);
  }
}

// Handlers are static and live for the whole process, so reference counting
// is a no-op on our side.
static void CEF_CALLBACK add_ref(cef_base_ref_counted_t* self) {}
static int CEF_CALLBACK release(cef_base_ref_counted_t* self) {
  return 0;
}
static int CEF_CALLBACK has_one_ref(cef_base_ref_counted_t* self) {
  return 1;
}

static void init_base(cef_base_ref_counted_t* base, size_t size) {
  base->size = size;
  base->add_ref = add_ref;
  base->release = release;
  base->has_one_ref = has_one_ref;
  base->has_at_least_one_ref = has_one_ref;
}

static void release_ref(void* object) {
  cef_base_ref_counted_t* base = object;
  if (base != NULL) {
    base->release(base);
  }
}

static cef_life_span_handler_t g_life_span;
static cef_client_t g_client;
static cef_browser_process_handler_t g_browser_process;
static cef_render_process_handler_t g_render_process;
static cef_app_t g_app;

static void create_browser(const char* url, const char* title, long width, long height) {
  cef_window_info_t window = {0};
  set_string(&window.window_name, title);
  window.bounds.x = 100;
  window.bounds.y = 100;
  window.bounds.width = width > 0 ? (int)width : 800;
  window.bounds.height = height > 0 ? (int)height : 600;
  cef_browser_settings_t settings = {0};
  settings.size = sizeof(settings);
  cef_string_t target = {0};
  set_string(&target, url);
  cef_browser_host_create_browser(&window, &g_client, &target, &settings, NULL, NULL);
  cef_string_clear(&target);
  cef_string_clear(&window.window_name);
}

static void CEF_CALLBACK on_after_created(cef_life_span_handler_t* self,
                                          cef_browser_t* browser) {
  g_browser = browser;
}

static void CEF_CALLBACK on_before_close(cef_life_span_handler_t* self,
                                         cef_browser_t* browser) {
  release_ref(g_browser);
  g_browser = NULL;
  release_ref(browser);
  cef_quit_message_loop();
}

static cef_life_span_handler_t* CEF_CALLBACK get_life_span_handler(cef_client_t* self) {
  return &g_life_span;
}

static void CEF_CALLBACK on_context_initialized(cef_browser_process_handler_t* self) {
  if (g_pending_url != NULL) {
    create_browser(g_pending_url, g_pending_title, g_pending_width, g_pending_height);
    free(g_pending_url);
    free(g_pending_title);
    g_pending_url = NULL;
    g_pending_title = NULL;
  }
}

static void CEF_CALLBACK on_context_created(cef_render_process_handler_t* self,
                                            cef_browser_t* browser,
                                            cef_frame_t* frame,
                                            cef_v8context_t* context) {
  if (frame->is_main(frame)) {
    cef_string_t code = {0};
    cef_string_t source = {0};
    set_string(&code, JAC_BOOTSTRAP_JS);
    set_string(&source, "jac://bootstrap");
    frame->execute_java_script(frame, &code, &source, 0);
    cef_string_clear(&code);
    cef_string_clear(&source);
    jac_log("render: bootstrap injected");
  }
  release_ref(context);
  release_ref(frame);
  release_ref(browser);
}

static void append_switch(cef_command_line_t* line, const char* name, const char* value) {
  cef_string_t key = {0};
  set_string(&key, name);
  if (value == NULL) {
    line->append_switch(line, &key);
  } else {
    cef_string_t val = {0};
    set_string(&val, value);
    line->append_switch_with_value(line, &key, &val);
    cef_string_clear(&val);
  }
  cef_string_clear(&key);
}

static int env_set(const char* name) {
  const char* value = getenv(name);
  return value != NULL && value[0] != '\0';
}

static void CEF_CALLBACK on_before_command_line_processing(cef_app_t* self,
                                                           const cef_string_t* process_type,
                                                           cef_command_line_t* line) {
  if (env_set("JAC_CEF_SINGLE_PROCESS")) {
    append_switch(line, "single-process", NULL);
  }
  if (env_set("JAC_CEF_HEADLESS")) {
    append_switch(line, "headless", NULL);
    append_switch(line, "disable-gpu", NULL);
  }
  if (env_set("JAC_CEF_DISABLE_GPU")) {
    append_switch(line, "disable-gpu", NULL);
    append_switch(line, "disable-gpu-compositing", NULL);
  }
  if (env_set("JAC_CEF_IN_PROCESS_GPU")) {
    append_switch(line, "in-process-gpu", NULL);
  }
  if (env_set("JAC_CEF_VERBOSE")) {
    append_switch(line, "enable-logging", "stderr");
    append_switch(line, "v", "1");
  }
  if (env_set("JAC_CEF_USER_DATA_DIR")) {
    append_switch(line, "user-data-dir", getenv("JAC_CEF_USER_DATA_DIR"));
  }
  release_ref(line);
}

static cef_browser_process_handler_t* CEF_CALLBACK get_browser_process_handler(cef_app_t* self) {
  return &g_browser_process;
}

static cef_render_process_handler_t* CEF_CALLBACK get_render_process_handler(cef_app_t* self) {
  return &g_render_process;
}

static void init_handlers(void) {
  if (g_app.base.size != 0) {
    return;
  }
  init_base(&g_life_span.base, sizeof(g_life_span));
  g_life_span.on_after_created = on_after_created;
  g_life_span.on_before_close = on_before_close;
  init_base(&g_client.base, sizeof(g_client));
  g_client.get_life_span_handler = get_life_span_handler;
  init_base(&g_browser_process.base, sizeof(g_browser_process));
  g_browser_process.on_context_initialized = on_context_initialized;
  init_base(&g_render_process.base, sizeof(g_render_process));
  g_render_process.on_context_created = on_context_created;
  init_base(&g_app.base, sizeof(g_app));
  g_app.on_before_command_line_processing = on_before_command_line_processing;
  g_app.get_browser_process_handler = get_browser_process_handler;
  g_app.get_render_process_handler = get_render_process_handler;
}

JAC_EXPORT int cef_dispatch_execute_process(void) {
  bootstrap();
  init_handlers();
  cef_main_args_t args = {g_argc, g_argv};
  return cef_execute_process(&args, &g_app, NULL);
}

JAC_EXPORT int cef_dispatch_startup(const char* cache_path, long no_sandbox) {
  bootstrap();
  init_handlers();
  jac_log("startup: initializing CEF");
  cef_settings_t settings = {0};
  settings.size = sizeof(settings);
  settings.no_sandbox = (int)no_sandbox;
  settings.log_severity = LOGSEVERITY_WARNING;
  if (cache_path != NULL && cache_path[0] != '\0') {
    set_string(&settings.cache_path, cache_path);
  }
  char path[PATH_MAX];
  set_string(&settings.resources_dir_path, g_exe_dir);
  if (exe_path(path, "locales")) {
    set_string(&settings.locales_dir_path, path);
  }
  if (exe_path(path, "cef-subprocess") && access(path, X_OK) == 0) {
    set_string(&settings.browser_subprocess_path, path);
  }
  signal(SIGCHLD, SIG_DFL);
  cef_main_args_t args = {g_argc, g_argv};
  int ok = cef_initialize(&args, &settings, &g_app, NULL);
  jac_log(ok == 1 ? "startup: cef_initialize ok" : "startup: cef_initialize failed");
  cef_string_clear(&settings.cache_path);
  cef_string_clear(&settings.resources_dir_path);
  cef_string_clear(&settings.locales_dir_path);
  cef_string_clear(&settings.browser_subprocess_path);
  return ok;
}

JAC_EXPORT void cef_dispatch_set_pending_browser(const char* url, const char* title,
                                                 long width, long height) {
  free(g_pending_url);
  free(g_pending_title);
  g_pending_url = strdup(url);
  g_pending_title = strdup(title);
  g_pending_width = width;
  g_pending_height = height;
}

JAC_EXPORT void cef_dispatch_open_browser(const char* url, const char* title,
                                          long width, long height) {
  init_handlers();
  create_browser(url, title, width, height);
}

JAC_EXPORT void cef_dispatch_navigate(const char* url) {
  if (g_browser == NULL) {
    return;
  }
  cef_frame_t* frame = g_browser->get_main_frame(g_browser);
  if (frame != NULL) {
    cef_string_t target = {0};
    set_string(&target, url);
    frame->load_url(frame, &target);
    cef_string_clear(&target);
    release_ref(frame);
  }
}

// Xlib is loaded at run time: libcef already depends on it, and this keeps the
// build free of X11 development headers.
typedef struct {
  void* (*open_display)(const char*);
  int (*close_display)(void*);
  unsigned long (*default_root_window)(void*);
  int (*query_tree)(void*, unsigned long, unsigned long*, unsigned long*,
                    unsigned long**, unsigned int*);
  unsigned long (*intern_atom)(void*, const char*, int);
  int (*get_window_property)(void*, unsigned long, unsigned long, long, long, int,
                             unsigned long, unsigned long*, int*, unsigned long*,
                             unsigned long*, unsigned char**);
  int (*store_name)(void*, unsigned long, const char*);
  int (*change_property)(void*, unsigned long, unsigned long, unsigned long, int,
                         int, const unsigned char*, int);
  int (*resize_window)(void*, unsigned long, unsigned int, unsigned int);
  int (*flush)(void*);
  int (*xfree)(void*);
} xlib_t;

static int load_xlib(xlib_t* x) {
  static void* lib;
  if (lib == NULL) {
    lib = dlopen("libX11.so.6", RTLD_LAZY);
  }
  if (lib == NULL) {
    return 0;
  }
  x->open_display = dlsym(lib, "XOpenDisplay");
  x->close_display = dlsym(lib, "XCloseDisplay");
  x->default_root_window = dlsym(lib, "XDefaultRootWindow");
  x->query_tree = dlsym(lib, "XQueryTree");
  x->intern_atom = dlsym(lib, "XInternAtom");
  x->get_window_property = dlsym(lib, "XGetWindowProperty");
  x->store_name = dlsym(lib, "XStoreName");
  x->change_property = dlsym(lib, "XChangeProperty");
  x->resize_window = dlsym(lib, "XResizeWindow");
  x->flush = dlsym(lib, "XFlush");
  x->xfree = dlsym(lib, "XFree");
  return x->open_display != NULL && x->xfree != NULL;
}

// CEF's handle is a child window; the window manager decorates the ancestor
// that carries WM_STATE, which is the one to retitle or resize.
static unsigned long toplevel_window(xlib_t* x, void* display, unsigned long window) {
  unsigned long root = x->default_root_window(display);
  unsigned long wm_state = x->intern_atom(display, "WM_STATE", 1);
  unsigned long current = window;
  for (int depth = 0; depth < 24 && current != 0 && current != root; depth++) {
    unsigned long type = 0, items = 0, after = 0;
    int format = 0;
    unsigned char* data = NULL;
    if (wm_state != 0 &&
        x->get_window_property(display, current, wm_state, 0, 0, 0, 0, &type, &format,
                               &items, &after, &data) == 0) {
      if (data != NULL) {
        x->xfree(data);
      }
      if (type != 0) {
        return current;
      }
    }
    unsigned long tree_root = 0, parent = 0;
    unsigned long* children = NULL;
    unsigned int count = 0;
    if (!x->query_tree(display, current, &tree_root, &parent, &children, &count)) {
      return current;
    }
    if (children != NULL) {
      x->xfree(children);
    }
    if (parent == 0 || parent == root) {
      return current;
    }
    current = parent;
  }
  return current != 0 ? current : window;
}

static void* open_browser_window(xlib_t* x, unsigned long* window) {
  if (g_browser == NULL || !load_xlib(x)) {
    return NULL;
  }
  cef_browser_host_t* host = g_browser->get_host(g_browser);
  if (host == NULL) {
    return NULL;
  }
  unsigned long handle = host->get_window_handle(host);
  release_ref(host);
  void* display = handle != 0 ? x->open_display(NULL) : NULL;
  if (display != NULL) {
    *window = toplevel_window(x, display, handle);
  }
  return display;
}

JAC_EXPORT int cef_dispatch_window_set_title(const char* title) {
  xlib_t x;
  unsigned long window = 0;
  void* display = open_browser_window(&x, &window);
  if (display == NULL) {
    return 0;
  }
  x.store_name(display, window, title);
  unsigned long net_name = x.intern_atom(display, "_NET_WM_NAME", 0);
  unsigned long utf8 = x.intern_atom(display, "UTF8_STRING", 0);
  if (net_name != 0 && utf8 != 0) {
    x.change_property(display, window, net_name, utf8, 8, 0,
                      (const unsigned char*)title, (int)strlen(title));
  }
  x.flush(display);
  x.close_display(display);
  return 1;
}

JAC_EXPORT int cef_dispatch_window_set_size(long width, long height) {
  if (width <= 0 || height <= 0) {
    return 0;
  }
  xlib_t x;
  unsigned long window = 0;
  void* display = open_browser_window(&x, &window);
  if (display == NULL) {
    return 0;
  }
  x.resize_window(display, window, (unsigned int)width, (unsigned int)height);
  x.flush(display);
  x.close_display(display);
  return 1;
}
