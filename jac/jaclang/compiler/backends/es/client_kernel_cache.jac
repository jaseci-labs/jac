import hashlib;
import os;

glob OSP_CORE_PARTS: tuple[str, ...] = (
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac"
     ),
     _OSP_CORE_JS_MEMO: list[str] = [];

def _cache_dir -> str {
    import from jaclang.jac0core.cache_paths { get_jir_cache_dir }
    d = os.path.join(str(get_jir_cache_dir()), "client_kernel");
    os.makedirs(d, exist_ok=True);
    return d;
}

def _es_backend_fingerprint -> str {
    import glob as _g;
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
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

def _unit_source_path -> tuple[str, str] {
    import from jaclang.compiler.frontend.codeinfo { kernel_unit_path }
    texts: list[str] = [];
    for rel in OSP_CORE_PARTS {
        with open(kernel_unit_path(rel), "r", encoding="utf-8") as f {
            texts.append(f.read());
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

def _artifact_path(source_digest: str) -> str {
    import from jaclang.compiler.driver.jir { running_compiler_digest }
    h = hashlib.sha256();
    h.update(running_compiler_digest().encode());
    h.update(source_digest.encode());
    h.update(_es_backend_fingerprint().encode());
    return os.path.join(_cache_dir(), f"osp_core_cl.{h.hexdigest()[:16]}.mjs");
}

def _lower(cl_copy: str) -> str {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    import from jaclang.compiler.backends.es.es_unparse { es_to_js }
    import from jaclang.compiler.backends.es { estree as es }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.pass_driver { run_pass }
    prog = JacProgram();
    ir = prog.compile(
        file_path=cl_copy,
        options=CompileOptions(force_codespace='client', no_cgen=True)
    );
    program = run_pass(EsastGenPass, ir, prog).ir_out.gen.es_ast;
    kept: list = [];
    if isinstance(program, es.Program) {
        for stmt in program.body {
            is_jac_rt = (
                isinstance(stmt, es.VariableDeclaration)
                and stmt.declarations
                and isinstance(stmt.declarations[0].id, es.Identifier)
                and (stmt.declarations[0].id.name == "_jac")
            );
            if is_jac_rt or isinstance(stmt, es.ExportNamedDeclaration) {
                continue;
            }
            kept.append(stmt);
        }
    }
    return es_to_js(es.Program(body=kept));
}

def osp_core_js -> str {
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
