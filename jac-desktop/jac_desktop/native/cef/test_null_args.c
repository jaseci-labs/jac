#include <stdio.h>
#include <string.h>
#include "include/capi/cef_app_capi.h"
#include "include/internal/cef_types.h"
#include "include/internal/cef_types_linux.h"

static void stub_add_ref(cef_base_ref_counted_t* s) { (void)s; }
static int stub_release(cef_base_ref_counted_t* s) { (void)s; return 0; }
static int stub_has_one_ref(cef_base_ref_counted_t* s) { (void)s; return 1; }
static int stub_has_at_least_one_ref(cef_base_ref_counted_t* s) { (void)s; return 1; }

static cef_app_t g_app;

int main(int argc, char** argv) {
    memset(&g_app, 0, sizeof(g_app));
    g_app.base.size = sizeof(g_app);
    g_app.base.add_ref = stub_add_ref;
    g_app.base.release = stub_release;
    g_app.base.has_one_ref = stub_has_one_ref;
    g_app.base.has_at_least_one_ref = stub_has_at_least_one_ref;

    /* Pass NULL args - CEF uses /proc/self/cmdline on Linux */
    fprintf(stderr, "calling cef_execute_process(NULL args)...\n");
    int code = cef_execute_process(NULL, &g_app, NULL);
    fprintf(stderr, "returned: %d\n", code);
    return 0;
}
