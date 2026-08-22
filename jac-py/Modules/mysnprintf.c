#include <stdarg.h>
#include <stdio.h>

int PyOS_vsnprintf(char *str, unsigned long size, const char *format, va_list va);

int PyOS_snprintf(char *str, unsigned long size, const char *format, ...) {
    int rc;
    va_list va;
    va_start(va, format);
    rc = PyOS_vsnprintf(str, size, format, va);
    va_end(va);
    return rc;
}

int PyOS_vsnprintf(char *str, unsigned long size, const char *format, va_list va) {
    int len;
    if (size > 2147483646) {
        len = -666;
    } else {
        len = vsnprintf(str, size, format, va);
    }
    if (size > 0 && size <= 2147483646) {
        str[size - 1] = 0;
    }
    return len;
}
