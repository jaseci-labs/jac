glob NATIVE_TIME_FUNCS: set[str] = {
         "time",
         "monotonic",
         "perf_counter",
         "time_ns",
         "monotonic_ns",
         "perf_counter_ns",
         "sleep",

     };
glob NATIVE_OS_FUNCS: set[str] = {
         "getpid",
         "getcwd",
         "getenv",
         "chdir",
         "mkdir",
         "makedirs",
         "rmdir",
         "remove",
         "unlink",
         "rename",
         "system",

     };
glob NATIVE_OSPATH_FUNCS: set[str] = {
         "join",
         "basename",
         "dirname",
         "realpath",
         "exists",
         "isfile",
         "isdir",
         "getsize",
         "getmtime",
         "normcase",

     };
glob NATIVE_RANDOM_FUNCS: set[str] = {
         "seed",
         "random",
         "getrandbits",
         "randint",
         "randrange",
         "uniform",

     };
glob NATIVE_STRUCT_FUNCS: set[str] = {"pack", "unpack", "calcsize", "pack_into", };
glob RC_COLOR_BLACK: int = 0,
     RC_COLOR_WHITE: int = 1,
     RC_COLOR_GRAY: int = 2,
     RC_COLOR_PURPLE: int = 3,
     RC_BUFFERED_BIT: int = 4,
     RC_COLOR_SHIFT: int = 48,
     RC_CYCLE_THRESHOLD: int = 1000;
glob LIVE_NODE_ID_OFF: int = 0,
     LIVE_NODE_USER_OFF: int = 8,
     LIVE_NODE_TAG_OFF: int = 16,
     LIVE_NODE_RC_OFF: int = 24,
     LIVE_NODE_NEXT_OFF: int = 32,
     LIVE_NODE_SIZE: int = 40;
