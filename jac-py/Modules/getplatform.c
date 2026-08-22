/* Header-free extract of CPython Python/getplatform.c (Py_GetPlatform). */

#ifndef PLATFORM
#define PLATFORM "linux"
#endif

const char *
Py_GetPlatform(void)
{
    return PLATFORM;
}
