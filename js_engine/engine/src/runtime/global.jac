"""Global Object Bootstrap.

JSGlobalObject wraps the globalThis JSObject (null prototype) and the libuv
loop pointer.  GlobalContext is the per-execution context threaded through all
runtime operations, analogous to Bun's `*JSGlobalObject` parameter pattern.

Bun Zig mapping:
  VirtualMachine.global : *JSGlobalObject  — root global object
  VirtualMachine itself                    — acts as GlobalContext
  VM.init() / initializeMain()             — init_global()
  global.throwException(err)               — throw_exception()
  global.hasException()                    — has_exception()

ECMAScript spec: §19 — The Global Object
  https://tc39.es/ecma262/#sec-global-object
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_false,
    js_int,
    js_number,
    js_nan,
    js_infinity,
    js_neg_infinity,
    jsv_is_undefined,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_from_string_id,
    jsv_from_htmldda_id,
    jsv_to_table_id,
    jsv_set_bigint_zero_id
}
import from engine.src.runtime.fn_meta { fn_meta_bind_closures }
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.runtime.jsobject {
    js_object_mark_global,
    JSProperty,
    js_object_create_null,
    js_object_create,
    js_object_set_ordinary_proto,
    js_function_set_proto,
    js_object_set_prototype,
    js_generator_set_intrinsics,
    js_iterator_set_native_protos,
    js_iterator_reparent_native_protos,
    js_object_get,
    js_object_set,
    js_object_has_own,
    js_object_define_property,
    js_object_define_nonenum,
    js_object_keys,
    js_object_all_keys,
    js_object_set_accessor_getter,
    js_object_set_accessor_setter,
    js_object_set_accessor_enumerable,
    js_object_set_accessor_configurable
}
import from engine.src.runtime.uncaught { print_uncaught }
import from engine.src.runtime.jsstring {
    str_intern,
    str_from_id,
    str_intern_seed_well_known,
    str_set_realm
}
import from engine.src.runtime.wk_keys { init_wk_keys }
import from engine.src.runtime.shape { shape_gate_set, shape_gate_enabled }
import from engine.src.runtime.jsobj_type {
    dense_gate_set,
    dense_gate_enabled,
    register_index_interner
}
import from engine.src.runtime.jsobject { obj_set_realm }

import from engine.src.builtins.native_registry {
    js_native_create,
    js_native_singleton,
    js_callable_create,
    native_set_realm
}
import from engine.src.builtins.function { fn_realm_set }
import from engine.src.runtime.proxy { proxy_init_keys }
import from engine.src.builtins.dispatch { init_dispatch_table }

import from engine.src.builtins.native_kinds {
    NATIVE_KIND_CONSOLE_LOG,
    NATIVE_KIND_CONSOLE_INFO,
    NATIVE_KIND_CONSOLE_DEBUG,
    NATIVE_KIND_CONSOLE_ERROR,
    NATIVE_KIND_CONSOLE_WARN,
    NATIVE_KIND_CONSOLE_DIR,
    NATIVE_KIND_CONSOLE_ASSERT,
    NATIVE_KIND_CONSOLE_COUNT,
    NATIVE_KIND_CONSOLE_COUNT_RESET,
    NATIVE_KIND_CONSOLE_TIME,
    NATIVE_KIND_CONSOLE_TIME_END,
    NATIVE_KIND_CONSOLE_TIME_LOG,
    NATIVE_KIND_CONSOLE_GROUP,
    NATIVE_KIND_CONSOLE_GROUP_COLLAPSED,
    NATIVE_KIND_CONSOLE_GROUP_END,
    NATIVE_KIND_CONSOLE_TABLE,
    NATIVE_KIND_PARSE_INT,
    NATIVE_KIND_PARSE_FLOAT,
    NATIVE_KIND_IS_NAN,
    NATIVE_KIND_IS_FINITE,
    NATIVE_KIND_NUMBER,
    NATIVE_KIND_BOOLEAN,
    NATIVE_KIND_STRING,
    NATIVE_KIND_BIGINT,
    NATIVE_KIND_BIGINT_TOSTRING,
    NATIVE_KIND_BIGINT_VALUEOF,
    NATIVE_KIND_BIGINT_TOLOCALESTRING,
    NATIVE_KIND_OBJECT,
    NATIVE_KIND_ARRAY,
    NATIVE_KIND_EVAL,
    NATIVE_KIND_QUEUE_MICROTASK,
    NATIVE_KIND_ENCODE_URI_COMPONENT,
    NATIVE_KIND_DECODE_URI_COMPONENT,
    NATIVE_KIND_ENCODE_URI,
    NATIVE_KIND_DECODE_URI,
    NATIVE_KIND_ERROR,
    NATIVE_KIND_TYPE_ERROR,
    NATIVE_KIND_REFERENCE_ERROR,
    NATIVE_KIND_SYNTAX_ERROR,
    NATIVE_KIND_RANGE_ERROR,
    NATIVE_KIND_URI_ERROR,
    NATIVE_KIND_EVAL_ERROR,
    NATIVE_KIND_ARRAY_ISARRAY,
    NATIVE_KIND_ARRAY_OF,
    NATIVE_KIND_ARRAY_FROM,
    NATIVE_KIND_ARRAY_FROM_ASYNC,
    NATIVE_KIND_ARRAY_SPECIES_GET,
    NATIVE_KIND_OBJ_STATIC_KEYS,
    NATIVE_KIND_OBJ_STATIC_ASSIGN,
    NATIVE_KIND_OBJ_STATIC_CREATE,
    NATIVE_KIND_OBJ_STATIC_FROM_ENTRIES,
    NATIVE_KIND_OBJ_STATIC_ENTRIES,
    NATIVE_KIND_OBJ_STATIC_VALUES,
    NATIVE_KIND_OBJ_STATIC_FREEZE,
    NATIVE_KIND_OBJ_STATIC_GETPROPNAMES,
    NATIVE_KIND_OBJ_STATIC_SEAL,
    NATIVE_KIND_OBJ_STATIC_IS_SEALED,
    NATIVE_KIND_OBJ_STATIC_IS_FROZEN,
    NATIVE_KIND_OBJ_SET_PROTOTYPE_OF,
    NATIVE_KIND_OBJ_GET_PROTOTYPE_OF,
    NATIVE_KIND_OBJ_PREVENT_EXTENSIONS,
    NATIVE_KIND_OBJ_IS_EXTENSIBLE,
    NATIVE_KIND_PROXY,
    NATIVE_KIND_PROXY_REVOCABLE,
    NATIVE_KIND_REFLECT_SET_PROTOTYPE_OF,
    NATIVE_KIND_REFLECT_GET_PROTOTYPE_OF,
    NATIVE_KIND_REFLECT_DEFINE_PROPERTY,
    NATIVE_KIND_REFLECT_OWN_KEYS,
    NATIVE_KIND_REFLECT_GET,
    NATIVE_KIND_REFLECT_SET,
    NATIVE_KIND_REFLECT_HAS,
    NATIVE_KIND_REFLECT_DELETE_PROPERTY,
    NATIVE_KIND_REFLECT_IS_EXTENSIBLE,
    NATIVE_KIND_REFLECT_PREVENT_EXTENSIONS,
    NATIVE_KIND_REFLECT_GET_OWN_PROPERTY_DESCRIPTOR,
    NATIVE_KIND_REFLECT_CONSTRUCT,
    NATIVE_KIND_REFLECT_APPLY,
    NATIVE_KIND_262_CREATE_REALM,
    NATIVE_KIND_262_EVAL_SCRIPT,
    NATIVE_KIND_OBJ_DEFINE_PROPERTY,
    NATIVE_KIND_OBJ_DEFINE_PROPERTIES,
    NATIVE_KIND_OBJ_IS,
    NATIVE_KIND_OBJ_HASOWN,
    NATIVE_KIND_OBJ_GETOWNPD,
    NATIVE_KIND_OBJ_GETOWNPDS,
    NATIVE_KIND_OBJ_GET_OWN_PROP_SYMBOLS,
    NATIVE_KIND_FUNCTION,
    NATIVE_KIND_FN_CALL,
    NATIVE_KIND_FN_APPLY,
    NATIVE_KIND_FN_BIND,
    NATIVE_KIND_FN_TOSTRING,
    NATIVE_KIND_FN_HAS_INSTANCE,
    NATIVE_KIND_FN_PROTOTYPE,
    NATIVE_KIND_STR_FROMCHARCODE,
    NATIVE_KIND_STR_FROMCODEPOINT,
    NATIVE_KIND_STR_RAW,
    NATIVE_KIND_STR_TOSTRING,
    NATIVE_KIND_STR_AT,
    NATIVE_KIND_STR_CHARAT,
    NATIVE_KIND_STR_CHARCODEAT,
    NATIVE_KIND_STR_CODEPOINTAT,
    NATIVE_KIND_STR_CONCAT,
    NATIVE_KIND_STR_ENDSWITH,
    NATIVE_KIND_STR_INCLUDES,
    NATIVE_KIND_STR_INDEXOF,
    NATIVE_KIND_STR_LASTINDEXOF,
    NATIVE_KIND_STR_LOCALECOMPARE,
    NATIVE_KIND_STR_MATCH,
    NATIVE_KIND_STR_MATCHALL,
    NATIVE_KIND_STR_NORMALIZE,
    NATIVE_KIND_STR_PADEND,
    NATIVE_KIND_STR_PADSTART,
    NATIVE_KIND_STR_REPEAT,
    NATIVE_KIND_STR_REPLACE,
    NATIVE_KIND_STR_REPLACEALL,
    NATIVE_KIND_STR_SEARCH,
    NATIVE_KIND_STR_SLICE,
    NATIVE_KIND_STR_SPLIT,
    NATIVE_KIND_STR_STARTSWITH,
    NATIVE_KIND_STR_SUBSTR,
    NATIVE_KIND_STR_SUBSTRING,
    NATIVE_KIND_STR_TOLOWER,
    NATIVE_KIND_STR_TOUPPER,
    NATIVE_KIND_STR_TRIM,
    NATIVE_KIND_STR_TRIMEND,
    NATIVE_KIND_STR_TRIMSTART,
    NATIVE_KIND_STR_ISWELLFORMED,
    NATIVE_KIND_STR_TOWELLFORMED,
    NATIVE_KIND_STR_ANCHOR,
    NATIVE_KIND_STR_BIG,
    NATIVE_KIND_STR_BLINK,
    NATIVE_KIND_STR_BOLD,
    NATIVE_KIND_STR_FIXED,
    NATIVE_KIND_STR_FONTCOLOR,
    NATIVE_KIND_STR_FONTSIZE,
    NATIVE_KIND_STR_ITALICS,
    NATIVE_KIND_STR_LINK,
    NATIVE_KIND_STR_SMALL,
    NATIVE_KIND_STR_STRIKE,
    NATIVE_KIND_STR_SUB,
    NATIVE_KIND_STR_SUP,
    NATIVE_KIND_NUM_TOFIXED,
    NATIVE_KIND_NUM_TOPRECISION,
    NATIVE_KIND_NUM_TOEXPONENTIAL,
    NATIVE_KIND_NUM_TOSTRING,
    NATIVE_KIND_NUM_VALUEOF,
    NATIVE_KIND_NUM_ISNAN,
    NATIVE_KIND_NUM_ISFINITE,
    NATIVE_KIND_NUM_ISINTEGER,
    NATIVE_KIND_NUM_ISSAFEINTEGER,
    NATIVE_KIND_NUM_PARSEFLOAT,
    NATIVE_KIND_NUM_PARSEINT,
    NATIVE_KIND_BOOL_TOSTRING,
    NATIVE_KIND_BOOL_VALUEOF,
    NATIVE_KIND_OBJ_PROTO_HAS_OWN,
    NATIVE_KIND_OBJ_PROTO_TOSTRING,
    NATIVE_KIND_OBJ_PROTO_VALUEOF,
    NATIVE_KIND_OBJ_PROTO_IS_PROTO_OF,
    NATIVE_KIND_OBJ_PROTO_PROP_IS_ENUM,
    NATIVE_KIND_OBJ_PROTO_TOLOCALESTRING,
    NATIVE_KIND_OBJ_PROTO_LOOKUP_GETTER,
    NATIVE_KIND_OBJ_PROTO_LOOKUP_SETTER,
    NATIVE_KIND_OBJ_PROTO_DEFINE_GETTER,
    NATIVE_KIND_OBJ_PROTO_DEFINE_SETTER,
    NATIVE_KIND_MARK_NON_CONSTRUCTOR,
    NATIVE_KIND_ERR_PROTO_TOSTRING,
    NATIVE_KIND_JSON_PARSE,
    NATIVE_KIND_JSON_STRINGIFY,
    NATIVE_KIND_SYMBOL,
    NATIVE_KIND_SYMBOL_FOR,
    NATIVE_KIND_SYMBOL_KEYFOR,
    NATIVE_KIND_SYMBOL_TOSTRING,
    NATIVE_KIND_SYMBOL_VALUEOF,
    NATIVE_KIND_SYMBOL_DESCRIPTION,
    NATIVE_KIND_ARRAY_ITER,
    NATIVE_KIND_STR_ITER,
    NATIVE_KIND_GENERATOR_NEXT,
    NATIVE_KIND_GENERATOR_RETURN,
    NATIVE_KIND_GENERATOR_THROW,
    NATIVE_KIND_GENERATOR_SYMBOL_ITER,
    NATIVE_KIND_ARRAY_PUSH,
    NATIVE_KIND_ARRAY_POP,
    NATIVE_KIND_ARRAY_SHIFT,
    NATIVE_KIND_ARRAY_UNSHIFT,
    NATIVE_KIND_ARRAY_SPLICE,
    NATIVE_KIND_ARRAY_SLICE,
    NATIVE_KIND_ARRAY_JOIN,
    NATIVE_KIND_ARRAY_REVERSE,
    NATIVE_KIND_ARRAY_FLAT,
    NATIVE_KIND_ARRAY_CONCAT,
    NATIVE_KIND_ARRAY_INDEXOF,
    NATIVE_KIND_ARRAY_LASTINDEXOF,
    NATIVE_KIND_ARRAY_INCLUDES,
    NATIVE_KIND_ARRAY_FILL,
    NATIVE_KIND_ARRAY_COPYWITHIN,
    NATIVE_KIND_ARRAY_AT,
    NATIVE_KIND_ARRAY_TOSTRING,
    NATIVE_KIND_ARRAY_TOLOCALESTRING,
    NATIVE_KIND_ARRAY_FOREACH,
    NATIVE_KIND_ARRAY_MAP,
    NATIVE_KIND_ARRAY_FILTER,
    NATIVE_KIND_ARRAY_REDUCE,
    NATIVE_KIND_ARRAY_REDUCERIGHT,
    NATIVE_KIND_ARRAY_FIND,
    NATIVE_KIND_ARRAY_FINDINDEX,
    NATIVE_KIND_ARRAY_SOME,
    NATIVE_KIND_ARRAY_EVERY,
    NATIVE_KIND_ARRAY_SORT,
    NATIVE_KIND_ARRAY_FLATMAP,
    NATIVE_KIND_ARRAY_KEYS,
    NATIVE_KIND_ARRAY_VALUES,
    NATIVE_KIND_ARRAY_ENTRIES,
    NATIVE_KIND_ARRAY_TOREVERSED,
    NATIVE_KIND_ARRAY_TOSORTED,
    NATIVE_KIND_ARRAY_TOSPLICED,
    NATIVE_KIND_ARRAY_WITH,
    NATIVE_KIND_ARRAY_FINDLAST,
    NATIVE_KIND_ARRAY_FINDLASTINDEX,
    NATIVE_KIND_MAP,
    NATIVE_KIND_MAP_GET,
    NATIVE_KIND_MAP_SET_METHOD,
    NATIVE_KIND_MAP_HAS,
    NATIVE_KIND_MAP_DELETE,
    NATIVE_KIND_MAP_CLEAR,
    NATIVE_KIND_MAP_FOREACH,
    NATIVE_KIND_MAP_KEYS,
    NATIVE_KIND_MAP_VALUES,
    NATIVE_KIND_MAP_ENTRIES,
    NATIVE_KIND_MAP_ITER,
    NATIVE_KIND_MAP_SIZE_GET,
    NATIVE_KIND_SET,
    NATIVE_KIND_SET_ADD,
    NATIVE_KIND_SET_HAS,
    NATIVE_KIND_SET_DELETE,
    NATIVE_KIND_SET_CLEAR,
    NATIVE_KIND_SET_FOREACH,
    NATIVE_KIND_SET_KEYS,
    NATIVE_KIND_SET_VALUES,
    NATIVE_KIND_SET_ENTRIES,
    NATIVE_KIND_SET_ITER,
    NATIVE_KIND_SET_SIZE_GET,
    NATIVE_KIND_WEAKMAP,
    NATIVE_KIND_WEAKMAP_GET,
    NATIVE_KIND_WEAKMAP_SET_METHOD,
    NATIVE_KIND_WEAKMAP_HAS,
    NATIVE_KIND_WEAKMAP_DELETE,
    NATIVE_KIND_WEAKSET,
    NATIVE_KIND_WEAKSET_ADD,
    NATIVE_KIND_WEAKSET_HAS,
    NATIVE_KIND_WEAKSET_DELETE,
    NATIVE_KIND_DATE,
    NATIVE_KIND_DATE_NOW,
    NATIVE_KIND_DATE_PARSE,
    NATIVE_KIND_DATE_UTC,
    NATIVE_KIND_DATE_GETTIME,
    NATIVE_KIND_DATE_GETFULLYEAR,
    NATIVE_KIND_DATE_GETMONTH,
    NATIVE_KIND_DATE_GETDATE,
    NATIVE_KIND_DATE_GETDAY,
    NATIVE_KIND_DATE_GETHOURS,
    NATIVE_KIND_DATE_GETMINUTES,
    NATIVE_KIND_DATE_GETSECONDS,
    NATIVE_KIND_DATE_GETMILLISECONDS,
    NATIVE_KIND_DATE_GETTIMEZONEOFFSET,
    NATIVE_KIND_DATE_GETUTCFULLYEAR,
    NATIVE_KIND_DATE_GETUTCMONTH,
    NATIVE_KIND_DATE_GETUTCDATE,
    NATIVE_KIND_DATE_GETUTCDAY,
    NATIVE_KIND_DATE_GETUTCHOURS,
    NATIVE_KIND_DATE_GETUTCMINUTES,
    NATIVE_KIND_DATE_GETUTCSECONDS,
    NATIVE_KIND_DATE_GETUTCMILLISECONDS,
    NATIVE_KIND_DATE_SETTIME,
    NATIVE_KIND_DATE_SETFULLYEAR,
    NATIVE_KIND_DATE_SETMONTH,
    NATIVE_KIND_DATE_SETDATE,
    NATIVE_KIND_DATE_SETHOURS,
    NATIVE_KIND_DATE_SETMINUTES,
    NATIVE_KIND_DATE_SETSECONDS,
    NATIVE_KIND_DATE_SETMILLISECONDS,
    NATIVE_KIND_DATE_SETUTCDATE,
    NATIVE_KIND_DATE_SETUTCFULLYEAR,
    NATIVE_KIND_DATE_SETUTCMONTH,
    NATIVE_KIND_DATE_SETUTCHOURS,
    NATIVE_KIND_DATE_SETUTCMINUTES,
    NATIVE_KIND_DATE_SETUTCSECONDS,
    NATIVE_KIND_DATE_SETUTCMILLISECONDS,
    NATIVE_KIND_DATE_TOTEMPORALINSTANT,
    NATIVE_KIND_DATE_TODATESTRING,
    NATIVE_KIND_DATE_TOISOSTRING,
    NATIVE_KIND_DATE_TOJSON,
    NATIVE_KIND_DATE_TOLOCALEDATESTRING,
    NATIVE_KIND_DATE_TOLOCALESTRING,
    NATIVE_KIND_DATE_TOLOCALETIMESTRING,
    NATIVE_KIND_DATE_TOSTRING,
    NATIVE_KIND_DATE_TOTIMESTRING,
    NATIVE_KIND_DATE_TOUTCSTRING,
    NATIVE_KIND_DATE_VALUEOF,
    NATIVE_KIND_GENERATOR_FUNCTION,
    NATIVE_KIND_PROMISE,
    NATIVE_KIND_PROMISE_THEN,
    NATIVE_KIND_PROMISE_CATCH,
    NATIVE_KIND_PROMISE_FINALLY,
    NATIVE_KIND_PROMISE_STATIC_RESOLVE,
    NATIVE_KIND_PROMISE_STATIC_REJECT,
    NATIVE_KIND_PROMISE_ALL,
    NATIVE_KIND_PROMISE_ALLSETTLED,
    NATIVE_KIND_PROMISE_RACE,
    NATIVE_KIND_PROMISE_ANY,
    NATIVE_KIND_PROMISE_WITHRESOLVERS,
    NATIVE_KIND_SET_TIMEOUT,
    NATIVE_KIND_CLEAR_TIMEOUT,
    NATIVE_KIND_SET_INTERVAL,
    NATIVE_KIND_CLEAR_INTERVAL,
    NATIVE_KIND_SET_IMMEDIATE,
    NATIVE_KIND_CLEAR_IMMEDIATE,
    NATIVE_KIND_PERFORMANCE_NOW,
    NATIVE_KIND_NEXT_TICK,
    NATIVE_KIND_PROCESS_EXIT,
    NATIVE_KIND_PROCESS_STDOUT_WRITE,
    NATIVE_KIND_PROCESS_STDERR_WRITE,
    NATIVE_KIND_PROCESS_HRTIME,
    NATIVE_KIND_PROCESS_CWD,
    NATIVE_KIND_PROCESS_HRTIME_BIGINT,
    NATIVE_KIND_PROCESS_UPTIME,
    NATIVE_KIND_PROCESS_ON,
    NATIVE_KIND_PROCESS_ONCE,
    NATIVE_KIND_PROCESS_OFF,
    NATIVE_KIND_PROCESS_EMIT,
    NATIVE_KIND_PROCESS_EMIT_WARNING,
    NATIVE_KIND_PROCESS_REMOVE_LISTENER,
    NATIVE_KIND_PROCESS_REMOVE_ALL,
    NATIVE_KIND_PROCESS_MEMORY_USAGE,
    NATIVE_KIND_PROCESS_CPU_USAGE,
    NATIVE_KIND_PROCESS_UMASK,
    NATIVE_KIND_PROCESS_ABORT,
    NATIVE_KIND_PROCESS_CHDIR,
    NATIVE_KIND_PROCESS_KILL,
    NATIVE_KIND_PROCESS_GETUID,
    NATIVE_KIND_PROCESS_GETGID,
    NATIVE_KIND_PROCESS_GETEUID,
    NATIVE_KIND_PROCESS_GETEGID,
    NATIVE_KIND_PROCESS_MEMORY_USAGE_RSS,
    NATIVE_KIND_PROCESS_AVAILABLE_MEMORY,
    NATIVE_KIND_PROCESS_RESOURCE_USAGE,
    NATIVE_KIND_PROCESS_GETGROUPS,
    NATIVE_KIND_PROCESS_SETUID,
    NATIVE_KIND_PROCESS_SETGID,
    NATIVE_KIND_PROCESS_SETEUID,
    NATIVE_KIND_PROCESS_SETEGID,
    NATIVE_KIND_PROCESS_LOAD_ENV_FILE,
    NATIVE_KIND_PROCESS_SET_SOURCE_MAPS_ENABLED,
    NATIVE_KIND_PROCESS_GET_BUILTIN_MODULE,
    NATIVE_KIND_PROCESS_GET_ACTIVE_RESOURCES_INFO,
    NATIVE_KIND_FS_READ_FILE,
    NATIVE_KIND_FS_WRITE_FILE,
    NATIVE_KIND_FS_READ_FILE_SYNC,
    NATIVE_KIND_FS_WRITE_FILE_SYNC,
    NATIVE_KIND_FS_EXISTS_SYNC,
    NATIVE_KIND_FS_UNLINK_SYNC,
    NATIVE_KIND_FS_STAT_SYNC,
    NATIVE_KIND_FS_APPEND_FILE_SYNC,
    NATIVE_KIND_FS_CREATE_READ_STREAM,
    NATIVE_KIND_FS_READDIR_SYNC,
    NATIVE_KIND_FS_MKDIR_SYNC,
    NATIVE_KIND_FS_RMDIR_SYNC,
    NATIVE_KIND_FS_RM_SYNC,
    NATIVE_KIND_FS_RENAME_SYNC,
    NATIVE_KIND_FS_COPYFILE_SYNC,
    NATIVE_KIND_FS_CHMOD_SYNC,
    NATIVE_KIND_FS_CHOWN_SYNC,
    NATIVE_KIND_FS_SYMLINK_SYNC,
    NATIVE_KIND_FS_READLINK_SYNC,
    NATIVE_KIND_FS_REALPATH_SYNC,
    NATIVE_KIND_FS_MKDTEMP_SYNC,
    NATIVE_KIND_FS_ACCESS_SYNC,
    NATIVE_KIND_FS_LSTAT_SYNC,
    NATIVE_KIND_FS_CREATE_WRITE_STREAM,
    NATIVE_KIND_FS_WATCH_START,
    NATIVE_KIND_FS_WATCH_CLOSE,
    NATIVE_KIND_FS_WATCH_REF,
    NATIVE_KIND_FS_WATCH_UNREF,
    NATIVE_KIND_FS_REALPATH,
    NATIVE_KIND_FS_STAT,
    NATIVE_KIND_FS_LSTAT,
    NATIVE_KIND_FS_READDIR,
    NATIVE_KIND_FS_MKDIR,
    NATIVE_KIND_FS_UNLINK,
    NATIVE_KIND_FS_RENAME,
    NATIVE_KIND_FS_ACCESS,
    NATIVE_KIND_FS_APPEND_FILE,
    NATIVE_KIND_FS_MKDTEMP,
    NATIVE_KIND_FS_COPYFILE,
    NATIVE_KIND_FS_CHMOD,
    NATIVE_KIND_FS_CHOWN,
    NATIVE_KIND_FS_SYMLINK,
    NATIVE_KIND_FS_READLINK,
    NATIVE_KIND_FS_RMDIR,
    NATIVE_KIND_FS_RM,
    NATIVE_KIND_FS_OPEN_SYNC,
    NATIVE_KIND_FS_OPEN,
    NATIVE_KIND_FS_CLOSE_SYNC,
    NATIVE_KIND_FS_CLOSE,
    NATIVE_KIND_FS_READ_SYNC,
    NATIVE_KIND_FS_WRITE_SYNC,
    NATIVE_KIND_FS_READ,
    NATIVE_KIND_FS_WRITE,
    NATIVE_KIND_FS_READV_SYNC,
    NATIVE_KIND_FS_WRITEV_SYNC,
    NATIVE_KIND_FS_READV,
    NATIVE_KIND_FS_WRITEV,
    NATIVE_KIND_FS_FSTAT_SYNC,
    NATIVE_KIND_FS_FSTAT,
    NATIVE_KIND_FS_FTRUNCATE_SYNC,
    NATIVE_KIND_FS_FTRUNCATE,
    NATIVE_KIND_FS_TRUNCATE_SYNC,
    NATIVE_KIND_FS_TRUNCATE,
    NATIVE_KIND_FS_UTIME_SYNC,
    NATIVE_KIND_FS_UTIME,
    NATIVE_KIND_FS_FUTIME_SYNC,
    NATIVE_KIND_FS_FUTIME,
    NATIVE_KIND_FS_LUTIME_SYNC,
    NATIVE_KIND_FS_LUTIME,
    NATIVE_KIND_FS_LINK_SYNC,
    NATIVE_KIND_FS_LINK,
    NATIVE_KIND_FS_FSYNC_SYNC,
    NATIVE_KIND_FS_FSYNC,
    NATIVE_KIND_FS_FDATASYNC_SYNC,
    NATIVE_KIND_FS_FDATASYNC,
    NATIVE_KIND_FS_FCHMOD_SYNC,
    NATIVE_KIND_FS_FCHMOD,
    NATIVE_KIND_FS_FCHOWN_SYNC,
    NATIVE_KIND_FS_FCHOWN,
    NATIVE_KIND_FS_LCHOWN_SYNC,
    NATIVE_KIND_FS_LCHOWN,
    NATIVE_KIND_FS_STATFS_SYNC,
    NATIVE_KIND_FS_STATFS,
    NATIVE_KIND_REQUIRE,
    NATIVE_KIND_MATH_ABS,
    NATIVE_KIND_MATH_ACOS,
    NATIVE_KIND_MATH_ACOSH,
    NATIVE_KIND_MATH_ASIN,
    NATIVE_KIND_MATH_ASINH,
    NATIVE_KIND_MATH_ATAN,
    NATIVE_KIND_MATH_ATAN2,
    NATIVE_KIND_MATH_ATANH,
    NATIVE_KIND_MATH_CBRT,
    NATIVE_KIND_MATH_CEIL,
    NATIVE_KIND_MATH_CLZ32,
    NATIVE_KIND_MATH_COS,
    NATIVE_KIND_MATH_COSH,
    NATIVE_KIND_MATH_EXP,
    NATIVE_KIND_MATH_EXPM1,
    NATIVE_KIND_MATH_FLOOR,
    NATIVE_KIND_MATH_FROUND,
    NATIVE_KIND_MATH_HYPOT,
    NATIVE_KIND_MATH_IMUL,
    NATIVE_KIND_MATH_LOG,
    NATIVE_KIND_MATH_LOG10,
    NATIVE_KIND_MATH_LOG1P,
    NATIVE_KIND_MATH_LOG2,
    NATIVE_KIND_MATH_MAX,
    NATIVE_KIND_MATH_MIN,
    NATIVE_KIND_MATH_POW,
    NATIVE_KIND_MATH_RANDOM,
    NATIVE_KIND_MATH_ROUND,
    NATIVE_KIND_MATH_SIGN,
    NATIVE_KIND_MATH_SIN,
    NATIVE_KIND_MATH_SINH,
    NATIVE_KIND_MATH_SQRT,
    NATIVE_KIND_MATH_TAN,
    NATIVE_KIND_MATH_TANH,
    NATIVE_KIND_MATH_TRUNC,
    NATIVE_KIND_STREAM_SET_RAW_MODE,
    NATIVE_KIND_NET_TCP_CONNECT,
    NATIVE_KIND_NET_TCP_READ,
    NATIVE_KIND_NET_TCP_WRITE,
    NATIVE_KIND_NET_TCP_CLOSE,
    NATIVE_KIND_NET_TLS_CONNECT,
    NATIVE_KIND_NET_TLS_READ,
    NATIVE_KIND_NET_TLS_WRITE,
    NATIVE_KIND_NET_TLS_CLOSE,
    NATIVE_KIND_NET_TCP_LISTEN,
    NATIVE_KIND_NET_TCP_ACCEPT,
    NATIVE_KIND_NET_TCP_LISTENER_CLOSE,
    NATIVE_KIND_NET_TCP_PEER_ADDR,
    NATIVE_KIND_NET_TCP_LISTENER_PORT,
    NATIVE_KIND_NET_UNIX_LISTEN,
    NATIVE_KIND_NET_TCP_CONNECT_NB,
    NATIVE_KIND_NET_TCP_READ_NB,
    NATIVE_KIND_NET_TLS_WRAP_CLIENT_NB,
    NATIVE_KIND_NET_TLS_CONNECT_NB,
    NATIVE_KIND_NET_TLS_READ_NB,
    NATIVE_KIND_NET_TCP_ACCEPT_NB,
    NATIVE_KIND_NET_TCP_SET_NODELAY,
    NATIVE_KIND_NET_TCP_SET_KEEPALIVE,
    NATIVE_KIND_NET_TCP_LOCAL_ADDR,
    NATIVE_KIND_NET_TCP_WRITE_NB,
    NATIVE_KIND_WS_ACCEPT_KEY,
    NATIVE_KIND_WS_RANDOM_KEY,
    NATIVE_KIND_WS_SEND_FRAME,
    NATIVE_KIND_WS_RECV_BUF_CREATE,
    NATIVE_KIND_WS_RECV_BUF_READ,
    NATIVE_KIND_WS_RECV_BUF_DECODE,
    NATIVE_KIND_WS_RECV_BUF_EXTRACT,
    NATIVE_KIND_WS_RECV_BUF_CONSUME,
    NATIVE_KIND_WS_RECV_BUF_PARSE_CLOSE,
    NATIVE_KIND_WS_MAKE_CLOSE_PAYLOAD,
    NATIVE_KIND_NET_READ_HTTP_RESPONSE,
    NATIVE_KIND_NET_READ_HTTP_REQUEST,
    NATIVE_KIND_H2_SESSION_CREATE_CLIENT,
    NATIVE_KIND_H2_SESSION_CREATE_SERVER,
    NATIVE_KIND_H2_SESSION_DEL,
    NATIVE_KIND_H2_SESSION_RECV,
    NATIVE_KIND_H2_SESSION_SEND,
    NATIVE_KIND_H2_SUBMIT_REQUEST,
    NATIVE_KIND_H2_SUBMIT_RESPONSE,
    NATIVE_KIND_H2_SUBMIT_SETTINGS,
    NATIVE_KIND_H2_SUBMIT_GOAWAY,
    NATIVE_KIND_H2_SUBMIT_RST_STREAM,
    NATIVE_KIND_H2_SUBMIT_DATA,
    NATIVE_KIND_H2_SUBMIT_TRAILER,
    NATIVE_KIND_H2_SET_LOCAL_WINDOW_SIZE,
    NATIVE_KIND_H2_GET_REMOTE_SETTING,
    NATIVE_KIND_H2_SESSION_WANT_READ,
    NATIVE_KIND_H2_SESSION_WANT_WRITE,
    NATIVE_KIND_H2_CONSUME,
    NATIVE_KIND_H2_SUBMIT_WINDOW_UPDATE,
    NATIVE_KIND_H2_POP_EVENT,
    NATIVE_KIND_H2_GET_SEND_PTR,
    NATIVE_KIND_H2_REQUEST,
    NATIVE_KIND_H2_RESPOND,
    NATIVE_KIND_BUF_ALLOC,
    NATIVE_KIND_BUF_FREE,
    NATIVE_KIND_BUF_GET_BYTE,
    NATIVE_KIND_BUF_SET_BYTE,
    NATIVE_KIND_BUF_COPY,
    NATIVE_KIND_BUF_FILL,
    NATIVE_KIND_BUF_REGISTER_BUFFER,
    NATIVE_KIND_BUF_REGISTER_TYPED_ARRAY,
    NATIVE_KIND_BUF_REGISTER_DATA_VIEW,
    NATIVE_KIND_BUF_BINARY_KIND,
    NATIVE_KIND_BUF_DV_GET_INT,
    NATIVE_KIND_BUF_DV_SET_INT,
    NATIVE_KIND_BUF_DECODE_UTF8,
    NATIVE_KIND_BUF_DECODE_LATIN1,
    NATIVE_KIND_BUF_TO_STRING,
    NATIVE_KIND_TD_DECODE,
    NATIVE_KIND_TA_GET_LENGTH,
    NATIVE_KIND_TA_GET_BYTELENGTH,
    NATIVE_KIND_TA_GET_BYTEOFFSET,
    NATIVE_KIND_TA_GET_BUFFER,
    NATIVE_KIND_TA_SPECIES_GET,
    NATIVE_KIND_TA_SUBARRAY,
    NATIVE_KIND_BUF_MAKE_VIEW,
    NATIVE_KIND_BUF_INIT_ARRAY_BUFFER,
    NATIVE_KIND_BUF_INIT_TYPED_ARRAY,
    NATIVE_KIND_BUF_UTF8_BYTE_LENGTH,
    NATIVE_KIND_BUF_WRITE_STRING,
    NATIVE_KIND_BUF_COPY_BYTES,
    NATIVE_KIND_BUF_EQUALS_BYTES,
    NATIVE_KIND_TD_DECODE_METHOD,
    NATIVE_KIND_SET_TD_DECODE_SLOW,
    NATIVE_KIND_BUF_TOSTRING_METHOD,
    NATIVE_KIND_BUF_SUBARRAY_METHOD,
    NATIVE_KIND_SET_BUF_SLOW,
    NATIVE_KIND_TA_SUBARRAY_METHOD,
    NATIVE_KIND_SET_TA_SUBARRAY_SLOW,
    NATIVE_KIND_TA_SET,
    NATIVE_KIND_TA_SLICE,
    NATIVE_KIND_BUF_STRING_BYTE_LENGTH,
    NATIVE_KIND_SET_AB_PROTO,
    NATIVE_KIND_ARRAY_INT_PROBE,
    NATIVE_KIND_TA_FILL_FROM_PROBE,
    NATIVE_KIND_NET_TCP_READ_BINARY_NB,
    NATIVE_KIND_NET_TLS_READ_BINARY_NB,
    NATIVE_KIND_ZLIB_STREAM_OPEN,
    NATIVE_KIND_ZLIB_STREAM_FEED,
    NATIVE_KIND_ZLIB_STREAM_CLOSE,
    NATIVE_KIND_NET_TCP_WRITE_RAW,
    NATIVE_KIND_ZLIB_INFLATE_ONESHOT,
    NATIVE_KIND_ZLIB_DEFLATE_STREAM_OPEN,
    NATIVE_KIND_ZLIB_DEFLATE_STREAM_FEED,
    NATIVE_KIND_ZLIB_DEFLATE_STREAM_CLOSE,
    NATIVE_KIND_ZLIB_COMPRESS_RAW,
    NATIVE_KIND_ZLIB_DEFLATE_PTR,
    NATIVE_KIND_ZLIB_DEFLATE_LEN,
    NATIVE_KIND_ZLIB_CRC32,
    NATIVE_KIND_BROTLI_COMPRESS,
    NATIVE_KIND_BROTLI_DECOMPRESS,
    NATIVE_KIND_BROTLI_ENC_OPEN,
    NATIVE_KIND_BROTLI_ENC_FEED,
    NATIVE_KIND_BROTLI_ENC_CLOSE,
    NATIVE_KIND_BROTLI_DEC_OPEN,
    NATIVE_KIND_BROTLI_DEC_FEED,
    NATIVE_KIND_BROTLI_DEC_CLOSE,
    NATIVE_KIND_ZSTD_COMPRESS,
    NATIVE_KIND_ZSTD_DECOMPRESS,
    NATIVE_KIND_ZSTD_ENC_OPEN,
    NATIVE_KIND_ZSTD_ENC_FEED,
    NATIVE_KIND_ZSTD_ENC_CLOSE,
    NATIVE_KIND_ZSTD_DEC_OPEN,
    NATIVE_KIND_ZSTD_DEC_FEED,
    NATIVE_KIND_ZSTD_DEC_CLOSE,
    NATIVE_KIND_AH_ENABLE,
    NATIVE_KIND_AH_ENABLED,
    NATIVE_KIND_AH_SET_EXEC_ID,
    NATIVE_KIND_AH_GET_EXEC_ID,
    NATIVE_KIND_AH_PROMISE_ASYNC_ID,
    NATIVE_KIND_AH_DRAIN_INIT,
    NATIVE_KIND_AH_DRAIN_RESOLVE,
    NATIVE_KIND_AH_PEEK_NEXT_ID,
    NATIVE_KIND_NET_TLS_CREATE_SERVER_CTX,
    NATIVE_KIND_NET_TLS_FREE_SERVER_CTX,
    NATIVE_KIND_NET_TLS_ACCEPT,
    NATIVE_KIND_NET_TLS_ACCEPT_NB,
    NATIVE_KIND_NET_TLS_GET_ALPN,
    NATIVE_KIND_NET_TLS_WRITE_NB,
    NATIVE_KIND_NET_UDP_CREATE,
    NATIVE_KIND_NET_UDP_BIND,
    NATIVE_KIND_NET_UDP_SEND_NB,
    NATIVE_KIND_NET_UDP_RECV_NB,
    NATIVE_KIND_NET_UDP_CLOSE,
    NATIVE_KIND_NET_UDP_ADDRESS,
    NATIVE_KIND_NET_UDP_SET_BROADCAST,
    NATIVE_KIND_NET_UDP_SET_RECV_BUF,
    NATIVE_KIND_NET_UDP_GET_RECV_BUF,
    NATIVE_KIND_NET_UDP_SET_SEND_BUF,
    NATIVE_KIND_NET_UDP_GET_SEND_BUF,
    NATIVE_KIND_NET_UDP_SET_TTL,
    NATIVE_KIND_REGEXP,
    NATIVE_KIND_REGEXP_TEST,
    NATIVE_KIND_REGEXP_EXEC,
    NATIVE_KIND_REGEXP_TOSTRING,
    NATIVE_KIND_REGEXP_SYMBOL_MATCH,
    NATIVE_KIND_REGEXP_SYMBOL_MATCHALL,
    NATIVE_KIND_REGEXP_SYMBOL_REPLACE,
    NATIVE_KIND_REGEXP_SYMBOL_SEARCH,
    NATIVE_KIND_REGEXP_SYMBOL_SPLIT,
    NATIVE_KIND_GC_GET_THRESHOLD,
    NATIVE_KIND_GC_SET_THRESHOLD,
    NATIVE_KIND_GC_COLLECT,
    NATIVE_KIND_GC_STATS,
    NATIVE_KIND_GC_START_MONITOR,
    NATIVE_KIND_GC_STOP_MONITOR,
    NATIVE_KIND_GC_DEBUG,
    NATIVE_KIND_CRYPTO_HASH_NEW,
    NATIVE_KIND_CRYPTO_HASH_UPDATE,
    NATIVE_KIND_CRYPTO_HASH_FINAL,
    NATIVE_KIND_CRYPTO_HASH_FREE,
    NATIVE_KIND_CRYPTO_HASH_ONESHOT,
    NATIVE_KIND_CRYPTO_HMAC,
    NATIVE_KIND_CRYPTO_RANDOM_HEX,
    NATIVE_KIND_CRYPTO_TIMING_SAFE_EQUAL,
    NATIVE_KIND_CRYPTO_PBKDF2,
    NATIVE_KIND_CRYPTO_CIPHER_ENCRYPT,
    NATIVE_KIND_CRYPTO_CIPHER_DECRYPT,
    NATIVE_KIND_CRYPTO_GET_HASHES,
    NATIVE_KIND_CRYPTO_GET_CIPHERS,
    NATIVE_KIND_CRYPTO_GET_LAST_ERROR,
    NATIVE_KIND_CRYPTO_KEYGEN,
    NATIVE_KIND_CRYPTO_KEY_IMPORT,
    NATIVE_KIND_CRYPTO_KEY_EXPORT,
    NATIVE_KIND_CRYPTO_KEY_INFO,
    NATIVE_KIND_CRYPTO_KEY_EQUALS,
    NATIVE_KIND_CRYPTO_KEY_FREE,
    NATIVE_KIND_CRYPTO_KEY_PUBLIC_OF,
    NATIVE_KIND_CP_SPAWN_SYNC,
    NATIVE_KIND_CP_SPAWN_ASYNC,
    NATIVE_KIND_CP_SPAWN_KILL,
    NATIVE_KIND_CP_SPAWN_WRITE,
    NATIVE_KIND_CP_SPAWN_WRITE_B64,
    NATIVE_KIND_CP_UNREF,
    NATIVE_KIND_CP_REF,
    NATIVE_KIND_CP_SPAWN_STDIN_END,
    NATIVE_KIND_CP_GET_PID,
    NATIVE_KIND_CP_POLL_EVENTS,
    NATIVE_KIND_WASM_VALIDATE,
    NATIVE_KIND_WASM_COMPILE,
    NATIVE_KIND_WASM_INSTANTIATE,
    NATIVE_KIND_WASM_EXPORT_COUNT,
    NATIVE_KIND_WASM_EXPORT_NAME,
    NATIVE_KIND_WASM_EXPORT_KIND,
    NATIVE_KIND_WASM_BIND_FUNC,
    NATIVE_KIND_WASM_FUNC_INVOKE,
    NATIVE_KIND_WASM_EXPORT_MEMORY,
    NATIVE_KIND_WASM_MEM_CREATE,
    NATIVE_KIND_WASM_MEM_PTR,
    NATIVE_KIND_WASM_MEM_SIZE,
    NATIVE_KIND_WASM_MEM_PAGES,
    NATIVE_KIND_WASM_MEM_GROW,
    NATIVE_KIND_WASM_MEM_FREE,
    NATIVE_KIND_WASM_LAST_ERROR,
    NATIVE_KIND_WASM_FREE_MODULE,
    NATIVE_KIND_WASM_MODULE_IMPORTS,
    NATIVE_KIND_WASM_MODULE_EXPORTS,
    NATIVE_KIND_WASM_EXPORT_GLOBAL,
    NATIVE_KIND_WASM_GLOBAL_GET,
    NATIVE_KIND_WASM_LAST_ERRCLASS,
    NATIVE_KIND_WASM_GLOBAL_CREATE,
    NATIVE_KIND_WASM_GLOBAL_SET,
    NATIVE_KIND_WASM_GLOBAL_IS_MUT,
    NATIVE_KIND_WASM_GLOBAL_KIND,
    NATIVE_KIND_WASM_TABLE_CREATE,
    NATIVE_KIND_WASM_TABLE_SIZE,
    NATIVE_KIND_WASM_TABLE_GET_KIND,
    NATIVE_KIND_WASM_TABLE_SET_NULL,
    NATIVE_KIND_WASM_TABLE_SET_FUNC,
    NATIVE_KIND_WASM_TABLE_GROW,
    NATIVE_KIND_WASM_EXPORT_TABLE,
    NATIVE_KIND_WASM_IMPORTS_BEGIN,
    NATIVE_KIND_WASM_IMPORTS_ADD_FUNC,
    NATIVE_KIND_WASM_IMPORTS_ADD_MEMORY,
    NATIVE_KIND_WASM_IMPORTS_ADD_GLOBAL,
    NATIVE_KIND_WASM_IMPORTS_ADD_TABLE,
    NATIVE_KIND_WASM_INSTANTIATE_IMPORTS,
    NATIVE_KIND_WASM_BIND_FUNC_KINDS,
    NATIVE_KIND_DNS_LOOKUP,
    NATIVE_KIND_DNS_REVERSE,
    NATIVE_KIND_DNS_LOOKUP_SERVICE,
    NATIVE_KIND_DNS_RESOLVE4,
    NATIVE_KIND_DNS_RESOLVE6,
    NATIVE_KIND_DNS_GET_DEFAULT_ORDER,
    NATIVE_KIND_DNS_SET_DEFAULT_ORDER,
    NATIVE_KIND_DNS_GET_SERVERS,
    NATIVE_KIND_DNS_SET_SERVERS,
    NATIVE_KIND_DNS_WIRE_RESOLVE,
    NATIVE_KIND_CP_REGISTER_DRAIN,
    NATIVE_KIND_REGEXP_GET_DOTALL,
    NATIVE_KIND_REGEXP_GET_FLAGS,
    NATIVE_KIND_REGEXP_GET_GLOBAL,
    NATIVE_KIND_REGEXP_GET_HASINDICES,
    NATIVE_KIND_REGEXP_GET_IGNORECASE,
    NATIVE_KIND_REGEXP_GET_MULTILINE,
    NATIVE_KIND_REGEXP_GET_SOURCE,
    NATIVE_KIND_REGEXP_GET_STICKY,
    NATIVE_KIND_REGEXP_GET_UNICODE,
    NATIVE_KIND_REGEXP_GET_UNICODESETS
}

import from engine.src.builtins.streams {
    stream_create_readable,
    stream_create_writable
}

import from engine.src.builtins.process {
    process_get_env,
    process_get_pid,
    process_get_ppid,
    process_init_start_time,
    process_get_argv0,
    process_get_exec_path,
    process_build_exec_argv,
    process_get_title,
    process_get_no_deprecation,
    process_get_throw_deprecation,
    process_get_expose_gc
}
import from engine.src.ffi.libc { isatty, write }
import from engine.src.builtins.generators {
    gen_seed_keys,
    gen_set_realm,
    gen_set_instance_proto
}
import from engine.src.runtime.iterator { js_set_iterator_helper_proto }
import from engine.src.builtins.promise { promise_seed_keys, js_promise_set_proto }
import from engine.src.builtins.regexp {
    regexp_seed_keys,
    js_regexp_set_proto,
    re_set_realm,
    js_regexp_pristine_snapshot
}
import from engine.src.builtins.array { js_array_create, js_array_set_proto }
import from engine.src.builtins.string { js_string_set_proto }
import from engine.src.builtins.map {
    js_map_set_proto,
    js_weakmap_set_proto,
    map_set_realm
}
import from engine.src.builtins.set {
    js_set_set_proto,
    js_weakset_set_proto,
    set_set_realm
}
import from engine.src.builtins.date { js_date_set_proto }
import from engine.src.builtins.temporal_init { js_temporal_wire_global }
import from engine.src.builtins.intl.intl_init { js_intl_wire_global }
import from engine.src.builtins.number {
    js_boolean_set_proto,
    js_number_set_proto,
    KEY_IS_NUMBER_OBJ
}
import from engine.src.builtins.math { js_math_seed_random }
import from engine.src.runtime.js_bigint { js_bigint_set_proto }
import from engine.src.version {
    JS_ENGINE_VERSION_V,
    JS_ENGINE_VERSION,
    NODE_COMPAT_VERSION,
    UV_VERSION,
    OPENSSL_VERSION,
    ZLIB_VERSION,
    PCRE2_VERSION,
    LLHTTP_VERSION,
    NGHTTP2_VERSION
}

import from engine.src.runtime.error {
    get_error_proto,
    get_type_error_proto,
    get_reference_error_proto,
    get_syntax_error_proto,
    get_range_error_proto,
    get_uri_error_proto,
    get_eval_error_proto
}
import from engine.src.runtime.realm { Realm, realm_new, realm_register }
import from engine.src.builtins.markers { KEY_HOME_REALM_ID, _KEY_IS_ARRAY }
import from engine.src.ffi.libc { getenv }
import from engine.src.runtime.jssymbol {
    symbol_seed_well_known,
    js_well_known_symbol,
    js_symbol_set_proto,
    SYMBOL_ITERATOR,
    SYMBOL_TO_PRIMITIVE,
    SYMBOL_HAS_INSTANCE,
    SYMBOL_TO_STRING_TAG,
    SYMBOL_SPECIES,
    SYMBOL_ASYNC_ITERATOR,
    SYMBOL_MATCH,
    SYMBOL_MATCH_ALL,
    SYMBOL_REPLACE,
    SYMBOL_SEARCH,
    SYMBOL_SPLIT,
    SYMBOL_UNSCOPABLES,
    SYMBOL_DISPOSE,
    SYMBOL_ASYNC_DISPOSE,
    SYMBOL_ISOONCATSPREADABLE
}

import from engine.src.vm.vm {
    VM,
    make_vm,
    vm_set_realm,
    init_opcode_table,
    vm_inline_calls_enable,
    vm_inline_calls_enabled,
    vm_ic_enable,
    vm_ic_disable,
    vm_ic_enabled,
    vm_reg_verify_set,
    vm_reg_stats_set
}
import from engine.src.parser.parser { parse, _PARSE_HAD_ERRORS }
import from engine.src.bytecode.compiler { make_compiler, Compiler }
import from engine.src.bytecode.optimizer {
    bcopt_gate_set,
    bcopt_p3_gate_set,
    bcopt_gate_enabled,
    bcopt_p3_gate_enabled
}
import from engine.src.bytecode.regisa {
    reg_isa_gate_set,
    reg_isa_gate_enabled,
    reg_isa_debug_set
}

# ── Global Object ─────────────────────────────────────────────────────────────

"""
The globalThis root object.

`object`      — JSValue with tag=Object; the null-prototype JSObject that is
                globalThis.  All global bindings are properties of this object.
`uv_loop_ptr` — libuv event loop pointer stored as int (UVLoop.loop_ptr).
                Avoids a cross-module struct import of UVLoop from ffi/.

Bun Zig: VirtualMachine.global (*JSGlobalObject)
"""
# Sentinel: forces emission of __jac_glob_init_runtime_global_na so the JIT
# linker can resolve it when this module has direct transitive imports.
glob _GLOBAL_MODULE_INIT_GUARD: int = 1;

obj:pub JSGlobalObject {
    has object: JSValue,
        uv_loop_ptr: int = 0;
}

# ── Execution Context ─────────────────────────────────────────────────────────

"""
Per-execution context — threaded through all runtime operations.

Analogous to Bun's `*JSGlobalObject` parameter passed everywhere.

`global`            — the root JSGlobalObject
`stack_depth`       — call-stack depth counter (overflow guard in )
`pending_exception` — currently thrown exception, or js_undefined() if none
                      (mirrors JSC's per-context exception slot)
"""
obj:pub GlobalContext {
    has pending_exception: JSValue,
        global_obj: JSGlobalObject,
        realm: Realm,
        stack_depth: int = 0;
}

# per-context state (strings, symbols, queues…)
# ── Factory ───────────────────────────────────────────────────────────────────

"""
Create and return a fresh GlobalContext backed by an empty null-prototype object.
Does NOT bootstrap built-in properties — call init_global(ctx) after this.

Bun Zig: VirtualMachine.init() → creates JSGlobalObject, wraps in VM struct
"""
def:pub global_context_create -> GlobalContext {
    realm: Realm = realm_new();
    str_set_realm(realm);
    obj_set_realm(realm);
    native_set_realm(realm);
    init_dispatch_table();
    init_opcode_table();
    fn_realm_set(realm);
    vm_set_realm(realm);
    map_set_realm(realm);
    set_set_realm(realm);
    gen_set_realm(realm);
    re_set_realm(realm);
    gobj: JSValue = js_object_create_null();
    realm.global_this = gobj;  # GC root — must be set before any GC tick fires
    g: JSGlobalObject = JSGlobalObject(object=gobj);
    pex: JSValue = js_undefined();
    ctx: GlobalContext = GlobalContext(
        pending_exception=pex, global_obj=g, realm=realm
    );
    return ctx;
}

# ── Bootstrap ─────────────────────────────────────────────────────────────────

"""Create the __JS_ENGINE_GC introspection object and attach it to globalThis."""
def _init_gc_obj(ctx: GlobalContext) {
    gv: JSValue = ctx.global_obj.object;
    k_gc_obj: int = str_intern("__JS_ENGINE_GC");
    k_getthresh: int = str_intern("getThreshold");
    k_setthresh: int = str_intern("setThreshold");
    k_collect_m: int = str_intern("collect");
    k_stats_m: int = str_intern("stats");
    k_startmon: int = str_intern("startMonitor");
    k_stopmon: int = str_intern("stopMonitor");
    k_debug_gc: int = str_intern("debug");
    gc_obj: JSValue = js_object_create_null();
    fn_getthresh: JSValue = js_native_create(
        "getThreshold", 0, NATIVE_KIND_GC_GET_THRESHOLD
    );
    fn_setthresh: JSValue = js_native_create(
        "setThreshold", 1, NATIVE_KIND_GC_SET_THRESHOLD
    );
    fn_collect: JSValue = js_native_create("collect", 0, NATIVE_KIND_GC_COLLECT);
    fn_stats: JSValue = js_native_create("stats", 0, NATIVE_KIND_GC_STATS);
    fn_startmon: JSValue = js_native_create(
        "startMonitor", 0, NATIVE_KIND_GC_START_MONITOR
    );
    fn_stopmon: JSValue = js_native_create(
        "stopMonitor", 0, NATIVE_KIND_GC_STOP_MONITOR
    );
    fn_debug: JSValue = js_native_create("debug", 0, NATIVE_KIND_GC_DEBUG);
    js_object_set(gc_obj, k_getthresh, fn_getthresh);
    js_object_set(gc_obj, k_setthresh, fn_setthresh);
    js_object_set(gc_obj, k_collect_m, fn_collect);
    js_object_set(gc_obj, k_stats_m, fn_stats);
    js_object_set(gc_obj, k_startmon, fn_startmon);
    js_object_set(gc_obj, k_stopmon, fn_stopmon);
    js_object_set(gc_obj, k_debug_gc, fn_debug);
    js_object_set(gv, k_gc_obj, gc_obj);
}

"""
Internal helper: define a property with explicit writability and configurability.
Used for §19.1 global primitives (undefined / NaN / Infinity / globalThis).
"""
def _define_prop(jobj: JSValue, key: int, val: JSValue, w: bool, e: bool, c: bool) {
    p: JSProperty = JSProperty(
        key=key, value=val, writable=w, enumerable=e, configurable=c, deleted=False
    );
    js_object_define_property(jobj, key, p);
}

"""Install a prototype method with spec-correct flags (w=true, e=false, c=true)."""
def _define_proto_method(jobj: JSValue, key: int, val: JSValue) {
    _define_prop(jobj, key, val, True, False, True);
}

"""Install a getter-only accessor property with builtin attributes.

ECMAScript gives builtin prototype accessors { enumerable: false,
configurable: true }, but js_object_set_accessor_getter defaults an accessor to
enumerable (object-literal semantics), so both flags are set explicitly here.

Without this, `Object.getOwnPropertyDescriptor(RegExp.prototype, "source")`
returns undefined and every descriptor test fails on `reading 'get'`."""
def _define_accessor(jobj: JSValue, key: int, get_fn: JSValue) {
    js_object_set_accessor_getter(jobj, key, get_fn);
    js_object_set_accessor_enumerable(jobj, key, False);
    js_object_set_accessor_configurable(jobj, key, True);
}

"""Install all Array.prototype methods as own data properties.

Each property descriptor is: { writable: true, enumerable: false, configurable: true }
per ECMAScript §23.1.3. Arity (`.length`) follows the spec table exactly.

Must be called after `js_array_set_proto(arr_proto)` so that `js_is_array(arr_proto)`
is true and GET_PROP falls through to _get_prop_accessor correctly.
`values` / Symbol.iterator are installed by the caller (shared fn object).
"""
def _init_array_proto_methods(arr_proto: JSValue) {
    _define_proto_method(
        arr_proto, str_intern("at"), js_native_create("at", 1, NATIVE_KIND_ARRAY_AT)
    );
    _define_proto_method(
        arr_proto,
        str_intern("concat"),
        js_native_create("concat", 1, NATIVE_KIND_ARRAY_CONCAT)
    );
    _define_proto_method(
        arr_proto,
        str_intern("copyWithin"),
        js_native_create("copyWithin", 2, NATIVE_KIND_ARRAY_COPYWITHIN)
    );
    _define_proto_method(
        arr_proto,
        str_intern("entries"),
        js_native_create("entries", 0, NATIVE_KIND_ARRAY_ENTRIES)
    );
    _define_proto_method(
        arr_proto,
        str_intern("every"),
        js_native_create("every", 1, NATIVE_KIND_ARRAY_EVERY)
    );
    _define_proto_method(
        arr_proto,
        str_intern("fill"),
        js_native_create("fill", 1, NATIVE_KIND_ARRAY_FILL)
    );
    _define_proto_method(
        arr_proto,
        str_intern("filter"),
        js_native_create("filter", 1, NATIVE_KIND_ARRAY_FILTER)
    );
    _define_proto_method(
        arr_proto,
        str_intern("find"),
        js_native_create("find", 1, NATIVE_KIND_ARRAY_FIND)
    );
    _define_proto_method(
        arr_proto,
        str_intern("findIndex"),
        js_native_create("findIndex", 1, NATIVE_KIND_ARRAY_FINDINDEX)
    );
    _define_proto_method(
        arr_proto,
        str_intern("findLast"),
        js_native_create("findLast", 1, NATIVE_KIND_ARRAY_FINDLAST)
    );
    _define_proto_method(
        arr_proto,
        str_intern("findLastIndex"),
        js_native_create("findLastIndex", 1, NATIVE_KIND_ARRAY_FINDLASTINDEX)
    );
    _define_proto_method(
        arr_proto,
        str_intern("flat"),
        js_native_create("flat", 0, NATIVE_KIND_ARRAY_FLAT)
    );
    _define_proto_method(
        arr_proto,
        str_intern("flatMap"),
        js_native_create("flatMap", 1, NATIVE_KIND_ARRAY_FLATMAP)
    );
    _define_proto_method(
        arr_proto,
        str_intern("forEach"),
        js_native_create("forEach", 1, NATIVE_KIND_ARRAY_FOREACH)
    );
    _define_proto_method(
        arr_proto,
        str_intern("includes"),
        js_native_create("includes", 1, NATIVE_KIND_ARRAY_INCLUDES)
    );
    _define_proto_method(
        arr_proto,
        str_intern("indexOf"),
        js_native_create("indexOf", 1, NATIVE_KIND_ARRAY_INDEXOF)
    );
    _define_proto_method(
        arr_proto,
        str_intern("join"),
        js_native_create("join", 1, NATIVE_KIND_ARRAY_JOIN)
    );
    _define_proto_method(
        arr_proto,
        str_intern("keys"),
        js_native_create("keys", 0, NATIVE_KIND_ARRAY_KEYS)
    );
    _define_proto_method(
        arr_proto,
        str_intern("lastIndexOf"),
        js_native_create("lastIndexOf", 1, NATIVE_KIND_ARRAY_LASTINDEXOF)
    );
    _define_proto_method(
        arr_proto, str_intern("map"), js_native_create("map", 1, NATIVE_KIND_ARRAY_MAP)
    );
    _define_proto_method(
        arr_proto, str_intern("pop"), js_native_create("pop", 0, NATIVE_KIND_ARRAY_POP)
    );
    _define_proto_method(
        arr_proto,
        str_intern("push"),
        js_native_create("push", 1, NATIVE_KIND_ARRAY_PUSH)
    );
    _define_proto_method(
        arr_proto,
        str_intern("reduce"),
        js_native_create("reduce", 1, NATIVE_KIND_ARRAY_REDUCE)
    );
    _define_proto_method(
        arr_proto,
        str_intern("reduceRight"),
        js_native_create("reduceRight", 1, NATIVE_KIND_ARRAY_REDUCERIGHT)
    );
    _define_proto_method(
        arr_proto,
        str_intern("reverse"),
        js_native_create("reverse", 0, NATIVE_KIND_ARRAY_REVERSE)
    );
    _define_proto_method(
        arr_proto,
        str_intern("shift"),
        js_native_create("shift", 0, NATIVE_KIND_ARRAY_SHIFT)
    );
    _define_proto_method(
        arr_proto,
        str_intern("slice"),
        js_native_create("slice", 2, NATIVE_KIND_ARRAY_SLICE)
    );
    _define_proto_method(
        arr_proto,
        str_intern("some"),
        js_native_create("some", 1, NATIVE_KIND_ARRAY_SOME)
    );
    _define_proto_method(
        arr_proto,
        str_intern("sort"),
        js_native_create("sort", 1, NATIVE_KIND_ARRAY_SORT)
    );
    _define_proto_method(
        arr_proto,
        str_intern("splice"),
        js_native_create("splice", 2, NATIVE_KIND_ARRAY_SPLICE)
    );
    _define_proto_method(
        arr_proto,
        str_intern("toLocaleString"),
        js_native_create("toLocaleString", 0, NATIVE_KIND_ARRAY_TOLOCALESTRING)
    );
    _define_proto_method(
        arr_proto,
        str_intern("toReversed"),
        js_native_create("toReversed", 0, NATIVE_KIND_ARRAY_TOREVERSED)
    );
    _define_proto_method(
        arr_proto,
        str_intern("toSorted"),
        js_native_create("toSorted", 1, NATIVE_KIND_ARRAY_TOSORTED)
    );
    _define_proto_method(
        arr_proto,
        str_intern("toSpliced"),
        js_native_create("toSpliced", 2, NATIVE_KIND_ARRAY_TOSPLICED)
    );
    _define_proto_method(
        arr_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_ARRAY_TOSTRING)
    );
    _define_proto_method(
        arr_proto,
        str_intern("unshift"),
        js_native_create("unshift", 1, NATIVE_KIND_ARRAY_UNSHIFT)
    );
    _define_proto_method(
        arr_proto,
        str_intern("with"),
        js_native_create("with", 2, NATIVE_KIND_ARRAY_WITH)
    );
}

"""Install all String.prototype methods as own data properties.

Each property descriptor is: { writable: true, enumerable: false, configurable: true }
per ECMAScript §22.1.3. Arity (`.length`) follows the spec table exactly — note the
cases where it is not the obvious argument count: `concat`/`push`-style rest params
are 1, and `replace`/`replaceAll`/`split`/`slice`/`substring`/`substr`/`padStart`/
`padEnd` are 2.

Before this existed, `_op_get_prop` in vm.na.jac synthesized these on every string
property read. That made `String.prototype.split` undefined, made computed access
(`"x"["split"]`) undefined, and returned a *fresh* function object per read so
`"".split !== "".split`. The VM fast path is now limited to `length`; everything
else resolves through this prototype.

`toString`/`valueOf`/`constructor`/@@iterator are installed by the caller.

Merge note: adel_fixes carried a second copy of this function (auto-merged lower
in the file); that copy created trimLeft/trimStart as *separate* native objects,
breaking `s.trimLeft === s.trimStart` (Annex B §B.2.2.14/15). This HEAD version —
which installs one shared native under both names — is kept, and the duplicate is
removed.
"""
def _init_string_proto_methods(str_proto: JSValue) {
    _define_proto_method(
        str_proto, str_intern("at"), js_native_create("at", 1, NATIVE_KIND_STR_AT)
    );
    _define_proto_method(
        str_proto,
        str_intern("charAt"),
        js_native_create("charAt", 1, NATIVE_KIND_STR_CHARAT)
    );
    _define_proto_method(
        str_proto,
        str_intern("charCodeAt"),
        js_native_create("charCodeAt", 1, NATIVE_KIND_STR_CHARCODEAT)
    );
    _define_proto_method(
        str_proto,
        str_intern("codePointAt"),
        js_native_create("codePointAt", 1, NATIVE_KIND_STR_CODEPOINTAT)
    );
    _define_proto_method(
        str_proto,
        str_intern("concat"),
        js_native_create("concat", 1, NATIVE_KIND_STR_CONCAT)
    );
    _define_proto_method(
        str_proto,
        str_intern("endsWith"),
        js_native_create("endsWith", 1, NATIVE_KIND_STR_ENDSWITH)
    );
    _define_proto_method(
        str_proto,
        str_intern("includes"),
        js_native_create("includes", 1, NATIVE_KIND_STR_INCLUDES)
    );
    _define_proto_method(
        str_proto,
        str_intern("indexOf"),
        js_native_create("indexOf", 1, NATIVE_KIND_STR_INDEXOF)
    );
    _define_proto_method(
        str_proto,
        str_intern("lastIndexOf"),
        js_native_create("lastIndexOf", 1, NATIVE_KIND_STR_LASTINDEXOF)
    );
    _define_proto_method(
        str_proto,
        str_intern("localeCompare"),
        js_native_create("localeCompare", 1, NATIVE_KIND_STR_LOCALECOMPARE)
    );
    _define_proto_method(
        str_proto,
        str_intern("match"),
        js_native_create("match", 1, NATIVE_KIND_STR_MATCH)
    );
    _define_proto_method(
        str_proto,
        str_intern("matchAll"),
        js_native_create("matchAll", 1, NATIVE_KIND_STR_MATCHALL)
    );
    _define_proto_method(
        str_proto,
        str_intern("normalize"),
        js_native_create("normalize", 0, NATIVE_KIND_STR_NORMALIZE)
    );
    _define_proto_method(
        str_proto,
        str_intern("padEnd"),
        js_native_create("padEnd", 1, NATIVE_KIND_STR_PADEND)
    );
    _define_proto_method(
        str_proto,
        str_intern("padStart"),
        js_native_create("padStart", 1, NATIVE_KIND_STR_PADSTART)
    );
    _define_proto_method(
        str_proto,
        str_intern("repeat"),
        js_native_create("repeat", 1, NATIVE_KIND_STR_REPEAT)
    );
    _define_proto_method(
        str_proto,
        str_intern("replace"),
        js_native_create("replace", 2, NATIVE_KIND_STR_REPLACE)
    );
    _define_proto_method(
        str_proto,
        str_intern("replaceAll"),
        js_native_create("replaceAll", 2, NATIVE_KIND_STR_REPLACEALL)
    );
    _define_proto_method(
        str_proto,
        str_intern("search"),
        js_native_create("search", 1, NATIVE_KIND_STR_SEARCH)
    );
    _define_proto_method(
        str_proto,
        str_intern("slice"),
        js_native_create("slice", 2, NATIVE_KIND_STR_SLICE)
    );
    _define_proto_method(
        str_proto,
        str_intern("split"),
        js_native_create("split", 2, NATIVE_KIND_STR_SPLIT)
    );
    _define_proto_method(
        str_proto,
        str_intern("startsWith"),
        js_native_create("startsWith", 1, NATIVE_KIND_STR_STARTSWITH)
    );
    _define_proto_method(
        str_proto,
        str_intern("substr"),
        js_native_create("substr", 2, NATIVE_KIND_STR_SUBSTR)
    );
    _define_proto_method(
        str_proto,
        str_intern("substring"),
        js_native_create("substring", 2, NATIVE_KIND_STR_SUBSTRING)
    );
    _define_proto_method(
        str_proto,
        str_intern("toLocaleLowerCase"),
        js_native_create("toLocaleLowerCase", 0, NATIVE_KIND_STR_TOLOWER)
    );
    _define_proto_method(
        str_proto,
        str_intern("toLocaleUpperCase"),
        js_native_create("toLocaleUpperCase", 0, NATIVE_KIND_STR_TOUPPER)
    );
    _define_proto_method(
        str_proto,
        str_intern("toLowerCase"),
        js_native_create("toLowerCase", 0, NATIVE_KIND_STR_TOLOWER)
    );
    _define_proto_method(
        str_proto,
        str_intern("toUpperCase"),
        js_native_create("toUpperCase", 0, NATIVE_KIND_STR_TOUPPER)
    );
    _define_proto_method(
        str_proto, str_intern("trim"), js_native_create("trim", 0, NATIVE_KIND_STR_TRIM)
    );
    # Annex B §B.2.2.14/15: trimLeft/trimRight are the SAME function objects as
    # trimStart/trimEnd (`s.trimLeft === s.trimStart`), so create each native once
    # and install it under both names rather than making a second object.
    fn_trim_start: JSValue = js_native_create(
        "trimStart", 0, NATIVE_KIND_STR_TRIMSTART
    );
    fn_trim_end: JSValue = js_native_create("trimEnd", 0, NATIVE_KIND_STR_TRIMEND);
    _define_proto_method(str_proto, str_intern("trimEnd"), fn_trim_end);
    _define_proto_method(str_proto, str_intern("trimStart"), fn_trim_start);
    _define_proto_method(str_proto, str_intern("trimLeft"), fn_trim_start);
    _define_proto_method(str_proto, str_intern("trimRight"), fn_trim_end);
    # Well-formed Unicode (§22.1.3.11 / §22.1.3.36).
    _define_proto_method(
        str_proto,
        str_intern("isWellFormed"),
        js_native_create("isWellFormed", 0, NATIVE_KIND_STR_ISWELLFORMED)
    );
    _define_proto_method(
        str_proto,
        str_intern("toWellFormed"),
        js_native_create("toWellFormed", 0, NATIVE_KIND_STR_TOWELLFORMED)
    );
    # Annex B §B.2.3 HTML wrappers. Methods taking an attribute value have length 1.
    _define_proto_method(
        str_proto,
        str_intern("anchor"),
        js_native_create("anchor", 1, NATIVE_KIND_STR_ANCHOR)
    );
    _define_proto_method(
        str_proto, str_intern("big"), js_native_create("big", 0, NATIVE_KIND_STR_BIG)
    );
    _define_proto_method(
        str_proto,
        str_intern("blink"),
        js_native_create("blink", 0, NATIVE_KIND_STR_BLINK)
    );
    _define_proto_method(
        str_proto, str_intern("bold"), js_native_create("bold", 0, NATIVE_KIND_STR_BOLD)
    );
    _define_proto_method(
        str_proto,
        str_intern("fixed"),
        js_native_create("fixed", 0, NATIVE_KIND_STR_FIXED)
    );
    _define_proto_method(
        str_proto,
        str_intern("fontcolor"),
        js_native_create("fontcolor", 1, NATIVE_KIND_STR_FONTCOLOR)
    );
    _define_proto_method(
        str_proto,
        str_intern("fontsize"),
        js_native_create("fontsize", 1, NATIVE_KIND_STR_FONTSIZE)
    );
    _define_proto_method(
        str_proto,
        str_intern("italics"),
        js_native_create("italics", 0, NATIVE_KIND_STR_ITALICS)
    );
    _define_proto_method(
        str_proto, str_intern("link"), js_native_create("link", 1, NATIVE_KIND_STR_LINK)
    );
    _define_proto_method(
        str_proto,
        str_intern("small"),
        js_native_create("small", 0, NATIVE_KIND_STR_SMALL)
    );
    _define_proto_method(
        str_proto,
        str_intern("strike"),
        js_native_create("strike", 0, NATIVE_KIND_STR_STRIKE)
    );
    _define_proto_method(
        str_proto, str_intern("sub"), js_native_create("sub", 0, NATIVE_KIND_STR_SUB)
    );
    _define_proto_method(
        str_proto, str_intern("sup"), js_native_create("sup", 0, NATIVE_KIND_STR_SUP)
    );
}

"""Install get Map [ @@species ] / get Set [ @@species ] on a constructor (§24.1.2.5 / §24.2.2.5)."""
def _define_ctor_species_accessor(ctor: JSValue) {
    sp_key: int = SYMBOL_KEY_BASE + SYMBOL_SPECIES;
    sp_getter: JSValue = js_native_create(
        "get [Symbol.species]", 0, NATIVE_KIND_ARRAY_SPECIES_GET
    );
    js_object_set_accessor_getter(ctor, sp_key, sp_getter);
    # Accessor tables default enumerable=true; species must be non-enumerable +
    # configurable. Do not also write a data-property sentinel — that fights the
    # accessor shape that getOwnPropertyDescriptor must report.
    js_object_set_accessor_enumerable(ctor, sp_key, False);
    js_object_set_accessor_configurable(ctor, sp_key, True);
}

"""Install all Map.prototype methods as own data properties (§24.1.3)."""
def _init_map_proto_methods(map_proto: JSValue) {
    _define_proto_method(
        map_proto, str_intern("get"), js_native_create("get", 1, NATIVE_KIND_MAP_GET)
    );
    _define_proto_method(
        map_proto,
        str_intern("set"),
        js_native_create("set", 2, NATIVE_KIND_MAP_SET_METHOD)
    );
    _define_proto_method(
        map_proto, str_intern("has"), js_native_create("has", 1, NATIVE_KIND_MAP_HAS)
    );
    _define_proto_method(
        map_proto,
        str_intern("delete"),
        js_native_create("delete", 1, NATIVE_KIND_MAP_DELETE)
    );
    _define_proto_method(
        map_proto,
        str_intern("clear"),
        js_native_create("clear", 0, NATIVE_KIND_MAP_CLEAR)
    );
    _define_proto_method(
        map_proto,
        str_intern("forEach"),
        js_native_create("forEach", 1, NATIVE_KIND_MAP_FOREACH)
    );
    map_entries_fn: JSValue = js_native_create("entries", 0, NATIVE_KIND_MAP_ENTRIES);
    map_keys_fn: JSValue = js_native_create("keys", 0, NATIVE_KIND_MAP_KEYS);
    map_values_fn: JSValue = js_native_create("values", 0, NATIVE_KIND_MAP_VALUES);
    _define_proto_method(map_proto, str_intern("keys"), map_keys_fn);
    _define_proto_method(map_proto, str_intern("values"), map_values_fn);
    _define_proto_method(map_proto, str_intern("entries"), map_entries_fn);
    _define_proto_method(map_proto, SYMBOL_KEY_BASE + SYMBOL_ITERATOR, map_entries_fn);
    # get Map.prototype.size — {enumerable:false, configurable:true}
    map_size_get: JSValue = js_native_create("get size", 0, NATIVE_KIND_MAP_SIZE_GET);
    js_object_set_accessor_getter(map_proto, str_intern("size"), map_size_get);
    js_object_set_accessor_enumerable(map_proto, str_intern("size"), False);
    js_object_set_accessor_configurable(map_proto, str_intern("size"), True);
    # Map.prototype[@@toStringTag] = "Map"
    _define_prop(
        map_proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Map")),
        False,
        False,
        True
    );
}

"""Install all Set.prototype methods as own data properties (§24.2.3)."""
def _init_set_proto_methods(set_proto: JSValue) {
    _define_proto_method(
        set_proto, str_intern("add"), js_native_create("add", 1, NATIVE_KIND_SET_ADD)
    );
    _define_proto_method(
        set_proto, str_intern("has"), js_native_create("has", 1, NATIVE_KIND_SET_HAS)
    );
    _define_proto_method(
        set_proto,
        str_intern("delete"),
        js_native_create("delete", 1, NATIVE_KIND_SET_DELETE)
    );
    _define_proto_method(
        set_proto,
        str_intern("clear"),
        js_native_create("clear", 0, NATIVE_KIND_SET_CLEAR)
    );
    _define_proto_method(
        set_proto,
        str_intern("forEach"),
        js_native_create("forEach", 1, NATIVE_KIND_SET_FOREACH)
    );
    set_values_fn: JSValue = js_native_create("values", 0, NATIVE_KIND_SET_VALUES);
    set_entries_fn: JSValue = js_native_create("entries", 0, NATIVE_KIND_SET_ENTRIES);
    _define_proto_method(set_proto, str_intern("values"), set_values_fn);
    _define_proto_method(set_proto, str_intern("keys"), set_values_fn);
    _define_proto_method(set_proto, str_intern("entries"), set_entries_fn);
    _define_proto_method(set_proto, SYMBOL_KEY_BASE + SYMBOL_ITERATOR, set_values_fn);
    # get Set.prototype.size — {enumerable:false, configurable:true}
    set_size_get: JSValue = js_native_create("get size", 0, NATIVE_KIND_SET_SIZE_GET);
    js_object_set_accessor_getter(set_proto, str_intern("size"), set_size_get);
    js_object_set_accessor_enumerable(set_proto, str_intern("size"), False);
    js_object_set_accessor_configurable(set_proto, str_intern("size"), True);
    # Set.prototype[@@toStringTag] = "Set"
    _define_prop(
        set_proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Set")),
        False,
        False,
        True
    );
}

"""Install all WeakMap.prototype methods as own data properties (§24.3.3)."""
def _init_weakmap_proto_methods(weakmap_proto: JSValue) {
    _define_proto_method(
        weakmap_proto,
        str_intern("get"),
        js_native_create("get", 1, NATIVE_KIND_WEAKMAP_GET)
    );
    _define_proto_method(
        weakmap_proto,
        str_intern("set"),
        js_native_create("set", 2, NATIVE_KIND_WEAKMAP_SET_METHOD)
    );
    _define_proto_method(
        weakmap_proto,
        str_intern("has"),
        js_native_create("has", 1, NATIVE_KIND_WEAKMAP_HAS)
    );
    _define_proto_method(
        weakmap_proto,
        str_intern("delete"),
        js_native_create("delete", 1, NATIVE_KIND_WEAKMAP_DELETE)
    );
    # WeakMap.prototype[@@toStringTag] = "WeakMap"
    _define_prop(
        weakmap_proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("WeakMap")),
        False,
        False,
        True
    );
}

"""Install all WeakSet.prototype methods as own data properties (§24.4.3)."""
def _init_weakset_proto_methods(weakset_proto: JSValue) {
    _define_proto_method(
        weakset_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_WEAKSET_ADD)
    );
    _define_proto_method(
        weakset_proto,
        str_intern("has"),
        js_native_create("has", 1, NATIVE_KIND_WEAKSET_HAS)
    );
    _define_proto_method(
        weakset_proto,
        str_intern("delete"),
        js_native_create("delete", 1, NATIVE_KIND_WEAKSET_DELETE)
    );
    # WeakSet.prototype[@@toStringTag] = "WeakSet"
    _define_prop(
        weakset_proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("WeakSet")),
        False,
        False,
        True
    );
}

"""
Wire an error constructor to its prototype (ECMAScript §20.5.3 / §20.5.6).

  [[Prototype]] of ctor   → Function.prototype  (so .call/.apply/.bind resolve)
  ctor.prototype          → proto   { w:F, e:F, c:F }
  proto.constructor       → ctor    { w:T, e:F, c:T }
  ctor.name               → "<Name>" { w:F, e:F, c:T }

The `constructor` back-link is what makes `err.constructor === <Ctor>` (and thus
`err.constructor.name`) work — required by test262's assert.throws helper. Chaining
the ctor to Function.prototype preserves `Error.call(this, msg)`-style subclassing
that worked when these were opaque native functions.
"""
def _wire_error_ctor(
    ctor: JSValue,
    proto: JSValue,
    fn_proto: JSValue,
    k_prototype: int,
    k_constructor: int,
    k_name_str: int
) {
    js_object_set_prototype(ctor, fn_proto);
    _define_prop(ctor, k_prototype, proto, False, False, False);
    _define_prop(proto, k_constructor, ctor, True, False, True);
    _define_prop(
        ctor, str_intern("name"), jsv_from_string_id(k_name_str), False, False, True
    );
    # §20.5.6.3: each NativeError prototype carries its own `name` and an empty
    # `message`, both { w:T, e:F, c:T }. error.na.jac seeds them with
    # js_object_set, which defaults to enumerable — redefine with spec attributes
    # so they stay out of Object.keys / JSON.stringify / for-in.
    _define_prop(
        proto, str_intern("name"), jsv_from_string_id(k_name_str), True, False, True
    );
    _define_prop(
        proto,
        str_intern("message"),
        jsv_from_string_id(str_intern("")),
        True,
        False,
        True
    );
}

"""Install a static built-in constant: { w:F, e:F, c:F }."""
def _define_static_const(jobj: JSValue, key: int, val: JSValue) {
    _define_prop(jobj, key, val, False, False, False);
}

"""Install a static built-in method: { w:T, e:F, c:T }."""
def _define_static_method(jobj: JSValue, key: int, val: JSValue) {
    _define_prop(jobj, key, val, True, False, True);
}

"""
Wire a js_callable_create constructor to Function.prototype (ECMAScript §17).

  [[Prototype]] of ctor → Function.prototype  (so .call/.apply/.bind resolve)
  ctor.prototype        → proto   (caller-specified descriptor flags)
  proto.constructor     → ctor    { w:T, e:F, c:T }
  ctor.length           → arity   { w:F, e:F, c:T }
  ctor.name             → name    { w:F, e:F, c:T }

Reusable by String, Boolean, Object, Array, etc. Error ctors keep _wire_error_ctor.
"""
def _wire_callable_ctor(
    ctor: JSValue,
    proto: JSValue,
    fn_proto: JSValue,
    k_prototype: int,
    k_constructor: int,
    k_name_str: int,
    arity: int,
    proto_w: bool,
    proto_e: bool,
    proto_c: bool
) {
    js_object_set_prototype(ctor, fn_proto);
    _define_prop(ctor, k_prototype, proto, proto_w, proto_e, proto_c);
    _define_prop(proto, k_constructor, ctor, True, False, True);
    _define_prop(ctor, str_intern("length"), js_int(arity), False, False, True);
    _define_prop(
        ctor, str_intern("name"), jsv_from_string_id(k_name_str), False, False, True
    );
}

"""Install Number static constants and methods with spec-correct descriptors (§21.1.2)."""
def _init_number_ctor_statics(num_ctor: JSValue) {
    _define_static_method(
        num_ctor,
        str_intern("isNaN"),
        js_native_create("isNaN", 1, NATIVE_KIND_NUM_ISNAN)
    );
    _define_static_method(
        num_ctor,
        str_intern("isFinite"),
        js_native_create("isFinite", 1, NATIVE_KIND_NUM_ISFINITE)
    );
    _define_static_method(
        num_ctor,
        str_intern("isInteger"),
        js_native_create("isInteger", 1, NATIVE_KIND_NUM_ISINTEGER)
    );
    _define_static_method(
        num_ctor,
        str_intern("isSafeInteger"),
        js_native_create("isSafeInteger", 1, NATIVE_KIND_NUM_ISSAFEINTEGER)
    );
    _define_static_method(
        num_ctor,
        str_intern("parseFloat"),
        js_native_create("parseFloat", 1, NATIVE_KIND_NUM_PARSEFLOAT)
    );
    _define_static_method(
        num_ctor,
        str_intern("parseInt"),
        js_native_create("parseInt", 2, NATIVE_KIND_NUM_PARSEINT)
    );
    _define_static_const(
        num_ctor, str_intern("MAX_VALUE"), js_number(1.7976931348623157e+308)
    );
    _define_static_const(num_ctor, str_intern("MIN_VALUE"), js_number(5e-324));
    _define_static_const(
        num_ctor, str_intern("EPSILON"), js_number(2.220446049250313e-16)
    );
    _define_static_const(
        num_ctor, str_intern("MAX_SAFE_INTEGER"), js_number(9007199254740991.0)
    );
    _define_static_const(
        num_ctor, str_intern("MIN_SAFE_INTEGER"), js_number(-9007199254740991.0)
    );
    _define_static_const(num_ctor, str_intern("POSITIVE_INFINITY"), js_infinity());
    _define_static_const(num_ctor, str_intern("NEGATIVE_INFINITY"), js_neg_infinity());
    _define_static_const(num_ctor, str_intern("NaN"), js_nan());
}

"""Install Number.prototype methods per ECMAScript §21.1.3."""
def _init_number_proto_methods(num_proto: JSValue) {
    _define_proto_method(
        num_proto,
        str_intern("toString"),
        js_native_singleton("toString", 1, NATIVE_KIND_NUM_TOSTRING)
    );
    _define_proto_method(
        num_proto,
        str_intern("valueOf"),
        js_native_singleton("valueOf", 0, NATIVE_KIND_NUM_VALUEOF)
    );
    _define_proto_method(
        num_proto,
        str_intern("toFixed"),
        js_native_singleton("toFixed", 1, NATIVE_KIND_NUM_TOFIXED)
    );
    _define_proto_method(
        num_proto,
        str_intern("toExponential"),
        js_native_singleton("toExponential", 1, NATIVE_KIND_NUM_TOEXPONENTIAL)
    );
    _define_proto_method(
        num_proto,
        str_intern("toPrecision"),
        js_native_singleton("toPrecision", 1, NATIVE_KIND_NUM_TOPRECISION)
    );
    # Placeholder — builtins_stubs.js replaces with thisNumberValue + ToString.
    _define_proto_method(
        num_proto,
        str_intern("toLocaleString"),
        js_native_create("toLocaleString", 0, NATIVE_KIND_OBJ_PROTO_TOLOCALESTRING)
    );
}

"""Install Date.prototype methods as own data properties (ECMAScript §21.4.4)."""
def _init_date_proto_methods(date_proto: JSValue) {
    _define_proto_method(
        date_proto,
        str_intern("getTime"),
        js_native_create("getTime", 0, NATIVE_KIND_DATE_GETTIME)
    );
    _define_proto_method(
        date_proto,
        str_intern("getFullYear"),
        js_native_create("getFullYear", 0, NATIVE_KIND_DATE_GETFULLYEAR)
    );
    _define_proto_method(
        date_proto,
        str_intern("getMonth"),
        js_native_create("getMonth", 0, NATIVE_KIND_DATE_GETMONTH)
    );
    _define_proto_method(
        date_proto,
        str_intern("getDate"),
        js_native_create("getDate", 0, NATIVE_KIND_DATE_GETDATE)
    );
    _define_proto_method(
        date_proto,
        str_intern("getDay"),
        js_native_create("getDay", 0, NATIVE_KIND_DATE_GETDAY)
    );
    _define_proto_method(
        date_proto,
        str_intern("getHours"),
        js_native_create("getHours", 0, NATIVE_KIND_DATE_GETHOURS)
    );
    _define_proto_method(
        date_proto,
        str_intern("getMinutes"),
        js_native_create("getMinutes", 0, NATIVE_KIND_DATE_GETMINUTES)
    );
    _define_proto_method(
        date_proto,
        str_intern("getSeconds"),
        js_native_create("getSeconds", 0, NATIVE_KIND_DATE_GETSECONDS)
    );
    _define_proto_method(
        date_proto,
        str_intern("getMilliseconds"),
        js_native_create("getMilliseconds", 0, NATIVE_KIND_DATE_GETMILLISECONDS)
    );
    _define_proto_method(
        date_proto,
        str_intern("getTimezoneOffset"),
        js_native_create("getTimezoneOffset", 0, NATIVE_KIND_DATE_GETTIMEZONEOFFSET)
    );
    _define_proto_method(
        date_proto,
        str_intern("getUTCFullYear"),
        js_native_create("getUTCFullYear", 0, NATIVE_KIND_DATE_GETUTCFULLYEAR)
    );
    _define_proto_method(
        date_proto,
        str_intern("getUTCMonth"),
        js_native_create("getUTCMonth", 0, NATIVE_KIND_DATE_GETUTCMONTH)
    );
    _define_proto_method(
        date_proto,
        str_intern("getUTCDate"),
        js_native_create("getUTCDate", 0, NATIVE_KIND_DATE_GETUTCDATE)
    );
    _define_proto_method(
        date_proto,
        str_intern("getUTCDay"),
        js_native_create("getUTCDay", 0, NATIVE_KIND_DATE_GETUTCDAY)
    );
    _define_proto_method(
        date_proto,
        str_intern("getUTCHours"),
        js_native_create("getUTCHours", 0, NATIVE_KIND_DATE_GETUTCHOURS)
    );
    _define_proto_method(
        date_proto,
        str_intern("getUTCMinutes"),
        js_native_create("getUTCMinutes", 0, NATIVE_KIND_DATE_GETUTCMINUTES)
    );
    _define_proto_method(
        date_proto,
        str_intern("getUTCSeconds"),
        js_native_create("getUTCSeconds", 0, NATIVE_KIND_DATE_GETUTCSECONDS)
    );
    _define_proto_method(
        date_proto,
        str_intern("getUTCMilliseconds"),
        js_native_create("getUTCMilliseconds", 0, NATIVE_KIND_DATE_GETUTCMILLISECONDS)
    );
    _define_proto_method(
        date_proto,
        str_intern("setTime"),
        js_native_create("setTime", 1, NATIVE_KIND_DATE_SETTIME)
    );
    _define_proto_method(
        date_proto,
        str_intern("setFullYear"),
        js_native_create("setFullYear", 3, NATIVE_KIND_DATE_SETFULLYEAR)
    );
    _define_proto_method(
        date_proto,
        str_intern("setMonth"),
        js_native_create("setMonth", 2, NATIVE_KIND_DATE_SETMONTH)
    );
    _define_proto_method(
        date_proto,
        str_intern("setDate"),
        js_native_create("setDate", 1, NATIVE_KIND_DATE_SETDATE)
    );
    _define_proto_method(
        date_proto,
        str_intern("setHours"),
        js_native_create("setHours", 4, NATIVE_KIND_DATE_SETHOURS)
    );
    _define_proto_method(
        date_proto,
        str_intern("setMinutes"),
        js_native_create("setMinutes", 3, NATIVE_KIND_DATE_SETMINUTES)
    );
    _define_proto_method(
        date_proto,
        str_intern("setSeconds"),
        js_native_create("setSeconds", 2, NATIVE_KIND_DATE_SETSECONDS)
    );
    _define_proto_method(
        date_proto,
        str_intern("setMilliseconds"),
        js_native_create("setMilliseconds", 1, NATIVE_KIND_DATE_SETMILLISECONDS)
    );
    _define_proto_method(
        date_proto,
        str_intern("setUTCDate"),
        js_native_create("setUTCDate", 1, NATIVE_KIND_DATE_SETUTCDATE)
    );
    _define_proto_method(
        date_proto,
        str_intern("setUTCFullYear"),
        js_native_create("setUTCFullYear", 3, NATIVE_KIND_DATE_SETUTCFULLYEAR)
    );
    _define_proto_method(
        date_proto,
        str_intern("setUTCMonth"),
        js_native_create("setUTCMonth", 2, NATIVE_KIND_DATE_SETUTCMONTH)
    );
    _define_proto_method(
        date_proto,
        str_intern("setUTCHours"),
        js_native_create("setUTCHours", 4, NATIVE_KIND_DATE_SETUTCHOURS)
    );
    _define_proto_method(
        date_proto,
        str_intern("setUTCMinutes"),
        js_native_create("setUTCMinutes", 3, NATIVE_KIND_DATE_SETUTCMINUTES)
    );
    _define_proto_method(
        date_proto,
        str_intern("setUTCSeconds"),
        js_native_create("setUTCSeconds", 2, NATIVE_KIND_DATE_SETUTCSECONDS)
    );
    _define_proto_method(
        date_proto,
        str_intern("setUTCMilliseconds"),
        js_native_create("setUTCMilliseconds", 1, NATIVE_KIND_DATE_SETUTCMILLISECONDS)
    );
    _define_proto_method(
        date_proto,
        str_intern("toTemporalInstant"),
        js_native_create("toTemporalInstant", 0, NATIVE_KIND_DATE_TOTEMPORALINSTANT)
    );
    _define_proto_method(
        date_proto,
        str_intern("toDateString"),
        js_native_create("toDateString", 0, NATIVE_KIND_DATE_TODATESTRING)
    );
    _define_proto_method(
        date_proto,
        str_intern("toISOString"),
        js_native_create("toISOString", 0, NATIVE_KIND_DATE_TOISOSTRING)
    );
    _define_proto_method(
        date_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_DATE_TOJSON)
    );
    _define_proto_method(
        date_proto,
        str_intern("toLocaleDateString"),
        js_native_create("toLocaleDateString", 0, NATIVE_KIND_DATE_TOLOCALEDATESTRING)
    );
    _define_proto_method(
        date_proto,
        str_intern("toLocaleString"),
        js_native_create("toLocaleString", 0, NATIVE_KIND_DATE_TOLOCALESTRING)
    );
    _define_proto_method(
        date_proto,
        str_intern("toLocaleTimeString"),
        js_native_create("toLocaleTimeString", 0, NATIVE_KIND_DATE_TOLOCALETIMESTRING)
    );
    _define_proto_method(
        date_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_DATE_TOSTRING)
    );
    _define_proto_method(
        date_proto,
        str_intern("toTimeString"),
        js_native_create("toTimeString", 0, NATIVE_KIND_DATE_TOTIMESTRING)
    );
    _define_proto_method(
        date_proto,
        str_intern("toUTCString"),
        js_native_create("toUTCString", 0, NATIVE_KIND_DATE_TOUTCSTRING)
    );
    _define_proto_method(
        date_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_DATE_VALUEOF)
    );
}

"""Install Promise.prototype methods as own data properties (ECMAScript §27.2.5)."""
def _init_promise_proto_methods(promise_proto: JSValue) {
    _define_proto_method(
        promise_proto,
        str_intern("then"),
        js_native_create("then", 2, NATIVE_KIND_PROMISE_THEN)
    );
    _define_proto_method(
        promise_proto,
        str_intern("catch"),
        js_native_create("catch", 1, NATIVE_KIND_PROMISE_CATCH)
    );
    _define_proto_method(
        promise_proto,
        str_intern("finally"),
        js_native_create("finally", 1, NATIVE_KIND_PROMISE_FINALLY)
    );
    # §27.2.6 Promise.prototype[ @@toStringTag ] = "Promise"
    _define_prop(
        promise_proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Promise")),
        False,
        False,
        True
    );
}

# ── Realm helpers (R13: cross-realm / $262.createRealm) ─────────────────────

"""Tag `o` with its home realm for GetFunctionRealm."""
def _realm_tag_home(o: JSValue, realm_id: int) {
    js_object_set(o, KEY_HOME_REALM_ID, js_int(realm_id));
}

"""Record main-realm intrinsics and tag them with realm_id."""
def _populate_main_realm_intrinsics(
    ctx: GlobalContext,
    obj_ctor: JSValue,
    obj_proto: JSValue,
    fn_ctor: JSValue,
    fn_proto: JSValue,
    arr_ctor: JSValue,
    arr_proto: JSValue
) {
    rid: int = ctx.realm.realm_id;
    ctx.realm.intrinsics.object_ctor = obj_ctor;
    ctx.realm.intrinsics.object_proto = obj_proto;
    ctx.realm.intrinsics.function_ctor = fn_ctor;
    ctx.realm.intrinsics.function_proto = fn_proto;
    ctx.realm.intrinsics.array_ctor = arr_ctor;
    ctx.realm.intrinsics.array_proto = arr_proto;
    _realm_tag_home(obj_ctor, rid);
    _realm_tag_home(obj_proto, rid);
    _realm_tag_home(fn_ctor, rid);
    _realm_tag_home(fn_proto, rid);
    _realm_tag_home(arr_ctor, rid);
    _realm_tag_home(arr_proto, rid);
}

# ── Global property accessors ─────────────────────────────────────────────────

"""Interner hook for jsobj_type.ensure_sparse (index → interned key id)."""
def _dense_index_intern(i: int) -> int {
    return str_intern(str(i));
}

"""True unless environment variable `name` is set to "0": the default-on
feature gates (JS_SHAPES=0 etc. switch one off for A/B debugging). A bare
`getenv(name) != None` reads as "on only when set", the inverse — the 72df095
regression that silently turned six gates off. Every gate goes through this
one helper; engine/tests/qa/cli/test_feature_gate_defaults.sh pins the
result through `js_engine --feature-gates`."""
def:pub env_gate_on(name: str) -> bool {
    gv: str = getenv(name);
    if gv == None {
        return True;
    }
    return gv != "0";
}

"""One `NAME=0|1` line per feature gate, read back from the live gate state
(not from the environment), for `js_engine --feature-gates`."""
def:pub feature_gates_report -> str {
    fg: list[str] = [];
    fg.append("JS_SHAPES=" + ("1" if shape_gate_enabled() else "0"));
    fg.append("JS_DENSE=" + ("1" if dense_gate_enabled() else "0"));
    fg.append("JS_BCOPT=" + ("1" if bcopt_gate_enabled() else "0"));
    fg.append("JS_BCOPT_P3=" + ("1" if bcopt_p3_gate_enabled() else "0"));
    fg.append("JS_INLINE_CALLS=" + ("1" if vm_inline_calls_enabled() else "0"));
    fg.append("JS_IC=" + ("1" if vm_ic_enabled() else "0"));
    fg.append("JS_REG_ISA=" + ("1" if reg_isa_gate_enabled() else "0"));
    return "\n".join(fg);
}

"""
Bootstrap all ECMAScript built-in global bindings on ctx.global_obj.object.

Sequence mirrors Bun's VM constructor + JSGlobalObject::init():
  1. globalThis → itself
  2. undefined / NaN / Infinity — non-writable, non-configurable (§19.1)
  3. Object / Array / String / Number / Boolean — real native constructors
  4. Error family — real native constructors
  5. parseInt / parseFloat / isNaN / isFinite + URI / eval / queueMicrotask
  6. console — full WHATWG console object with native method dispatch
  7. Math — object with all standard constants (§21.3)
  8. JSON — stub (§25.5)

Bun Zig: VM.init() + ConsoleObject.init() + api.zig Bun namespace
"""
def:pub init_global(ctx: GlobalContext) {
    # Seed the intern table FIRST so KEY_PROTO/KEY_LENGTH/KEY_NAME/KEY_VALUE
    # constants match str_intern() at run time.  Idempotent.
    str_intern_seed_well_known();
    if ctx.realm.realm_id == 0 {
        realm_register(ctx.realm);
    }
    # Pre-compute all well-known property key IDs so dispatch chains compare ints.
    init_wk_keys();
    # Shape-mode property storage is the default; JS_SHAPES=0 forces dict mode
    # (A/B debug lever — docs/shapes_impl_plan.md Phase 3).
    shape_gate_set(env_gate_on("JS_SHAPES"));
    # Dense array elements (docs/dense_elements_impl_plan.md): default-on;
    # JS_DENSE=0 keeps arrays in the property map. The interner hook lets
    # jsobj_type.ensure_sparse mint index keys without importing jsstring.
    dense_gate_set(env_gate_on("JS_DENSE"));
    # Bytecode optimizer (docs/bytecode_optimizer_impl_plan.md): default-on;
    # JS_BCOPT=0 skips the pass for runtime-compiled code (builtins .jsbc
    # were optimized at precompile — A/B those with JSBC=0).
    bcopt_gate_set(env_gate_on("JS_BCOPT"));
    bcopt_p3_gate_set(env_gate_on("JS_BCOPT_P3"));
    # Same-loop inline calls (call_path_impl_plan Phase 3); JS_INLINE_CALLS=0
    # falls back to the native-recursion call path.
    vm_inline_calls_enable(env_gate_on("JS_INLINE_CALLS"));
    # Shape-keyed property inline caches: default-on; JS_IC=0 is the A/B
    # lever. Read here with the other gates — init_opcode_table runs before
    # init_global, so reading it there also overwrote main's --ic.
    if env_gate_on("JS_IC") {
        vm_ic_enable();
    } else {
        vm_ic_disable();
    }
    # Register ISA (docs/VM_REARCH_PLAN.md V2): default-on; JS_REG_ISA=0 keeps
    # every function on the stack interpreter. JS_REG_DEBUG=1 prints each
    # function's translation outcome.
    reg_isa_gate_set(env_gate_on("JS_REG_ISA"));
    reg_isa_debug_set(getenv("JS_REG_DEBUG") == "1");
    vm_reg_verify_set(getenv("JS_REG_VERIFY") == "1");
    vm_reg_stats_set(getenv("JS_REG_STATS") == "1");
    register_index_interner(_dense_index_intern);
    # Set BigInt zero intern ID so jsv_coerce_to_bool treats BigInt(0) as falsy.
    jsv_set_bigint_zero_id(str_intern("0"));

    # Seed well-known symbols FIRST so their IDs are stable before any
    # str_intern() or user-land code runs.  Idempotent.
    symbol_seed_well_known(ctx.realm);

    # Seed generator hidden-property keys.
    gen_seed_keys();
    promise_seed_keys();
    regexp_seed_keys();
    proxy_init_keys();

    gv: JSValue = ctx.global_obj.object;

    # ── Intern property key strings ──────────────────────────────────────────
    k_gthis: int = str_intern("globalThis");
    k_undef: int = str_intern("undefined");
    k_nan_k: int = str_intern("NaN");
    k_inf_k: int = str_intern("Infinity");
    k_object: int = str_intern("Object");
    k_func: int = str_intern("Function");
    k_array: int = str_intern("Array");
    k_str_key: int = str_intern("String");
    k_number: int = str_intern("Number");
    k_boolean: int = str_intern("Boolean");
    k_console: int = str_intern("console");
    k_math: int = str_intern("Math");
    k_json: int = str_intern("JSON");
    k_error: int = str_intern("Error");
    k_typerr: int = str_intern("TypeError");
    k_referr: int = str_intern("ReferenceError");
    k_synterr: int = str_intern("SyntaxError");
    k_rangerr: int = str_intern("RangeError");
    k_urierr: int = str_intern("URIError");
    k_evalerr: int = str_intern("EvalError");

    # Array / Object static method keys
    k_isarray: int = str_intern("isArray");
    k_of: int = str_intern("of");
    k_from: int = str_intern("from");
    k_fromasync: int = str_intern("fromAsync");
    k_keys: int = str_intern("keys");
    k_values: int = str_intern("values");
    k_entries: int = str_intern("entries");
    k_assign: int = str_intern("assign");
    k_fromentries: int = str_intern("fromEntries");
    k_create: int = str_intern("create");
    k_freeze: int = str_intern("freeze");
    k_seal: int = str_intern("seal");
    k_issealed: int = str_intern("isSealed");
    k_isfrozen: int = str_intern("isFrozen");
    k_gopn: int = str_intern("getOwnPropertyNames");
    k_gops: int = str_intern("getOwnPropertySymbols");
    k_defprop: int = str_intern("defineProperty");
    k_defprops: int = str_intern("defineProperties");
    k_obj_is: int = str_intern("is");
    k_hasown: int = str_intern("hasOwn");
    k_gopd: int = str_intern("getOwnPropertyDescriptor");
    k_gopds: int = str_intern("getOwnPropertyDescriptors");
    k_setprotoof: int = str_intern("setPrototypeOf");
    k_getprotoof: int = str_intern("getPrototypeOf");
    k_preventext: int = str_intern("preventExtensions");
    k_isext: int = str_intern("isExtensible");
    k_proxy: int = str_intern("Proxy");
    k_reflect: int = str_intern("Reflect");
    k_parseint: int = str_intern("parseInt");
    k_parseflt: int = str_intern("parseFloat");
    k_isnan: int = str_intern("isNaN");
    k_isfinite: int = str_intern("isFinite");
    k_eval: int = str_intern("eval");
    k_qtask: int = str_intern("queueMicrotask");
    k_encuri_c: int = str_intern("encodeURIComponent");
    k_decuri_c: int = str_intern("decodeURIComponent");
    k_encuri: int = str_intern("encodeURI");
    k_decuri: int = str_intern("decodeURI");
    k_require: int = str_intern("require");

    # Math property keys
    k_pi: int = str_intern("PI");
    k_e: int = str_intern("E");
    k_ln2: int = str_intern("LN2");
    k_ln10: int = str_intern("LN10");
    k_log2e: int = str_intern("LOG2E");
    k_log10e: int = str_intern("LOG10E");
    k_sqrt2: int = str_intern("SQRT2");

    # console method keys
    k_log_k: int = str_intern("log");
    k_info_k: int = str_intern("info");
    k_debug_k: int = str_intern("debug");
    k_error_k: int = str_intern("error");
    k_warn_k: int = str_intern("warn");
    k_dir_k: int = str_intern("dir");
    k_assert_k: int = str_intern("assert");
    k_count_k: int = str_intern("count");
    k_ctreset: int = str_intern("countReset");
    k_time_k: int = str_intern("time");
    k_timend: int = str_intern("timeEnd");
    k_timlog: int = str_intern("timeLog");
    k_group_k: int = str_intern("group");
    k_grpcol: int = str_intern("groupCollapsed");
    k_grpend: int = str_intern("groupEnd");
    k_table_k: int = str_intern("table");

    # Number static property / method keys (reuse k_isnan, k_isfinite, k_parseint, k_parseflt)
    k_n_isint: int = str_intern("isInteger");
    k_n_issafe: int = str_intern("isSafeInteger");
    k_maxval: int = str_intern("MAX_VALUE");
    k_minval: int = str_intern("MIN_VALUE");
    k_epsilon: int = str_intern("EPSILON");
    k_maxsafe: int = str_intern("MAX_SAFE_INTEGER");
    k_minsafe: int = str_intern("MIN_SAFE_INTEGER");
    k_posinf: int = str_intern("POSITIVE_INFINITY");
    k_neginf: int = str_intern("NEGATIVE_INFINITY");
    # String static method keys
    k_fromcharcode: int = str_intern("fromCharCode");
    k_fromcodepoint: int = str_intern("fromCodePoint");
    k_raw_key: int = str_intern("raw");
    # Object.prototype / constructor wiring keys
    k_prototype: int = str_intern("prototype");
    k_constructor: int = str_intern("constructor");
    k_hastown: int = str_intern("hasOwnProperty");
    k_isprotoof: int = str_intern("isPrototypeOf");
    k_propisenum: int = str_intern("propertyIsEnumerable");
    k_tostring: int = str_intern("toString");
    k_valueof: int = str_intern("valueOf");
    k_tolocalestring: int = str_intern("toLocaleString");

    # ── §19.1 globalThis — writable=true, enumerable=false, configurable=true
    _define_prop(gv, k_gthis, gv, True, False, True);
    # Node/Bundler legacy alias: global === globalThis (Vite cli.js reads global.__vite_*)
    _define_prop(gv, str_intern("global"), gv, True, False, True);

    # ── §19.1 undefined / NaN / Infinity — non-writable, non-enumerable, non-configurable
    _define_prop(gv, k_undef, js_undefined(), False, False, False);
    _define_prop(gv, k_nan_k, js_nan(), False, False, False);
    _define_prop(gv, k_inf_k, js_infinity(), False, False, False);

    # ── §19.2 Constructor built-ins ──────────────────────────────────────────

    # Array — callable JSObject with static methods
    arr_ctor: JSValue = js_callable_create("Array", 1, NATIVE_KIND_ARRAY);
    _define_prop(
        arr_ctor,
        k_isarray,
        js_native_create("isArray", 1, NATIVE_KIND_ARRAY_ISARRAY),
        True,
        False,
        True
    );
    _define_prop(
        arr_ctor,
        k_of,
        js_native_create("of", 0, NATIVE_KIND_ARRAY_OF),
        True,
        False,
        True
    );
    _define_prop(
        arr_ctor,
        k_from,
        js_native_create("from", 1, NATIVE_KIND_ARRAY_FROM),
        True,
        False,
        True
    );
    _define_prop(
        arr_ctor,
        k_fromasync,
        js_native_create("fromAsync", 1, NATIVE_KIND_ARRAY_FROM_ASYNC),
        True,
        False,
        True
    );
    # get Array [ @@species ] — §23.1.2.5: accessor, getter returns this, no setter
    sp_key: int = SYMBOL_KEY_BASE + SYMBOL_SPECIES;
    sp_getter: JSValue = js_native_create(
        "get [Symbol.species]", 0, NATIVE_KIND_ARRAY_SPECIES_GET
    );
    js_object_set_accessor_getter(arr_ctor, sp_key, sp_getter);
    # Set accessor attrs directly (no shadowing data-property sentinel).
    js_object_set_accessor_enumerable(arr_ctor, sp_key, False);
    js_object_set_accessor_configurable(arr_ctor, sp_key, True);
    _define_prop(gv, k_array, arr_ctor, True, False, True);

    # Object — callable JSObject with static methods
    obj_ctor: JSValue = js_callable_create("Object", 1, NATIVE_KIND_OBJECT);
    _define_static_method(
        obj_ctor, k_keys, js_native_create("keys", 1, NATIVE_KIND_OBJ_STATIC_KEYS)
    );
    _define_static_method(
        obj_ctor, k_values, js_native_create("values", 1, NATIVE_KIND_OBJ_STATIC_VALUES)
    );
    _define_static_method(
        obj_ctor,
        k_entries,
        js_native_create("entries", 1, NATIVE_KIND_OBJ_STATIC_ENTRIES)
    );
    _define_static_method(
        obj_ctor, k_assign, js_native_create("assign", 2, NATIVE_KIND_OBJ_STATIC_ASSIGN)
    );
    _define_static_method(
        obj_ctor,
        k_fromentries,
        js_native_create("fromEntries", 1, NATIVE_KIND_OBJ_STATIC_FROM_ENTRIES)
    );
    _define_static_method(
        obj_ctor, k_create, js_native_create("create", 2, NATIVE_KIND_OBJ_STATIC_CREATE)
    );
    _define_static_method(
        obj_ctor, k_freeze, js_native_create("freeze", 1, NATIVE_KIND_OBJ_STATIC_FREEZE)
    );
    _define_static_method(
        obj_ctor, k_seal, js_native_create("seal", 1, NATIVE_KIND_OBJ_STATIC_SEAL)
    );
    _define_static_method(
        obj_ctor,
        k_issealed,
        js_native_create("isSealed", 1, NATIVE_KIND_OBJ_STATIC_IS_SEALED)
    );
    _define_static_method(
        obj_ctor,
        k_isfrozen,
        js_native_create("isFrozen", 1, NATIVE_KIND_OBJ_STATIC_IS_FROZEN)
    );
    _define_static_method(
        obj_ctor,
        k_gopn,
        js_native_create("getOwnPropertyNames", 1, NATIVE_KIND_OBJ_STATIC_GETPROPNAMES)
    );
    _define_static_method(
        obj_ctor,
        k_gops,
        js_native_create(
            "getOwnPropertySymbols", 1, NATIVE_KIND_OBJ_GET_OWN_PROP_SYMBOLS
        )
    );
    _define_static_method(
        obj_ctor,
        k_setprotoof,
        js_native_create("setPrototypeOf", 2, NATIVE_KIND_OBJ_SET_PROTOTYPE_OF)
    );
    _define_static_method(
        obj_ctor,
        k_getprotoof,
        js_native_create("getPrototypeOf", 1, NATIVE_KIND_OBJ_GET_PROTOTYPE_OF)
    );
    _define_static_method(
        obj_ctor,
        k_defprop,
        js_native_create("defineProperty", 3, NATIVE_KIND_OBJ_DEFINE_PROPERTY)
    );
    _define_static_method(
        obj_ctor,
        k_defprops,
        js_native_create("defineProperties", 2, NATIVE_KIND_OBJ_DEFINE_PROPERTIES)
    );
    _define_static_method(
        obj_ctor, k_obj_is, js_native_create("is", 2, NATIVE_KIND_OBJ_IS)
    );
    _define_static_method(
        obj_ctor, k_hasown, js_native_create("hasOwn", 2, NATIVE_KIND_OBJ_HASOWN)
    );
    _define_static_method(
        obj_ctor,
        k_gopd,
        js_native_create("getOwnPropertyDescriptor", 2, NATIVE_KIND_OBJ_GETOWNPD)
    );
    _define_static_method(
        obj_ctor,
        k_gopds,
        js_native_create("getOwnPropertyDescriptors", 1, NATIVE_KIND_OBJ_GETOWNPDS)
    );
    _define_static_method(
        obj_ctor,
        k_preventext,
        js_native_create("preventExtensions", 1, NATIVE_KIND_OBJ_PREVENT_EXTENSIONS)
    );
    _define_static_method(
        obj_ctor,
        k_isext,
        js_native_create("isExtensible", 1, NATIVE_KIND_OBJ_IS_EXTENSIBLE)
    );
    _define_prop(gv, k_object, obj_ctor, True, False, True);

    # Proxy — §28.2
    proxy_ctor: JSValue = js_callable_create("Proxy", 2, NATIVE_KIND_PROXY);
    _define_static_method(
        proxy_ctor,
        str_intern("revocable"),
        js_native_create("revocable", 2, NATIVE_KIND_PROXY_REVOCABLE)
    );
    _define_prop(gv, k_proxy, proxy_ctor, True, False, True);

    # Reflect — §28.3 (Phase 1C surface)
    reflect_obj: JSValue = js_object_create_null();
    _define_static_method(
        reflect_obj,
        k_getprotoof,
        js_native_create("getPrototypeOf", 1, NATIVE_KIND_REFLECT_GET_PROTOTYPE_OF)
    );
    _define_static_method(
        reflect_obj,
        k_setprotoof,
        js_native_create("setPrototypeOf", 2, NATIVE_KIND_REFLECT_SET_PROTOTYPE_OF)
    );
    _define_static_method(
        reflect_obj,
        k_defprop,
        js_native_create("defineProperty", 3, NATIVE_KIND_REFLECT_DEFINE_PROPERTY)
    );
    _define_static_method(
        reflect_obj,
        str_intern("ownKeys"),
        js_native_create("ownKeys", 1, NATIVE_KIND_REFLECT_OWN_KEYS)
    );
    _define_static_method(
        reflect_obj,
        str_intern("get"),
        js_native_create("get", 2, NATIVE_KIND_REFLECT_GET)
    );
    _define_static_method(
        reflect_obj,
        str_intern("set"),
        js_native_create("set", 3, NATIVE_KIND_REFLECT_SET)
    );
    _define_static_method(
        reflect_obj,
        str_intern("has"),
        js_native_create("has", 2, NATIVE_KIND_REFLECT_HAS)
    );
    _define_static_method(
        reflect_obj,
        str_intern("deleteProperty"),
        js_native_create("deleteProperty", 2, NATIVE_KIND_REFLECT_DELETE_PROPERTY)
    );
    _define_static_method(
        reflect_obj,
        str_intern("isExtensible"),
        js_native_create("isExtensible", 1, NATIVE_KIND_REFLECT_IS_EXTENSIBLE)
    );
    _define_static_method(
        reflect_obj,
        str_intern("preventExtensions"),
        js_native_create("preventExtensions", 1, NATIVE_KIND_REFLECT_PREVENT_EXTENSIONS)
    );
    _define_static_method(
        reflect_obj,
        str_intern("getOwnPropertyDescriptor"),
        js_native_create(
            "getOwnPropertyDescriptor",
            2,
            NATIVE_KIND_REFLECT_GET_OWN_PROPERTY_DESCRIPTOR
        )
    );
    _define_prop(
        reflect_obj,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Reflect")),
        False,
        False,
        True
    );
    # Writable, non-enumerable, configurable (ordinary built-in method attributes).
    _define_prop(
        reflect_obj,
        str_intern("construct"),
        js_native_create("construct", 2, NATIVE_KIND_REFLECT_CONSTRUCT),
        True,
        False,
        True
    );
    _define_prop(
        reflect_obj,
        str_intern("apply"),
        js_native_create("apply", 3, NATIVE_KIND_REFLECT_APPLY),
        True,
        False,
        True
    );
    _define_prop(gv, k_reflect, reflect_obj, True, False, True);

    # Function — callable JSObject so .prototype can be wired (§20.2)
    fn_ctor: JSValue = js_callable_create("Function", 1, NATIVE_KIND_FUNCTION);
    _define_prop(gv, k_func, fn_ctor, True, False, True);

    # String — callable JSObject with static methods (fromCharCode, fromCodePoint, raw)
    str_ctor: JSValue = js_callable_create("String", 1, NATIVE_KIND_STRING);
    _define_static_method(
        str_ctor,
        k_fromcharcode,
        js_native_create("fromCharCode", 1, NATIVE_KIND_STR_FROMCHARCODE)
    );
    _define_static_method(
        str_ctor,
        k_fromcodepoint,
        js_native_create("fromCodePoint", 1, NATIVE_KIND_STR_FROMCODEPOINT)
    );
    _define_static_method(
        str_ctor, k_raw_key, js_native_create("raw", 1, NATIVE_KIND_STR_RAW)
    );
    _define_prop(gv, k_str_key, str_ctor, True, False, True);

    # Number — callable JSObject; statics + fn_proto wiring after prototype block (§21.1)
    num_ctor: JSValue = js_callable_create("Number", 1, NATIVE_KIND_NUMBER);
    _define_prop(gv, k_number, num_ctor, True, False, True);

    # Boolean — callable JSObject (§20.3)
    bool_ctor: JSValue = js_callable_create("Boolean", 1, NATIVE_KIND_BOOLEAN);
    _define_prop(gv, k_boolean, bool_ctor, True, False, True);

    # BigInt — callable JSObject (§21.2). js_engine represents BigInt values as
    # plain numbers (no true bigint type yet). BigInt(n) returns n as a number;
    # bitwise ops on the result work correctly for bitmask usage patterns.
    k_bigint: int = str_intern("BigInt");
    bigint_ctor: JSValue = js_callable_create("BigInt", 1, NATIVE_KIND_BIGINT);
    _define_prop(gv, k_bigint, bigint_ctor, True, False, True);

    # ── §20.5 Error family constructors ───────────────────────────────────────
    # Created as callable JSObjects (not opaque natives) so each can hold a
    # `prototype` own slot and so `<Ctor>.prototype.constructor === <Ctor>` holds
    # (needed by test262's assert.throws, which reads `err.constructor.name`).
    # Prototype/constructor wiring happens in the prototype-setup block below.
    error_ctor: JSValue = js_callable_create("Error", 1, NATIVE_KIND_ERROR);
    typerr_ctor: JSValue = js_callable_create("TypeError", 1, NATIVE_KIND_TYPE_ERROR);
    referr_ctor: JSValue = js_callable_create(
        "ReferenceError", 1, NATIVE_KIND_REFERENCE_ERROR
    );
    synterr_ctor: JSValue = js_callable_create(
        "SyntaxError", 1, NATIVE_KIND_SYNTAX_ERROR
    );
    rangerr_ctor: JSValue = js_callable_create(
        "RangeError", 1, NATIVE_KIND_RANGE_ERROR
    );
    urierr_ctor: JSValue = js_callable_create("URIError", 1, NATIVE_KIND_URI_ERROR);
    evalerr_ctor: JSValue = js_callable_create("EvalError", 1, NATIVE_KIND_EVAL_ERROR);
    _define_prop(gv, k_error, error_ctor, True, False, True);
    _define_prop(gv, k_typerr, typerr_ctor, True, False, True);
    _define_prop(gv, k_referr, referr_ctor, True, False, True);
    _define_prop(gv, k_synterr, synterr_ctor, True, False, True);
    _define_prop(gv, k_rangerr, rangerr_ctor, True, False, True);
    _define_prop(gv, k_urierr, urierr_ctor, True, False, True);
    _define_prop(gv, k_evalerr, evalerr_ctor, True, False, True);

    # ── §19.2 Global utility functions ────────────────────────────────────────
    # All global functions are { w:T, e:F, c:T } (§17). adel_fixes installed the
    # URI helpers + require via js_object_set (enumerable) — spec-incorrect; the
    # non-enumerable _define_prop form is kept.
    _define_prop(
        gv,
        k_parseint,
        js_native_create("parseInt", 2, NATIVE_KIND_PARSE_INT),
        True,
        False,
        True
    );
    _define_prop(
        gv,
        k_parseflt,
        js_native_create("parseFloat", 1, NATIVE_KIND_PARSE_FLOAT),
        True,
        False,
        True
    );
    _define_prop(
        gv, k_isnan, js_native_create("isNaN", 1, NATIVE_KIND_IS_NAN), True, False, True
    );
    _define_prop(
        gv,
        k_isfinite,
        js_native_create("isFinite", 1, NATIVE_KIND_IS_FINITE),
        True,
        False,
        True
    );
    _define_prop(
        gv, k_eval, js_native_create("eval", 1, NATIVE_KIND_EVAL), True, False, True
    );
    _define_prop(
        gv,
        k_qtask,
        js_native_create("queueMicrotask", 1, NATIVE_KIND_QUEUE_MICROTASK),
        True,
        False,
        True
    );
    # --expose-gc: gc() requests a collection at the next tick (effective when the
    # collector is enabled: --gc / --smol), like Node's V8 flag.
    if process_get_expose_gc() {
        _define_prop(
            gv,
            str_intern("gc"),
            js_native_create("gc", 0, NATIVE_KIND_GC_COLLECT),
            True,
            False,
            True
        );
    }
    _define_prop(
        gv,
        k_encuri_c,
        js_native_create("encodeURIComponent", 1, NATIVE_KIND_ENCODE_URI_COMPONENT),
        True,
        False,
        True
    );
    _define_prop(
        gv,
        k_decuri_c,
        js_native_create("decodeURIComponent", 1, NATIVE_KIND_DECODE_URI_COMPONENT),
        True,
        False,
        True
    );
    _define_prop(
        gv,
        k_encuri,
        js_native_create("encodeURI", 1, NATIVE_KIND_ENCODE_URI),
        True,
        False,
        True
    );
    _define_prop(
        gv,
        k_decuri,
        js_native_create("decodeURI", 1, NATIVE_KIND_DECODE_URI),
        True,
        False,
        True
    );
    _define_prop(
        gv,
        k_require,
        js_native_create("require", 1, NATIVE_KIND_REQUIRE),
        True,
        False,
        True
    );

    # ── console (Bun: ConsoleObject.create(global)) ───────────────────────────
    console: JSValue = js_object_create_null();
    js_object_set(
        console, k_log_k, js_native_create("log", 1, NATIVE_KIND_CONSOLE_LOG)
    );
    js_object_set(
        console, k_info_k, js_native_create("info", 1, NATIVE_KIND_CONSOLE_INFO)
    );
    js_object_set(
        console, k_debug_k, js_native_create("debug", 1, NATIVE_KIND_CONSOLE_DEBUG)
    );
    js_object_set(
        console, k_error_k, js_native_create("error", 1, NATIVE_KIND_CONSOLE_ERROR)
    );
    js_object_set(
        console, k_warn_k, js_native_create("warn", 1, NATIVE_KIND_CONSOLE_WARN)
    );
    js_object_set(
        console, k_dir_k, js_native_create("dir", 1, NATIVE_KIND_CONSOLE_DIR)
    );
    js_object_set(
        console, k_assert_k, js_native_create("assert", 1, NATIVE_KIND_CONSOLE_ASSERT)
    );
    js_object_set(
        console, k_count_k, js_native_create("count", 1, NATIVE_KIND_CONSOLE_COUNT)
    );
    js_object_set(
        console,
        k_ctreset,
        js_native_create("countReset", 1, NATIVE_KIND_CONSOLE_COUNT_RESET)
    );
    js_object_set(
        console, k_time_k, js_native_create("time", 1, NATIVE_KIND_CONSOLE_TIME)
    );
    js_object_set(
        console, k_timend, js_native_create("timeEnd", 1, NATIVE_KIND_CONSOLE_TIME_END)
    );
    js_object_set(
        console, k_timlog, js_native_create("timeLog", 1, NATIVE_KIND_CONSOLE_TIME_LOG)
    );
    js_object_set(
        console, k_group_k, js_native_create("group", 1, NATIVE_KIND_CONSOLE_GROUP)
    );
    js_object_set(
        console,
        k_grpcol,
        js_native_create("groupCollapsed", 1, NATIVE_KIND_CONSOLE_GROUP_COLLAPSED)
    );
    js_object_set(
        console,
        k_grpend,
        js_native_create("groupEnd", 0, NATIVE_KIND_CONSOLE_GROUP_END)
    );
    js_object_set(
        console, k_table_k, js_native_create("table", 1, NATIVE_KIND_CONSOLE_TABLE)
    );
    _define_prop(gv, k_console, console, True, False, True);

    # ── Math (§21.3) ──────────────────────────────────────────────────────────
    js_math_seed_random();  # seed drand48 with time(0) once
    # ES §21.3: the Math object is an ordinary object whose [[Prototype]] is
    # %Object.prototype%. obj_proto does not exist yet at this point in the
    # bootstrap, so the chain is wired up later (see "Math [[Prototype]]" below).
    math: JSValue = js_object_create_null();
    # Constants — ES §21.3.1: non-enumerable, non-writable, non-configurable
    # (js_object_set would make them all true, so `delete Math.E` wrongly succeeded).
    _define_static_const(math, k_pi, js_number(3.141592653589793));
    _define_static_const(math, k_e, js_number(2.718281828459045));
    _define_static_const(math, k_ln2, js_number(0.6931471805599453));
    _define_static_const(math, k_ln10, js_number(2.302585092994046));
    _define_static_const(math, k_log2e, js_number(1.4426950408889634));
    _define_static_const(math, k_log10e, js_number(0.4342944819032518));
    _define_static_const(math, k_sqrt2, js_number(1.4142135623730951));
    _define_static_const(math, str_intern("SQRT1_2"), js_number(0.7071067811865476));
    # §21.3.1.9 Math [ @@toStringTag ] → "Math"  { w:F, e:F, c:T }
    _define_prop(
        math,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Math")),
        False,
        False,
        True
    );
    # Methods
    k_m_abs: int = str_intern("abs");
    k_m_acos: int = str_intern("acos");
    k_m_acosh: int = str_intern("acosh");
    k_m_asin: int = str_intern("asin");
    k_m_asinh: int = str_intern("asinh");
    k_m_atan: int = str_intern("atan");
    k_m_atan2: int = str_intern("atan2");
    k_m_atanh: int = str_intern("atanh");
    k_m_cbrt: int = str_intern("cbrt");
    k_m_ceil: int = str_intern("ceil");
    k_m_clz32: int = str_intern("clz32");
    k_m_cos: int = str_intern("cos");
    k_m_cosh: int = str_intern("cosh");
    k_m_exp: int = str_intern("exp");
    k_m_expm1: int = str_intern("expm1");
    k_m_floor: int = str_intern("floor");
    k_m_fround: int = str_intern("fround");
    k_m_hypot: int = str_intern("hypot");
    k_m_imul: int = str_intern("imul");
    k_m_log: int = str_intern("log");
    k_m_log10: int = str_intern("log10");
    k_m_log1p: int = str_intern("log1p");
    k_m_log2: int = str_intern("log2");
    k_m_max: int = str_intern("max");
    k_m_min: int = str_intern("min");
    k_m_pow: int = str_intern("pow");
    k_m_random: int = str_intern("random");
    k_m_round: int = str_intern("round");
    k_m_sign: int = str_intern("sign");
    k_m_sin: int = str_intern("sin");
    k_m_sinh: int = str_intern("sinh");
    k_m_sqrt: int = str_intern("sqrt");
    k_m_tan: int = str_intern("tan");
    k_m_tanh: int = str_intern("tanh");
    k_m_trunc: int = str_intern("trunc");
    _define_static_method(
        math, k_m_abs, js_native_create("abs", 1, NATIVE_KIND_MATH_ABS)
    );
    _define_static_method(
        math, k_m_acos, js_native_create("acos", 1, NATIVE_KIND_MATH_ACOS)
    );
    _define_static_method(
        math, k_m_acosh, js_native_create("acosh", 1, NATIVE_KIND_MATH_ACOSH)
    );
    _define_static_method(
        math, k_m_asin, js_native_create("asin", 1, NATIVE_KIND_MATH_ASIN)
    );
    _define_static_method(
        math, k_m_asinh, js_native_create("asinh", 1, NATIVE_KIND_MATH_ASINH)
    );
    _define_static_method(
        math, k_m_atan, js_native_create("atan", 1, NATIVE_KIND_MATH_ATAN)
    );
    _define_static_method(
        math, k_m_atan2, js_native_create("atan2", 2, NATIVE_KIND_MATH_ATAN2)
    );
    _define_static_method(
        math, k_m_atanh, js_native_create("atanh", 1, NATIVE_KIND_MATH_ATANH)
    );
    _define_static_method(
        math, k_m_cbrt, js_native_create("cbrt", 1, NATIVE_KIND_MATH_CBRT)
    );
    _define_static_method(
        math, k_m_ceil, js_native_create("ceil", 1, NATIVE_KIND_MATH_CEIL)
    );
    _define_static_method(
        math, k_m_clz32, js_native_create("clz32", 1, NATIVE_KIND_MATH_CLZ32)
    );
    _define_static_method(
        math, k_m_cos, js_native_create("cos", 1, NATIVE_KIND_MATH_COS)
    );
    _define_static_method(
        math, k_m_cosh, js_native_create("cosh", 1, NATIVE_KIND_MATH_COSH)
    );
    _define_static_method(
        math, k_m_exp, js_native_create("exp", 1, NATIVE_KIND_MATH_EXP)
    );
    _define_static_method(
        math, k_m_expm1, js_native_create("expm1", 1, NATIVE_KIND_MATH_EXPM1)
    );
    _define_static_method(
        math, k_m_floor, js_native_create("floor", 1, NATIVE_KIND_MATH_FLOOR)
    );
    _define_static_method(
        math, k_m_fround, js_native_create("fround", 1, NATIVE_KIND_MATH_FROUND)
    );
    _define_static_method(
        math, k_m_hypot, js_native_create("hypot", 2, NATIVE_KIND_MATH_HYPOT)
    );
    _define_static_method(
        math, k_m_imul, js_native_create("imul", 2, NATIVE_KIND_MATH_IMUL)
    );
    _define_static_method(
        math, k_m_log, js_native_create("log", 1, NATIVE_KIND_MATH_LOG)
    );
    _define_static_method(
        math, k_m_log10, js_native_create("log10", 1, NATIVE_KIND_MATH_LOG10)
    );
    _define_static_method(
        math, k_m_log1p, js_native_create("log1p", 1, NATIVE_KIND_MATH_LOG1P)
    );
    _define_static_method(
        math, k_m_log2, js_native_create("log2", 1, NATIVE_KIND_MATH_LOG2)
    );
    _define_static_method(
        math, k_m_max, js_native_create("max", 2, NATIVE_KIND_MATH_MAX)
    );
    _define_static_method(
        math, k_m_min, js_native_create("min", 2, NATIVE_KIND_MATH_MIN)
    );
    _define_static_method(
        math, k_m_pow, js_native_create("pow", 2, NATIVE_KIND_MATH_POW)
    );
    _define_static_method(
        math, k_m_random, js_native_create("random", 0, NATIVE_KIND_MATH_RANDOM)
    );
    _define_static_method(
        math, k_m_round, js_native_create("round", 1, NATIVE_KIND_MATH_ROUND)
    );
    _define_static_method(
        math, k_m_sign, js_native_create("sign", 1, NATIVE_KIND_MATH_SIGN)
    );
    _define_static_method(
        math, k_m_sin, js_native_create("sin", 1, NATIVE_KIND_MATH_SIN)
    );
    _define_static_method(
        math, k_m_sinh, js_native_create("sinh", 1, NATIVE_KIND_MATH_SINH)
    );
    _define_static_method(
        math, k_m_sqrt, js_native_create("sqrt", 1, NATIVE_KIND_MATH_SQRT)
    );
    _define_static_method(
        math, k_m_tan, js_native_create("tan", 1, NATIVE_KIND_MATH_TAN)
    );
    _define_static_method(
        math, k_m_tanh, js_native_create("tanh", 1, NATIVE_KIND_MATH_TANH)
    );
    _define_static_method(
        math, k_m_trunc, js_native_create("trunc", 1, NATIVE_KIND_MATH_TRUNC)
    );
    # §21.3.1.1 Math[@@toStringTag] = "Math" (non-enumerable)
    _define_prop(
        math,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Math")),
        False,
        False,
        True
    );
    _define_prop(gv, k_math, math, True, False, True);

    # ── JSON (§25.5) ──────────────────────────────────────────────────
    k_j_parse: int = str_intern("parse");
    k_j_strf: int = str_intern("stringify");
    # ES §25.5: JSON is an ordinary object rooted at %Object.prototype% (linked
    # after obj_proto exists — see the "Math [[Prototype]]" block). Its methods
    # are { w:T, e:F, c:T }; js_object_set made them enumerable.
    json: JSValue = js_object_create_null();
    _define_static_method(
        json, k_j_parse, js_native_create("parse", 2, NATIVE_KIND_JSON_PARSE)
    );
    _define_static_method(
        json, k_j_strf, js_native_create("stringify", 3, NATIVE_KIND_JSON_STRINGIFY)
    );
    # §25.5.3 JSON [ @@toStringTag ] → "JSON"  { w:F, e:F, c:T }
    _define_prop(
        json,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("JSON")),
        False,
        False,
        True
    );
    _define_prop(gv, k_json, json, True, False, True);
    # ── Symbol (§20.4) ─────────────────────────────────────────────────────
    k_symbol: int = str_intern("Symbol");
    k_sym_for: int = str_intern("for");
    k_sym_keyfor: int = str_intern("keyFor");
    k_sym_tostr: int = str_intern("toString");
    k_sym_desckey: int = str_intern("description");
    k_sym_iter: int = str_intern("iterator");
    k_sym_toprim: int = str_intern("toPrimitive");
    k_sym_hasinst: int = str_intern("hasInstance");
    k_sym_tag: int = str_intern("toStringTag");
    k_sym_species: int = str_intern("species");
    k_sym_asynciter: int = str_intern("asyncIterator");
    k_sym_match: int = str_intern("match");
    k_sym_matchall: int = str_intern("matchAll");
    k_sym_replace: int = str_intern("replace");
    k_sym_search: int = str_intern("search");
    k_sym_split: int = str_intern("split");
    k_sym_unscopables: int = str_intern("unscopables");
    k_sym_dispose: int = str_intern("dispose");
    k_sym_async_dispose: int = str_intern("asyncDispose");
    k_sym_isconcatspreadable: int = str_intern("isConcatSpreadable");

    # Symbol is a callable JSObject so static properties can be attached.
    # §20.4.1: the Symbol constructor's `length` is 0 (description is optional).
    # adel_fixes used length 1 — spec-incorrect. Well-known-symbol static props are
    # { w:F, e:F, c:F }; _define_static_const installs exactly that (equivalent to
    # adel_fixes' explicit _define_prop(..., False, False, False) form).
    sym_ctor: JSValue = js_callable_create("Symbol", 0, NATIVE_KIND_SYMBOL);
    # Static methods
    _define_static_method(
        sym_ctor, k_sym_for, js_native_create("for", 1, NATIVE_KIND_SYMBOL_FOR)
    );
    _define_static_method(
        sym_ctor, k_sym_keyfor, js_native_create("keyFor", 1, NATIVE_KIND_SYMBOL_KEYFOR)
    );
    # Well-known symbol static properties (fixed IDs seeded above)
    _define_static_const(sym_ctor, k_sym_iter, js_well_known_symbol(SYMBOL_ITERATOR));
    _define_static_const(
        sym_ctor, k_sym_toprim, js_well_known_symbol(SYMBOL_TO_PRIMITIVE)
    );
    _define_static_const(
        sym_ctor, k_sym_hasinst, js_well_known_symbol(SYMBOL_HAS_INSTANCE)
    );
    _define_static_const(
        sym_ctor, k_sym_tag, js_well_known_symbol(SYMBOL_TO_STRING_TAG)
    );
    _define_static_const(sym_ctor, k_sym_species, js_well_known_symbol(SYMBOL_SPECIES));
    _define_static_const(
        sym_ctor, k_sym_asynciter, js_well_known_symbol(SYMBOL_ASYNC_ITERATOR)
    );
    _define_static_const(sym_ctor, k_sym_match, js_well_known_symbol(SYMBOL_MATCH));
    _define_static_const(
        sym_ctor, k_sym_matchall, js_well_known_symbol(SYMBOL_MATCH_ALL)
    );
    _define_static_const(sym_ctor, k_sym_replace, js_well_known_symbol(SYMBOL_REPLACE));
    _define_static_const(sym_ctor, k_sym_search, js_well_known_symbol(SYMBOL_SEARCH));
    _define_static_const(sym_ctor, k_sym_split, js_well_known_symbol(SYMBOL_SPLIT));
    _define_static_const(
        sym_ctor, k_sym_unscopables, js_well_known_symbol(SYMBOL_UNSCOPABLES)
    );
    _define_static_const(sym_ctor, k_sym_dispose, js_well_known_symbol(SYMBOL_DISPOSE));
    _define_static_const(
        sym_ctor, k_sym_async_dispose, js_well_known_symbol(SYMBOL_ASYNC_DISPOSE)
    );
    _define_static_const(
        sym_ctor,
        k_sym_isconcatspreadable,
        js_well_known_symbol(SYMBOL_ISOONCATSPREADABLE)
    );
    _define_prop(gv, k_symbol, sym_ctor, True, False, True);
    # ── Map (§24.1) ─────────────────────────────────────────────────────────────────
    k_map: int = str_intern("Map");
    map_ctor: JSValue = js_callable_create("Map", 0, NATIVE_KIND_MAP);
    _define_prop(gv, k_map, map_ctor, True, False, True);
    # ── Set (§24.2) ─────────────────────────────────────────────────────────────────
    k_set: int = str_intern("Set");
    set_ctor: JSValue = js_callable_create("Set", 0, NATIVE_KIND_SET);
    _define_prop(gv, k_set, set_ctor, True, False, True);
    # ── WeakMap (§24.3) ───────────────────────────────────────────────────────────
    k_weakmap: int = str_intern("WeakMap");
    weakmap_ctor: JSValue = js_callable_create("WeakMap", 0, NATIVE_KIND_WEAKMAP);
    _define_prop(gv, k_weakmap, weakmap_ctor, True, False, True);
    # ── WeakSet (§24.4) ───────────────────────────────────────────────────────────
    k_weakset: int = str_intern("WeakSet");
    weakset_ctor: JSValue = js_callable_create("WeakSet", 0, NATIVE_KIND_WEAKSET);
    _define_prop(gv, k_weakset, weakset_ctor, True, False, True);
    # ── Date (§21.4) ──────────────────────────────────────────────────────────────
    k_date: int = str_intern("Date");
    date_ctor: JSValue = js_callable_create("Date", 7, NATIVE_KIND_DATE);
    _define_static_method(
        date_ctor, str_intern("now"), js_native_create("now", 0, NATIVE_KIND_DATE_NOW)
    );
    _define_static_method(
        date_ctor,
        str_intern("parse"),
        js_native_create("parse", 1, NATIVE_KIND_DATE_PARSE)
    );
    _define_static_method(
        date_ctor, str_intern("UTC"), js_native_create("UTC", 7, NATIVE_KIND_DATE_UTC)
    );
    _define_prop(gv, k_date, date_ctor, True, False, True);
    # ── GeneratorFunction (§27.3) ─────────────────────────────────────────────
    k_genfn: int = str_intern("GeneratorFunction");
    gen_fn_ctor: JSValue = js_callable_create(
        "GeneratorFunction", 1, NATIVE_KIND_GENERATOR_FUNCTION
    );
    _define_prop(gv, k_genfn, gen_fn_ctor, True, False, True);
    # ── Promise (§27.2) ───────────────────────────────────────────────────────
    k_promise: int = str_intern("Promise");
    promise_ctor: JSValue = js_callable_create("Promise", 1, NATIVE_KIND_PROMISE);
    _define_static_method(
        promise_ctor,
        str_intern("resolve"),
        js_native_create("resolve", 1, NATIVE_KIND_PROMISE_STATIC_RESOLVE)
    );
    _define_static_method(
        promise_ctor,
        str_intern("reject"),
        js_native_create("reject", 1, NATIVE_KIND_PROMISE_STATIC_REJECT)
    );
    _define_static_method(
        promise_ctor,
        str_intern("all"),
        js_native_create("all", 1, NATIVE_KIND_PROMISE_ALL)
    );
    _define_static_method(
        promise_ctor,
        str_intern("allSettled"),
        js_native_create("allSettled", 1, NATIVE_KIND_PROMISE_ALLSETTLED)
    );
    _define_static_method(
        promise_ctor,
        str_intern("race"),
        js_native_create("race", 1, NATIVE_KIND_PROMISE_RACE)
    );
    _define_static_method(
        promise_ctor,
        str_intern("any"),
        js_native_create("any", 1, NATIVE_KIND_PROMISE_ANY)
    );
    _define_static_method(
        promise_ctor,
        str_intern("withResolvers"),
        js_native_create("withResolvers", 0, NATIVE_KIND_PROMISE_WITHRESOLVERS)
    );
    _define_prop(gv, k_promise, promise_ctor, True, False, True);
    # ── RegExp (§22.2) ────────────────────────────────────────────────────────
    k_regexp: int = str_intern("RegExp");
    regexp_ctor: JSValue = js_callable_create("RegExp", 2, NATIVE_KIND_REGEXP);
    # Function `name` is a non-writable, non-enumerable, configurable data prop
    # (ECMAScript §20.2.4.2).  Needed so `RegExp.name` and `r.constructor.name`
    # resolve to "RegExp" — rolldown's napi binding relies on this to recognise
    # a RegExp filter payload.
    _define_prop(
        regexp_ctor,
        str_intern("name"),
        jsv_from_string_id(str_intern("RegExp")),
        False,
        False,
        True
    );
    _define_prop(gv, k_regexp, regexp_ctor, True, False, True);

    # ── Timers ─────────────────────────────────────────────────────
    # setTimeout / clearTimeout / setInterval / clearInterval / setImmediate / clearImmediate
    js_object_set(
        gv,
        str_intern("setTimeout"),
        js_native_create("setTimeout", 2, NATIVE_KIND_SET_TIMEOUT)
    );
    js_object_set(
        gv,
        str_intern("clearTimeout"),
        js_native_create("clearTimeout", 1, NATIVE_KIND_CLEAR_TIMEOUT)
    );
    js_object_set(
        gv,
        str_intern("setInterval"),
        js_native_create("setInterval", 2, NATIVE_KIND_SET_INTERVAL)
    );
    js_object_set(
        gv,
        str_intern("clearInterval"),
        js_native_create("clearInterval", 1, NATIVE_KIND_CLEAR_INTERVAL)
    );
    js_object_set(
        gv,
        str_intern("setImmediate"),
        js_native_create("setImmediate", 1, NATIVE_KIND_SET_IMMEDIATE)
    );
    js_object_set(
        gv,
        str_intern("clearImmediate"),
        js_native_create("clearImmediate", 1, NATIVE_KIND_CLEAR_IMMEDIATE)
    );
    # performance.now()
    perf_obj: JSValue = js_object_create_null();
    js_object_set(
        perf_obj,
        str_intern("now"),
        js_native_create("now", 0, NATIVE_KIND_PERFORMANCE_NOW)
    );
    js_object_set(gv, str_intern("performance"), perf_obj);

    # ── process ───────────────────────────────────────────────────
    proc_obj: JSValue = js_object_create_null();
    # Capture process start time for process.uptime()
    process_init_start_time();
    # process.nextTick
    js_object_set(
        proc_obj,
        str_intern("nextTick"),
        js_native_create("nextTick", 1, NATIVE_KIND_NEXT_TICK)
    );
    # process.version / platform / arch
    js_object_set(
        proc_obj,
        str_intern("version"),
        jsv_from_string_id(str_intern(JS_ENGINE_VERSION_V))
    );
    js_object_set(
        proc_obj, str_intern("platform"), jsv_from_string_id(str_intern("linux"))
    );
    js_object_set(proc_obj, str_intern("arch"), jsv_from_string_id(str_intern("x64")));
    # process.pid / process.ppid
    js_object_set(proc_obj, str_intern("pid"), js_int(process_get_pid()));
    js_object_set(proc_obj, str_intern("ppid"), js_int(process_get_ppid()));
    # process.title — process name visible in ps/top (--title=<val> overrides the default)
    js_object_set(
        proc_obj,
        str_intern("title"),
        jsv_from_string_id(str_intern(process_get_title()))
    );
    # --no-deprecation / --throw-deprecation are visible as process.noDeprecation /
    # process.throwDeprecation (Node); util.deprecate and emitWarning consult them.
    if process_get_no_deprecation() {
        js_object_set(proc_obj, str_intern("noDeprecation"), js_true());
    }
    if process_get_throw_deprecation() {
        js_object_set(proc_obj, str_intern("throwDeprecation"), js_true());
    }
    # process.argv0 / process.execPath — set from OS argv[0] via process_set_bootstrap_paths
    js_object_set(
        proc_obj,
        str_intern("argv0"),
        jsv_from_string_id(str_intern(process_get_argv0()))
    );
    js_object_set(
        proc_obj,
        str_intern("execPath"),
        jsv_from_string_id(str_intern(process_get_exec_path()))
    );
    # process.execArgv — Node-compatible engine flags (populated by main CLI parse)
    js_object_set(proc_obj, str_intern("execArgv"), process_build_exec_argv());
    # process.versions — only components that actually exist in js_engine.
    # V8, modules, napi, ares, brotli are Node.js/V8 internals omitted here.
    # nghttp2 and llhttp ARE included — js_engine ships both libraries (Phase D/E).
    proc_versions: JSValue = js_object_create_null();
    js_object_set(
        proc_versions,
        str_intern("js_engine"),
        jsv_from_string_id(str_intern(JS_ENGINE_VERSION))
    );
    js_object_set(
        proc_versions,
        str_intern("node"),
        jsv_from_string_id(str_intern(NODE_COMPAT_VERSION))
    );
    js_object_set(
        proc_versions, str_intern("uv"), jsv_from_string_id(str_intern(UV_VERSION))
    );
    js_object_set(
        proc_versions,
        str_intern("openssl"),
        jsv_from_string_id(str_intern(OPENSSL_VERSION))
    );
    js_object_set(
        proc_versions, str_intern("zlib"), jsv_from_string_id(str_intern(ZLIB_VERSION))
    );
    js_object_set(
        proc_versions,
        str_intern("pcre2"),
        jsv_from_string_id(str_intern(PCRE2_VERSION))
    );
    js_object_set(
        proc_versions,
        str_intern("llhttp"),
        jsv_from_string_id(str_intern(LLHTTP_VERSION))
    );
    js_object_set(
        proc_versions,
        str_intern("nghttp2"),
        jsv_from_string_id(str_intern(NGHTTP2_VERSION))
    );
    js_object_set(proc_obj, str_intern("versions"), proc_versions);
    # process.release — js_engine release metadata
    proc_release: JSValue = js_object_create_null();
    js_object_set(
        proc_release, str_intern("name"), jsv_from_string_id(str_intern("js_engine"))
    );
    js_object_set(
        proc_release,
        str_intern("version"),
        jsv_from_string_id(str_intern(JS_ENGINE_VERSION_V))
    );
    js_object_set(proc_obj, str_intern("release"), proc_release);
    # process.features — js_engine actual build capabilities (not Node.js flags)
    proc_features: JSValue = js_object_create_null();
    js_object_set(proc_features, str_intern("uv"), js_true());  # uses libuv
    js_object_set(proc_features, str_intern("ipv6"), js_true());  # dual-stack networking
    js_object_set(proc_features, str_intern("tls"), js_true());  # OpenSSL TLS
    js_object_set(proc_features, str_intern("tls_sni"), js_true());  # SNI supported
    js_object_set(proc_features, str_intern("tls_alpn"), js_true());  # ALPN wired — Phase G
    js_object_set(proc_features, str_intern("tls_ocsp"), js_false());  # OCSP not implemented
    js_object_set(proc_features, str_intern("debug"), js_false());  # not a debug build
    js_object_set(proc_features, str_intern("inspector"), js_false());  # inspector not enabled
    # TypeScript stripping/transform not enabled — expose so test harness skip() paths
    # can read process.features.typescript without crashing on undefined.
    js_object_set(proc_features, str_intern("typescript"), js_false());
    js_object_set(proc_obj, str_intern("features"), proc_features);
    # process[@@toStringTag] = "process" (writable, as Node; also set from process.js)
    js_object_define_nonenum(
        proc_obj,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("process"))
    );
    # process.config — Node-shaped configure variables (needed by test/common)
    proc_config: JSValue = js_object_create_null();
    proc_config_vars: JSValue = js_object_create_null();
    js_object_set(
        proc_config_vars, str_intern("v8_enable_i18n_support"), js_number(0.0)
    );
    js_object_set(proc_config_vars, str_intern("asan"), js_number(0.0));
    js_object_set(proc_config_vars, str_intern("node_use_openssl"), js_true());
    js_object_set(proc_config_vars, str_intern("node_shared_openssl"), js_false());
    js_object_set(proc_config_vars, str_intern("icu_small"), js_false());
    js_object_set(proc_config, str_intern("variables"), proc_config_vars);
    proc_config_td: JSValue = js_object_create_null();
    js_object_set(
        proc_config_td,
        str_intern("default_configuration"),
        jsv_from_string_id(str_intern("Release"))
    );
    js_object_set(proc_config, str_intern("target_defaults"), proc_config_td);
    js_object_set(proc_obj, str_intern("config"), proc_config);
    # process.noDeprecation / throwDeprecation / traceDeprecation / traceProcessWarnings
    js_object_set(proc_obj, str_intern("noDeprecation"), js_false());
    js_object_set(proc_obj, str_intern("throwDeprecation"), js_false());
    js_object_set(proc_obj, str_intern("traceDeprecation"), js_false());
    js_object_set(proc_obj, str_intern("traceProcessWarnings"), js_false());
    # process.exit(code?)
    js_object_set(
        proc_obj,
        str_intern("exit"),
        js_native_create("exit", 1, NATIVE_KIND_PROCESS_EXIT)
    );
    # process.hrtime([prev])
    js_object_set(
        proc_obj,
        str_intern("hrtime"),
        js_native_create("hrtime", 0, NATIVE_KIND_PROCESS_HRTIME)
    );
    # process.uptime()
    js_object_set(
        proc_obj,
        str_intern("uptime"),
        js_native_create("uptime", 0, NATIVE_KIND_PROCESS_UPTIME)
    );
    # process EventEmitter surface
    js_object_set(
        proc_obj, str_intern("on"), js_native_create("on", 2, NATIVE_KIND_PROCESS_ON)
    );
    js_object_set(
        proc_obj,
        str_intern("once"),
        js_native_create("once", 2, NATIVE_KIND_PROCESS_ONCE)
    );
    js_object_set(
        proc_obj, str_intern("off"), js_native_create("off", 2, NATIVE_KIND_PROCESS_OFF)
    );
    js_object_set(
        proc_obj,
        str_intern("removeListener"),
        js_native_create("removeListener", 2, NATIVE_KIND_PROCESS_REMOVE_LISTENER)
    );
    js_object_set(
        proc_obj,
        str_intern("removeAllListeners"),
        js_native_create("removeAllListeners", 1, NATIVE_KIND_PROCESS_REMOVE_ALL)
    );
    js_object_set(
        proc_obj,
        str_intern("emit"),
        js_native_create("emit", 1, NATIVE_KIND_PROCESS_EMIT)
    );
    js_object_set(
        proc_obj,
        str_intern("emitWarning"),
        js_native_create("emitWarning", 1, NATIVE_KIND_PROCESS_EMIT_WARNING)
    );
    # process.memoryUsage()
    js_object_set(
        proc_obj,
        str_intern("memoryUsage"),
        js_native_create("memoryUsage", 0, NATIVE_KIND_PROCESS_MEMORY_USAGE)
    );
    # process.cpuUsage()
    js_object_set(
        proc_obj,
        str_intern("cpuUsage"),
        js_native_create("cpuUsage", 0, NATIVE_KIND_PROCESS_CPU_USAGE)
    );
    # process.umask()
    js_object_set(
        proc_obj,
        str_intern("umask"),
        js_native_create("umask", 0, NATIVE_KIND_PROCESS_UMASK)
    );
    # process.cwd()
    js_object_set(
        proc_obj, str_intern("cwd"), js_native_create("cwd", 0, NATIVE_KIND_PROCESS_CWD)
    );
    # process.abort() — generate core dump
    js_object_set(
        proc_obj,
        str_intern("abort"),
        js_native_create("abort", 0, NATIVE_KIND_PROCESS_ABORT)
    );
    # process.chdir(dir) — change working directory
    js_object_set(
        proc_obj,
        str_intern("chdir"),
        js_native_create("chdir", 1, NATIVE_KIND_PROCESS_CHDIR)
    );
    # process.kill(pid[, signal]) — send signal to process
    js_object_set(
        proc_obj,
        str_intern("kill"),
        js_native_create("kill", 1, NATIVE_KIND_PROCESS_KILL)
    );
    # process.getuid/getgid/geteuid/getegid — POSIX user/group IDs
    js_object_set(
        proc_obj,
        str_intern("getuid"),
        js_native_create("getuid", 0, NATIVE_KIND_PROCESS_GETUID)
    );
    js_object_set(
        proc_obj,
        str_intern("getgid"),
        js_native_create("getgid", 0, NATIVE_KIND_PROCESS_GETGID)
    );
    js_object_set(
        proc_obj,
        str_intern("geteuid"),
        js_native_create("geteuid", 0, NATIVE_KIND_PROCESS_GETEUID)
    );
    js_object_set(
        proc_obj,
        str_intern("getegid"),
        js_native_create("getegid", 0, NATIVE_KIND_PROCESS_GETEGID)
    );
    # process.getgroups() / set*id — Phase E
    js_object_set(
        proc_obj,
        str_intern("getgroups"),
        js_native_create("getgroups", 0, NATIVE_KIND_PROCESS_GETGROUPS)
    );
    js_object_set(
        proc_obj,
        str_intern("setuid"),
        js_native_create("setuid", 1, NATIVE_KIND_PROCESS_SETUID)
    );
    js_object_set(
        proc_obj,
        str_intern("setgid"),
        js_native_create("setgid", 1, NATIVE_KIND_PROCESS_SETGID)
    );
    js_object_set(
        proc_obj,
        str_intern("seteuid"),
        js_native_create("seteuid", 1, NATIVE_KIND_PROCESS_SETEUID)
    );
    js_object_set(
        proc_obj,
        str_intern("setegid"),
        js_native_create("setegid", 1, NATIVE_KIND_PROCESS_SETEGID)
    );
    # process.availableMemory() / process.resourceUsage() — Phase E
    js_object_set(
        proc_obj,
        str_intern("availableMemory"),
        js_native_create("availableMemory", 0, NATIVE_KIND_PROCESS_AVAILABLE_MEMORY)
    );
    js_object_set(
        proc_obj,
        str_intern("resourceUsage"),
        js_native_create("resourceUsage", 0, NATIVE_KIND_PROCESS_RESOURCE_USAGE)
    );
    # process.loadEnvFile(path) — Phase E
    js_object_set(
        proc_obj,
        str_intern("loadEnvFile"),
        js_native_create("loadEnvFile", 1, NATIVE_KIND_PROCESS_LOAD_ENV_FILE)
    );
    # process.setSourceMapsEnabled(bool) — Vite V-03 no-op compatibility
    js_object_set(
        proc_obj,
        str_intern("setSourceMapsEnabled"),
        js_native_create(
            "setSourceMapsEnabled", 1, NATIVE_KIND_PROCESS_SET_SOURCE_MAPS_ENABLED
        )
    );
    # process.getBuiltinModule(id) — Vite importMetaResolver
    js_object_set(
        proc_obj,
        str_intern("getBuiltinModule"),
        js_native_create("getBuiltinModule", 1, NATIVE_KIND_PROCESS_GET_BUILTIN_MODULE)
    );
    # process.getActiveResourcesInfo() — timer-backed type-string list
    js_object_set(
        proc_obj,
        str_intern("getActiveResourcesInfo"),
        js_native_create(
            "getActiveResourcesInfo", 0, NATIVE_KIND_PROCESS_GET_ACTIVE_RESOURCES_INFO
        )
    );
    # process.env — pre-populated from entry point via process_add_env()
    js_object_set(proc_obj, str_intern("env"), process_get_env());
    # process.stdout — Writable stream backed by fd 1
    proc_stdout: JSValue = stream_create_writable(1);
    if isatty(1) != 0 {
        js_object_set(proc_stdout, str_intern("isTTY"), js_true());
    }
    js_object_set(proc_obj, str_intern("stdout"), proc_stdout);
    # process.stderr — Writable stream backed by fd 2
    proc_stderr: JSValue = stream_create_writable(2);
    if isatty(2) != 0 {
        js_object_set(proc_stderr, str_intern("isTTY"), js_true());
    }
    js_object_set(proc_obj, str_intern("stderr"), proc_stderr);
    # process.stdin — Readable stream backed by fd 0
    proc_stdin: JSValue = stream_create_readable();
    js_object_set(proc_stdin, str_intern("fd"), js_int(0));
    if isatty(0) != 0 {
        js_object_set(proc_stdin, str_intern("isTTY"), js_true());
        js_object_set(proc_stdin, str_intern("isRaw"), js_false());
        js_object_set(
            proc_stdin,
            str_intern("setRawMode"),
            js_native_create("setRawMode", 1, NATIVE_KIND_STREAM_SET_RAW_MODE)
        );
    }
    js_object_set(proc_obj, str_intern("stdin"), proc_stdin);

    # ── __tty_info — TTY detection map for tty.isatty() ──────────
    # Maps fd string ("0", "1", "2") to boolean isatty() result.
    # Used by builtins/js/tty.js via globalThis.__tty_info.
    tty_info: JSValue = js_object_create_null();
    if isatty(0) != 0 {
        js_object_set(tty_info, str_intern("0"), js_true());
    } else {
        js_object_set(tty_info, str_intern("0"), js_false());
    }
    if isatty(1) != 0 {
        js_object_set(tty_info, str_intern("1"), js_true());
    } else {
        js_object_set(tty_info, str_intern("1"), js_false());
    }
    if isatty(2) != 0 {
        js_object_set(tty_info, str_intern("2"), js_true());
    } else {
        js_object_set(tty_info, str_intern("2"), js_false());
    }
    js_object_set(gv, str_intern("__tty_info"), tty_info);

    # process.argv — populated later from el_run (needs script_name)
    js_object_set(gv, str_intern("process"), proc_obj);

    # ── globalThis.js_engine — runtime identity (mirrors Bun/Deno pattern) ────────
    # Exposes version so tooling (e.g. cac/vite CLI) can detect our runtime
    # and show "js_engine-vX.Y.Z" instead of "node-vX.Y.Z".
    js_engine_obj: JSValue = js_object_create_null();
    js_object_set(
        js_engine_obj,
        str_intern("version"),
        jsv_from_string_id(str_intern(JS_ENGINE_VERSION))
    );
    js_object_set(gv, str_intern("js_engine"), js_engine_obj);

    # ── fs global object ─────────────────────────────────────────
    # Exposed as globalThis.fs (interim until require("fs") is implemented)
    fs_obj: JSValue = js_object_create_null();
    js_object_set(
        fs_obj,
        str_intern("readFile"),
        js_native_create("readFile", 3, NATIVE_KIND_FS_READ_FILE)
    );
    js_object_set(
        fs_obj,
        str_intern("writeFile"),
        js_native_create("writeFile", 3, NATIVE_KIND_FS_WRITE_FILE)
    );
    js_object_set(
        fs_obj,
        str_intern("readFileSync"),
        js_native_create("readFileSync", 2, NATIVE_KIND_FS_READ_FILE_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("writeFileSync"),
        js_native_create("writeFileSync", 2, NATIVE_KIND_FS_WRITE_FILE_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("appendFileSync"),
        js_native_create("appendFileSync", 2, NATIVE_KIND_FS_APPEND_FILE_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("existsSync"),
        js_native_create("existsSync", 1, NATIVE_KIND_FS_EXISTS_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("unlinkSync"),
        js_native_create("unlinkSync", 1, NATIVE_KIND_FS_UNLINK_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("statSync"),
        js_native_create("statSync", 1, NATIVE_KIND_FS_STAT_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("createReadStream"),
        js_native_create("createReadStream", 1, NATIVE_KIND_FS_CREATE_READ_STREAM)
    );
    js_object_set(
        fs_obj,
        str_intern("readdirSync"),
        js_native_create("readdirSync", 1, NATIVE_KIND_FS_READDIR_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("mkdirSync"),
        js_native_create("mkdirSync", 2, NATIVE_KIND_FS_MKDIR_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("rmdirSync"),
        js_native_create("rmdirSync", 1, NATIVE_KIND_FS_RMDIR_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("rmSync"),
        js_native_create("rmSync", 2, NATIVE_KIND_FS_RM_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("renameSync"),
        js_native_create("renameSync", 2, NATIVE_KIND_FS_RENAME_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("copyFileSync"),
        js_native_create("copyFileSync", 3, NATIVE_KIND_FS_COPYFILE_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("chmodSync"),
        js_native_create("chmodSync", 2, NATIVE_KIND_FS_CHMOD_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("chownSync"),
        js_native_create("chownSync", 3, NATIVE_KIND_FS_CHOWN_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("symlinkSync"),
        js_native_create("symlinkSync", 3, NATIVE_KIND_FS_SYMLINK_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("readlinkSync"),
        js_native_create("readlinkSync", 1, NATIVE_KIND_FS_READLINK_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("realpathSync"),
        js_native_create("realpathSync", 1, NATIVE_KIND_FS_REALPATH_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("mkdtempSync"),
        js_native_create("mkdtempSync", 1, NATIVE_KIND_FS_MKDTEMP_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("accessSync"),
        js_native_create("accessSync", 2, NATIVE_KIND_FS_ACCESS_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("lstatSync"),
        js_native_create("lstatSync", 1, NATIVE_KIND_FS_LSTAT_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("createWriteStream"),
        js_native_create("createWriteStream", 2, NATIVE_KIND_FS_CREATE_WRITE_STREAM)
    );
    js_object_set(
        fs_obj,
        str_intern("__jacWatchStart"),
        js_native_create("__jacWatchStart", 4, NATIVE_KIND_FS_WATCH_START)
    );
    js_object_set(
        fs_obj,
        str_intern("__jacWatchClose"),
        js_native_create("__jacWatchClose", 0, NATIVE_KIND_FS_WATCH_CLOSE)
    );
    js_object_set(
        fs_obj,
        str_intern("__jacWatchRef"),
        js_native_create("__jacWatchRef", 0, NATIVE_KIND_FS_WATCH_REF)
    );
    js_object_set(
        fs_obj,
        str_intern("__jacWatchUnref"),
        js_native_create("__jacWatchUnref", 0, NATIVE_KIND_FS_WATCH_UNREF)
    );
    js_object_set(
        fs_obj,
        str_intern("realpath"),
        js_native_create("realpath", 3, NATIVE_KIND_FS_REALPATH)
    );
    js_object_set(
        fs_obj, str_intern("stat"), js_native_create("stat", 3, NATIVE_KIND_FS_STAT)
    );
    js_object_set(
        fs_obj, str_intern("lstat"), js_native_create("lstat", 3, NATIVE_KIND_FS_LSTAT)
    );
    js_object_set(
        fs_obj,
        str_intern("readdir"),
        js_native_create("readdir", 3, NATIVE_KIND_FS_READDIR)
    );
    js_object_set(
        fs_obj, str_intern("mkdir"), js_native_create("mkdir", 3, NATIVE_KIND_FS_MKDIR)
    );
    js_object_set(
        fs_obj,
        str_intern("unlink"),
        js_native_create("unlink", 2, NATIVE_KIND_FS_UNLINK)
    );
    js_object_set(
        fs_obj,
        str_intern("rename"),
        js_native_create("rename", 3, NATIVE_KIND_FS_RENAME)
    );
    js_object_set(
        fs_obj,
        str_intern("access"),
        js_native_create("access", 3, NATIVE_KIND_FS_ACCESS)
    );
    js_object_set(
        fs_obj,
        str_intern("appendFile"),
        js_native_create("appendFile", 4, NATIVE_KIND_FS_APPEND_FILE)
    );
    js_object_set(
        fs_obj,
        str_intern("mkdtemp"),
        js_native_create("mkdtemp", 3, NATIVE_KIND_FS_MKDTEMP)
    );
    js_object_set(
        fs_obj,
        str_intern("copyFile"),
        js_native_create("copyFile", 4, NATIVE_KIND_FS_COPYFILE)
    );
    js_object_set(
        fs_obj, str_intern("chmod"), js_native_create("chmod", 3, NATIVE_KIND_FS_CHMOD)
    );
    js_object_set(
        fs_obj, str_intern("chown"), js_native_create("chown", 4, NATIVE_KIND_FS_CHOWN)
    );
    js_object_set(
        fs_obj,
        str_intern("symlink"),
        js_native_create("symlink", 4, NATIVE_KIND_FS_SYMLINK)
    );
    js_object_set(
        fs_obj,
        str_intern("readlink"),
        js_native_create("readlink", 3, NATIVE_KIND_FS_READLINK)
    );
    js_object_set(
        fs_obj, str_intern("rmdir"), js_native_create("rmdir", 3, NATIVE_KIND_FS_RMDIR)
    );
    js_object_set(
        fs_obj, str_intern("rm"), js_native_create("rm", 3, NATIVE_KIND_FS_RM)
    );
    js_object_set(
        fs_obj,
        str_intern("openSync"),
        js_native_create("openSync", 3, NATIVE_KIND_FS_OPEN_SYNC)
    );
    js_object_set(
        fs_obj, str_intern("open"), js_native_create("open", 4, NATIVE_KIND_FS_OPEN)
    );
    js_object_set(
        fs_obj,
        str_intern("closeSync"),
        js_native_create("closeSync", 1, NATIVE_KIND_FS_CLOSE_SYNC)
    );
    js_object_set(
        fs_obj, str_intern("close"), js_native_create("close", 2, NATIVE_KIND_FS_CLOSE)
    );
    js_object_set(
        fs_obj,
        str_intern("__readPtr"),
        js_native_create("__readPtr", 4, NATIVE_KIND_FS_READ_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("__writePtr"),
        js_native_create("__writePtr", 4, NATIVE_KIND_FS_WRITE_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("__readPtrAsync"),
        js_native_create("__readPtrAsync", 5, NATIVE_KIND_FS_READ)
    );
    js_object_set(
        fs_obj,
        str_intern("__writePtrAsync"),
        js_native_create("__writePtrAsync", 5, NATIVE_KIND_FS_WRITE)
    );
    js_object_set(
        fs_obj,
        str_intern("__readvPtr"),
        js_native_create("__readvPtr", -1, NATIVE_KIND_FS_READV_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("__writevPtr"),
        js_native_create("__writevPtr", -1, NATIVE_KIND_FS_WRITEV_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("__readvPtrAsync"),
        js_native_create("__readvPtrAsync", -1, NATIVE_KIND_FS_READV)
    );
    js_object_set(
        fs_obj,
        str_intern("__writevPtrAsync"),
        js_native_create("__writevPtrAsync", -1, NATIVE_KIND_FS_WRITEV)
    );
    js_object_set(
        fs_obj,
        str_intern("fstatSync"),
        js_native_create("fstatSync", 1, NATIVE_KIND_FS_FSTAT_SYNC)
    );
    js_object_set(
        fs_obj, str_intern("fstat"), js_native_create("fstat", 2, NATIVE_KIND_FS_FSTAT)
    );
    js_object_set(
        fs_obj,
        str_intern("ftruncateSync"),
        js_native_create("ftruncateSync", 2, NATIVE_KIND_FS_FTRUNCATE_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("ftruncate"),
        js_native_create("ftruncate", 3, NATIVE_KIND_FS_FTRUNCATE)
    );
    js_object_set(
        fs_obj,
        str_intern("truncateSync"),
        js_native_create("truncateSync", 2, NATIVE_KIND_FS_TRUNCATE_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("truncate"),
        js_native_create("truncate", 3, NATIVE_KIND_FS_TRUNCATE)
    );
    js_object_set(
        fs_obj,
        str_intern("utimesSync"),
        js_native_create("utimesSync", 3, NATIVE_KIND_FS_UTIME_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("utimes"),
        js_native_create("utimes", 4, NATIVE_KIND_FS_UTIME)
    );
    js_object_set(
        fs_obj,
        str_intern("futimesSync"),
        js_native_create("futimesSync", 3, NATIVE_KIND_FS_FUTIME_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("futimes"),
        js_native_create("futimes", 4, NATIVE_KIND_FS_FUTIME)
    );
    js_object_set(
        fs_obj,
        str_intern("lutimesSync"),
        js_native_create("lutimesSync", 3, NATIVE_KIND_FS_LUTIME_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("lutimes"),
        js_native_create("lutimes", 4, NATIVE_KIND_FS_LUTIME)
    );
    js_object_set(
        fs_obj,
        str_intern("linkSync"),
        js_native_create("linkSync", 2, NATIVE_KIND_FS_LINK_SYNC)
    );
    js_object_set(
        fs_obj, str_intern("link"), js_native_create("link", 3, NATIVE_KIND_FS_LINK)
    );
    js_object_set(
        fs_obj,
        str_intern("fsyncSync"),
        js_native_create("fsyncSync", 1, NATIVE_KIND_FS_FSYNC_SYNC)
    );
    js_object_set(
        fs_obj, str_intern("fsync"), js_native_create("fsync", 2, NATIVE_KIND_FS_FSYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("fdatasyncSync"),
        js_native_create("fdatasyncSync", 1, NATIVE_KIND_FS_FDATASYNC_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("fdatasync"),
        js_native_create("fdatasync", 2, NATIVE_KIND_FS_FDATASYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("fchmodSync"),
        js_native_create("fchmodSync", 2, NATIVE_KIND_FS_FCHMOD_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("fchmod"),
        js_native_create("fchmod", 3, NATIVE_KIND_FS_FCHMOD)
    );
    js_object_set(
        fs_obj,
        str_intern("fchownSync"),
        js_native_create("fchownSync", 3, NATIVE_KIND_FS_FCHOWN_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("fchown"),
        js_native_create("fchown", 4, NATIVE_KIND_FS_FCHOWN)
    );
    js_object_set(
        fs_obj,
        str_intern("lchownSync"),
        js_native_create("lchownSync", 3, NATIVE_KIND_FS_LCHOWN_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("lchown"),
        js_native_create("lchown", 4, NATIVE_KIND_FS_LCHOWN)
    );
    js_object_set(
        fs_obj,
        str_intern("statfsSync"),
        js_native_create("statfsSync", 1, NATIVE_KIND_FS_STATFS_SYNC)
    );
    js_object_set(
        fs_obj,
        str_intern("statfs"),
        js_native_create("statfs", 2, NATIVE_KIND_FS_STATFS)
    );
    js_object_set(gv, str_intern("fs"), fs_obj);

    # ── __net global object (Phase 6.4 — network socket bridge) ──────────────
    # Exposes TCP/TLS socket operations for JS-level fetch() / node:http.
    net_obj: JSValue = js_object_create_null();
    js_object_set(
        net_obj,
        str_intern("tcpConnect"),
        js_native_create("tcpConnect", 2, NATIVE_KIND_NET_TCP_CONNECT)
    );
    js_object_set(
        net_obj,
        str_intern("tcpRead"),
        js_native_create("tcpRead", 2, NATIVE_KIND_NET_TCP_READ)
    );
    js_object_set(
        net_obj,
        str_intern("tcpWrite"),
        js_native_create("tcpWrite", 2, NATIVE_KIND_NET_TCP_WRITE)
    );
    js_object_set(
        net_obj,
        str_intern("tcpClose"),
        js_native_create("tcpClose", 1, NATIVE_KIND_NET_TCP_CLOSE)
    );
    js_object_set(
        net_obj,
        str_intern("tlsConnect"),
        js_native_create("tlsConnect", 2, NATIVE_KIND_NET_TLS_CONNECT)
    );
    js_object_set(
        net_obj,
        str_intern("tlsRead"),
        js_native_create("tlsRead", 2, NATIVE_KIND_NET_TLS_READ)
    );
    js_object_set(
        net_obj,
        str_intern("tlsWrite"),
        js_native_create("tlsWrite", 2, NATIVE_KIND_NET_TLS_WRITE)
    );
    js_object_set(
        net_obj,
        str_intern("tlsClose"),
        js_native_create("tlsClose", 1, NATIVE_KIND_NET_TLS_CLOSE)
    );
    # Phase 6.5 — server operations
    js_object_set(
        net_obj,
        str_intern("tcpListen"),
        js_native_create("tcpListen", 3, NATIVE_KIND_NET_TCP_LISTEN)
    );
    js_object_set(
        net_obj,
        str_intern("unixListen"),
        js_native_create("unixListen", 2, NATIVE_KIND_NET_UNIX_LISTEN)
    );
    js_object_set(
        net_obj,
        str_intern("tcpAccept"),
        js_native_create("tcpAccept", 1, NATIVE_KIND_NET_TCP_ACCEPT)
    );
    js_object_set(
        net_obj,
        str_intern("tcpListenerClose"),
        js_native_create("tcpListenerClose", 1, NATIVE_KIND_NET_TCP_LISTENER_CLOSE)
    );
    js_object_set(
        net_obj,
        str_intern("tcpPeerAddr"),
        js_native_create("tcpPeerAddr", 1, NATIVE_KIND_NET_TCP_PEER_ADDR)
    );
    js_object_set(
        net_obj,
        str_intern("tcpListenerPort"),
        js_native_create("tcpListenerPort", 1, NATIVE_KIND_NET_TCP_LISTENER_PORT)
    );
    # Phase 6.6 — non-blocking I/O
    js_object_set(
        net_obj,
        str_intern("tcpConnectNb"),
        js_native_create("tcpConnectNb", 3, NATIVE_KIND_NET_TCP_CONNECT_NB)
    );
    js_object_set(
        net_obj,
        str_intern("tcpReadNb"),
        js_native_create("tcpReadNb", 3, NATIVE_KIND_NET_TCP_READ_NB)
    );
    # Phase 6.6 — non-blocking TLS I/O
    js_object_set(
        net_obj,
        str_intern("tlsConnectNb"),
        js_native_create("tlsConnectNb", 5, NATIVE_KIND_NET_TLS_CONNECT_NB)
    );
    js_object_set(
        net_obj,
        str_intern("tlsWrapClientNb"),
        js_native_create("tlsWrapClientNb", 4, NATIVE_KIND_NET_TLS_WRAP_CLIENT_NB)
    );
    js_object_set(
        net_obj,
        str_intern("tlsReadNb"),
        js_native_create("tlsReadNb", 3, NATIVE_KIND_NET_TLS_READ_NB)
    );

    js_object_set(
        net_obj,
        str_intern("tcpAcceptNb"),
        js_native_create("tcpAcceptNb", 2, NATIVE_KIND_NET_TCP_ACCEPT_NB)
    );
    js_object_set(
        net_obj,
        str_intern("tcpSetNodelay"),
        js_native_create("tcpSetNodelay", 2, NATIVE_KIND_NET_TCP_SET_NODELAY)
    );
    js_object_set(
        net_obj,
        str_intern("tcpSetKeepalive"),
        js_native_create("tcpSetKeepalive", 3, NATIVE_KIND_NET_TCP_SET_KEEPALIVE)
    );
    js_object_set(
        net_obj,
        str_intern("tcpLocalAddr"),
        js_native_create("tcpLocalAddr", 1, NATIVE_KIND_NET_TCP_LOCAL_ADDR)
    );
    js_object_set(
        net_obj,
        str_intern("tcpWriteNb"),
        js_native_create("tcpWriteNb", 3, NATIVE_KIND_NET_TCP_WRITE_NB)
    );
    # Phase 6.12 — HTTP response reader with binary-safe decompression
    js_object_set(
        net_obj,
        str_intern("readHTTPResponse"),
        js_native_create("readHTTPResponse", 3, NATIVE_KIND_NET_READ_HTTP_RESPONSE)
    );
    # Phase C — HTTP request reader (server-side, llhttp-based)
    js_object_set(
        net_obj,
        str_intern("readHTTPRequest"),
        js_native_create("readHTTPRequest", 2, NATIVE_KIND_NET_READ_HTTP_REQUEST)
    );
    # Phase E — HTTP/2 native bridge (nghttp2)
    js_object_set(
        net_obj,
        str_intern("h2SessionCreateClient"),
        js_native_create(
            "h2SessionCreateClient", 1, NATIVE_KIND_H2_SESSION_CREATE_CLIENT
        )
    );
    js_object_set(
        net_obj,
        str_intern("h2SessionCreateServer"),
        js_native_create(
            "h2SessionCreateServer", 1, NATIVE_KIND_H2_SESSION_CREATE_SERVER
        )
    );
    js_object_set(
        net_obj,
        str_intern("h2SessionDel"),
        js_native_create("h2SessionDel", 1, NATIVE_KIND_H2_SESSION_DEL)
    );
    js_object_set(
        net_obj,
        str_intern("h2SessionRecv"),
        js_native_create("h2SessionRecv", 3, NATIVE_KIND_H2_SESSION_RECV)
    );
    js_object_set(
        net_obj,
        str_intern("h2SessionSend"),
        js_native_create("h2SessionSend", 1, NATIVE_KIND_H2_SESSION_SEND)
    );
    js_object_set(
        net_obj,
        str_intern("h2SubmitRequest"),
        js_native_create("h2SubmitRequest", 3, NATIVE_KIND_H2_SUBMIT_REQUEST)
    );
    js_object_set(
        net_obj,
        str_intern("h2SubmitResponse"),
        js_native_create("h2SubmitResponse", 4, NATIVE_KIND_H2_SUBMIT_RESPONSE)
    );
    js_object_set(
        net_obj,
        str_intern("h2SubmitSettings"),
        js_native_create("h2SubmitSettings", 3, NATIVE_KIND_H2_SUBMIT_SETTINGS)
    );
    js_object_set(
        net_obj,
        str_intern("h2SubmitGoaway"),
        js_native_create("h2SubmitGoaway", 3, NATIVE_KIND_H2_SUBMIT_GOAWAY)
    );
    js_object_set(
        net_obj,
        str_intern("h2SubmitRstStream"),
        js_native_create("h2SubmitRstStream", 3, NATIVE_KIND_H2_SUBMIT_RST_STREAM)
    );
    js_object_set(
        net_obj,
        str_intern("h2SubmitData"),
        js_native_create("h2SubmitData", 4, NATIVE_KIND_H2_SUBMIT_DATA)
    );
    js_object_set(
        net_obj,
        str_intern("h2SubmitTrailer"),
        js_native_create("h2SubmitTrailer", 3, NATIVE_KIND_H2_SUBMIT_TRAILER)
    );
    js_object_set(
        net_obj,
        str_intern("h2SetLocalWindowSize"),
        js_native_create(
            "h2SetLocalWindowSize", 2, NATIVE_KIND_H2_SET_LOCAL_WINDOW_SIZE
        )
    );
    js_object_set(
        net_obj,
        str_intern("h2GetRemoteSetting"),
        js_native_create("h2GetRemoteSetting", 2, NATIVE_KIND_H2_GET_REMOTE_SETTING)
    );
    js_object_set(
        net_obj,
        str_intern("h2SessionWantRead"),
        js_native_create("h2SessionWantRead", 1, NATIVE_KIND_H2_SESSION_WANT_READ)
    );
    js_object_set(
        net_obj,
        str_intern("h2SessionWantWrite"),
        js_native_create("h2SessionWantWrite", 1, NATIVE_KIND_H2_SESSION_WANT_WRITE)
    );
    js_object_set(
        net_obj,
        str_intern("h2Consume"),
        js_native_create("h2Consume", 3, NATIVE_KIND_H2_CONSUME)
    );
    js_object_set(
        net_obj,
        str_intern("h2SubmitWindowUpdate"),
        js_native_create("h2SubmitWindowUpdate", 3, NATIVE_KIND_H2_SUBMIT_WINDOW_UPDATE)
    );
    js_object_set(
        net_obj,
        str_intern("h2PopEvent"),
        js_native_create("h2PopEvent", 1, NATIVE_KIND_H2_POP_EVENT)
    );
    js_object_set(
        net_obj,
        str_intern("h2GetSendPtr"),
        js_native_create("h2GetSendPtr", 1, NATIVE_KIND_H2_GET_SEND_PTR)
    );
    js_object_set(
        net_obj,
        str_intern("h2Request"),
        js_native_create("h2Request", 3, NATIVE_KIND_H2_REQUEST)
    );
    js_object_set(
        net_obj,
        str_intern("h2Respond"),
        js_native_create("h2Respond", 4, NATIVE_KIND_H2_RESPOND)
    );
    # Phase 6.12 — binary-safe async reads + raw write
    js_object_set(
        net_obj,
        str_intern("tcpReadBinaryNb"),
        js_native_create("tcpReadBinaryNb", 3, NATIVE_KIND_NET_TCP_READ_BINARY_NB)
    );
    js_object_set(
        net_obj,
        str_intern("tlsReadBinaryNb"),
        js_native_create("tlsReadBinaryNb", 3, NATIVE_KIND_NET_TLS_READ_BINARY_NB)
    );
    js_object_set(
        net_obj,
        str_intern("tcpWriteRaw"),
        js_native_create("tcpWriteRaw", 3, NATIVE_KIND_NET_TCP_WRITE_RAW)
    );
    # Phase 6.14 — TLS server operations
    js_object_set(
        net_obj,
        str_intern("tlsCreateServerCtx"),
        js_native_create("tlsCreateServerCtx", 3, NATIVE_KIND_NET_TLS_CREATE_SERVER_CTX)
    );
    js_object_set(
        net_obj,
        str_intern("tlsFreeServerCtx"),
        js_native_create("tlsFreeServerCtx", 1, NATIVE_KIND_NET_TLS_FREE_SERVER_CTX)
    );
    js_object_set(
        net_obj,
        str_intern("tlsAccept"),
        js_native_create("tlsAccept", 2, NATIVE_KIND_NET_TLS_ACCEPT)
    );
    js_object_set(
        net_obj,
        str_intern("tlsAcceptNb"),
        js_native_create("tlsAcceptNb", 3, NATIVE_KIND_NET_TLS_ACCEPT_NB)
    );
    js_object_set(
        net_obj,
        str_intern("tlsGetAlpn"),
        js_native_create("tlsGetAlpn", 1, NATIVE_KIND_NET_TLS_GET_ALPN)
    );
    js_object_set(
        net_obj,
        str_intern("tlsWriteNb"),
        js_native_create("tlsWriteNb", 3, NATIVE_KIND_NET_TLS_WRITE_NB)
    );
    # Wave 7 — UDP / dgram
    js_object_set(
        net_obj,
        str_intern("udpCreate"),
        js_native_create("udpCreate", 1, NATIVE_KIND_NET_UDP_CREATE)
    );
    js_object_set(
        net_obj,
        str_intern("udpBind"),
        js_native_create("udpBind", 4, NATIVE_KIND_NET_UDP_BIND)
    );
    js_object_set(
        net_obj,
        str_intern("udpSendNb"),
        js_native_create("udpSendNb", 5, NATIVE_KIND_NET_UDP_SEND_NB)
    );
    js_object_set(
        net_obj,
        str_intern("udpRecvNb"),
        js_native_create("udpRecvNb", 2, NATIVE_KIND_NET_UDP_RECV_NB)
    );
    js_object_set(
        net_obj,
        str_intern("udpClose"),
        js_native_create("udpClose", 1, NATIVE_KIND_NET_UDP_CLOSE)
    );
    js_object_set(
        net_obj,
        str_intern("udpAddress"),
        js_native_create("udpAddress", 1, NATIVE_KIND_NET_UDP_ADDRESS)
    );
    js_object_set(
        net_obj,
        str_intern("udpSetBroadcast"),
        js_native_create("udpSetBroadcast", 2, NATIVE_KIND_NET_UDP_SET_BROADCAST)
    );
    js_object_set(
        net_obj,
        str_intern("udpSetRecvBuf"),
        js_native_create("udpSetRecvBuf", 2, NATIVE_KIND_NET_UDP_SET_RECV_BUF)
    );
    js_object_set(
        net_obj,
        str_intern("udpGetRecvBuf"),
        js_native_create("udpGetRecvBuf", 1, NATIVE_KIND_NET_UDP_GET_RECV_BUF)
    );
    js_object_set(
        net_obj,
        str_intern("udpSetSendBuf"),
        js_native_create("udpSetSendBuf", 2, NATIVE_KIND_NET_UDP_SET_SEND_BUF)
    );
    js_object_set(
        net_obj,
        str_intern("udpGetSendBuf"),
        js_native_create("udpGetSendBuf", 1, NATIVE_KIND_NET_UDP_GET_SEND_BUF)
    );
    js_object_set(
        net_obj,
        str_intern("udpSetTTL"),
        js_native_create("udpSetTTL", 2, NATIVE_KIND_NET_UDP_SET_TTL)
    );
    js_object_set(gv, str_intern("__net"), net_obj);

    # ── __ws global object (Phase 6.9 — binary-safe WebSocket bridge) ───────
    ws_obj: JSValue = js_object_create_null();
    js_object_set(
        ws_obj,
        str_intern("acceptKey"),
        js_native_create("acceptKey", 1, NATIVE_KIND_WS_ACCEPT_KEY)
    );
    js_object_set(
        ws_obj,
        str_intern("randomKey"),
        js_native_create("randomKey", 0, NATIVE_KIND_WS_RANDOM_KEY)
    );
    js_object_set(
        ws_obj,
        str_intern("sendFrame"),
        js_native_create("sendFrame", 5, NATIVE_KIND_WS_SEND_FRAME)
    );
    js_object_set(
        ws_obj,
        str_intern("createRecvBuf"),
        js_native_create("createRecvBuf", 0, NATIVE_KIND_WS_RECV_BUF_CREATE)
    );
    js_object_set(
        ws_obj,
        str_intern("recvBufRead"),
        js_native_create("recvBufRead", 3, NATIVE_KIND_WS_RECV_BUF_READ)
    );
    js_object_set(
        ws_obj,
        str_intern("recvBufDecode"),
        js_native_create("recvBufDecode", 1, NATIVE_KIND_WS_RECV_BUF_DECODE)
    );
    js_object_set(
        ws_obj,
        str_intern("recvBufExtract"),
        js_native_create("recvBufExtract", 4, NATIVE_KIND_WS_RECV_BUF_EXTRACT)
    );
    js_object_set(
        ws_obj,
        str_intern("recvBufConsume"),
        js_native_create("recvBufConsume", 2, NATIVE_KIND_WS_RECV_BUF_CONSUME)
    );
    js_object_set(
        ws_obj,
        str_intern("recvBufParseClose"),
        js_native_create("recvBufParseClose", 4, NATIVE_KIND_WS_RECV_BUF_PARSE_CLOSE)
    );
    js_object_set(
        ws_obj,
        str_intern("makeClosePayload"),
        js_native_create("makeClosePayload", 2, NATIVE_KIND_WS_MAKE_CLOSE_PAYLOAD)
    );
    js_object_set(gv, str_intern("__ws"), ws_obj);

    # ── __buf global object (Phase 6.13 — ArrayBuffer binary bridge) ────────
    buf_obj: JSValue = js_object_create_null();
    js_object_set(
        buf_obj,
        str_intern("alloc"),
        js_native_create("alloc", 1, NATIVE_KIND_BUF_ALLOC)
    );
    js_object_set(
        buf_obj, str_intern("free"), js_native_create("free", 1, NATIVE_KIND_BUF_FREE)
    );
    js_object_set(
        buf_obj,
        str_intern("getByte"),
        js_native_create("getByte", 2, NATIVE_KIND_BUF_GET_BYTE)
    );
    js_object_set(
        buf_obj,
        str_intern("setByte"),
        js_native_create("setByte", 3, NATIVE_KIND_BUF_SET_BYTE)
    );
    js_object_set(
        buf_obj, str_intern("copy"), js_native_create("copy", 5, NATIVE_KIND_BUF_COPY)
    );
    js_object_set(
        buf_obj, str_intern("fill"), js_native_create("fill", 4, NATIVE_KIND_BUF_FILL)
    );
    js_object_set(
        buf_obj,
        str_intern("registerBuffer"),
        js_native_create("registerBuffer", 6, NATIVE_KIND_BUF_REGISTER_BUFFER)
    );
    js_object_set(
        buf_obj,
        str_intern("registerTypedArray"),
        js_native_create("registerTypedArray", 7, NATIVE_KIND_BUF_REGISTER_TYPED_ARRAY)
    );
    js_object_set(
        buf_obj,
        str_intern("registerDataView"),
        js_native_create("registerDataView", 5, NATIVE_KIND_BUF_REGISTER_DATA_VIEW)
    );
    js_object_set(
        buf_obj,
        str_intern("binaryKind"),
        js_native_create("binaryKind", 1, NATIVE_KIND_BUF_BINARY_KIND)
    );
    js_object_set(
        buf_obj,
        str_intern("dvGetInt"),
        js_native_create("dvGetInt", 5, NATIVE_KIND_BUF_DV_GET_INT)
    );
    js_object_set(
        buf_obj,
        str_intern("dvSetInt"),
        js_native_create("dvSetInt", 5, NATIVE_KIND_BUF_DV_SET_INT)
    );
    js_object_set(
        buf_obj,
        str_intern("decodeUtf8"),
        js_native_create("decodeUtf8", 3, NATIVE_KIND_BUF_DECODE_UTF8)
    );
    js_object_set(
        buf_obj,
        str_intern("decodeLatin1"),
        js_native_create("decodeLatin1", 3, NATIVE_KIND_BUF_DECODE_LATIN1)
    );
    js_object_set(
        buf_obj,
        str_intern("toString"),
        js_native_create("toString", 4, NATIVE_KIND_BUF_TO_STRING)
    );
    js_object_set(
        buf_obj,
        str_intern("tdDecode"),
        js_native_create("tdDecode", 2, NATIVE_KIND_TD_DECODE)
    );
    # %TypedArray%.prototype getters / @@species as natives (binary_types.js
    # installs them; vm.jac GET_PROP recognises them by kind), plus native view
    # construction for subarray (buffer_native.jac).
    js_object_set(
        buf_obj,
        str_intern("getLength"),
        js_native_create("get length", 0, NATIVE_KIND_TA_GET_LENGTH)
    );
    js_object_set(
        buf_obj,
        str_intern("getByteLength"),
        js_native_create("get byteLength", 0, NATIVE_KIND_TA_GET_BYTELENGTH)
    );
    js_object_set(
        buf_obj,
        str_intern("getByteOffset"),
        js_native_create("get byteOffset", 0, NATIVE_KIND_TA_GET_BYTEOFFSET)
    );
    js_object_set(
        buf_obj,
        str_intern("getBuffer"),
        js_native_create("get buffer", 0, NATIVE_KIND_TA_GET_BUFFER)
    );
    js_object_set(
        buf_obj,
        str_intern("speciesGetter"),
        js_native_create("get [Symbol.species]", 0, NATIVE_KIND_TA_SPECIES_GET)
    );
    js_object_set(
        buf_obj,
        str_intern("taSubarray"),
        js_native_create("taSubarray", 4, NATIVE_KIND_TA_SUBARRAY)
    );
    js_object_set(
        buf_obj,
        str_intern("makeView"),
        js_native_create("makeView", 5, NATIVE_KIND_BUF_MAKE_VIEW)
    );
    # Constructor bodies + bulk byte ops (buffer_native.jac): ArrayBuffer /
    # TypedArray field init + registration, wire-UTF-8 encode, copy, equals.
    js_object_set(
        buf_obj,
        str_intern("initArrayBuffer"),
        js_native_create("initArrayBuffer", 2, NATIVE_KIND_BUF_INIT_ARRAY_BUFFER)
    );
    js_object_set(
        buf_obj,
        str_intern("initTypedArray"),
        js_native_create("initTypedArray", 11, NATIVE_KIND_BUF_INIT_TYPED_ARRAY)
    );
    js_object_set(
        buf_obj,
        str_intern("utf8ByteLength"),
        js_native_create("utf8ByteLength", 1, NATIVE_KIND_BUF_UTF8_BYTE_LENGTH)
    );
    js_object_set(
        buf_obj,
        str_intern("writeString"),
        js_native_create("writeString", 5, NATIVE_KIND_BUF_WRITE_STRING)
    );
    js_object_set(
        buf_obj,
        str_intern("copyBytes"),
        js_native_create("copyBytes", 5, NATIVE_KIND_BUF_COPY_BYTES)
    );
    js_object_set(
        buf_obj,
        str_intern("equalsBytes"),
        js_native_create("equalsBytes", 2, NATIVE_KIND_BUF_EQUALS_BYTES)
    );
    # Fully native prototype methods (installed by the JS builtins over their
    # own implementations, which they register as slow paths).
    js_object_set(
        buf_obj,
        str_intern("tdDecodeMethod"),
        js_native_create("decode", 1, NATIVE_KIND_TD_DECODE_METHOD)
    );
    js_object_set(
        buf_obj,
        str_intern("setTdDecodeSlow"),
        js_native_create("setTdDecodeSlow", 1, NATIVE_KIND_SET_TD_DECODE_SLOW)
    );
    js_object_set(
        buf_obj,
        str_intern("bufToStringMethod"),
        js_native_create("toString", 3, NATIVE_KIND_BUF_TOSTRING_METHOD)
    );
    js_object_set(
        buf_obj,
        str_intern("bufSubarrayMethod"),
        js_native_create("subarray", 2, NATIVE_KIND_BUF_SUBARRAY_METHOD)
    );
    js_object_set(
        buf_obj,
        str_intern("setBufSlow"),
        js_native_create("setBufSlow", 3, NATIVE_KIND_SET_BUF_SLOW)
    );
    js_object_set(
        buf_obj,
        str_intern("taSubarrayMethod"),
        js_native_create("subarray", 2, NATIVE_KIND_TA_SUBARRAY_METHOD)
    );
    js_object_set(
        buf_obj,
        str_intern("setTaSubarraySlow"),
        js_native_create("setTaSubarraySlow", 1, NATIVE_KIND_SET_TA_SUBARRAY_SLOW)
    );
    js_object_set(
        buf_obj, str_intern("taSet"), js_native_create("taSet", 3, NATIVE_KIND_TA_SET)
    );
    js_object_set(
        buf_obj,
        str_intern("taSlice"),
        js_native_create("taSlice", 3, NATIVE_KIND_TA_SLICE)
    );
    js_object_set(
        buf_obj,
        str_intern("intArrayProbe"),
        js_native_create("intArrayProbe", 1, NATIVE_KIND_ARRAY_INT_PROBE)
    );
    js_object_set(
        buf_obj,
        str_intern("taFillFromProbe"),
        js_native_create("taFillFromProbe", 1, NATIVE_KIND_TA_FILL_FROM_PROBE)
    );
    js_object_set(
        buf_obj,
        str_intern("stringByteLength"),
        js_native_create("stringByteLength", 2, NATIVE_KIND_BUF_STRING_BYTE_LENGTH)
    );
    js_object_set(
        buf_obj,
        str_intern("setArrayBufferProto"),
        js_native_create("setArrayBufferProto", 1, NATIVE_KIND_SET_AB_PROTO)
    );
    js_object_set(gv, str_intern("__buf"), buf_obj);

    # ── __jacMarkNonConstructor — mark JS closures as non-constructible ─────
    js_object_set(
        gv,
        str_intern("__jacMarkNonConstructor"),
        js_native_create("__jacMarkNonConstructor", 1, NATIVE_KIND_MARK_NON_CONSTRUCTOR)
    );

    # SetData size for ES2024 Set algebra (bypasses receiver .size accessor overrides).
    js_object_set(
        gv,
        str_intern("__jacSetDataSize"),
        js_native_create("__jacSetDataSize", 0, NATIVE_KIND_SET_SIZE_GET)
    );

    # ── __zlib global object (Phase 6.12 — streaming decompression) ─────────
    zlib_obj: JSValue = js_object_create_null();
    js_object_set(
        zlib_obj,
        str_intern("open"),
        js_native_create("open", 1, NATIVE_KIND_ZLIB_STREAM_OPEN)
    );
    js_object_set(
        zlib_obj,
        str_intern("feed"),
        js_native_create("feed", 3, NATIVE_KIND_ZLIB_STREAM_FEED)
    );
    js_object_set(
        zlib_obj,
        str_intern("close"),
        js_native_create("close", 1, NATIVE_KIND_ZLIB_STREAM_CLOSE)
    );
    js_object_set(
        zlib_obj,
        str_intern("inflate"),
        js_native_create("inflate", 3, NATIVE_KIND_ZLIB_INFLATE_ONESHOT)
    );
    js_object_set(
        zlib_obj,
        str_intern("dopen"),
        js_native_create("dopen", 2, NATIVE_KIND_ZLIB_DEFLATE_STREAM_OPEN)
    );
    js_object_set(
        zlib_obj,
        str_intern("dfeed"),
        js_native_create("dfeed", 4, NATIVE_KIND_ZLIB_DEFLATE_STREAM_FEED)
    );
    js_object_set(
        zlib_obj,
        str_intern("dclose"),
        js_native_create("dclose", 1, NATIVE_KIND_ZLIB_DEFLATE_STREAM_CLOSE)
    );
    js_object_set(
        zlib_obj,
        str_intern("compress"),
        js_native_create("compress", 3, NATIVE_KIND_ZLIB_COMPRESS_RAW)
    );
    js_object_set(
        zlib_obj,
        str_intern("cptr"),
        js_native_create("cptr", 0, NATIVE_KIND_ZLIB_DEFLATE_PTR)
    );
    js_object_set(
        zlib_obj,
        str_intern("clen"),
        js_native_create("clen", 0, NATIVE_KIND_ZLIB_DEFLATE_LEN)
    );
    js_object_set(
        zlib_obj,
        str_intern("crc32"),
        js_native_create("crc32", 3, NATIVE_KIND_ZLIB_CRC32)
    );
    js_object_set(
        zlib_obj,
        str_intern("bcompress"),
        js_native_create("bcompress", 3, NATIVE_KIND_BROTLI_COMPRESS)
    );
    js_object_set(
        zlib_obj,
        str_intern("bdecompress"),
        js_native_create("bdecompress", 3, NATIVE_KIND_BROTLI_DECOMPRESS)
    );
    js_object_set(
        zlib_obj,
        str_intern("bopen"),
        js_native_create("bopen", 1, NATIVE_KIND_BROTLI_ENC_OPEN)
    );
    js_object_set(
        zlib_obj,
        str_intern("bfeed"),
        js_native_create("bfeed", 4, NATIVE_KIND_BROTLI_ENC_FEED)
    );
    js_object_set(
        zlib_obj,
        str_intern("bclose"),
        js_native_create("bclose", 1, NATIVE_KIND_BROTLI_ENC_CLOSE)
    );
    js_object_set(
        zlib_obj,
        str_intern("bdopen"),
        js_native_create("bdopen", 0, NATIVE_KIND_BROTLI_DEC_OPEN)
    );
    js_object_set(
        zlib_obj,
        str_intern("bdfeed"),
        js_native_create("bdfeed", 3, NATIVE_KIND_BROTLI_DEC_FEED)
    );
    js_object_set(
        zlib_obj,
        str_intern("bdclose"),
        js_native_create("bdclose", 1, NATIVE_KIND_BROTLI_DEC_CLOSE)
    );
    js_object_set(
        zlib_obj,
        str_intern("zcompress"),
        js_native_create("zcompress", 3, NATIVE_KIND_ZSTD_COMPRESS)
    );
    js_object_set(
        zlib_obj,
        str_intern("zdecompress"),
        js_native_create("zdecompress", 3, NATIVE_KIND_ZSTD_DECOMPRESS)
    );
    js_object_set(
        zlib_obj,
        str_intern("zopen"),
        js_native_create("zopen", 1, NATIVE_KIND_ZSTD_ENC_OPEN)
    );
    js_object_set(
        zlib_obj,
        str_intern("zfeed"),
        js_native_create("zfeed", 4, NATIVE_KIND_ZSTD_ENC_FEED)
    );
    js_object_set(
        zlib_obj,
        str_intern("zclose"),
        js_native_create("zclose", 1, NATIVE_KIND_ZSTD_ENC_CLOSE)
    );
    js_object_set(
        zlib_obj,
        str_intern("zdopen"),
        js_native_create("zdopen", 0, NATIVE_KIND_ZSTD_DEC_OPEN)
    );
    js_object_set(
        zlib_obj,
        str_intern("zdfeed"),
        js_native_create("zdfeed", 3, NATIVE_KIND_ZSTD_DEC_FEED)
    );
    js_object_set(
        zlib_obj,
        str_intern("zdclose"),
        js_native_create("zdclose", 1, NATIVE_KIND_ZSTD_DEC_CLOSE)
    );
    js_object_set(gv, str_intern("__zlib"), zlib_obj);

    # ── __asyncHooks (Wave 20 — native PromiseHook bridge) ───────────────────
    ah_obj: JSValue = js_object_create_null();
    js_object_set(
        ah_obj,
        str_intern("enable"),
        js_native_create("enable", 1, NATIVE_KIND_AH_ENABLE)
    );
    js_object_set(
        ah_obj,
        str_intern("enabled"),
        js_native_create("enabled", 0, NATIVE_KIND_AH_ENABLED)
    );
    js_object_set(
        ah_obj,
        str_intern("setExecutionAsyncId"),
        js_native_create("setExecutionAsyncId", 1, NATIVE_KIND_AH_SET_EXEC_ID)
    );
    js_object_set(
        ah_obj,
        str_intern("getExecutionAsyncId"),
        js_native_create("getExecutionAsyncId", 0, NATIVE_KIND_AH_GET_EXEC_ID)
    );
    js_object_set(
        ah_obj,
        str_intern("promiseAsyncId"),
        js_native_create("promiseAsyncId", 1, NATIVE_KIND_AH_PROMISE_ASYNC_ID)
    );
    js_object_set(
        ah_obj,
        str_intern("drainInit"),
        js_native_create("drainInit", 0, NATIVE_KIND_AH_DRAIN_INIT)
    );
    js_object_set(
        ah_obj,
        str_intern("drainResolve"),
        js_native_create("drainResolve", 0, NATIVE_KIND_AH_DRAIN_RESOLVE)
    );
    js_object_set(
        ah_obj,
        str_intern("peekNextAsyncId"),
        js_native_create("peekNextAsyncId", 0, NATIVE_KIND_AH_PEEK_NEXT_ID)
    );
    js_object_set(gv, str_intern("__asyncHooks"), ah_obj);

    # ── __crypto (node:crypto / WebCrypto OpenSSL bridge) ─────────────────────
    crypto_obj: JSValue = js_object_create_null();
    js_object_set(
        crypto_obj,
        str_intern("hashNew"),
        js_native_create("hashNew", 1, NATIVE_KIND_CRYPTO_HASH_NEW)
    );
    js_object_set(
        crypto_obj,
        str_intern("hashUpdate"),
        js_native_create("hashUpdate", 3, NATIVE_KIND_CRYPTO_HASH_UPDATE)
    );
    js_object_set(
        crypto_obj,
        str_intern("hashFinal"),
        js_native_create("hashFinal", 1, NATIVE_KIND_CRYPTO_HASH_FINAL)
    );
    js_object_set(
        crypto_obj,
        str_intern("hashFree"),
        js_native_create("hashFree", 1, NATIVE_KIND_CRYPTO_HASH_FREE)
    );
    js_object_set(
        crypto_obj,
        str_intern("hashOneshot"),
        js_native_create("hashOneshot", 3, NATIVE_KIND_CRYPTO_HASH_ONESHOT)
    );
    js_object_set(
        crypto_obj,
        str_intern("hmac"),
        js_native_create("hmac", 5, NATIVE_KIND_CRYPTO_HMAC)
    );
    js_object_set(
        crypto_obj,
        str_intern("randomHex"),
        js_native_create("randomHex", 1, NATIVE_KIND_CRYPTO_RANDOM_HEX)
    );
    js_object_set(
        crypto_obj,
        str_intern("timingSafeEqual"),
        js_native_create("timingSafeEqual", 4, NATIVE_KIND_CRYPTO_TIMING_SAFE_EQUAL)
    );
    js_object_set(
        crypto_obj,
        str_intern("pbkdf2"),
        js_native_create("pbkdf2", 7, NATIVE_KIND_CRYPTO_PBKDF2)
    );
    js_object_set(
        crypto_obj,
        str_intern("cipherEncrypt"),
        js_native_create("cipherEncrypt", 7, NATIVE_KIND_CRYPTO_CIPHER_ENCRYPT)
    );
    js_object_set(
        crypto_obj,
        str_intern("cipherDecrypt"),
        js_native_create("cipherDecrypt", 6, NATIVE_KIND_CRYPTO_CIPHER_DECRYPT)
    );
    js_object_set(
        crypto_obj,
        str_intern("getHashes"),
        js_native_create("getHashes", 0, NATIVE_KIND_CRYPTO_GET_HASHES)
    );
    js_object_set(
        crypto_obj,
        str_intern("getCiphers"),
        js_native_create("getCiphers", 0, NATIVE_KIND_CRYPTO_GET_CIPHERS)
    );
    js_object_set(
        crypto_obj,
        str_intern("getLastError"),
        js_native_create("getLastError", 0, NATIVE_KIND_CRYPTO_GET_LAST_ERROR)
    );
    js_object_set(
        crypto_obj,
        str_intern("keygen"),
        js_native_create("keygen", 4, NATIVE_KIND_CRYPTO_KEYGEN)
    );
    js_object_set(
        crypto_obj,
        str_intern("keyImport"),
        js_native_create("keyImport", 6, NATIVE_KIND_CRYPTO_KEY_IMPORT)
    );
    js_object_set(
        crypto_obj,
        str_intern("keyExport"),
        js_native_create("keyExport", 5, NATIVE_KIND_CRYPTO_KEY_EXPORT)
    );
    js_object_set(
        crypto_obj,
        str_intern("keyInfo"),
        js_native_create("keyInfo", 1, NATIVE_KIND_CRYPTO_KEY_INFO)
    );
    js_object_set(
        crypto_obj,
        str_intern("keyEquals"),
        js_native_create("keyEquals", 2, NATIVE_KIND_CRYPTO_KEY_EQUALS)
    );
    js_object_set(
        crypto_obj,
        str_intern("keyFree"),
        js_native_create("keyFree", 1, NATIVE_KIND_CRYPTO_KEY_FREE)
    );
    js_object_set(
        crypto_obj,
        str_intern("keyPublicOf"),
        js_native_create("keyPublicOf", 1, NATIVE_KIND_CRYPTO_KEY_PUBLIC_OF)
    );
    js_object_set(gv, str_intern("__crypto"), crypto_obj);

    # ── __cp (node:child_process Linux fork/exec bridge) ──────────────────────
    cp_obj: JSValue = js_object_create_null();
    js_object_set(
        cp_obj,
        str_intern("spawnSync"),
        js_native_create("spawnSync", 6, NATIVE_KIND_CP_SPAWN_SYNC)
    );
    js_object_set(
        cp_obj,
        str_intern("spawnAsync"),
        js_native_create("spawnAsync", 4, NATIVE_KIND_CP_SPAWN_ASYNC)
    );
    js_object_set(
        cp_obj,
        str_intern("spawnKill"),
        js_native_create("spawnKill", 1, NATIVE_KIND_CP_SPAWN_KILL)
    );
    js_object_set(
        cp_obj,
        str_intern("spawnWriteStdin"),
        js_native_create("spawnWriteStdin", 2, NATIVE_KIND_CP_SPAWN_WRITE)
    );
    js_object_set(
        cp_obj,
        str_intern("spawnWriteStdinB64"),
        js_native_create("spawnWriteStdinB64", 2, NATIVE_KIND_CP_SPAWN_WRITE_B64)
    );
    js_object_set(
        cp_obj, str_intern("unref"), js_native_create("unref", 1, NATIVE_KIND_CP_UNREF)
    );
    js_object_set(
        cp_obj, str_intern("ref"), js_native_create("ref", 1, NATIVE_KIND_CP_REF)
    );
    js_object_set(
        cp_obj,
        str_intern("spawnStdinEnd"),
        js_native_create("spawnStdinEnd", 1, NATIVE_KIND_CP_SPAWN_STDIN_END)
    );
    js_object_set(
        cp_obj,
        str_intern("getPid"),
        js_native_create("getPid", 1, NATIVE_KIND_CP_GET_PID)
    );
    js_object_set(
        cp_obj,
        str_intern("pollEvents"),
        js_native_create("pollEvents", 0, NATIVE_KIND_CP_POLL_EVENTS)
    );
    js_object_set(
        cp_obj,
        str_intern("registerDrain"),
        js_native_create("registerDrain", 1, NATIVE_KIND_CP_REGISTER_DRAIN)
    );
    js_object_set(gv, str_intern("__cp"), cp_obj);

    # ── __wasm (WebAssembly / Wasmtime bridge — docs/wasm.md Phase 2) ─────────
    # Backs engine/src/builtins/js/webassembly.js. Module/instance/func/memory
    # are opaque small-int handles; wasm bytes cross via (ptr,len) from __buf.
    # Imports/tables/globals + trap→RuntimeError are Phase 3.
    wasm_obj: JSValue = js_object_create_null();
    js_object_set(
        wasm_obj,
        str_intern("validate"),
        js_native_create("validate", 2, NATIVE_KIND_WASM_VALIDATE)
    );
    js_object_set(
        wasm_obj,
        str_intern("compile"),
        js_native_create("compile", 2, NATIVE_KIND_WASM_COMPILE)
    );
    js_object_set(
        wasm_obj,
        str_intern("instantiate"),
        js_native_create("instantiate", 1, NATIVE_KIND_WASM_INSTANTIATE)
    );
    js_object_set(
        wasm_obj,
        str_intern("exportCount"),
        js_native_create("exportCount", 1, NATIVE_KIND_WASM_EXPORT_COUNT)
    );
    js_object_set(
        wasm_obj,
        str_intern("exportName"),
        js_native_create("exportName", 2, NATIVE_KIND_WASM_EXPORT_NAME)
    );
    js_object_set(
        wasm_obj,
        str_intern("exportKind"),
        js_native_create("exportKind", 2, NATIVE_KIND_WASM_EXPORT_KIND)
    );
    js_object_set(
        wasm_obj,
        str_intern("bindFunc"),
        js_native_create("bindFunc", 2, NATIVE_KIND_WASM_BIND_FUNC)
    );
    js_object_set(
        wasm_obj,
        str_intern("invoke"),
        js_native_create("invoke", 1, NATIVE_KIND_WASM_FUNC_INVOKE)
    );
    js_object_set(
        wasm_obj,
        str_intern("exportMemory"),
        js_native_create("exportMemory", 2, NATIVE_KIND_WASM_EXPORT_MEMORY)
    );
    js_object_set(
        wasm_obj,
        str_intern("memCreate"),
        js_native_create("memCreate", 2, NATIVE_KIND_WASM_MEM_CREATE)
    );
    js_object_set(
        wasm_obj,
        str_intern("memPtr"),
        js_native_create("memPtr", 1, NATIVE_KIND_WASM_MEM_PTR)
    );
    js_object_set(
        wasm_obj,
        str_intern("memSize"),
        js_native_create("memSize", 1, NATIVE_KIND_WASM_MEM_SIZE)
    );
    js_object_set(
        wasm_obj,
        str_intern("memPages"),
        js_native_create("memPages", 1, NATIVE_KIND_WASM_MEM_PAGES)
    );
    js_object_set(
        wasm_obj,
        str_intern("memGrow"),
        js_native_create("memGrow", 2, NATIVE_KIND_WASM_MEM_GROW)
    );
    js_object_set(
        wasm_obj,
        str_intern("memFree"),
        js_native_create("memFree", 1, NATIVE_KIND_WASM_MEM_FREE)
    );
    js_object_set(
        wasm_obj,
        str_intern("lastError"),
        js_native_create("lastError", 0, NATIVE_KIND_WASM_LAST_ERROR)
    );
    js_object_set(
        wasm_obj,
        str_intern("freeModule"),
        js_native_create("freeModule", 1, NATIVE_KIND_WASM_FREE_MODULE)
    );
    js_object_set(
        wasm_obj,
        str_intern("moduleImports"),
        js_native_create("moduleImports", 1, NATIVE_KIND_WASM_MODULE_IMPORTS)
    );
    js_object_set(
        wasm_obj,
        str_intern("moduleExports"),
        js_native_create("moduleExports", 1, NATIVE_KIND_WASM_MODULE_EXPORTS)
    );
    js_object_set(
        wasm_obj,
        str_intern("exportGlobal"),
        js_native_create("exportGlobal", 2, NATIVE_KIND_WASM_EXPORT_GLOBAL)
    );
    js_object_set(
        wasm_obj,
        str_intern("globalGet"),
        js_native_create("globalGet", 1, NATIVE_KIND_WASM_GLOBAL_GET)
    );
    # Phase 3: imports (JS→WASM callbacks), tables, globals (create/set), traps.
    js_object_set(
        wasm_obj,
        str_intern("lastErrorClass"),
        js_native_create("lastErrorClass", 0, NATIVE_KIND_WASM_LAST_ERRCLASS)
    );
    js_object_set(
        wasm_obj,
        str_intern("globalCreate"),
        js_native_create("globalCreate", 4, NATIVE_KIND_WASM_GLOBAL_CREATE)
    );
    js_object_set(
        wasm_obj,
        str_intern("globalSet"),
        js_native_create("globalSet", 3, NATIVE_KIND_WASM_GLOBAL_SET)
    );
    js_object_set(
        wasm_obj,
        str_intern("globalIsMutable"),
        js_native_create("globalIsMutable", 1, NATIVE_KIND_WASM_GLOBAL_IS_MUT)
    );
    js_object_set(
        wasm_obj,
        str_intern("globalKind"),
        js_native_create("globalKind", 1, NATIVE_KIND_WASM_GLOBAL_KIND)
    );
    js_object_set(
        wasm_obj,
        str_intern("tableCreate"),
        js_native_create("tableCreate", 3, NATIVE_KIND_WASM_TABLE_CREATE)
    );
    js_object_set(
        wasm_obj,
        str_intern("tableSize"),
        js_native_create("tableSize", 1, NATIVE_KIND_WASM_TABLE_SIZE)
    );
    js_object_set(
        wasm_obj,
        str_intern("tableGetKind"),
        js_native_create("tableGetKind", 2, NATIVE_KIND_WASM_TABLE_GET_KIND)
    );
    js_object_set(
        wasm_obj,
        str_intern("tableSetNull"),
        js_native_create("tableSetNull", 2, NATIVE_KIND_WASM_TABLE_SET_NULL)
    );
    js_object_set(
        wasm_obj,
        str_intern("tableSetFunc"),
        js_native_create("tableSetFunc", 3, NATIVE_KIND_WASM_TABLE_SET_FUNC)
    );
    js_object_set(
        wasm_obj,
        str_intern("tableGrow"),
        js_native_create("tableGrow", 2, NATIVE_KIND_WASM_TABLE_GROW)
    );
    js_object_set(
        wasm_obj,
        str_intern("exportTable"),
        js_native_create("exportTable", 2, NATIVE_KIND_WASM_EXPORT_TABLE)
    );
    js_object_set(
        wasm_obj,
        str_intern("importsBegin"),
        js_native_create("importsBegin", 1, NATIVE_KIND_WASM_IMPORTS_BEGIN)
    );
    js_object_set(
        wasm_obj,
        str_intern("importsAddFunc"),
        js_native_create("importsAddFunc", 2, NATIVE_KIND_WASM_IMPORTS_ADD_FUNC)
    );
    js_object_set(
        wasm_obj,
        str_intern("importsAddMemory"),
        js_native_create("importsAddMemory", 2, NATIVE_KIND_WASM_IMPORTS_ADD_MEMORY)
    );
    js_object_set(
        wasm_obj,
        str_intern("importsAddGlobal"),
        js_native_create("importsAddGlobal", 2, NATIVE_KIND_WASM_IMPORTS_ADD_GLOBAL)
    );
    js_object_set(
        wasm_obj,
        str_intern("importsAddTable"),
        js_native_create("importsAddTable", 2, NATIVE_KIND_WASM_IMPORTS_ADD_TABLE)
    );
    js_object_set(
        wasm_obj,
        str_intern("instantiateImports"),
        js_native_create("instantiateImports", 1, NATIVE_KIND_WASM_INSTANTIATE_IMPORTS)
    );
    js_object_set(
        wasm_obj,
        str_intern("bindFuncKinds"),
        js_native_create("bindFuncKinds", 1, NATIVE_KIND_WASM_BIND_FUNC_KINDS)
    );
    js_object_set(gv, str_intern("__wasm"), wasm_obj);

    # ── __dns (node:dns getaddrinfo / getnameinfo bridge) ─────────────────────
    dns_obj: JSValue = js_object_create_null();
    js_object_set(
        dns_obj,
        str_intern("lookup"),
        js_native_create("lookup", 4, NATIVE_KIND_DNS_LOOKUP)
    );
    js_object_set(
        dns_obj,
        str_intern("reverse"),
        js_native_create("reverse", 2, NATIVE_KIND_DNS_REVERSE)
    );
    js_object_set(
        dns_obj,
        str_intern("lookupService"),
        js_native_create("lookupService", 2, NATIVE_KIND_DNS_LOOKUP_SERVICE)
    );
    js_object_set(
        dns_obj,
        str_intern("resolve4"),
        js_native_create("resolve4", 2, NATIVE_KIND_DNS_RESOLVE4)
    );
    js_object_set(
        dns_obj,
        str_intern("resolve6"),
        js_native_create("resolve6", 2, NATIVE_KIND_DNS_RESOLVE6)
    );
    js_object_set(
        dns_obj,
        str_intern("wireResolve"),
        js_native_create("wireResolve", 3, NATIVE_KIND_DNS_WIRE_RESOLVE)
    );
    js_object_set(
        dns_obj,
        str_intern("getDefaultResultOrder"),
        js_native_create("getDefaultResultOrder", 0, NATIVE_KIND_DNS_GET_DEFAULT_ORDER)
    );
    js_object_set(
        dns_obj,
        str_intern("setDefaultResultOrder"),
        js_native_create("setDefaultResultOrder", 1, NATIVE_KIND_DNS_SET_DEFAULT_ORDER)
    );
    js_object_set(
        dns_obj,
        str_intern("getServers"),
        js_native_create("getServers", 0, NATIVE_KIND_DNS_GET_SERVERS)
    );
    js_object_set(
        dns_obj,
        str_intern("setServers"),
        js_native_create("setServers", 1, NATIVE_KIND_DNS_SET_SERVERS)
    );
    js_object_set(gv, str_intern("__dns"), dns_obj);

    # ── §20.1.3 / §20.2.3 / §23.1.3 Prototype chain wiring ──────────────────
    # Create the standard prototype objects and wire them to constructors.
    # ECMAScript: all ordinary objects ultimately inherit from Object.prototype.

    # Object.prototype — the root of the prototype chain (ECMAScript §20.1.3)
    obj_proto: JSValue = js_object_create_null();
    _define_proto_method(obj_proto, k_constructor, obj_ctor);
    _define_proto_method(
        obj_proto,
        k_hastown,
        js_native_create("hasOwnProperty", 1, NATIVE_KIND_OBJ_PROTO_HAS_OWN)
    );
    _define_proto_method(
        obj_proto,
        k_tostring,
        js_native_create("toString", 0, NATIVE_KIND_OBJ_PROTO_TOSTRING)
    );
    _define_proto_method(
        obj_proto,
        k_valueof,
        js_native_create("valueOf", 0, NATIVE_KIND_OBJ_PROTO_VALUEOF)
    );
    _define_proto_method(
        obj_proto,
        k_isprotoof,
        js_native_create("isPrototypeOf", 1, NATIVE_KIND_OBJ_PROTO_IS_PROTO_OF)
    );
    _define_proto_method(
        obj_proto,
        k_propisenum,
        js_native_create("propertyIsEnumerable", 1, NATIVE_KIND_OBJ_PROTO_PROP_IS_ENUM)
    );
    # R17: Object.prototype.toLocaleString — Invoke(this, "toString") (§20.1.3.5)
    _define_proto_method(
        obj_proto,
        k_tolocalestring,
        js_native_create("toLocaleString", 0, NATIVE_KIND_OBJ_PROTO_TOLOCALESTRING)
    );
    # Annex B.2.2 — legacy accessor helpers
    _define_proto_method(
        obj_proto,
        str_intern("__lookupGetter__"),
        js_native_create("__lookupGetter__", 1, NATIVE_KIND_OBJ_PROTO_LOOKUP_GETTER)
    );
    _define_proto_method(
        obj_proto,
        str_intern("__lookupSetter__"),
        js_native_create("__lookupSetter__", 1, NATIVE_KIND_OBJ_PROTO_LOOKUP_SETTER)
    );
    _define_proto_method(
        obj_proto,
        str_intern("__defineGetter__"),
        js_native_create("__defineGetter__", 2, NATIVE_KIND_OBJ_PROTO_DEFINE_GETTER)
    );
    _define_proto_method(
        obj_proto,
        str_intern("__defineSetter__"),
        js_native_create("__defineSetter__", 2, NATIVE_KIND_OBJ_PROTO_DEFINE_SETTER)
    );
    # §20.1.2.19 Object.prototype is { w:F, e:F, c:F }. Math/JSON prototype linking
    # that once lived here is redundant — js_object_set_prototype(math/json,
    # obj_proto) runs a few lines below via the direct refs.
    _define_prop(obj_ctor, k_prototype, obj_proto, False, False, False);
    js_object_set_ordinary_proto(obj_proto);
    # Math / JSON / Reflect were created via js_object_create_null(); wire [[Prototype]].
    js_object_set_prototype(math, obj_proto);
    js_object_set_prototype(json, obj_proto);
    js_object_set_prototype(reflect_obj, obj_proto);
    # The global object inherits from Object.prototype, as in Node and browsers:
    # `globalThis.hasOwnProperty`, `'toString' in globalThis`, and — through the
    # LOAD_GLOBAL fallback — bare `hasOwnProperty.call(o, k)` (@babel/types).
    js_object_set_prototype(gv, obj_proto);

    # Function.prototype — inherits from Object.prototype (ECMAScript §20.2.3)
    # ES §20.2.3: %Function.prototype% is itself a built-in function object — `typeof
    # Function.prototype === "function"`, calling it returns undefined, but it is NOT a
    # constructor. Object-backed callable so it keeps its own properties (call/apply/bind/
    # toString/@@hasInstance) AND satisfies IsCallable (test262 property-accessors, instanceof
    # prototype-getter-with-object). [[Prototype]] is %Object.prototype% (set below).
    fn_proto: JSValue = js_callable_create("", 0, NATIVE_KIND_FN_PROTOTYPE);
    _ = js_object_set_prototype(fn_proto, obj_proto);
    _define_proto_method(fn_proto, k_constructor, fn_ctor);
    _define_prop(fn_ctor, k_prototype, fn_proto, False, False, False);
    # Own properties so lookups do not fall through to Object.prototype.toString (§20.2.3).
    _define_proto_method(
        fn_proto,
        str_intern("call"),
        js_native_singleton("call", 1, NATIVE_KIND_FN_CALL)
    );
    _define_proto_method(
        fn_proto,
        str_intern("apply"),
        js_native_singleton("apply", 2, NATIVE_KIND_FN_APPLY)
    );
    _define_proto_method(
        fn_proto,
        str_intern("bind"),
        js_native_singleton("bind", 1, NATIVE_KIND_FN_BIND)
    );
    # §20.2.3.5 — Function.prototype.toString is writable, non-enumerable, configurable.
    _define_prop(
        fn_proto,
        k_tostring,
        js_native_singleton("toString", 0, NATIVE_KIND_FN_TOSTRING),
        True,
        False,
        True
    );
    # §20.2.3 — own length/name so lookups do not fall through Object.prototype.
    _define_prop(fn_proto, str_intern("length"), js_number(0.0), False, False, True);
    _define_prop(
        fn_proto,
        str_intern("name"),
        jsv_from_string_id(str_intern("")),
        False,
        False,
        True
    );
    # §20.2.3.6 — Function.prototype[@@hasInstance] (OrdinaryHasInstance). Unlike
    # the other prototype methods it is { w:F, e:F, c:F } (non-configurable);
    # name is "[Symbol.hasInstance]", length 1.
    _define_prop(
        fn_proto,
        SYMBOL_KEY_BASE + SYMBOL_HAS_INSTANCE,
        js_native_create("[Symbol.hasInstance]", 1, NATIVE_KIND_FN_HAS_INSTANCE),
        False,
        False,
        False
    );
    js_function_set_proto(fn_proto);
    # Wire [[Prototype]] on native constructors not covered by _wire_callable_ctor /
    # _wire_error_ctor (Number and Error* are wired later).
    js_object_set_prototype(arr_ctor, fn_proto);
    js_object_set_prototype(obj_ctor, fn_proto);
    js_object_set_prototype(proxy_ctor, fn_proto);
    js_object_set_prototype(fn_ctor, fn_proto);
    js_object_set_prototype(str_ctor, fn_proto);
    js_object_set_prototype(bool_ctor, fn_proto);
    js_object_set_prototype(bigint_ctor, fn_proto);
    js_object_set_prototype(sym_ctor, fn_proto);
    js_object_set_prototype(map_ctor, fn_proto);
    js_object_set_prototype(set_ctor, fn_proto);
    js_object_set_prototype(weakmap_ctor, fn_proto);
    js_object_set_prototype(weakset_ctor, fn_proto);
    js_object_set_prototype(date_ctor, fn_proto);
    js_object_set_prototype(gen_fn_ctor, fn_proto);
    js_object_set_prototype(promise_ctor, fn_proto);
    js_object_set_prototype(regexp_ctor, fn_proto);

    # ── Generator intrinsics (ES §27.3 / §27.5) ──────────────────────────────
    # Chain:  g  --[[Proto]]-->  %Generator%  --[[Proto]]-->  Function.prototype
    #         g.prototype  --[[Proto]]-->  %GeneratorPrototype%  --[[Proto]]-->
    #             %IteratorPrototype%  --[[Proto]]-->  Object.prototype
    # We keep the js_is_generator special-case in GET_PROP for next/throw/return
    # dispatch (instances carry _KEY_IS_GEN), but installing them on
    # %GeneratorPrototype% too makes the prototype spec-shaped and lets an instance
    # whose g.prototype was cleared still resolve them.
    k_gen_sym_iter: int = SYMBOL_KEY_BASE + SYMBOL_ITERATOR;
    k_gen_sym_tag: int = SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG;
    # %IteratorPrototype% — inherits Object.prototype.
    iter_proto: JSValue = js_object_create(obj_proto);
    # %GeneratorPrototype% (Generator.prototype) — inherits %IteratorPrototype%.
    gen_proto: JSValue = js_object_create(iter_proto);
    _define_proto_method(
        gen_proto,
        str_intern("next"),
        js_native_singleton("next", 1, NATIVE_KIND_GENERATOR_NEXT)
    );
    _define_proto_method(
        gen_proto,
        str_intern("return"),
        js_native_singleton("return", 1, NATIVE_KIND_GENERATOR_RETURN)
    );
    _define_proto_method(
        gen_proto,
        str_intern("throw"),
        js_native_singleton("throw", 1, NATIVE_KIND_GENERATOR_THROW)
    );
    _define_prop(
        gen_proto,
        k_gen_sym_tag,
        jsv_from_string_id(str_intern("Generator")),
        False,
        False,
        True
    );
    # %Generator% (GeneratorFunction.prototype) — inherits Function.prototype; its
    # `prototype` property is %GeneratorPrototype% (non-writable, non-enum, config).
    gen_fn_intrinsic: JSValue = js_object_create(fn_proto);
    _define_prop(gen_fn_intrinsic, k_prototype, gen_proto, False, False, True);
    _define_prop(
        gen_fn_intrinsic,
        k_gen_sym_tag,
        jsv_from_string_id(str_intern("GeneratorFunction")),
        False,
        False,
        True
    );
    _define_prop(gen_fn_ctor, k_prototype, gen_fn_intrinsic, False, False, False);
    _define_prop(gen_fn_intrinsic, k_constructor, gen_fn_ctor, False, False, True);
    # %AsyncGeneratorPrototype% / %AsyncGenerator% — parallel chain (async gens
    # share the same next/return/throw native dispatch via js_is_generator).
    async_iter_proto: JSValue = js_object_create(obj_proto);
    async_gen_proto: JSValue = js_object_create(async_iter_proto);
    _define_proto_method(
        async_gen_proto,
        str_intern("next"),
        js_native_create("next", 1, NATIVE_KIND_GENERATOR_NEXT)
    );
    _define_proto_method(
        async_gen_proto,
        str_intern("return"),
        js_native_create("return", 1, NATIVE_KIND_GENERATOR_RETURN)
    );
    _define_proto_method(
        async_gen_proto,
        str_intern("throw"),
        js_native_create("throw", 1, NATIVE_KIND_GENERATOR_THROW)
    );
    _define_prop(
        async_gen_proto,
        k_gen_sym_tag,
        jsv_from_string_id(str_intern("AsyncGenerator")),
        False,
        False,
        True
    );
    async_gen_fn_intrinsic: JSValue = js_object_create(fn_proto);
    _define_prop(
        async_gen_fn_intrinsic, k_prototype, async_gen_proto, False, False, True
    );
    _define_prop(
        async_gen_fn_intrinsic,
        k_gen_sym_tag,
        jsv_from_string_id(str_intern("AsyncGeneratorFunction")),
        False,
        False,
        True
    );
    # AsyncGeneratorFunction is not installed as a global, but its .prototype.constructor
    # must still be non-writable / non-enumerable / configurable for metadata tests.
    # Wire a private ctor object for the constructor property.
    async_gen_fn_ctor: JSValue = js_callable_create(
        "AsyncGeneratorFunction", 1, NATIVE_KIND_FUNCTION
    );
    js_object_set_prototype(async_gen_fn_ctor, fn_proto);
    _define_prop(
        async_gen_fn_ctor, k_prototype, async_gen_fn_intrinsic, False, False, False
    );
    _define_prop(
        async_gen_fn_intrinsic, k_constructor, async_gen_fn_ctor, False, False, True
    );
    js_generator_set_intrinsics(
        gen_fn_intrinsic, gen_proto, async_gen_fn_intrinsic, async_gen_proto
    );
    # Remember the native %Iterator.prototype% objects so they can be re-parented
    # onto the JS `Iterator.prototype` stub (which owns the iterator-helper methods)
    # once builtins_stubs has loaded — see below.
    js_iterator_set_native_protos(iter_proto, async_iter_proto);

    # Array.prototype — inherits from Object.prototype (ECMAScript §23.1.3)
    arr_proto: JSValue = js_object_create(obj_proto);
    # Array.prototype is itself an Array exotic object (ECMAScript §23.1.1, §23.1.3)
    _define_prop(arr_proto, _KEY_IS_ARRAY, js_true(), False, False, False);
    _define_proto_method(arr_proto, k_constructor, arr_ctor);
    _define_prop(arr_ctor, k_prototype, arr_proto, False, False, False);
    _define_prop(arr_ctor, str_intern("length"), js_int(1), False, False, True);
    _define_prop(
        arr_ctor,
        str_intern("name"),
        jsv_from_string_id(str_intern("Array")),
        False,
        False,
        True
    );
    _define_prop(arr_proto, str_intern("length"), js_int(0), True, False, False);
    js_array_set_proto(arr_proto);  # wire prototype for all future js_array_create() calls
    # Array.prototype.values === Array.prototype[Symbol.iterator] (ECMAScript §23.1.3.35 / §23.1.3.37)
    # A single native function object serves both slots so identity checks hold.
    # R15: CreateArrayIterator(O, "value") — not the legacy {__I,__J} shell.
    arr_values_fn: JSValue = js_native_create("values", 0, NATIVE_KIND_ARRAY_VALUES);
    _define_proto_method(arr_proto, k_values, arr_values_fn);
    _define_proto_method(arr_proto, SYMBOL_KEY_BASE + SYMBOL_ITERATOR, arr_values_fn);
    # Cache the canonical %Array.prototype.values% so `arguments` objects can share
    # the *same* native (identity-stable @@iterator, ES §10.4.4).
    ctx.realm.array_values_fn = arr_values_fn;
    # Array.prototype[Symbol.unscopables] — null-proto object with `true` for each
    # method that should be excluded from `with` scope (ECMAScript §23.1.3.34).
    arr_unsc: JSValue = js_object_create_null();
    _define_prop(arr_unsc, str_intern("at"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("copyWithin"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("entries"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("fill"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("find"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("findIndex"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("findLast"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("findLastIndex"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("flat"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("flatMap"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("includes"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("keys"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("toReversed"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("toSorted"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("toSpliced"), js_true(), True, True, True);
    _define_prop(arr_unsc, str_intern("values"), js_true(), True, True, True);
    _define_prop(
        arr_proto, SYMBOL_KEY_BASE + SYMBOL_UNSCOPABLES, arr_unsc, False, False, True
    );
    # Install all §23.1.3 methods as own data properties on Array.prototype.
    _init_array_proto_methods(arr_proto);

    # Map.prototype — inherits from Object.prototype (ECMAScript §24.1.3)
    map_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(map_proto, k_constructor, map_ctor);
    _define_prop(map_ctor, k_prototype, map_proto, False, False, False);
    _define_ctor_species_accessor(map_ctor);
    js_map_set_proto(map_proto);
    _init_map_proto_methods(map_proto);

    # Set.prototype — inherits from Object.prototype (ECMAScript §24.2.3)
    set_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(set_proto, k_constructor, set_ctor);
    _define_prop(set_ctor, k_prototype, set_proto, False, False, False);
    _define_ctor_species_accessor(set_ctor);
    js_set_set_proto(set_proto);
    _init_set_proto_methods(set_proto);

    # WeakMap.prototype — inherits from Object.prototype (ECMAScript §24.3.3)
    weakmap_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(weakmap_proto, k_constructor, weakmap_ctor);
    _define_prop(weakmap_ctor, k_prototype, weakmap_proto, False, False, False);
    js_weakmap_set_proto(weakmap_proto);
    _init_weakmap_proto_methods(weakmap_proto);

    # WeakSet.prototype — inherits from Object.prototype (ECMAScript §24.4.3)
    weakset_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(weakset_proto, k_constructor, weakset_ctor);
    _define_prop(weakset_ctor, k_prototype, weakset_proto, False, False, False);
    js_weakset_set_proto(weakset_proto);
    _init_weakset_proto_methods(weakset_proto);

    # Date.prototype — inherits from Object.prototype (ECMAScript §21.4.4)
    date_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(date_proto, k_constructor, date_ctor);
    _define_prop(date_ctor, k_prototype, date_proto, False, False, False);
    _init_date_proto_methods(date_proto);
    js_date_set_proto(date_proto);

    # Promise.prototype — inherits from Object.prototype (ECMAScript §27.2.5)
    promise_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(promise_proto, k_constructor, promise_ctor);
    _define_prop(promise_ctor, k_prototype, promise_proto, False, False, False);
    _init_promise_proto_methods(promise_proto);
    js_promise_set_proto(promise_proto);

    # Number.prototype — inherits from Object.prototype (ECMAScript §21.1.3)
    num_proto: JSValue = js_object_create(obj_proto);
    # §21.1.3: Number.prototype is itself a Number object with [[NumberData]] = +0
    js_object_set(num_proto, KEY_IS_NUMBER_OBJ, js_number(0.0));
    _init_number_proto_methods(num_proto);
    # §21.1.3.1 Number.prototype[ @@toStringTag ] → "Number"
    _define_prop(
        num_proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Number")),
        False,
        False,
        True
    );
    _init_number_ctor_statics(num_ctor);
    _wire_callable_ctor(
        num_ctor,
        num_proto,
        fn_proto,
        k_prototype,
        k_constructor,
        k_number,
        1,
        False,
        False,
        False
    );
    js_number_set_proto(num_proto);

    # String.prototype — inherits from Object.prototype (ECMAScript §22.1.3)
    str_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(str_proto, k_constructor, str_ctor);
    # Wrapper objects (new String(...)) need prototype methods too.
    _define_proto_method(
        str_proto, k_tostring, js_native_create("toString", 0, NATIVE_KIND_STR_TOSTRING)
    );
    _define_proto_method(
        str_proto, k_valueof, js_native_create("valueOf", 0, NATIVE_KIND_STR_TOSTRING)
    );
    # §22.1.2.3: String.prototype is { w:F, e:F, c:F }. adel_fixes used {w:T,c:T}
    # (wrong) and re-called _init_string_proto_methods here — redundant, since the
    # call below (after js_string_set_proto) already installs the methods.
    _define_prop(str_ctor, k_prototype, str_proto, False, False, False);
    js_string_set_proto(str_proto);
    # All remaining String.prototype methods (§22.1.3). Primitive string property
    # access resolves through here — vm.na.jac's fast path only handles `length`.
    _init_string_proto_methods(str_proto);
    # String.prototype[Symbol.iterator] — returns a native StringIterator (2.3)
    _define_proto_method(
        str_proto,
        SYMBOL_KEY_BASE + SYMBOL_ITERATOR,
        js_native_singleton("[Symbol.iterator]", 0, NATIVE_KIND_STR_ITER)
    );

    # RegExp.prototype — inherits from Object.prototype (ECMAScript §22.2.6)
    regexp_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(regexp_proto, k_constructor, regexp_ctor);
    _define_proto_method(
        regexp_proto,
        k_tostring,
        js_native_create("toString", 0, NATIVE_KIND_REGEXP_TOSTRING)
    );
    _define_proto_method(
        regexp_proto,
        str_intern("test"),
        js_native_create("test", 1, NATIVE_KIND_REGEXP_TEST)
    );
    _define_proto_method(
        regexp_proto,
        str_intern("exec"),
        js_native_create("exec", 1, NATIVE_KIND_REGEXP_EXEC)
    );
    _define_proto_method(
        regexp_proto,
        SYMBOL_KEY_BASE + SYMBOL_MATCH,
        js_native_create("[Symbol.match]", 1, NATIVE_KIND_REGEXP_SYMBOL_MATCH)
    );
    _define_proto_method(
        regexp_proto,
        SYMBOL_KEY_BASE + SYMBOL_MATCH_ALL,
        js_native_create("[Symbol.matchAll]", 1, NATIVE_KIND_REGEXP_SYMBOL_MATCHALL)
    );
    _define_proto_method(
        regexp_proto,
        SYMBOL_KEY_BASE + SYMBOL_REPLACE,
        js_native_create("[Symbol.replace]", 2, NATIVE_KIND_REGEXP_SYMBOL_REPLACE)
    );
    _define_proto_method(
        regexp_proto,
        SYMBOL_KEY_BASE + SYMBOL_SEARCH,
        js_native_create("[Symbol.search]", 1, NATIVE_KIND_REGEXP_SYMBOL_SEARCH)
    );
    _define_proto_method(
        regexp_proto,
        SYMBOL_KEY_BASE + SYMBOL_SPLIT,
        js_native_create("[Symbol.split]", 2, NATIVE_KIND_REGEXP_SYMBOL_SPLIT)
    );
    _define_prop(regexp_ctor, k_prototype, regexp_proto, False, False, False);
    # get RegExp [ @@species ] — §22.2.4.2 (returns this)
    _define_ctor_species_accessor(regexp_ctor);
    # RegExp.prototype accessors (§22.2.6): getter-only, { e:F, c:T }. These are
    # prototype accessors in the spec — not own data properties on each instance —
    # so getOwnPropertyDescriptor(RegExp.prototype, "source") must find them here.
    _define_accessor(
        regexp_proto,
        str_intern("source"),
        js_native_create("get source", 0, NATIVE_KIND_REGEXP_GET_SOURCE)
    );
    _define_accessor(
        regexp_proto,
        str_intern("flags"),
        js_native_create("get flags", 0, NATIVE_KIND_REGEXP_GET_FLAGS)
    );
    _define_accessor(
        regexp_proto,
        str_intern("global"),
        js_native_create("get global", 0, NATIVE_KIND_REGEXP_GET_GLOBAL)
    );
    _define_accessor(
        regexp_proto,
        str_intern("ignoreCase"),
        js_native_create("get ignoreCase", 0, NATIVE_KIND_REGEXP_GET_IGNORECASE)
    );
    _define_accessor(
        regexp_proto,
        str_intern("multiline"),
        js_native_create("get multiline", 0, NATIVE_KIND_REGEXP_GET_MULTILINE)
    );
    _define_accessor(
        regexp_proto,
        str_intern("dotAll"),
        js_native_create("get dotAll", 0, NATIVE_KIND_REGEXP_GET_DOTALL)
    );
    _define_accessor(
        regexp_proto,
        str_intern("unicode"),
        js_native_create("get unicode", 0, NATIVE_KIND_REGEXP_GET_UNICODE)
    );
    _define_accessor(
        regexp_proto,
        str_intern("sticky"),
        js_native_create("get sticky", 0, NATIVE_KIND_REGEXP_GET_STICKY)
    );
    _define_accessor(
        regexp_proto,
        str_intern("hasIndices"),
        js_native_create("get hasIndices", 0, NATIVE_KIND_REGEXP_GET_HASINDICES)
    );
    _define_accessor(
        regexp_proto,
        str_intern("unicodeSets"),
        js_native_create("get unicodeSets", 0, NATIVE_KIND_REGEXP_GET_UNICODESETS)
    );
    js_regexp_set_proto(regexp_proto);

    # Boolean.prototype — inherits from Object.prototype (ECMAScript §20.3.3)
    bool_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(bool_proto, k_constructor, bool_ctor);
    _define_proto_method(
        bool_proto,
        k_tostring,
        js_native_singleton("toString", 0, NATIVE_KIND_BOOL_TOSTRING)
    );
    _define_proto_method(
        bool_proto,
        k_valueof,
        js_native_singleton("valueOf", 0, NATIVE_KIND_BOOL_VALUEOF)
    );
    _define_prop(bool_ctor, k_prototype, bool_proto, False, False, False);
    js_boolean_set_proto(bool_proto);

    # BigInt.prototype — inherits from Object.prototype (ECMAScript §21.2.3).
    # New in 87232de: valueOf / toLocaleString.
    bigint_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(bigint_proto, k_constructor, bigint_ctor);
    _define_proto_method(
        bigint_proto,
        k_tostring,
        js_native_singleton("toString", 0, NATIVE_KIND_BIGINT_TOSTRING)
    );
    _define_proto_method(
        bigint_proto,
        k_valueof,
        js_native_singleton("valueOf", 0, NATIVE_KIND_BIGINT_VALUEOF)
    );
    _define_proto_method(
        bigint_proto,
        str_intern("toLocaleString"),
        js_native_singleton("toLocaleString", 0, NATIVE_KIND_BIGINT_TOLOCALESTRING)
    );
    _define_prop(bigint_ctor, k_prototype, bigint_proto, False, False, False);
    js_bigint_set_proto(bigint_proto);

    # §21.2.3.5 BigInt.prototype[@@toStringTag] = "BigInt" (from adel_fixes)
    _define_prop(
        bigint_proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("BigInt")),
        False,
        False,
        True
    );

    # Symbol.prototype — ECMAScript §20.4.3. Created here (not at the Symbol
    # constructor block above) because obj_proto does not exist yet at that
    # point in the bootstrap. Without it, `Symbol.prototype` was undefined and
    # every descriptor/brand test on it failed. The description getter uses
    # NATIVE_KIND_SYMBOL_DESCRIPTION, whose handler unwraps boxed Symbol objects
    # (thisSymbolValue); adel_fixes' SYMBOL_DESCRIPTION_GET variant was a
    # duplicate that only accepted primitive symbols, so it is dropped (and its
    # accessor+data-sentinel shape fought getOwnPropertyDescriptor).
    sym_proto: JSValue = js_object_create(obj_proto);
    _define_proto_method(sym_proto, k_constructor, sym_ctor);
    _define_proto_method(
        sym_proto,
        k_tostring,
        js_native_singleton("toString", 0, NATIVE_KIND_SYMBOL_TOSTRING)
    );
    _define_proto_method(
        sym_proto,
        k_valueof,
        js_native_singleton("valueOf", 0, NATIVE_KIND_SYMBOL_VALUEOF)
    );
    # §20.4.3.2: `description` is a getter-only accessor, { e:F, c:T }.
    _define_accessor(
        sym_proto,
        str_intern("description"),
        js_native_create("get description", 0, NATIVE_KIND_SYMBOL_DESCRIPTION)
    );
    # §20.4.3.5: Symbol.prototype[@@toStringTag] = "Symbol"  { w:F, e:F, c:T }
    _define_prop(
        sym_proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Symbol")),
        False,
        False,
        True
    );
    # §20.4.3.5 Symbol.prototype[@@toPrimitive](hint): returns thisSymbolValue(this)
    # regardless of hint — so ToPrimitive of a boxed Symbol (Object(Symbol())) yields
    # the underlying Symbol primitive, and the subsequent ToString(Symbol) throws
    # (String.prototype.indexOf searchstring-tostring-errors). Reuses the valueOf
    # handler (both return the underlying symbol). Descriptor { w:F, e:F, c:T }.
    sym_toprim: JSValue = js_native_create(
        "[Symbol.toPrimitive]", 1, NATIVE_KIND_SYMBOL_VALUEOF
    );
    _define_prop(
        sym_proto, SYMBOL_KEY_BASE + SYMBOL_TO_PRIMITIVE, sym_toprim, False, False, True
    );
    _define_prop(sym_ctor, k_prototype, sym_proto, False, False, False);
    js_symbol_set_proto(sym_proto);

    # Error.prototype — inherits from Object.prototype (ECMAScript §20.5.3)
    # get_error_proto() lazily creates the shared glob used by make_error() etc.
    # We attach toString here so new Error('msg').toString() works via the chain.
    err_proto: JSValue = get_error_proto();
    # ES §20.5.3: Error.prototype is an ordinary object rooted at %Object.prototype%.
    # It is created lazily in error.na.jac (before obj_proto exists) with a null
    # prototype, so without this link no Error instance inherits hasOwnProperty /
    # isPrototypeOf / propertyIsEnumerable.
    js_object_set_prototype(err_proto, obj_proto);
    # §20.5.3.2-3: `name` and `message` live on the prototype as
    # { w:T, e:F, c:T } data properties — js_object_set made them enumerable,
    # so they showed up in Object.keys(err) and JSON.stringify.
    _define_prop(
        err_proto,
        str_intern("name"),
        jsv_from_string_id(str_intern("Error")),
        True,
        False,
        True
    );
    _define_prop(
        err_proto,
        str_intern("message"),
        jsv_from_string_id(str_intern("")),
        True,
        False,
        True
    );
    _define_proto_method(
        err_proto,
        k_tostring,
        js_native_create("toString", 0, NATIVE_KIND_ERR_PROTO_TOSTRING)
    );

    # Wire each error ctor ↔ its prototype (ECMAScript §20.5.3.1 / §20.5.6.*).
    # `Ctor.prototype` is { w:F, e:F, c:F }; `prototype.constructor` is { w:T, e:F, c:T };
    # `Ctor.name` is { w:F, e:F, c:T }. Without this, `err.constructor` is undefined
    # and `err.constructor.name` throws — breaking test262's assert.throws.
    _wire_error_ctor(
        error_ctor, err_proto, fn_proto, k_prototype, k_constructor, k_error
    );
    _wire_error_ctor(
        typerr_ctor,
        get_type_error_proto(),
        fn_proto,
        k_prototype,
        k_constructor,
        k_typerr
    );
    _wire_error_ctor(
        referr_ctor,
        get_reference_error_proto(),
        fn_proto,
        k_prototype,
        k_constructor,
        k_referr
    );
    _wire_error_ctor(
        synterr_ctor,
        get_syntax_error_proto(),
        fn_proto,
        k_prototype,
        k_constructor,
        k_synterr
    );
    _wire_error_ctor(
        rangerr_ctor,
        get_range_error_proto(),
        fn_proto,
        k_prototype,
        k_constructor,
        k_rangerr
    );
    _wire_error_ctor(
        urierr_ctor,
        get_uri_error_proto(),
        fn_proto,
        k_prototype,
        k_constructor,
        k_urierr
    );
    _wire_error_ctor(
        evalerr_ctor,
        get_eval_error_proto(),
        fn_proto,
        k_prototype,
        k_constructor,
        k_evalerr
    );

    _populate_main_realm_intrinsics(
        ctx, obj_ctor, obj_proto, fn_ctor, fn_proto, arr_ctor, arr_proto
    );

    _init_gc_obj(ctx);

    # test262 host object — enabled when JAC_ENGINE_ENABLE_262_HOST=1 (set by test262 runner).
    host_env: str = getenv("JAC_ENGINE_ENABLE_262_HOST");
    if host_env == "1" {
        k_262: int = str_intern("$262");
        host_262: JSValue = js_object_create_null();
        js_object_set(
            host_262,
            str_intern("createRealm"),
            js_native_create("createRealm", 0, NATIVE_KIND_262_CREATE_REALM)
        );
        js_object_set(
            host_262,
            str_intern("evalScript"),
            js_native_create("evalScript", 1, NATIVE_KIND_262_EVAL_SCRIPT)
        );
        # Annex B host-defined document.all exotic. It is an object for identity,
        # property access, and SameValue, but VM ToBoolean/typeof/equality recognize
        # its dedicated cell kind.
        html_dda_obj: JSValue = js_object_create_null();
        html_dda: JSValue = jsv_from_htmldda_id(jsv_to_table_id(html_dda_obj));
        js_object_set(host_262, str_intern("IsHTMLDDA"), html_dda);
        js_object_set(gv, k_262, host_262);
    }

    # Temporal API — §Temporal
    js_temporal_wire_global(gv);

    # Intl API — ECMA-402 (private __icu bridge; constructors via intl.js)
    js_intl_wire_global(gv);
}

def:pub get_global(ctx: GlobalContext, key: int) -> JSValue {
    return js_object_get(ctx.global_obj.object, key);
}

"""[[Set]] on globalThis."""
def:pub set_global(ctx: GlobalContext, key: int, val: JSValue) {
    js_object_set(ctx.global_obj.object, key, val);
}

"""[[HasOwnProperty]] on globalThis (does not walk prototype chain)."""
def:pub has_global(ctx: GlobalContext, key: int) -> bool {
    return js_object_has_own(ctx.global_obj.object, key);
}

# ── Exception handling ────────────────────────────────────────────────────────

"""
Set the pending exception on the context.

Bun Zig: globalThis.throwException(exception)
The caller is responsible for checking has_exception() before continuing.
"""
def:pub throw_exception(ctx: GlobalContext, err: JSValue) {
    ctx.pending_exception = err;
}

"""
Clear the pending exception (after handling it).

Bun Zig: global.clearException() / implicit on re-entry
"""
def:pub clear_exception(ctx: GlobalContext) {
    ctx.pending_exception = js_undefined();
}

"""
Return True if there is a pending uncaught exception.

Bun Zig: globalThis.hasException()
"""
def:pub has_exception(ctx: GlobalContext) -> bool {
    return not jsv_is_undefined(ctx.pending_exception);
}


# ── VM integration ──────────────────────────────────────────────────────────────────────

"""
Create a VM wired to the global context.

Copies all globalThis property names into vm.globals so that LOAD_GLOBAL
instructions can find built-in values (Number, console, parseInt, …).

Bun Zig: VirtualMachine.create()
"""
def:pub create_vm(ctx: GlobalContext) -> VM {
    vm: VM = make_vm();
    vm.realm = ctx.realm;
    fn_meta_bind_closures(vm.realm.closures);
    vm.global_this = ctx.global_obj.object;
    _populate_vm_globals(vm, ctx);
    # From here on, writes through globalThis are recorded so the VM's bare-name
    # reads (vm.globals, filled just above) see them.
    js_object_mark_global(vm.global_this);
    return vm;
}

"""
Copy every own property of globalThis into vm.globals.

LOAD_GLOBAL / STORE_GLOBAL in the bytecode use plain string keys, so we
convert each intern-ID (int) back to the original string for the dict.
Includes non-enumerable properties (NaN, Infinity, undefined) that are
defined via _define_prop with enumerable=False.
"""
def _populate_vm_globals(vm: VM, ctx: GlobalContext) {
    gv: JSValue = ctx.global_obj.object;
    keys: list[int] = js_object_all_keys(gv);
    ki: int = 0;
    while ki < len(keys) {
        kid: int = keys[ki];
        name: str = str_from_id(kid);
        val: JSValue = js_object_get(gv, kid);
        vm.globals[name] = val;
        ki = ki + 1;
    }
}

"""
Bootstrap JS-defined globals (fetch, Headers, Request, Response, etc.).

In Node.js ≥18, these are globals — not modules.  There is no
`require("fetch")` in Node core.  We load the JS bootstrap file once
at startup so `globalThis.fetch` etc. are set, then resync the
globalThis JSObject properties back into `vm.globals` so that
`LOAD_GLOBAL "fetch"` in user bytecode finds them.

Must be called after `vm.engine_root` is set.
"""
def:pub bootstrap_js_globals(vm: VM, ctx: GlobalContext) {
    # Load the url module first — it registers globalThis.URL and
    # globalThis.URLSearchParams (Web API globals, available in
    # Node.js ≥10 and all browsers).
    vm._require_module("url");

    # EventTarget / CustomEvent — Vite cac CLI (extends EventTarget)
    vm._require_module("event_target");

    # Load the fetch bootstrap — its top-level code sets
    # globalThis.fetch, globalThis.Headers, etc.
    vm._require_module("fetch");

    # WHATWG WritableStream / TransformStream (ReadableStream comes from fetch).
    vm._require_module("webstreams");

    # MessageChannel / MessagePort / BroadcastChannel globals
    vm._require_module("worker_threads");

    # Attach console.Console onto the global console object
    vm._require_module("console");

    # Wave 21 — process.seteuid/setegid/… validation wrappers
    vm._require_module("process");

    # Load the HTTP server bootstrap — sets globalThis.Server,
    # globalThis.Bun.serve, and exports createServer.
    vm._require_module("http_server");

    # Load the WebSocket bootstrap — sets globalThis.WebSocket (Web API global).
    vm._require_module("websocket");

    # Load binary types — sets globalThis.ArrayBuffer, Uint8Array, etc.
    vm._require_module("binary_types");

    # Load milestone stubs — Iterator, AggregateError, SAB/Atomics presence, etc.
    vm._require_module("builtins_stubs");

    # ECMA-402 Intl — installs globalThis.Intl using the __icu native bridge.
    vm._require_module("intl");
    iter_hp: JSValue = js_object_get(
        ctx.global_obj.object, str_intern("__jacIteratorPrototype")
    );
    if jsv_is_object_cell(iter_hp) and jsv_to_table_id(iter_hp) > 0 {
        js_set_iterator_helper_proto(iter_hp);
        # Re-parent the native %Iterator.prototype% objects (which %GeneratorPrototype%
        # and %AsyncGeneratorPrototype% inherit from) onto the stub Iterator.prototype
        # so generator instances resolve map/filter/take/drop/… helper methods.
        js_iterator_reparent_native_protos(iter_hp);
    }
    gen_ip: JSValue = js_object_get(
        ctx.global_obj.object, str_intern("__jacGeneratorPrototype")
    );
    if jsv_is_object_cell(gen_ip) and jsv_to_table_id(gen_ip) > 0 {
        gen_set_instance_proto(gen_ip);
    }

    # Load WebAssembly stub — sets globalThis.WebAssembly with methods that
    # return rejected promises (needed so bundled WASM-based parsers like
    # vite's rolldown/oxc chunk don't crash at module-load time).
    vm._require_module("webassembly");

    # Load TextEncoder / TextDecoder — Vite V-16 (requires Uint8Array)
    vm._require_module("text_codec");

    # Load structuredClone — Vite V-17 (requires DOMException from fetch.js)
    vm._require_module("structured_clone");

    # Pre-load the Web Crypto builtin so globalThis.crypto (getRandomValues,
    # randomUUID, subtle) is available before any user script runs.
    # Vite's resolveConfig calls crypto.getRandomValues as a global during
    # startup, before any import("node:crypto") is issued.
    vm._require_module("crypto");

    # Resync: after the module executed, globalThis JSObject has new
    # properties.  Copy them into vm.globals so LOAD_GLOBAL finds them.
    _populate_vm_globals(vm, ctx);

    # The built-in RegExp state the String methods' fast paths compare against
    # (every builtin module has run; no user code yet).
    js_regexp_pristine_snapshot();
}

"""
Full-pipeline entry point: source JS → lex → parse → compile → run.

Returns the completion value of the script (typically undefined for
top-level statements, or the final expression value).

If the script throws an uncaught exception, prints it to stdout in the
same format Node/Bun use ("Uncaught TypeError: x is not a function")
and returns js_undefined().

Bun Zig: VirtualMachine.loadEntryPointForMainThread()
"""
def:pub run_script(ctx: GlobalContext, source: str) -> JSValue {
    # Pass detect_module explicitly: the native backend does not reliably fill
    # omitted default-valued params, so relying on parse()'s default would leave
    # module-goal detection off. See parse() and js_engine/issues/.
    ast = parse(source, False, True);
    if _PARSE_HAD_ERRORS {
        return js_undefined();
    }
    c = make_compiler();
    c.source_text = source;
    top_fn = c.compile_program(ast);
    vm: VM = create_vm(ctx);
    result: JSValue = vm.eval(top_fn, c.all_fns);
    if vm.had_exception {
        print_uncaught(vm.pending_exc);
        return js_undefined();
    }
    return result;
}

"""
Like run_script but uses an existing VM instance instead of creating a new one.

This is essential for event-loop integration: the async callbacks that fire
after the top-level script need to share the same globals dict that the
script wrote to (e.g., `var order = []` in top-level scope).
"""
def:pub run_script_with_vm(vm: VM, source: str, source_file: str) -> JSValue {
    # A .mjs / ESM entry is always a module (TLA allowed even with only dynamic
    # import()); the event loop sets esm_entry before calling us.
    ast = parse(source, vm.esm_entry == 1, True);
    if _PARSE_HAD_ERRORS {
        vm.had_exception = True;
        return js_undefined();
    }
    c = make_compiler();
    c.source_file = source_file;
    c.source_text = source;
    top_fn = c.compile_program(ast);
    result: JSValue = vm.eval(top_fn, c.all_fns);
    if vm.had_exception {
        print_uncaught(vm.pending_exc);
        return js_undefined();
    }
    return result;
}
