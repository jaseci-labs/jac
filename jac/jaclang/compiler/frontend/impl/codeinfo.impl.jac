impl InteropBinding.is_cross_module.getter -> bool {
    return (self.source_module is not None);
}

impl InteropBinding.native_callable.getter -> bool {
    return self.source_context == InteropContext.SERVER
        and InteropContext.NATIVE in self.callers
        and self.kind == 'function'
        and bool(self.symbol);
}

impl InteropManifest.boundary_types_for(scope: str) -> dict[str, BoundaryTypeInfo] {
    return {
        name: self.boundary_types[type_id]
        for (name, type_id) in self.boundary_type_names.get(scope, {}).items()
    };
}

impl InteropManifest.native_imports.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.SERVER)
            and (InteropContext.NATIVE in b.callers)
        )
    ];
}

impl InteropManifest.callable_native_imports.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if b.native_callable
    ];
}

impl InteropManifest.native_exports.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.NATIVE)
            and (InteropContext.SERVER in b.callers)
        )
    ];
}

impl InteropManifest.native_cross_module_imports.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.NATIVE)
            and (InteropContext.NATIVE in b.callers)
            and (b.source_module is not None)
        )
    ];
}

impl InteropManifest.client_native_imports.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.NATIVE)
            and (InteropContext.CLIENT in b.callers)
        )
    ];
}

impl InteropManifest.server_exports_to_client.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.SERVER)
            and (InteropContext.CLIENT in b.callers)
        )
    ];
}

impl InteropManifest.server_exports_to_server.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.SERVER)
            and (InteropContext.SERVER in b.callers)
            and (b.source_module is not None)
        )
    ];
}

impl CodeGenTarget.doc_ir.getter -> Doc {
    if (self._doc_ir is None) {
        import jaclang.compiler.tools.doc_ir as doc;
        self._doc_ir = doc.Text('');
    }
    return self._doc_ir;
}

impl CodeGenTarget.doc_ir.setter(value: Doc) {
    self._doc_ir = value;
}

impl CodeGenTarget.client_manifest.getter -> ClientManifest {
    if (self._client_manifest is None) {
        self._client_manifest = ClientManifest();
    }
    return self._client_manifest;
}

impl CodeGenTarget.client_manifest.setter(value: ClientManifest) -> None {
    self._client_manifest = value;
}

impl CodeGenTarget.interop_manifest.getter -> InteropManifest {
    if (self._interop_manifest is None) {
        self._interop_manifest = InteropManifest();
    }
    return self._interop_manifest;
}

impl CodeGenTarget.interop_manifest.setter(value: InteropManifest) -> None {
    self._interop_manifest = value;
}

impl str_len_tag(length: int, is_ascii: bool = False) -> int {
    return (
        (length << STR_LEN_TAG_SHIFT)
        | (STR_ASCII_TAG_BIT if is_ascii else 0)
        | STR_LEN_TAG_BIT
    );
}

impl native_safe_sym(src: str) -> str {
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

impl _reserved_c_symbols -> frozenset[str] {
    names: set[str] = set();
    for base in (
        "acos asin atan atan2 cos sin tan acosh asinh atanh cosh sinh tanh exp exp2 "
        "exp10 expm1 frexp ilogb ldexp log log10 log1p log2 logb modf scalbn scalbln "
        "cbrt fabs hypot pow sqrt erf erfc lgamma tgamma ceil floor nearbyint rint "
        "lrint llrint round lround llround trunc fmod remainder remquo copysign nan "
        "nextafter nexttoward fdim fmax fmin fma sincos "
    ).split() {
        for suffix in ("", "f", "l") {
            names.add(base + suffix);
        }
    }
    for name in (
        "isalnum isalpha isblank iscntrl isdigit isgraph islower isprint ispunct "
        "isspace isupper isxdigit tolower toupper "
        "feclearexcept fegetexceptflag feraiseexcept fesetexceptflag fetestexcept "
        "fegetround fesetround fegetenv feholdexcept fesetenv feupdateenv "
        "setlocale localeconv nl_langinfo setjmp longjmp _setjmp _longjmp sigsetjmp siglongjmp "
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
        "localtime localtime_r strftime clock_gettime nanosleep sleep usleep "
        "open openat creat close read pread write lseek stat fstat lstat access "
        "chmod chdir getcwd mkdir rmdir link symlink readlink unlink utime "
        "opendir readdir closedir getpid getpwuid_r getpwnam_r getuid uname "
        "gnu_get_libc_version errno __error "
        "pipe poll fcntl ioctl tcgetattr tcsetattr cfgetispeed cfgetospeed cfsetispeed cfsetospeed waitpid posix_spawnp posix_spawn_file_actions_init "
        "posix_spawn_file_actions_destroy posix_spawn_file_actions_addopen "
        "posix_spawn_file_actions_addclose posix_spawn_file_actions_adddup2 "
        "posix_spawn_file_actions_addchdir_np "
        "__errno_location environ _NSGetExecutablePath "
        "pthread_create pthread_join pthread_key_create pthread_getspecific "
        "pthread_setspecific sched_yield "
        "socket connect send recv shutdown getaddrinfo freeaddrinfo gai_strerror "
        "dlopen dlsym dlclose dlerror "
        "__jac_win_executable_path "
        "__jac_errno __jac_stdio __jac_platform_id __jac_stat __jac_opendir "
        "__jac_readdir __jac_closedir __jac_dirent_name __jac_at_fdcwd "
        "__jac_home_dir __jac_executable_path __jac_addrinfo_layout "
        "__jac_sockaddr_family __jac_clock_id __jac_sleep_ns __jac_malloc_size "
        "__jac_fmadd __jac_va_list __jac_va_i64 __jac_va_f64 "
        "main _start __libc_start_main __getmainargs mainCRTStartup "
        "compress2 uncompress uncompress2 compressBound crc32_z adler32_z "
        "BZ2_bzBuffToBuffCompress BZ2_bzBuffToBuffDecompress "
        "ZSTD_isError ZSTD_getErrorName ZSTD_compressBound ZSTD_freeCCtx "
        "ZSTD_createCCtx ZSTD_createDCtx ZSTD_DStreamOutSize ZSTD_versionNumber "
        "ZSTD_CCtx_setParameter ZSTD_compress2 ZSTD_freeDCtx ZSTD_DCtx_setParameter "
        "ZSTD_decompressStream_simpleArgs ZSTD_getFrameContentSize "
        "ZSTD_getDictID_fromFrame "
        "RAND_bytes CRYPTO_memcmp TLS_client_method "
        "SSL_CTX_new SSL_CTX_set_verify SSL_CTX_load_verify_locations "
        "SSL_CTX_set_default_verify_paths SSL_CTX_free SSL_new SSL_set_fd SSL_ctrl "
        "SSL_set1_host SSL_connect SSL_get_verify_result SSL_get_error SSL_read "
        "SSL_write SSL_shutdown SSL_free X509_verify_cert_error_string "
        "ERR_reason_error_string ERR_get_error ERR_peek_error "
        "Py_DecRef PyBool_FromLong PyBytes_AsString PyDict_New PyDict_SetItemString "
        "PyErr_Print PyFloat_AsDouble PyFloat_FromDouble PyGILState_Ensure "
        "PyGILState_Release PyImport_ImportModule PyLong_AsLongLong "
        "PyLong_FromLongLong PyObject_Call PyObject_GetAttrString PyObject_IsTrue "
        "PyObject_SetAttrString PyTuple_New PyTuple_SetItem PyUnicode_AsUTF8String "
        "PyUnicode_FromString "
        "__mt_genrand_u32 __mt_getrandbits __mt_init_by_array __mt_randbelow "
        "GC_malloc "
        "clock_settime clock_nanosleep inflateInit2_ inflate inflateEnd zlibVersion "
        "__connect "
        "sqlite3_open sqlite3_open_v2 sqlite3_close sqlite3_exec sqlite3_free "
        "sqlite3_errmsg sqlite3_errcode sqlite3_extended_errcode sqlite3_libversion "
        "sqlite3_busy_timeout sqlite3_prepare_v2 sqlite3_step sqlite3_reset "
        "sqlite3_finalize sqlite3_clear_bindings sqlite3_bind_null sqlite3_bind_int64 "
        "sqlite3_bind_double sqlite3_bind_text sqlite3_bind_blob "
        "sqlite3_bind_parameter_count sqlite3_bind_parameter_name "
        "sqlite3_column_count sqlite3_column_name sqlite3_column_type "
        "sqlite3_column_int64 sqlite3_column_double sqlite3_column_text "
        "sqlite3_column_blob sqlite3_column_bytes sqlite3_changes64 "
        "sqlite3_total_changes64 sqlite3_last_insert_rowid sqlite3_get_autocommit "
        "sqlite3_stmt_readonly sqlite3_complete "
    ).split() {
        names.add(name);
    }
    return frozenset(names);
}

impl native_arch_scope(mod_path: str) -> str {
    import os;
    if not mod_path {
        return "";
    }
    gen = kernel_target_generation();
    if _native_arch_scope_gen[0] != gen {
        _native_arch_scope_memo.clear();
        _native_arch_scope_gen[0] = gen;
    }
    memo = _native_arch_scope_memo.get(mod_path);
    if memo is not None {
        return memo;
    }
    import from jaclang.compiler.native_scope { binds_bare_arch_names }
    source = real_path(mod_path);
    out = "";
    if source.endswith(".jac") and not binds_bare_arch_names(source) {
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

impl native_arch_name(mod_path: str, name: str) -> str {
    if not name {
        return name;
    }
    return f"{name}{native_arch_scope(mod_path)}";
}

impl _is_word_char(ch: str) -> bool {
    return ch.isalnum() or ch == "_";
}

impl native_unit_spelling(text: str, mod_path: str) -> str {
    scope = native_arch_scope(mod_path) if NATIVE_ARCH_SCOPE_SEP in text else "";
    if not scope {
        return text;
    }
    out: list[str] = [];
    i = 0;
    while i < len(text) {
        j = text.find(scope, i);
        if j < 0 {
            out.append(text[i:]);
            break;
        }
        end = j + len(scope);
        if end < len(text) and _is_word_char(text[end]) {
            out.append(text[i:end]);
        } else {
            out.append(text[i:j]);
        }
        i = end;
    }
    return "".join(out);
}

impl native_arch_display(native_name: str) -> str {
    sep = native_name.find(NATIVE_ARCH_SCOPE_SEP);
    return native_name if sep < 0 else native_name[:sep];
}

impl _scope_suffix_end(text: str, start: int) -> int {
    n = len(text);
    k = start + 1;
    while k < n and _is_word_char(text[k]) {
        if text[k] == "_"
            and k + 9 <= n
            and (k + 9 == n or not _is_word_char(text[k + 9])) {
            digest = text[k + 1:k + 9];
            if all(ch in "0123456789abcdef" for ch in digest) {
                return k + 9;
            }
        }
        k += 1;
    }
    return -1;
}

impl native_display_text(text: str) -> str {
    if NATIVE_ARCH_SCOPE_SEP not in text {
        return text;
    }
    out: list[str] = [];
    i = 0;
    while i < len(text) {
        j = text.find(NATIVE_ARCH_SCOPE_SEP, i);
        if j < 0 {
            out.append(text[i:]);
            break;
        }
        end = _scope_suffix_end(text, j);
        if end < 0 {
            out.append(text[i:j + 1]);
            i = j + 1;
        } else {
            out.append(text[i:j]);
            i = end;
        }
    }
    return "".join(out);
}

impl native_def_symbol(name: str) -> str {
    return f"__jac_def_{name}" if name in NATIVE_RESERVED_C_SYMBOLS else name;
}

impl module_dotted_name(mod_path: str, mod_name: str = "") -> str {
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

impl native_unit_root(directory: str) -> (str | None) {
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

impl native_unit_identity(path: str) -> str {
    memo = _native_unit_identity_memo.get(path);
    if memo is not None {
        return memo;
    }
    import os;
    rp = real_path(path);
    unit_root = native_unit_root(os.path.dirname(rp));
    identity = rp;
    if unit_root is not None {
        rel = os.path.relpath(rp, unit_root).replace("\\", "/");
        identity = f"{os.path.basename(unit_root)}/{rel}";
    }
    _native_unit_identity_memo[path] = identity;
    return identity;
}

impl native_module_key(path: str) -> str {
    import os;
    rp = real_path(path);
    base = os.path.basename(rp);
    dot = base.rfind(".");
    stem = base[0:dot] if dot > 0 else base;
    ident = native_unit_identity(rp);
    return f"{stem}:{hashlib.sha1(ident.encode()).hexdigest()[:12]}";
}

impl native_unit_prefix(path: str) -> str {
    return native_safe_sym(native_module_key(path));
}

impl interop_callback_symbol(provider_path: str, name: str) -> str {
    return f"__jac_na_import_{native_unit_prefix(provider_path)}_{native_safe_sym(
        name
    )}";
}

impl native_symbol_name(prefix: str, name: str) -> str {
    return f"{prefix}.{name}";
}

impl native_glob_init_name(path: str) -> str {
    return f"__jac_glob_init_{native_unit_prefix(path)}";
}

impl native_entry_name(path: str) -> str {
    return f"__jac_entry_{native_unit_prefix(path)}";
}

impl native_runtime_probe_name(path: str) -> str {
    return f"__jac_rt_probe_{native_unit_prefix(path)}";
}

impl native_test_symbol(name: str, line: int, prefix: str = "") -> str {
    bare = f"__jac_test_{name}_{line}";
    return native_symbol_name(prefix, bare) if prefix else bare;
}

impl jaclang_pkg_root -> str {
    return package_root();
}

impl is_compiler_source_path(source_path: str) -> bool {
    import os;
    if not _PKG_REAL {
        _PKG_REAL.append(real_path(jaclang_pkg_root()) + os.sep);
    }
    try {
        return real_path(source_path).startswith(_PKG_REAL[0]);
    } except (OSError, ValueError) {
        return False;
    }
}

impl kernel_unit_rels -> list[str] {
    spec = active_kernel_target();
    return list(spec.kernel_unit_rel) if spec is not None else list(KERNEL_UNIT_REL);
}

impl is_package_keyed_path(source_path: str) -> bool {
    if is_compiler_source_path(source_path) {
        return True;
    }
    return kernel_target_active() and is_target_package_path(source_path);
}

impl kernel_unit_path(rel: str) -> str {
    import os;
    return os.path.join(target_pkg_root(), rel.replace("/", os.sep));
}

impl kernel_unit_paths -> list[str] {
    return [kernel_unit_path(rel) for rel in kernel_unit_rels()];
}

impl real_path(path: str) -> str {
    found = _REAL_PATHS.get(path);
    if found is None {
        import os;
        found = os.path.realpath(path);
        _REAL_PATHS[path] = found;
    }
    return found;
}

impl forget_real_paths {
    _REAL_PATHS.clear();
}

impl is_kernel_unit_path(path: str) -> bool {
    import os;
    if not path {
        return False;
    }
    rp = real_path(path);
    for rel in kernel_unit_rels() {
        if rp == real_path(kernel_unit_path(rel)) {
            return True;
        }
    }
    return False;
}

impl native_erased_import_names(module_name: str, names: list[str]) -> bool {
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

impl set_effective_default_codespace(value: str) {
    _effective_codespace_ctx.set(value);
}

impl get_effective_default_codespace_override -> str {
    return _effective_codespace_ctx.get('');
}

impl effective_default_codespace -> str {
    cur = _effective_codespace_ctx.get('');
    if cur {
        return cur;
    }
    import from jaclang.compiler.frontend.host { active_host }
    project = active_host().project_defaults();
    return project.default_codespace if project is not None else "server";
}

impl set_native_unit_compile(value: bool) -> bool {
    prev = _native_unit_ctx.get(False);
    _native_unit_ctx.set(value);
    return prev;
}

impl reset_native_unit_compile(prev: bool) {
    _native_unit_ctx.set(prev);
}

impl native_unit_compile_active -> bool {
    return _native_unit_ctx.get(False);
}

impl native_stdlib_root -> (str | None) {
    import os;
    pkg = target_pkg_root();
    if not pkg {
        return None;
    }
    stdlib_dir = os.path.join(pkg, "runtime", "na_stdlib");
    return stdlib_dir if os.path.isdir(stdlib_dir) else None;
}

impl bundled_pkg_roots -> list[str] {
    roots: list[str] = [];
    pkg = jaclang_pkg_root();
    if pkg {
        roots.append(pkg);
    }
    if kernel_target_active() {
        target = target_pkg_root();
        if target and target not in roots {
            roots.append(target);
        }
    }
    return roots;
}

impl is_toolchain_unit(file_path: str) -> bool {
    import os;
    if not file_path {
        return False;
    }
    unit_root = native_unit_root(os.path.dirname(real_path(file_path)));
    if unit_root is None {
        return False;
    }
    keyed = real_path(unit_root);
    return any(keyed == real_path(pkg) for pkg in bundled_pkg_roots());
}

impl bundled_native_module_names -> list[str] {
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

impl is_native_by_location(file_path: str) -> bool {
    import os;
    if not file_path {
        return False;
    }
    ap = os.path.abspath(file_path);
    for pkg in bundled_pkg_roots() {
        if ap.startswith(os.path.join(pkg, "runtime", "na_stdlib") + os.sep) {
            return True;
        }
    }
    return False;
}

impl bundled_stdlib_module_of(file_path: str) -> (str | None) {
    import os;
    if not file_path {
        return None;
    }
    ap = os.path.abspath(file_path);
    for pkg in bundled_pkg_roots() {
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
    }
    return None;
}

impl is_client_by_location(file_path: str) -> bool {
    import os;
    if not file_path {
        return False;
    }
    ap = os.path.abspath(file_path);
    for pkg in bundled_pkg_roots() {
        for rel in CLIENT_RUNTIME_SOURCE_PATHS {
            if ap == os.path.join(pkg, rel.replace("/", os.sep)) {
                return True;
            }
        }
    }
    return False;
}

impl is_shared_runtime_module(file_path: str) -> bool {
    import os;
    if not file_path {
        return False;
    }
    stem = os.path.basename(file_path);
    named = False;
    for module in SHARED_RUNTIME_MODULES {
        if stem == module.rpartition('.')[2] + '.jac' {
            named = True;
        }
    }
    if not named {
        return False;
    }
    path = real_path(file_path);
    for pkg in bundled_pkg_roots() {
        package = real_path(pkg);
        for module in SHARED_RUNTIME_MODULES {
            rel = module.split('.', 1)[1].replace('.', os.sep) + '.jac';
            if path == os.path.join(package, rel) {
                return True;
            }
        }
    }
    return False;
}

impl is_bundled_native_module(module_name: str) -> bool {
    import os;
    stdlib_dir = native_stdlib_root();
    if stdlib_dir is None or not module_name {
        return False;
    }
    clean = module_name.lstrip('.');
    path_name = NATIVE_STDLIB_EXTENSIONS.get(clean, clean).replace('.', os.sep);
    return _native_variant_path(os.path.join(stdlib_dir, path_name)) is not None;
}

impl set_native_target_override(triple: str | None) -> (str | None) {
    prev = _native_target_ctx.get(None);
    _native_target_ctx.set(triple);
    return prev;
}

impl effective_native_target -> str {
    cur = _native_target_ctx.get(None);
    if cur is not None {
        return cur;
    }
    import from jaclang.compiler.frontend.host { active_host }
    project = active_host().project_defaults();
    return project.native_target if project is not None else "";
}

impl native_target_os -> str {
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

impl native_target_arch -> str {
    _t = effective_native_target();
    if _t {
        machine = _t.split("-")[0].lower();
    } else {
        import from jaclang.compiler.frontend.host { active_host }
        machine = active_host().host_platform().machine.lower();
    }
    if machine in ("arm64", "aarch64") or machine.startswith("arm64") {
        return "aarch64";
    }
    if machine in ("x86_64", "amd64", "x64") {
        return "x86_64";
    }
    return machine;
}

impl _native_variant_path(base_no_ext: str) -> (str | None) {
    import os;
    _osarchv = f"{base_no_ext}.{native_target_os()}.{native_target_arch()}.jac";
    if os.path.exists(_osarchv) {
        return _osarchv;
    }
    _archv = f"{base_no_ext}.{native_target_arch()}.jac";
    if os.path.exists(_archv) {
        return _archv;
    }
    _os = native_target_os();
    _osv = os.path.join(f"{base_no_ext}.{_os}.jac");
    if os.path.exists(_osv) {
        return _osv;
    }
    if _os == "windows" {
        _floorv = f"{base_no_ext}.linux.jac";
        if os.path.exists(_floorv) {
            return _floorv;
        }
    }
    _plain = f"{base_no_ext}.jac";
    if os.path.exists(_plain) {
        return _plain;
    }
    return None;
}

impl is_selected_native_variant(path: str) -> bool {
    import os;
    if not is_native_variant_path(path) {
        return False;
    }
    parts = os.path.basename(path)[:-len(".jac")].split(".");
    for cut in (2, 1) {
        portable = os.path.join(os.path.dirname(path), ".".join(parts[:-cut]) + ".jac");
        if len(parts) > cut and os.path.exists(portable) {
            return real_path(native_variant_of(portable)) == real_path(path);
        }
    }
    return False;
}

impl is_native_variant_path(path: str) -> bool {
    import os;
    name = os.path.basename(path);
    if not name.endswith(".jac") {
        return False;
    }
    parts = name[:-len(".jac")].split(".");
    if len(parts) < 2 {
        return False;
    }
    tail = parts[-2:] if len(parts) >= 3 else parts[-1:];
    if len(tail) == 2
        and not (tail[0] in NATIVE_VARIANT_OSES and tail[1] in NATIVE_VARIANT_ARCHES) {
        tail = tail[-1:];
    }
    for part in tail {
        if part not in NATIVE_VARIANT_OSES and part not in NATIVE_VARIANT_ARCHES {
            return False;
        }
    }
    stem = ".".join(parts[:len(parts) - len(tail)]);
    return os.path.isfile(os.path.join(os.path.dirname(path), stem + ".jac"));
}

impl native_variant_of(module_path: str) -> str {
    if not module_path.endswith('.jac') {
        return module_path;
    }
    return _native_variant_path(module_path[:-len('.jac')]) or module_path;
}

impl _inferred_native_path(candidate: (str | None)) -> (str | None) {
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

impl resolve_native_module(
    module_name: str, base_dir: str, allow_inferred: bool = True
) -> tuple[(str | None, str | None)] {
    import os;
    clean = module_name.lstrip('.');
    path_name = clean.replace('.', os.sep);

    if module_name == clean and clean.startswith('jaclang.') {
        runtime_rel = clean[len('jaclang.'):].replace('.', '/') + '.jac';
        if runtime_rel in kernel_unit_rels() {
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
        import from jaclang.compiler.frontend.host { active_host }
        import from jaclang.compiler.native_scope { in_native_scope_path }
        (candidate, language) = active_host().resolve_module(
            clean, os.path.join(base_dir, "")
        );
        if language != 'jac' or not candidate.endswith('.jac') {
            return (None, None);
        }

        candidate = real_path(
            _native_variant_path(candidate[:-len('.jac')]) or candidate
        );
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

    if allow_inferred and not clean.startswith('jaclang.') {
        import from jaclang.compiler.frontend.host { active_host }
        host = active_host();
        owners: list[str] = [];
        for start in [base_dir, ""] {
            owner = host.project_root(start);
            if owner {
                owners.append(owner);
            }
        }
        for owner in owners {
            facts = host.project_facts(owner);
            mounts = facts.package_mounts if facts is not None else "";
            if mounts and os.path.isdir(mounts) {
                mounted = _inferred_native_path(
                    _native_variant_path(os.path.join(mounts, path_name))
                );
                if mounted is not None {
                    return (path_name, mounted);
                }
            }
        }
    }

    if clean.startswith('jaclang.') {
        import from jaclang.compiler.native_scope { in_native_scope_path }
        _cand = os.path.join(
            target_pkg_root(), clean.split('.', 1)[1].replace('.', os.sep) + '.jac'
        );
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

impl native_wasm_stem(path: str) -> str {
    import os;
    stem = os.path.splitext(os.path.basename(path))[0];
    for marker in ('.cl', ) {
        if stem.endswith(marker) {
            stem = stem[0:-len(marker)];
        }
    }
    return stem;
}

impl CodeGenTarget.has_native_ir -> bool {
    return self.ir_module is not None or self.llvm_ir is not None;
}

impl CodeGenTarget.drop_native_ir {
    self.ir_module = None;
    self.llvm_ir = None;
    self.native_fallbacks = None;
}

impl endpoint_descriptor(module: Module, kind: str, name: str) -> dict[str, str] {
    import os;
    path = module.loc.mod_path;
    host = active_host();
    workspace = host.workspace(path);
    owner = host.app_for_path(path) if workspace else None;
    app = owner.name if owner is not None else "";
    source = os.path.relpath(path, workspace.project_root)
        if workspace
        else module.name;
    source = source.replace(os.sep, "/");
    return {"app": app, "module": source, "kind": kind, "name": name};
}

impl endpoint_key(module: Module, kind: str, name: str) -> str {
    import json;
    d = endpoint_descriptor(module, kind, name);
    return "["
        + ",".join([json.dumps(part) for part in [d["app"], d["module"], kind, name]])
        + "]";
}
