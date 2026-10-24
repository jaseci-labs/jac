glob WIN_CRT_DLL: str = "ucrtbase.dll",
     WIN_CRT_ALIAS: dict[str, str] = {
         "strtol": "strtoll",
         "strtoul": "strtoull",
         "atol": "atoll",
         "labs": "llabs",
         "lround": "llround",
         "lroundf": "llroundf",
         "lrint": "llrint",
         "lrintf": "llrintf",
         "malloc_usable_size": "_msize",
         "strdup": "_strdup",
         "getpid": "_getpid",
         "chdir": "_chdir",
         "rmdir": "_rmdir",
         "unlink": "_unlink",
         "fileno": "_fileno",
         "isatty": "_isatty",
         "close": "_close",
         "read": "_read",
         "write": "_write",
         "dup": "_dup",
         "dup2": "_dup2",
         "strcasecmp": "_stricmp",
         "strncasecmp": "_strnicmp",
         "fseek": "_fseeki64",
         "ftell": "_ftelli64",
         "fseeko": "_fseeki64",
         "ftello": "_ftelli64",
         "lseek": "_lseeki64",
         "putenv": "_putenv",
         "tzset": "_tzset",
         "timegm": "_mkgmtime64",
         "mktime": "_mktime64",
         "time": "_time64",
         "strtok_r": "strtok_s",
         "_exit": "_Exit",
         "j0": "_j0",
         "j1": "_j1",
         "y0": "_y0",
         "y1": "_y1"
     },
     WIN_UCRT_PREFIX: str = "__ucrt_",
     WIN_CRT_LIBRARIES: list[str] = [
         "c.dll",
         "m.dll",
         "pthread.dll",
         "dl.dll",
         "rt.dll",
         "msvcrt.dll"
     ];

def win_import_dll(name: str, declared: (str | None), crt: str = "") -> str;

def win_import_name(name: str) -> str;

def _win_jmp_ir -> str;

def win_floor_ir -> str;
