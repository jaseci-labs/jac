impl _primary_dir -> str {
    return os.path.join(str(get_jir_cache_dir()), "client_kernel");
}

impl _trusted_dir(path: str) -> bool {
    try {
        st = os.lstat(path);
    } except OSError {
        return False;
    }
    if not stat.S_ISDIR(st.st_mode) {
        return False;
    }
    if not os?.getuid {
        return True;
    }
    return st.st_uid == os.getuid() and not (st.st_mode & 0o022);
}

impl _fallback_dir(create: bool) -> (str | None) {
    try {
        temp_root = tempfile.gettempdir();
    } except OSError {
        return None;
    }
    user = str(os.getuid()) if os?.getuid else os.environ.get("USERNAME", "user");
    folder = os.path.join(temp_root, f"jac-cache-{user}");
    for part in ["", "jir", "client_kernel"] {
        folder = os.path.join(folder, part) if part else folder;
        if create and not os.path.lexists(folder) {
            try {
                os.mkdir(folder, 0o700);
            } except FileExistsError {} except OSError {
                return None;
            }
        }
        if not _trusted_dir(folder) {
            return None;
        }
    }
    return folder;
}

impl _find_cached(name: str) -> (str | None) {
    for folder in [_primary_dir(), _fallback_dir(False)] {
        if folder is not None and os.path.isfile(os.path.join(folder, name)) {
            return os.path.join(folder, name);
        }
    }
    return None;
}

impl _write_one(folder: str, name: str, text: str) -> (str | None) {
    path = os.path.join(folder, name);
    tmp = f"{path}.{secrets.token_hex(8)}.tmp";
    try {
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644);
        with os.fdopen(fd, "w", encoding="utf-8") as f {
            f.write(text);
        }
        os.replace(tmp, path);
        return path;
    } except OSError as e {
        logger.debug(f"client kernel cache: cannot write {path}: {e}");
        try {
            os.unlink(tmp);
        } except OSError {}
    }
    return None;
}

impl _write_cached(name: str, text: str) -> (str | None) {
    primary = _primary_dir();
    try {
        os.makedirs(primary, exist_ok=True);
    } except OSError {}
    written = _write_one(primary, name, text);
    if written is not None {
        return written;
    }
    fallback = _fallback_dir(True);
    return _write_one(fallback, name, text) if fallback is not None else None;
}

impl _es_backend_fingerprint -> str {
    import glob as _g;

    es_dir = os.path.join(jaclang_pkg_root(), "compiler", "backends", "es");
    h = hashlib.sha256();
    for pat in ["*.jac", os.path.join("impl", "*.jac")] {
        for p in sorted(_g.`glob(os.path.join(es_dir, pat))) {
            try {
                with open(p, "rb") as f {
                    h.update(f.read());
                }
            } except Exception {}
        }
    }
    return h.hexdigest()[:16];
}

impl _unit_source_path -> tuple[str, str] {
    texts: list[str] = [];
    for rel in OSP_CORE_PARTS {
        head = kernel_unit_path(rel);
        (folder, name) = os.path.split(head);
        stem = name[:-len(".jac")];
        parts = [
            head,
            os.path.join(folder, stem + ".impl.jac"),
            os.path.join(folder, "impl", stem + ".impl.jac")
        ];
        annex_dir = os.path.join(folder, stem + ".impl");
        if os.path.isdir(annex_dir) {
            for listed in sorted(os.listdir(annex_dir)) {
                if listed.endswith(".impl.jac") {
                    parts.append(os.path.join(annex_dir, listed));
                }
            }
        }
        for part in parts {
            if part == head or os.path.isfile(part) {
                with open(part, "r", encoding="utf-8") as f {
                    texts.append(f.read());
                }
            }
        }
    }
    source = "\n\n".join(texts);
    digest = hashlib.sha256(source.encode()).hexdigest()[:16];
    name = f"osp_core_cl.{digest}.jac";
    path = _find_cached(name) or _write_cached(name, source);
    if path is None {
        raise OSError(
            f"no writable folder for the client kernel source {name}; tried "
            f"{_primary_dir()} and a private folder under the temp directory"
        );
    }
    return (path, digest);
}

impl _artifact_name(source_digest: str) -> str {
    h = hashlib.sha256();
    h.update(running_compiler_digest().encode());
    h.update(source_digest.encode());
    h.update(_es_backend_fingerprint().encode());
    return f"osp_core_cl.{h.hexdigest()[:16]}.mjs";
}

impl _lower(cl_copy: str) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=cl_copy,
        options=CompileOptions(force_codespace='client', no_cgen=True)
    );
    if not require(prog, ir, CompilationProduct.CLIENT) {
        raise RuntimeError("Could not compile OSP client runtime");
    }
    program = ir.gen.es_ast;
    kept: list[es.Statement | es.ModuleDeclaration] = [];
    if isinstance(program, es.Program) {
        for stmt in program.body {
            is_jac_rt = (
                isinstance(stmt, es.ImportDeclaration)
                and stmt.source is not None
                and (stmt.source.value == JAC_PRELUDE_MODULE)
            );
            if is_jac_rt or isinstance(stmt, es.ExportNamedDeclaration) {
                continue;
            }
            kept.append(stmt);
        }
    }
    return es_to_js(es.Program(body=kept));
}

impl osp_core_js -> str {
    if _OSP_CORE_JS_MEMO {
        return _OSP_CORE_JS_MEMO[0];
    }
    (cl_copy, source_digest) = _unit_source_path();
    name = _artifact_name(source_digest);
    artifact = _find_cached(name);
    if artifact is not None {
        try {
            with open(artifact, "r", encoding="utf-8") as f {
                js = f.read();
            }
            _OSP_CORE_JS_MEMO.append(js);
            return js;
        } except Exception {}
    }
    js = _lower(cl_copy);
    if _write_cached(name, js) is None {
        logger.warning(
            f"client kernel JS could not be cached in {_primary_dir()} or a private "
            "temp folder; "
            "this process keeps it in memory and the next one lowers it again"
        );
    }
    _OSP_CORE_JS_MEMO.append(js);
    return js;
}
