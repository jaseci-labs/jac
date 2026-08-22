/* Header-free extract of CPython Python/getcompiler.c (Py_GetCompiler). */

#ifndef COMPILER
#if defined(__clang__)
#define COMPILER "[Clang " __clang_version__ "]"
#elif defined(__GNUC__)
#define COMPILER "[GCC " __VERSION__ "]"
#elif defined(__cplusplus)
#define COMPILER "[C++]"
#else
#define COMPILER "[C]"
#endif
#endif

const char *
Py_GetCompiler(void)
{
    return COMPILER;
}
