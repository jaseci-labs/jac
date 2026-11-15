impl _cache_dir -> str {
    d = os.path.join(str(get_jir_cache_dir()), "client_kernel");
    os.makedirs(d, exist_ok=True);
    return d;
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
    path = os.path.join(_cache_dir(), f"osp_core_cl.{digest}.jac");
    if not os.path.exists(path) {
        tmp = f"{path}.{os.getpid()}.tmp";
        with open(tmp, "w", encoding="utf-8") as f {
            f.write(source);
        }
        os.replace(tmp, path);
    }
    return (path, digest);
}

impl _artifact_path(source_digest: str) -> str {
    h = hashlib.sha256();
    h.update(running_compiler_digest().encode());
    h.update(source_digest.encode());
    h.update(_es_backend_fingerprint().encode());
    return os.path.join(_cache_dir(), f"osp_core_cl.{h.hexdigest()[:16]}.mjs");
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
    artifact = _artifact_path(source_digest);
    try {
        with open(artifact, "r", encoding="utf-8") as f {
            js = f.read();
        }
        _OSP_CORE_JS_MEMO.append(js);
        return js;
    } except Exception {}
    js = _lower(cl_copy);
    tmp = f"{artifact}.{os.getpid()}.tmp";
    with open(tmp, "w", encoding="utf-8") as f {
        f.write(js);
    }
    os.replace(tmp, artifact);
    _OSP_CORE_JS_MEMO.append(js);
    return js;
}
