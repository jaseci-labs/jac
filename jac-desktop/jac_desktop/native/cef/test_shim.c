#include <stdio.h>
#include <stddef.h>
#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_life_span_handler_capi.h"
#include "include/capi/cef_client_capi.h"

int main(void) {
    printf("sizeof(cef_app_t) = %zu\n", sizeof(cef_app_t));
    printf("sizeof(cef_client_t) = %zu\n", sizeof(cef_client_t));
    printf("sizeof(cef_life_span_handler_t) = %zu\n", sizeof(cef_life_span_handler_t));
    printf("offsetof(cef_app_t, base) = %zu\n", offsetof(cef_app_t, base));
    return 0;
}
