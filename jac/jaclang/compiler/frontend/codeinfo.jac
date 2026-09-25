import type from jaclang.runtime.native_library { SharedNativeEngine }
import hashlib;
import from jaclang.runtime.surface { SurfaceEntry }
import from collections.abc { Sequence }
import from contextvars { ContextVar }
import from jaclang.compiler.frontend.constant {
    NATIVE_ERASED_ANNOTATIONS,
    NATIVE_ERASED_TYPE_MARKERS,
    TYPE_PARAM_CONSTRUCTORS
}
import from jaclang.compiler.frontend.srcloc { CodeLocInfo }
import type from jaclang.compiler.backends.es.estree { IndexInfo, SliceInfo }
import type from jaclang.compiler.backends.es.estree { Node as EsNode }
import type from jaclang.compiler.frontend.unitree { CommentToken }
import type from jaclang.compiler.tools.doc_ir { Doc }
import type from jaclang.compiler.frontend.unitree { Source, Token }
import type from jaclang.compiler.passes.osp_analysis { OspModel }
import type from jaclang.compiler.backends.native.llvm.ir { Module as IRModule }
import type from jaclang.compiler.backends.native.llvm.binding {
    ModuleRef,
    ExecutionEngine
}
import type from jaclang.compiler.driver.native_iface { NativeIface }

obj ClientManifest {
    has exports: list[str] = [],
        globals: list[str] = [],
        params: dict[str, list[str]] = {},
        globals_values: dict[(str, any)] = {},
        has_client: bool = False,
        imports: dict[(str, str)] = {},
        runtime_imports: dict[str, list[str]] = {},
        endpoint_effects: dict[(str, dict[str, any])] = {},
        tests: list[dict[(str, str)]] = [],
        server_imports: list[str] = [],
        server_import_routes: dict[(str, dict[(str, str)])] = {},
        page_export: (str | None) = None,
        layout_export: (str | None) = None;
}

obj ClientArtifact {
    has js: str,
        manifest: ClientManifest,
        native_import_sources: list[str] = [],
        source_map: list[tuple[int, int, int, int, str]] = [],
        dep_digests: dict[str, str] = {},
        boundary_contracts: dict[str, any] = {},
        framework: str = "";

    def to_bytes -> bytes;
    static def from_bytes(raw: bytes) -> (ClientArtifact | None);
}

enum InteropContext { SERVER = 'server', NATIVE = 'native', CLIENT = 'client' }

glob HDR_ALLOC_ID_OFF: int = -32,
     HDR_TAG_OFF: int = -24,
     HDR_RC_OFF: int = -16,
     HDR_DTOR_OFF: int = -8,
     HDR_TOTAL: int = 32;

glob HDR_MAGIC: int = 44061,
     HDR_MAGIC_SHIFT_BASE: int = 44061 * 4294967296,
     RC_SENTINEL: int = 0x7FFFFFFFFFFFFFFF;

glob STR_LEN_TAG_BIT: int = 1,
     STR_LEN_TAG_SHIFT: int = 1;

glob JACSTR_DESC_FIELDS: dict[(str, tuple[str, ...])] = {
         'jacstr3': ('root', 'data', 'len'),
         'jacstr2': ('data', 'len')
     };

def str_len_tag(length: int) -> int {
    return (length << STR_LEN_TAG_SHIFT) | STR_LEN_TAG_BIT;
}

obj NativeFieldInfo {
    has name: str,
        llvm_type: str,
        index: int,
        enum_type: (str | None) = None,
        is_func_ptr: bool = False,
        func_param_types: (list[str] | None) = None,
        func_ret_type: (str | None) = None,
        elem_keys: (list[str | None] | None) = None,
        foreign: bool = False;
}

obj NativeStructLayout {
    has name: str,
        fields: list[NativeFieldInfo] = [],
        has_vtable: bool = False,
        accessors: dict[(str, dict[(str, str)])] = {};
}

obj NativeEnumLayout {
    has name: str,
        is_string_valued: bool = False,
        members: list[tuple[str, any, int]] = [];
}

obj NativeTupleLayout {
    has key: str,
        element_types: list[str] = [],
        element_struct_hints: list[str | None] = [];
}

obj NativeFuncLayout {
    has name: str,
        param_types: list[str] = [],
        param_names: list[str] = [],
        ret_type: str = "i64",
        ret_struct_name: (str | None) = None,
        ret_tuple_layout: (NativeTupleLayout | None) = None,
        ret_enum_type: (str | None) = None,
        ret_elem_keys: (list[str | None] | None) = None;
}

obj NativeTestLayout {
    has name: str,
        symbol: str,
        description: str = "",
        line: int = 0;
}

def native_safe_sym(src: str) -> str {
    safe = '';
    for ch in src {
        if ((ch >= 'a') and (ch <= 'z'))
            or ((ch >= 'A') and (ch <= 'Z'))
            or ((ch >= '0') and (ch <= '9'))
            or (ch == '_') {
            safe += ch;
        } else {
            safe += '_';
        }
    }
    return f"{safe}_{hashlib.sha1(src.encode()).hexdigest()[:8]}";
}

glob NATIVE_ARCH_SCOPE_SEP: str = "$",
     _native_arch_scope_memo: dict[str, str] = {},
     _native_toolchain_roots: list[str] = [];

def native_arch_scope(mod_path: str) -> str {
    import os;
    if not mod_path {
        return "";
    }
    memo = _native_arch_scope_memo.get(mod_path);
    if memo is not None {
        return memo;
    }
    source = os.path.realpath(mod_path);
    out = "";
    if not any(
        source.startswith(toolchain + os.sep) for toolchain in native_toolchain_roots()
    ) {
        stem = os.path.basename(source);
        dot = stem.find(".");
        if dot > 0 {
            stem = stem[:dot];
        }
        safe = "".join(
            ch if (ch.isascii() and (ch.isalnum() or ch == "_")) else "_" for ch in stem
        );
        ident = native_unit_identity(source);
        digest = hashlib.sha1(ident.encode()).hexdigest()[:8];
        out = f"{NATIVE_ARCH_SCOPE_SEP}{safe}_{digest}";
    }
    _native_arch_scope_memo[mod_path] = out;
    return out;
}

def native_arch_name(mod_path: str, name: str) -> str {
    if not name {
        return name;
    }
    return f"{name}{native_arch_scope(mod_path)}";
}

def native_unit_spelling(text: str, mod_path: str) -> str {
    import re;
    scope = native_arch_scope(mod_path) if NATIVE_ARCH_SCOPE_SEP in text else "";
    if not scope {
        return text;
    }
    return re.sub(re.escape(scope) + r"(?!\w)", "", text);
}

def native_arch_display(native_name: str) -> str {
    sep = native_name.find(NATIVE_ARCH_SCOPE_SEP);
    return native_name if sep < 0 else native_name[:sep];
}

def native_display_text(text: str) -> str {
    import re;
    if NATIVE_ARCH_SCOPE_SEP not in text {
        return text;
    }
    return re.sub(r"\$\w*?_[0-9a-f]{8}\b", "", text);
}

def native_toolchain_roots -> list[str] {
    import os;
    if _native_toolchain_roots {
        return _native_toolchain_roots;
    }
    import jaclang;
    if jaclang?.__file__ {
        _native_toolchain_roots.append(
            os.path.realpath(os.path.dirname(jaclang.__file__))
        );
    }
    return _native_toolchain_roots;
}

glob NATIVE_RESERVED_C_SYMBOLS: frozenset[str] = frozenset(
         [
             f"{base}{suffix}"
             for base in (
                 "acos asin atan atan2 cos sin tan acosh asinh atanh cosh sinh tanh exp exp2 "
                 "exp10 expm1 frexp ilogb ldexp log log10 log1p log2 logb modf scalbn scalbln "
                 "cbrt fabs hypot pow sqrt erf erfc lgamma tgamma ceil floor nearbyint rint "
                 "lrint llrint round lround llround trunc fmod remainder remquo copysign nan "
                 "nextafter nexttoward fdim fmax fmin fma sincos "
             ).split() for suffix in ("", "f", "l")
         ]
             + (
                 "isalnum isalpha isblank iscntrl isdigit isgraph islower isprint ispunct "
                 "isspace isupper isxdigit tolower toupper "
                 "feclearexcept fegetexceptflag feraiseexcept fesetexceptflag fetestexcept "
                 "fegetround fesetround fegetenv feholdexcept fesetenv feupdateenv "
                 "setlocale localeconv setjmp longjmp _setjmp _longjmp sigsetjmp siglongjmp "
                 "signal raise kill bsd_signal sigemptyset sigaddset sigismember "
                 "sigprocmask setitimer select "
                 "remove rename renameat tmpfile tmpnam fclose fflush fopen freopen fdopen "
                 "fileno setbuf setvbuf "
                 "fprintf fscanf printf scanf snprintf sprintf sscanf dprintf vfprintf "
                 "vfscanf vprintf vscanf vsnprintf vsprintf vsscanf "
                 "fgetc fgets fputc fputs getc getchar putc putchar puts ungetc fread fwrite "
                 "fgetpos fseek fseeko fsetpos ftell ftello rewind clearerr feof ferror "
                 "perror getline getdelim popen pclose "
                 "stdin stdout stderr __stdinp __stdoutp __stderrp "
                 "atof atoi atol atoll strtod strtof strtold strtol strtoll strtoul strtoull "
                 "rand srand "
                 "aligned_alloc calloc free malloc realloc posix_memalign malloc_size "
                 "malloc_usable_size "
                 "abort atexit at_quick_exit exit _exit _Exit quick_exit getenv setenv "
                 "unsetenv putenv system realpath mkstemp bsearch qsort "
                 "abs labs llabs div ldiv lldiv mblen mbtowc wctomb mbstowcs wcstombs "
                 "memcpy memmove memset memcmp memchr memmem memccpy strcpy strncpy stpcpy "
                 "stpncpy strcat strncat strcmp strncmp strcasecmp strncasecmp strcoll "
                 "strxfrm "
                 "strchr strrchr strcspn strpbrk strspn strstr strtok strtok_r strerror "
                 "strerror_r strlen strnlen strdup strndup bcmp bcopy bzero "
                 "clock difftime mktime time timespec_get asctime ctime gmtime gmtime_r "
                 "localtime localtime_r strftime clock_gettime clock_settime "
                 "clock_nanosleep nanosleep sleep usleep "
                 "open openat creat close read pread write lseek stat fstat lstat access "
                 "chmod chdir getcwd mkdir rmdir link symlink readlink unlink utime "
                 "pipe poll waitpid posix_spawnp posix_spawn_file_actions_init "
                 "posix_spawn_file_actions_destroy posix_spawn_file_actions_addopen "
                 "posix_spawn_file_actions_addclose posix_spawn_file_actions_adddup2 "
                 "posix_spawn_file_actions_addchdir_np "
                 "opendir readdir closedir getpid getpwuid_r getpwnam_r errno __error "
                 "__errno_location environ _NSGetExecutablePath "
                 "pthread_create pthread_join pthread_key_create pthread_getspecific "
                 "pthread_setspecific "
                 "socket connect send recv shutdown getaddrinfo freeaddrinfo gai_strerror "
                 "dlopen dlsym dlclose dlerror "
                 "main _start __libc_start_main __getmainargs mainCRTStartup "
                 "compress2 uncompress uncompress2 compressBound crc32_z adler32_z "
                 "inflateInit2_ inflate inflateEnd zlibVersion "
                 "BZ2_bzBuffToBuffCompress BZ2_bzBuffToBuffDecompress "
                 "ZSTD_isError ZSTD_getErrorName ZSTD_compressBound ZSTD_freeCCtx "
                 "ZSTD_CCtx_setParameter ZSTD_compress2 ZSTD_freeDCtx ZSTD_DCtx_setParameter "
                 "ZSTD_decompressStream_simpleArgs ZSTD_getFrameContentSize "
                 "ZSTD_getDictID_fromFrame "
                 "RAND_bytes EVP_MD_CTX_free EVP_DigestInit_ex EVP_DigestUpdate "
                 "EVP_DigestFinal_ex HMAC_CTX_free HMAC_Init_ex HMAC_Update HMAC_Final "
                 "SSL_CTX_new SSL_CTX_set_verify SSL_CTX_load_verify_locations "
                 "SSL_CTX_set_default_verify_paths SSL_CTX_free SSL_new SSL_set_fd SSL_ctrl "
                 "SSL_set1_host SSL_connect SSL_get_verify_result SSL_get_error SSL_read "
                 "SSL_write SSL_shutdown SSL_free X509_verify_cert_error_string "
                 "ERR_reason_error_string "
                 "Py_DecRef PyBool_FromLong PyBytes_AsString PyDict_New PyDict_SetItemString "
                 "PyErr_Print PyFloat_AsDouble PyFloat_FromDouble PyGILState_Ensure "
                 "PyGILState_Release PyImport_ImportModule PyLong_AsLongLong "
                 "PyLong_FromLongLong PyObject_Call PyObject_GetAttrString PyObject_IsTrue "
                 "PyObject_SetAttrString PyTuple_New PyTuple_SetItem PyUnicode_AsUTF8String "
                 "PyUnicode_FromString "
                 "__mt_genrand_u32 __mt_getrandbits __mt_init_by_array __mt_randbelow "
                 "GC_malloc "
                 "__connect "
                 "sqlite3_open sqlite3_open_v2 sqlite3_close sqlite3_prepare_v2 "
                 "sqlite3_step sqlite3_reset sqlite3_finalize sqlite3_clear_bindings "
                 "sqlite3_column_count sqlite3_column_type sqlite3_column_int64 "
                 "sqlite3_column_double sqlite3_column_blob sqlite3_column_text "
                 "sqlite3_column_bytes sqlite3_column_name sqlite3_errmsg "
                 "sqlite3_errcode sqlite3_extended_errcode sqlite3_exec "
                 "sqlite3_changes64 sqlite3_total_changes64 sqlite3_last_insert_rowid "
                 "sqlite3_get_autocommit sqlite3_busy_timeout sqlite3_libversion "
                 "sqlite3_complete sqlite3_bind_parameter_count "
                 "sqlite3_bind_parameter_name sqlite3_bind_null sqlite3_bind_int64 "
                 "sqlite3_bind_double sqlite3_bind_text sqlite3_bind_blob "
                 "sqlite3_stmt_readonly sqlite3_free "
             ).split()
     );

def native_def_symbol(name: str) -> str {
    return f"__jac_def_{name}" if name in NATIVE_RESERVED_C_SYMBOLS else name;
}

def module_dotted_name(mod_path: str, mod_name: str = "") -> str {
    import os;
    path = mod_path.replace("\\", "/");
    if not path {
        return mod_name;
    }
    idx = path.rfind("/jaclang/");
    stem = path[idx + 1:] if idx >= 0 else os.path.basename(path);
    for ext in (".impl.jac", ".test.jac", ".jac", ".py") {
        if stem.endswith(ext) {
            stem = stem[:-len(ext)];
            break;
        }
    }
    if stem.endswith("/__init__") {
        stem = stem[:-len("/__init__")];
    }
    return stem.replace("/", ".");
}

def native_unit_root(directory: str) -> (str | None) {
    import os;
    d = directory;
    while True {
        if os.path.isdir(os.path.join(d, "_precompiled"))
            or os.path.isfile(os.path.join(d, "jac.toml"))
            or (
                os.path.isfile(os.path.join(d, "jac0.py"))
                and os.path.isfile(os.path.join(d, "__init__.py"))
            ) {
            return d;
        }
        parent = os.path.dirname(d);
        if parent == d or not parent {
            return None;
        }
        d = parent;
    }
}

def native_unit_identity(path: str) -> str {
    import os;
    rp = os.path.realpath(path);
    unit_root = native_unit_root(os.path.dirname(rp));
    if unit_root is None {
        return rp;
    }
    rel = os.path.relpath(rp, unit_root).replace("\\", "/");
    return f"{os.path.basename(unit_root)}/{rel}";
}

def native_unit_ref(path: str) -> str {
    """How one unit names another in what it writes to disk: by package
    identity when the other lives under a root, so the reference survives
    the package moving, and by real path otherwise.""";
    import os;
    rp = os.path.realpath(path);
    ident = native_unit_identity(rp);
    return ident if ident != rp else rp;
}

def resolve_native_unit_ref(ref: str, anchor: str = "") -> str {
    """The path a unit reference names here: an absolute path is itself;
    `jaclang/...` is under this process's jaclang; another root's identity
    is looked for as the anchor unit's own root, beside it, then under each
    import path. A reference found nowhere names a path that cannot exist,
    never one relative to the working directory, so its unit reads as
    missing and is rebuilt.""";
    import os;
    if not ref or os.path.isabs(ref) {
        return ref;
    }
    (root_name, _sep, rel) = ref.partition("/");
    if not rel {
        return ref;
    }
    if root_name == "jaclang" {
        return os.path.join(os.path.dirname(jaclang_pkg_root()), ref);
    }
    if anchor {
        anchor_root = native_unit_root(os.path.dirname(os.path.realpath(anchor)));
        if anchor_root is not None {
            if os.path.basename(anchor_root) == root_name {
                return os.path.join(anchor_root, rel);
            }
            sibling = os.path.join(os.path.dirname(anchor_root), ref);
            if os.path.isfile(sibling) {
                return sibling;
            }
        }
    }
    import sys;
    for search_dir in sys.path {
        if search_dir and os.path.isabs(search_dir) {
            candidate = os.path.join(search_dir, ref);
            if os.path.isfile(candidate) {
                return candidate;
            }
        }
    }
    return os.path.join(os.path.abspath(os.sep), "<unresolved native unit>", ref);
}

def native_module_key(path: str) -> str {
    """The key names a unit the same wherever its package lands: a module
    under a sealed package, a `jac.toml` project or the jaclang package is
    keyed by its path within that root, so the symbols a sealed unit
    defines at build time are the ones consumers reference at run time.""";
    import os;
    rp = os.path.realpath(path);
    base = os.path.basename(rp);
    dot = base.rfind(".");
    stem = base[0:dot] if dot > 0 else base;
    ident = native_unit_identity(rp);
    return f"{stem}:{hashlib.sha1(ident.encode()).hexdigest()[:12]}";
}

def native_unit_prefix(path: str) -> str {
    return native_safe_sym(native_module_key(path));
}

def native_symbol_name(prefix: str, name: str) -> str {
    return f"{prefix}.{name}";
}

def native_glob_init_name(path: str) -> str {
    return f"__jac_glob_init_{native_unit_prefix(path)}";
}

def native_entry_name(path: str) -> str {
    return f"__jac_entry_{native_unit_prefix(path)}";
}

def native_runtime_probe_name(path: str) -> str {
    return f"__jac_rt_probe_{native_unit_prefix(path)}";
}

def native_test_symbol(name: str, line: int, prefix: str = "") -> str {
    bare = f"__jac_test_{name}_{line}";
    return native_symbol_name(prefix, bare) if prefix else bare;
}

glob JAC_ENTRY_SYMBOL: str = "jac_entry",
     JAC_SHARED_INIT_SYMBOL: str = "__jac_shared_init";

def install_native_static_init(engine: any, init_symbols: list[str]) -> None {
    if engine is None {
        return;
    }
    engine.static_init_symbols = list(init_symbols);
    engine.static_init_chained = {JAC_ENTRY_SYMBOL};
}

glob KERNEL_UNIT_REL: tuple[str, ...] = (
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac",
         "runtime/region_native.jac",
         "compiler/backends/common/fmt_kernel.jac"
     ),
     OSP_KERNEL_REL: str = "runtime/osp_kernel.jac",
     OSP_GRAPH_REL: str = "runtime/osp_graph.jac",
     REGION_KERNEL_REL: str = "runtime/region_native.jac",
     FMT_KERNEL_REL: str = "compiler/backends/common/fmt_kernel.jac";

def jaclang_pkg_root -> str {
    import os;
    import jaclang;
    return os.path.dirname(os.path.abspath(str(jaclang.__file__)));
}

def kernel_unit_path(rel: str) -> str {
    import os;
    return os.path.join(jaclang_pkg_root(), rel.replace("/", os.sep));
}

def kernel_unit_paths -> list[str] {
    return [kernel_unit_path(rel) for rel in KERNEL_UNIT_REL];
}

def is_kernel_unit_path(path: str) -> bool {
    import os;
    if not path {
        return False;
    }
    rp = os.path.realpath(path);
    for rel in KERNEL_UNIT_REL {
        if rp == os.path.realpath(kernel_unit_path(rel)) {
            return True;
        }
    }
    return False;
}

glob NATIVE_STDLIB_EXTENSIONS: dict[str, str] = {"os": "_os_native"},
     NOGC_NATIVE_STDLIB: set[str] = {
         "time",
         "_time_native",
         "_time_common",
         "_errno_native",
         "_errno_platform"
     };

glob NATIVE_SUPPORTED_STDLIB: set[str] = {
         "sys",
         "os",
         "random",
         "struct",
         "enum",
         "collections.abc"
     },
     _effective_codespace_ctx: ContextVar[str] = ContextVar(
         "jac_effective_default_codespace"
     ),
     _closure_cap_ctx: ContextVar[int] = ContextVar("jac_native_closure_cap"),
     _native_unit_ctx: ContextVar[bool] = ContextVar("jac_native_unit_compile"),
     _native_target_ctx: ContextVar[str | None] = ContextVar("jac_native_target");

glob NATIVE_ERASED_ABC_BASES: frozenset = frozenset({"ABC"});

glob NATIVE_ERASED_BASES: frozenset = NATIVE_ERASED_ABC_BASES;

glob NATIVE_ERASED_IDENTITY_CALLS: frozenset = frozenset({"cast"});

glob NATIVE_ERASED_FIELD_MARKERS: frozenset = frozenset({"ObjectField"});

glob NATIVE_ERASED_IMPORTS: dict[str, frozenset] = {
         "abc": NATIVE_ERASED_ABC_BASES,
         "jaclang.runtime.object_model": NATIVE_ERASED_FIELD_MARKERS,
         "typing": TYPE_PARAM_CONSTRUCTORS
             | NATIVE_ERASED_IDENTITY_CALLS
             | NATIVE_ERASED_TYPE_MARKERS
             | NATIVE_ERASED_ANNOTATIONS
     };

def native_erased_import_names(module_name: str, names: list[str]) -> bool {
    allowed = NATIVE_ERASED_IMPORTS.get(module_name.lstrip('.'));
    if allowed is None or not names {
        return False;
    }
    for n in names {
        if n not in allowed {
            return False;
        }
    }
    return True;
}

def set_effective_default_codespace(value: str) {
    _effective_codespace_ctx.set(value);
}

def get_effective_default_codespace_override -> str {
    return _effective_codespace_ctx.get('');
}

def effective_default_codespace -> str {
    cur = _effective_codespace_ctx.get('');
    if cur {
        return cur;
    }
    try {
        import from jaclang.project.config { get_config, PlacementConfig }
        cfg = get_config();
        if cfg is not None {
            return cfg.placement.default_codespace;
        }
        return PlacementConfig().default_codespace;
    } except Exception {
        return "server";
    }
}

def set_native_unit_compile(value: bool) -> bool {
    prev = _native_unit_ctx.get(False);
    _native_unit_ctx.set(value);
    return prev;
}

def reset_native_unit_compile(prev: bool) {
    _native_unit_ctx.set(prev);
}

def native_unit_compile_active -> bool {
    return _native_unit_ctx.get(False);
}

def set_native_closure_cap(value: int) {
    _closure_cap_ctx.set(value);
}

def get_native_closure_cap_override -> int {
    return _closure_cap_ctx.get(0);
}

def effective_native_closure_cap -> int {
    cur = _closure_cap_ctx.get(0);
    if cur > 0 {
        return cur;
    }
    try {
        import from jaclang.project.config { get_config, BuildConfig }
        cfg = get_config();
        if cfg is not None {
            return cfg.build.native_closure_cap;
        }
        return BuildConfig().native_closure_cap;
    } except Exception {
        return 256;
    }
}

def _jaclang_pkg_dir -> (str | None) {
    import os;
    import jaclang;
    if not jaclang?.__file__ {
        return None;
    }
    return os.path.dirname(os.path.abspath(str(jaclang.__file__)));
}

def native_stdlib_root -> (str | None) {
    import os;
    pkg = _jaclang_pkg_dir();
    if pkg is None {
        return None;
    }
    stdlib_dir = os.path.join(pkg, "runtime", "na_stdlib");
    return stdlib_dir if os.path.isdir(stdlib_dir) else None;
}

def is_in_jaclang_package(file_path: str) -> bool {
    import os;
    pkg = _jaclang_pkg_dir();
    if not file_path or pkg is None {
        return False;
    }
    return os.path.abspath(file_path).startswith(pkg + os.sep);
}

def bundled_native_module_names -> list[str] {
    import os;
    stdlib_root = native_stdlib_root();
    if stdlib_root is None {
        return [];
    }
    names: set[str] = set();
    for item in os.listdir(stdlib_root) {
        if item.startswith("_") or item.startswith(".") {
            continue;
        }
        if os.path.isdir(os.path.join(stdlib_root, item)) {
            names.add(item);
        } elif item.endswith(".jac") {
            names.add(item.split(".")[0]);
        }
    }
    return sorted(names);
}

def is_native_by_location(file_path: str) -> bool {
    import os;
    pkg = _jaclang_pkg_dir();
    if not file_path or pkg is None {
        return False;
    }
    ap = os.path.abspath(file_path);
    return ap.startswith(os.path.join(pkg, "runtime", "na_stdlib") + os.sep);
}

def bundled_stdlib_module_of(file_path: str) -> (str | None) {
    import os;
    pkg = _jaclang_pkg_dir();
    if not file_path or pkg is None {
        return None;
    }
    ap = os.path.abspath(file_path);
    native_root = os.path.join(pkg, "runtime", "na_stdlib") + os.sep;
    stub_root = os.path.join(pkg, "vendor", "typeshed", "stdlib") + os.sep;
    if ap.startswith(native_root) and ap.endswith(".jac") {
        rel = ap[len(native_root):-len(".jac")];
        parts = rel.split(os.sep);

        parts[-1] = parts[-1].split(".")[0];
        return ".".join(parts);
    }
    if ap.startswith(stub_root) and ap.endswith(".pyi") {
        rel = ap[len(stub_root):-len(".pyi")];
        parts = rel.split(os.sep);
        if parts[-1] == "__init__" {
            parts = parts[:-1];
        }
        return ".".join(parts) if parts else None;
    }
    return None;
}

glob SHARED_RUNTIME_MODULES: tuple[str, ...] = (
         "jaclang.runtime.graph_fragment",

     ),
     CLIENT_RUNTIME_SOURCE_PATHS: list[str] = [
         "client/client_runtime.jac",
         "client/client_runtime_core.jac",
         "client/solid_runtime.jac",
         "client/pwa_runtime.jac",
         "client/wasm_host.jac",
         "client/webgl.jac",
         "client/endpoint_cache.jac",
         "client/auth_contract.jac",
         "client/client_mobui.jac",
         "client/client_react_core.jac",
         "client/client_runtime_native.jac",
         "client/targets/desktop/plugin/desktop_api.jac"
     ];


def is_client_by_location(file_path: str) -> bool {
    import os;
    pkg = _jaclang_pkg_dir();
    if not file_path or pkg is None {
        return False;
    }
    ap = os.path.abspath(file_path);
    for rel in CLIENT_RUNTIME_SOURCE_PATHS {
        if ap == os.path.join(pkg, rel.replace("/", os.sep)) {
            return True;
        }
    }
    return False;
}

def is_shared_runtime_module(file_path: str) -> bool {
    import os;
    import jaclang;
    if not file_path or not jaclang?.__file__ {
        return False;
    }
    package = os.path.dirname(os.path.realpath(str(jaclang.__file__)));
    path = os.path.realpath(file_path);
    return any(
        path == os.path.join(package, *module.split('.')[1:]) + '.jac'
        for module in SHARED_RUNTIME_MODULES
    );
}

def is_bundled_native_module(module_name: str) -> bool {
    import os;
    stdlib_dir = native_stdlib_root();
    if stdlib_dir is None or not module_name {
        return False;
    }
    clean = module_name.lstrip('.');
    path_name = NATIVE_STDLIB_EXTENSIONS.get(clean, clean).replace('.', os.sep);
    return _native_variant_path(os.path.join(stdlib_dir, path_name)) is not None;
}

def set_native_target_override(triple: str | None) -> (str | None) {
    prev = _native_target_ctx.get(None);
    _native_target_ctx.set(triple);
    return prev;
}

def effective_native_target -> str {
    cur = _native_target_ctx.get(None);
    if cur is not None {
        return cur;
    }
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        return cfg.native.target if cfg is not None else "";
    } except Exception {
        return "";
    }
}

def native_target_os -> str {
    import sys;
    _t = effective_native_target();
    if _t {
        if ("darwin" in _t) or ("apple" in _t) {
            return "darwin";
        }
        if ("windows" in _t) or ("msvc" in _t) {
            return "windows";
        }
        return "linux";
    }
    _s = sys.platform;
    if _s == "darwin" {
        return "darwin";
    }
    if _s == "win32" {
        return "windows";
    }
    return "linux";
}

def native_target_arch -> str {
    import platform;
    _t = effective_native_target();
    machine = (_t.split("-")[0] if _t else platform.machine()).lower();
    if machine in ("arm64", "aarch64") or machine.startswith("arm64") {
        return "aarch64";
    }
    if machine in ("x86_64", "amd64", "x64") {
        return "x86_64";
    }
    return machine;
}

def _native_variant_path(base_no_ext: str) -> (str | None) {
    import os;
    _archv = f"{base_no_ext}.{native_target_arch()}.jac";
    if os.path.exists(_archv) {
        return _archv;
    }
    _osv = os.path.join(f"{base_no_ext}.{native_target_os()}.jac");
    if os.path.exists(_osv) {
        return _osv;
    }
    _plain = f"{base_no_ext}.jac";
    if os.path.exists(_plain) {
        return _plain;
    }
    return None;
}

def _inferred_native_path(candidate: (str | None)) -> (str | None) {
    if candidate is None {
        return None;
    }
    import from jaclang.compiler.native_scope { scope_allows_inferred_path }
    if not scope_allows_inferred_path(candidate) {
        return None;
    }
    import from jaclang.compiler.placement.placement_solver { native_default_path_ok }
    return candidate if native_default_path_ok(candidate) else None;
}

def resolve_native_module(
    module_name: str, base_dir: str, allow_inferred: bool = True
) -> tuple[(str | None, str | None)] {
    import os;
    clean = module_name.lstrip('.');
    path_name = clean.replace('.', os.sep);

    if module_name == clean and clean.startswith('jaclang.') {
        runtime_rel = clean[len('jaclang.'):].replace('.', '/') + '.jac';
        if runtime_rel in KERNEL_UNIT_REL {
            runtime_path = kernel_unit_path(runtime_rel);
            if os.path.isfile(runtime_path) {
                return (path_name, runtime_path);
            }
        }
    }

    level = len(module_name) - len(clean);
    if level > 0 {
        if not allow_inferred {
            return (None, None);
        }
        search = os.path.abspath(base_dir);
        for _ in range(level - 1) {
            search = os.path.dirname(search);
        }
        candidate = os.path.join(search, path_name);
        if os.path.isdir(candidate) {
            candidate = os.path.join(candidate, '__init__');
        }
        local = _inferred_native_path(_native_variant_path(candidate));
        if local is not None {
            return (str(os.path.relpath(local, os.path.abspath(base_dir))), local);
        }
        return (None, None);
    }

    if clean.startswith('jaclang.') {
        import from jaclang.project.modresolver { resolve_module }
        import from jaclang.compiler.native_scope { in_native_scope_path }
        (candidate, language) = resolve_module(clean, os.path.join(base_dir, ""));
        if language != 'jac' or not candidate.endswith('.jac') {
            return (None, None);
        }
        candidate = os.path.realpath(candidate);
        if (native_unit_compile_active() and in_native_scope_path(candidate))
            or clean in SHARED_RUNTIME_MODULES {
            return (candidate, candidate);
        }
        if allow_inferred {
            search = os.path.abspath(base_dir);
            while True {
                local = _native_variant_path(os.path.join(search, path_name));
                if local is not None {
                    native = _inferred_native_path(candidate);
                    return (native, native);
                }
                parent = os.path.dirname(search);
                if parent == search {
                    break;
                }
                search = parent;
            }
        }
    }

    if allow_inferred {
        local = _inferred_native_path(
            _native_variant_path(os.path.join(base_dir, clean))
        );
        if local is not None {
            return (str(os.path.relpath(local, os.path.abspath(base_dir))), local);
        }
        if path_name != clean {
            search = os.path.abspath(base_dir);
            while True {
                cand = _inferred_native_path(
                    _native_variant_path(os.path.join(search, path_name))
                );
                if cand is not None {
                    rel = str(os.path.relpath(cand, os.path.abspath(base_dir)));
                    return (rel, cand);
                }
                parent = os.path.dirname(search);
                if parent == search {
                    break;
                }
                search = parent;
            }
        }
    }

    if clean.startswith('jaclang.') {
        import from jaclang.compiler.native_scope { in_native_scope_path }
        _parts = clean.split('.')[1:];
        _cand = os.path.join(jaclang_pkg_root(), *_parts) + '.jac';
        if native_unit_compile_active() {
            if in_native_scope_path(_cand) and os.path.isfile(_cand) {
                return (path_name, _cand);
            }
        }
        if clean in SHARED_RUNTIME_MODULES and os.path.isfile(_cand) {
            return (path_name, _cand);
        }
    }

    bundled_root = native_stdlib_root();
    if bundled_root is not None {
        bundled_name = NATIVE_STDLIB_EXTENSIONS.get(clean, path_name);
        bundled = _native_variant_path(os.path.join(bundled_root, bundled_name));
        if bundled is not None {
            return (path_name, bundled);
        }
    }
    return (None, None);
}

def native_wasm_stem(path: str) -> str {
    import os;
    stem = os.path.splitext(os.path.basename(path))[0];
    for marker in ('.cl', ) {
        if stem.endswith(marker) {
            stem = stem[0:-len(marker)];
        }
    }
    return stem;
}

glob NATIVE_ABI_VERSION: int = 1;

obj NativeModuleLayout {
    has abi_version: int = NATIVE_ABI_VERSION,
        structs: dict[(str, NativeStructLayout)] = {},
        enums: dict[(str, NativeEnumLayout)] = {},
        functions: dict[(str, NativeFuncLayout)] = {},
        methods: dict[(str, NativeFuncLayout)] = {},
        list_elem_types: dict[(str, str)] = {},
        tuples: dict[(str, NativeTupleLayout)] = {},
        tests: list[NativeTestLayout] = [],
        str_headerless: (bool | None) = None;
}

def _tuple_layout_to_dict(t: (NativeTupleLayout | None)) -> (dict[str, any] | None) {
    if t is None {
        return None;
    }
    return {
        "key": t.key,
        "element_types": list(t.element_types),
        "element_struct_hints": list(t.element_struct_hints)
    };
}

def _func_layout_to_dict(f: NativeFuncLayout) -> dict[str, any] {
    return {
        "name": f.name,
        "param_types": list(f.param_types),
        "param_names": list(f.param_names),
        "ret_type": f.ret_type,
        "ret_struct_name": f.ret_struct_name,
        "ret_tuple_layout": _tuple_layout_to_dict(f.ret_tuple_layout),
        "ret_enum_type": f.ret_enum_type,
        "ret_elem_keys": (
            list(f.ret_elem_keys) if f.ret_elem_keys is not None else None
        )
    };
}

def native_layout_to_dict(layout: NativeModuleLayout) -> dict[str, any] {
    return {
        "abi_version": layout.abi_version,
        "structs": {
            name: {
                "name": s.name,
                "has_vtable": s.has_vtable,
                "accessors": {
                    fname: dict[str, str](kinds)
                    for (fname, kinds) in s.accessors.items()
                },
                "fields": [
                    {
                        "name": fld.name,
                        "llvm_type": fld.llvm_type,
                        "index": fld.index,
                        "enum_type": fld.enum_type,
                        "is_func_ptr": fld.is_func_ptr,
                        "func_param_types": (
                            list(fld.func_param_types)
                                if fld.func_param_types is not None
                                else None
                        ),
                        "func_ret_type": fld.func_ret_type,
                        "elem_keys": (
                            list(fld.elem_keys) if fld.elem_keys is not None else None
                        ),
                        "foreign": fld.foreign
                    } for fld in s.fields
                ]
            } for (name, s) in layout.structs.items()
        },
        "enums": {
            name: {
                "name": e.name,
                "is_string_valued": e.is_string_valued,
                "members": list(e.members)
            } for (name, e) in layout.enums.items()
        },
        "functions": {
            name: _func_layout_to_dict(f) for (name, f) in layout.functions.items()
        },
        "methods": {
            name: _func_layout_to_dict(f) for (name, f) in layout.methods.items()
        },
        "list_elem_types": dict(layout.list_elem_types),
        "tuples": {key: _tuple_layout_to_dict(t) for (key, t) in layout.tuples.items()},
        "str_headerless": layout.str_headerless
    };
}

def _tuple_layout_from_dict(raw: any) -> (NativeTupleLayout | None) {
    if not isinstance(raw, dict) {
        return None;
    }
    d: dict[str, any] = raw;
    return NativeTupleLayout(
        key=str(d.get("key", "")),
        element_types=[str(x) for x in (d.get("element_types") or [])],
        element_struct_hints=list(d.get("element_struct_hints") or [])
    );
}

def _func_layout_from_dict(raw: any) -> NativeFuncLayout {
    d: dict[str, any] = raw;
    keys: any = d.get("ret_elem_keys");
    return NativeFuncLayout(
        name=str(d.get("name", "")),
        param_types=[str(x) for x in (d.get("param_types") or [])],
        param_names=[str(x) for x in (d.get("param_names") or [])],
        ret_type=str(d.get("ret_type", "i64")),
        ret_struct_name=d.get("ret_struct_name"),
        ret_tuple_layout=_tuple_layout_from_dict(d.get("ret_tuple_layout")),
        ret_enum_type=d.get("ret_enum_type"),
        ret_elem_keys=list(keys) if keys is not None else None
    );
}

def _field_info_from_dict(raw: any) -> NativeFieldInfo {
    fd: dict[str, any] = raw;
    fpt: any = fd.get("func_param_types");
    ek: any = fd.get("elem_keys");
    return NativeFieldInfo(
        name=str(fd.get("name", "")),
        llvm_type=str(fd.get("llvm_type", "i64")),
        index=int(fd.get("index", 0)),
        enum_type=fd.get("enum_type"),
        is_func_ptr=bool(fd.get("is_func_ptr", False)),
        func_param_types=list(fpt) if fpt is not None else None,
        func_ret_type=fd.get("func_ret_type"),
        elem_keys=list(ek) if ek is not None else None,
        foreign=bool(fd.get("foreign", False))
    );
}

def native_layout_from_dict(raw: any) -> NativeModuleLayout {
    d: dict[str, any] = raw;
    layout = NativeModuleLayout(
        abi_version=int(d.get("abi_version", NATIVE_ABI_VERSION)),
        str_headerless=d.get("str_headerless")
    );
    structs: dict[str, any] = d.get("structs") or {};
    for (name, sraw) in structs.items() {
        sd: dict[str, any] = sraw;
        fields: list[NativeFieldInfo] = [];
        for fd in (sd.get("fields") or []) {
            fields.append(_field_info_from_dict(fd));
        }
        accessors: dict[str, dict[str, str]] = {};
        raw_acc: dict[str, any] = sd.get("accessors") or {};
        for (fn_name, kinds) in raw_acc.items() {
            kind_map: dict[str, any] = kinds;
            accessors[str(fn_name)] = {str(k): str(v) for (k, v) in kind_map.items()};
        }
        layout.structs[str(name)] = NativeStructLayout(
            name=str(sd.get("name", name)),
            fields=fields,
            has_vtable=bool(sd.get("has_vtable", False)),
            accessors=accessors
        );
    }
    enums: dict[str, any] = d.get("enums") or {};
    for (name, eraw) in enums.items() {
        ed: dict[str, any] = eraw;
        layout.enums[str(name)] = NativeEnumLayout(
            name=str(ed.get("name", name)),
            is_string_valued=bool(ed.get("is_string_valued", False)),
            members=list(ed.get("members") or [])
        );
    }
    functions: dict[str, any] = d.get("functions") or {};
    for (name, fraw) in functions.items() {
        layout.functions[str(name)] = _func_layout_from_dict(fraw);
    }
    methods: dict[str, any] = d.get("methods") or {};
    for (name, mraw) in methods.items() {
        layout.methods[str(name)] = _func_layout_from_dict(mraw);
    }
    elem_types: dict[str, any] = d.get("list_elem_types") or {};
    layout.list_elem_types = {str(k): str(v) for (k, v) in elem_types.items()};
    tuples: dict[str, any] = d.get("tuples") or {};
    for (key, traw) in tuples.items() {
        t = _tuple_layout_from_dict(traw);
        if t is not None {
            layout.tuples[str(key)] = t;
        }
    }
    return layout;
}

obj BoundaryTypeInfo {
    has name: str,
        kind: str,
        type_id: str = '',
        type_scope: str = '',
        fields: list[tuple[(str, str)]] = [],
        field_defaults: dict[(str, any)] = {},
        enum_members: list[tuple[(str, any)]] = [],
        nested_types: list[str] = [];
}


obj InteropBinding {
    has name: str,
        source_context: InteropContext,
        callers: set[InteropContext] = set(),
        ret_type: str = 'int',
        param_types: list[str] = [],
        param_names: list[str] = [],
        ast_node: any = None,
        source_module: (str | None) = None,
        type_scope: str = '',
        kind: str = 'function',
        provider_app: str = '',
        native_contract: dict[str, any] = {},
        endpoint_id: str = '';

    has is_cross_module: bool { getter; }
}

obj InteropManifest {
    has native_host_imports: dict[str, dict[str, any]] = {},
        bindings: dict[(str, InteropBinding)] = {},
        boundary_types: dict[(str, BoundaryTypeInfo)] = {},
        boundary_type_names: dict[str, dict[str, str]] = {},
        endpoint_effects: dict[(str, dict[str, any])] = {},
        surface: dict[(str, SurfaceEntry)] = {},
        app_edges: list[tuple[(str, str)]] = [],
        provider_routes: dict[(str, str)] = {};

    has native_imports: list[InteropBinding] { getter; }
    has native_exports: list[InteropBinding] { getter; }
    has native_cross_module_imports: list[InteropBinding] { getter; }
    has client_native_imports: list[InteropBinding] { getter; }
    has server_exports_to_client: list[InteropBinding] { getter; }
    has server_exports_to_server: list[InteropBinding] { getter; }

    def boundary_types_for(scope: str) -> dict[str, BoundaryTypeInfo];
}

obj NodeComments {
    has leading: list[CommentToken] = [],
        trailing_inline: list[CommentToken] = [],
        trailing_own: list[CommentToken] = [],
        indent_trailing_own: bool = False;
}

obj CodeGenTarget {
    has _py: (str | None) = None,
        jac: str = '',
        _doc_ir: (Doc | None) = None,
        js: str = '',
        css: str = '',
        _client_manifest: (ClientManifest | None) = None,
        py_ast: list[any] = [],
        py_bytecode: (bytes | None) = None,
        jcir: (bytes | None) = None,
        es_ast: EsNode | Sequence[EsNode] | SliceInfo | IndexInfo | None = None,
        llvm_ir: (ModuleRef | IRModule | None) = None,
        native_engine: (ExecutionEngine | SharedNativeEngine | None) = None,
        native_bitcode: (bytes | None) = None,
        native_object: (bytes | None) = None,
        native_iface: (NativeIface | None) = None,
        native_deps: list[str] = [],
        _interop_manifest: (InteropManifest | None) = None,
        interop_py_funcs: dict[(str, any)] = {},
        _interop_callbacks: list[any] = [],
        native_layout: (NativeModuleLayout | None) = None,
        osp_model: (OspModel | None) = None,
        native_osp_model: (OspModel | None) = None,
        component_call_abi: str = "",
        jc_layout: (str | None) = None,
        has_root_access: (bool | None) = None,
        nogc_enforced: bool = False,
        nogc_provenance: str = '',
        layout_registry: any = None,
        _clib_paths: list[str] = [],
        _clib_symbol_lib: dict[(str, str)] = {},
        _exported_symbols: list[str] = [],
        doc_comments: (NodeComments | None) = None;

    has py: str { getter; setter(value: str); }
    has doc_ir: Doc { getter; setter(value: Doc); }
    has client_manifest: ClientManifest { getter; setter(value: ClientManifest); }
    has interop_manifest: InteropManifest { getter; setter(value: InteropManifest); }
}

def endpoint_descriptor(module: any, kind: str, name: str) -> dict[str, str] {
    import os;
    import from jaclang.project.workspace { workspace_for_path }
    path = module.loc.mod_path;
    workspace = workspace_for_path(path);
    owner = workspace.app_for_path(path) if workspace else None;
    app = owner.name if owner is not None else "";
    source = os.path.relpath(path, workspace.project_root)
        if workspace
        else module.name;
    source = source.replace(os.sep, "/");
    return {"app": app, "module": source, "kind": kind, "name": name};
}

def endpoint_key(module: any, kind: str, name: str) -> str {
    import json;
    d = endpoint_descriptor(module, kind, name);
    return "["
        + ",".join([json.dumps(part) for part in [d["app"], d["module"], kind, name]])
        + "]";
}
