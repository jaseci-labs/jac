glob NATIVE_COPY_FUNCS: set[str] = {"copy", "deepcopy"};
glob NATIVE_OS_FUNCS: set[str] = {
         "getpid",
         "listdir",
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
glob NATIVE_STRUCT_FUNCS: set[str] = {
         "pack",
         "unpack",
         "calcsize",
         "pack_into",
         "unpack_from",

     };
glob RC_COLOR_BLACK: int = 0,
     RC_COLOR_WHITE: int = 1,
     RC_COLOR_GRAY: int = 2,
     RC_COLOR_PURPLE: int = 3,
     RC_BUFFERED_BIT: int = 4,
     RC_COLOR_SHIFT: int = 48,
     RC_CYCLE_THRESHOLD: int = 1000;

glob JACVAL_ELLIPSIS_TAG: int = 9;

glob CLASS_DISPLAY_OFF: int = 24;

# Field of a class record (`__jac_class_ctors`) holding the class's ancestry
# records, the `{name hash, class name}` MRO its defining module emits.
glob CLASS_RECORD_ANCESTRY: int = 6;

# The program's vtables, registered at initialization by the module that
# defines each one: `VTABLE_SET_BUCKETS` address-hashed lists of
# `{next, vtable}` nodes. A headerless build reads an erased object's first
# word as a vtable only once it is found here.
glob VTABLE_SET_SYMBOL: str = "__jac_vtables",
     VTABLE_SET_BUCKETS: int = 256;
glob LIVE_NODE_ID_OFF: int = 0,
     LIVE_NODE_USER_OFF: int = 8,
     LIVE_NODE_TAG_OFF: int = 16,
     LIVE_NODE_RC_OFF: int = 24,
     LIVE_NODE_NEXT_OFF: int = 32,
     LIVE_NODE_SIZE: int = 40;

glob NATIVE_CONTAINER_CODES: dict[str, str] = {"dict": "natdict", "set": "natset"};

glob EXC_LINEAGE_BITS: int = 11,
     EXC_LINEAGE_SLOTS: int = 2048,
     EXC_LINEAGE_MIX: int = -7046029254386353131,
     # The hidden local holding the exception a handler that binds no name
     # caught; not a valid Jac name, so no user variable can clash with it.
     UNBOUND_CAUGHT: str = "__jac caught";
