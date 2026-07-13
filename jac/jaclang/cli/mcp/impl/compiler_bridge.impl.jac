import tempfile;
import os;
import sys;
import threading;
import logging;

def _extract_error_info(alert: object) -> dict[str, any] {
    return {
        "line": alert?.loc?.first_line or 0,
        "col": alert?.loc?.col_start or 0,
        "message": alert?.msg or str(alert)
    };
}

def _snippet_task(code: str, worker: object, suffix: str = ".jac") -> object {
    def _run -> object {
        with tempfile.NamedTemporaryFile(mode="w", suffix=suffix, delete=False) as f {
            f.write(code);
            tmp_path = f.name;
        }
        try {
            return worker(tmp_path);
        } finally {
            os.unlink(tmp_path);
        }
    }
    return _run;
}

impl run_with_timeout(func: object, timeout: int = 10) -> tuple {
    result_holder: list = [None];
    error_holder: list = [None];
    def _worker {
        try {
            result_holder[0] = func();
        } except Exception as e {
            error_holder[0] = e;
        }
    }
    t = threading.Thread(target=_worker);
    t.start();
    t.join(timeout=timeout);
    if t.is_alive() {
        return (False, "Operation timed out");
    }
    if error_holder[0] is not None {
        return (False, str(error_holder[0]));
    }
    return (True, result_holder[0]);
}

def _cap_read(stream: object, holder: list, cap: int) {
    try {
        chunks: list = [];
        total: int = 0;
        while True {
            want: int = min(4096, cap - total);
            if want <= 0 {
                break;
            }
            chunk: bytes = stream.read(want);
            if not chunk {
                break;
            }
            chunks.append(chunk);
            total += len(chunk);
        }
        data: bytes = b"".join(chunks);
        if total >= cap {
            if stream.read(1) {
                while stream.read(65536) { }
                holder[0] = data + OUTPUT_TRUNCATION_MARKER.encode();
            } else {
                holder[0] = data;
            }
        } else {
            holder[0] = data;
        }
    } finally {
        try {
            stream.close();
        } except Exception { }
    }
}

def _join_reader(t: threading.Thread, name: str, deadline: float = 5.0) {
    t.join(timeout=deadline);
    if t.is_alive() {
        logging.getLogger("jac.mcp").warning(
            f"{name} reader thread still alive {deadline}s after "
            "process teardown; pipe may be held open by a descendant"
        );
    }
}

impl CompilerBridge.parse_snippet(
    code: str, filename: str = "snippet.jac"
) -> dict[str, any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "valid": False,
            "errors": [
                {
                    "line": 0,
                    "col": 0,
                    "message": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
                }
            ]
        };
    }
    def _do_parse(tmp_path: str) -> dict[str, any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        program = JacProgram();

        ir = program.parse_str(code, tmp_path);

        errors: list[dict] = [];
        for e in program.errors_had {
            errors.append(_extract_error_info(e));
        }

        valid = len(errors) == 0 and ir is not None;
        return {"valid": valid, "errors": errors};
    }
    (success, result) = run_with_timeout(_snippet_task(code, _do_parse));
    if not success {
        return {
            "valid": False,
            "errors": [{"line": 0, "col": 0, "message": str(result)}]
        };
    }
    return result;
}

impl CompilerBridge.typecheck_snippet(
    code: str, filename: str = "snippet.jac"
) -> dict[str, any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "valid": False,
            "errors": [
                {
                    "line": 0,
                    "col": 0,
                    "message": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
                }
            ],
            "warnings": []
        };
    }
    def _do_typecheck(tmp_path: str) -> dict[str, any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        program = JacProgram();
        compiler = Jac.get_compiler();

        ir = compiler.compile(tmp_path, program);

        errors: list[dict] = [];
        warnings: list[dict] = [];
        for e in program.errors_had {
            errors.append(_extract_error_info(e));
        }
        for w in program.warnings_had {
            warnings.append(_extract_error_info(w));
        }

        valid = len(errors) == 0 and ir is not None;
        return {"valid": valid, "errors": errors, "warnings": warnings};
    }
    (success, result) = run_with_timeout(_snippet_task(code, _do_typecheck));
    if not success {
        return {
            "valid": False,
            "errors": [{"line": 0, "col": 0, "message": str(result)}],
            "warnings": []
        };
    }
    return result;
}

impl CompilerBridge.format_snippet(code: str) -> dict[str, any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "formatted": code,
            "changed": False,
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
        };
    }
    def _do_format(tmp_path: str) -> dict[str, any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }

        compiler = Jac.get_compiler();

        result_prog = compiler.jac_str_formatter(code, tmp_path);

        if result_prog is None {
            return {"formatted": code, "changed": False, "error": "Format failed"};
        }

        formatted = code;
        if result_prog.mod and result_prog.mod?.unparse {
            formatted = result_prog.mod.unparse();
        }

        changed = formatted != code;
        return {"formatted": formatted, "changed": changed};
    }
    (success, result) = run_with_timeout(_snippet_task(code, _do_format));
    if not success {
        return {"formatted": code, "changed": False, "error": str(result)};
    }
    return result;
}

impl CompilerBridge.py_to_jac(python_code: str) -> dict[str, any] {
    if len(python_code) > MAX_INPUT_SIZE {
        return {
            "jac_code": "",
            "warnings": [f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"]
        };
    }
    def _do_py2jac(tmp_path: str) -> dict[str, any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        compiler = Jac.get_compiler();

        program = JacProgram();

        ir = compiler.compile(tmp_path, program);

        warnings: list[str] = [];
        for w in program.warnings_had {
            warnings.append(str(w));
        }

        if ir is None {
            errors: list[str] = [];
            for e in program.errors_had {
                errors.append(str(e));
            }
            return {"jac_code": "", "warnings": errors or ["Conversion failed"]};
        }

        jac_code = "";
        if ir?.unparse {
            jac_code = ir.unparse();
        }

        return {"jac_code": jac_code, "warnings": warnings};
    }
    (success, result) = run_with_timeout(
        _snippet_task(python_code, _do_py2jac, suffix=".py")
    );
    if not success {
        return {"jac_code": "", "warnings": [str(result)]};
    }
    return result;
}

impl CompilerBridge.get_ast_snippet(code: str, fmt: str = "tree") -> dict[str, any] {
    import json;

    if len(code) > MAX_INPUT_SIZE {
        return {
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes",
            "ast": None
        };
    }
    def _do_ast(tmp_path: str) -> dict[str, any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        program = JacProgram();

        ir = program.parse_str(code, tmp_path);

        errors: list[dict] = [];
        for e in program.errors_had {
            errors.append(_extract_error_info(e));
        }

        if ir is None {
            return {"error": "Parse failed", "errors": errors, "ast": None};
        }

        if fmt == "json" {
            ast_output = json.dumps(ir.to_dict(), default=str);
        } else {
            ast_output = ir.pp();
        }

        return {"ast": ast_output, "valid": len(errors) == 0, "errors": errors};
    }
    (success, result) = run_with_timeout(_snippet_task(code, _do_ast));
    if not success {
        return {"error": str(result), "ast": None};
    }
    return result;
}

impl CompilerBridge.lint_snippet(code: str, auto_fix: bool = False) -> dict[str, any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "violations": [],
            "fixed_code": None,
            "changed": False,
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
        };
    }
    def _do_lint(tmp_path: str) -> dict[str, any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.compiler { JacCompiler }

        if auto_fix {
            prog = JacCompiler.jac_str_formatter(
                source_str=code, file_path=tmp_path, auto_lint=True
            );
        } else {
            prog = JacCompiler.jac_file_linter(file_path=tmp_path);
        }

        violations: list[dict] = [];
        for w in prog.warnings_had {
            violations.append(_extract_error_info(w));
        }
        for e in prog.errors_had {
            info = _extract_error_info(e);
            info["severity"] = "error";
            violations.append(info);
        }

        fixed_code: (str | None) = None;
        changed = False;
        if auto_fix and prog.mod and prog.mod.main and prog.mod.main.gen {
            fixed_code = prog.mod.main.gen.jac;
            if fixed_code is None and hasattr(prog.mod.main, "unparse") {
                fixed_code = prog.mod.main.unparse();
            }
            changed = fixed_code is not None and fixed_code != code;
        }

        return {"violations": violations, "fixed_code": fixed_code, "changed": changed};
    }
    (success, result) = run_with_timeout(_snippet_task(code, _do_lint));
    if not success {
        return {
            "violations": [],
            "fixed_code": None,
            "changed": False,
            "error": str(result)
        };
    }
    return result;
}

impl CompilerBridge.jac_to_py(code: str) -> dict[str, any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "python_code": "",
            "warnings": [f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"]
        };
    }
    def _do_jac2py(tmp_path: str) -> dict[str, any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        prog = JacProgram();
        ir = prog.compile(file_path=tmp_path);

        warnings: list[str] = [];
        for w in prog.warnings_had {
            warnings.append(str(w));
        }

        if ir is None or prog.errors_had {
            errors: list[str] = [];
            for e in prog.errors_had {
                errors.append(str(e));
            }
            return {"python_code": "", "warnings": errors or ["Conversion failed"]};
        }

        py_code = ir.gen.py or "";
        return {"python_code": py_code, "warnings": warnings};
    }
    (success, result) = run_with_timeout(
        _snippet_task(code, _do_jac2py), timeout=DEFAULT_TIMEOUT
    );
    if not success {
        return {"python_code": "", "warnings": [str(result)]};
    }
    return result;
}

impl CompilerBridge.jac_to_js(code: str) -> dict[str, any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "js_code": "",
            "warnings": [f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"]
        };
    }
    def _do_jac2js(tmp_path: str) -> dict[str, any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        prog = JacProgram();
        ir = prog.compile(file_path=tmp_path);

        warnings: list[str] = [];
        for w in prog.warnings_had {
            warnings.append(str(w));
        }

        if ir is None or prog.errors_had {
            errors: list[str] = [];
            for e in prog.errors_had {
                errors.append(str(e));
            }
            return {"js_code": "", "warnings": errors or ["Conversion failed"]};
        }

        js_code = ir.gen.js or "";
        if not js_code.strip() {
            warnings.append("ECMAScript code generation produced no output.");
        }
        return {"js_code": js_code, "warnings": warnings};
    }
    (success, result) = run_with_timeout(
        _snippet_task(code, _do_jac2js, suffix=".cl.jac"), timeout=DEFAULT_TIMEOUT
    );
    if not success {
        return {"js_code": "", "warnings": [str(result)]};
    }
    return result;
}

impl CompilerBridge.run_snippet(
    code: str, entrypoint: str = "", timeout: int = 10
) -> dict[str, any] {
    import subprocess;
    import signal;
    import shutil;

    if len(code) > MAX_INPUT_SIZE {
        return {
            "stdout": "",
            "stderr": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes",
            "exit_code": 1,
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
        };
    }

    tmp_dir = tempfile.mkdtemp();
    jac_path = os.path.join(tmp_dir, "snippet.jac");
    with open(jac_path, "w") as f {
        f.write(code);
    }

    if entrypoint {
        cmd = ["jac", "run", "--entry", entrypoint, jac_path];
    } else {
        cmd = ["jac", "run", jac_path];
    }

    is_windows = os.name == "nt";
    try {
        if is_windows {
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP,
            );
        } else {
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True,
            );
        }
        out_buf: list = [None];
        err_buf: list = [None];
        t_out = threading.Thread(
            target=_cap_read, args=(proc.stdout, out_buf, MAX_OUTPUT_SIZE), daemon=True
        );
        t_err = threading.Thread(
            target=_cap_read, args=(proc.stderr, err_buf, MAX_OUTPUT_SIZE), daemon=True
        );
        t_out.start();
        t_err.start();

        try {
            try {
                proc.wait(timeout=timeout);
                _join_reader(t_out, "stdout");
                _join_reader(t_err, "stderr");
            } except subprocess.TimeoutExpired {
                try {
                    if is_windows {
                        subprocess.run(
                            ["taskkill", "/T", "/F", "/PID", str(proc.pid)],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        );
                    } else {
                        os.killpg(os.getpgid(proc.pid), signal.SIGKILL);
                    }
                } except Exception { }
                proc.wait();
                _join_reader(t_out, "stdout");
                _join_reader(t_err, "stderr");
                return {
                    "stdout": "",
                    "stderr": "Operation timed out",
                    "exit_code": 1,
                    "error": "Operation timed out"
                };
            }
            out_text = out_buf[0].decode(errors="replace")
                if out_buf[0] is not None
                else "";
            err_text = err_buf[0].decode(errors="replace")
                if err_buf[0] is not None
                else "";
            exit_code = proc.returncode if proc.returncode is not None else 1;
            result: dict[str, any] = {
                "stdout": out_text,
                "stderr": err_text,
                "exit_code": exit_code,

            };
            if exit_code != 0 {
                result["error"] = err_text or f"Process exited with code {exit_code}";
            }
            return result;
        } finally {
            if not t_out.is_alive() {
                try {
                    proc.stdout.close();
                } except Exception { }
            }
            if not t_err.is_alive() {
                try {
                    proc.stderr.close();
                } except Exception { }
            }
        }
    } finally {
        try {
            shutil.rmtree(tmp_dir);
        } except Exception { }
    }
}

impl CompilerBridge.graph_viz_snippet(
    code: str,
    format: str = "dot",
    depth: int = -1,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512
) -> dict[str, any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "graph": "",
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
        };
    }
    def _do_graph -> dict[str, any] {
        import subprocess;
        import shutil;
        import from pathlib { Path }

        tmp_dir = tempfile.mkdtemp();
        tmp_path = os.path.join(tmp_dir, "snippet.jac");
        dot_path = os.path.join(tmp_dir, "snippet.dot");

        try {
            with open(tmp_path, "w") as f {
                f.write(code);
            }
            proc = subprocess.run(
                ["jac", "dot", tmp_path],
                capture_output=True,
                text=True,
                timeout=DEFAULT_TIMEOUT,
                cwd=tmp_dir
            );
            if os.path.exists(dot_path) {
                with open(dot_path) as f {
                    graph_output = f.read();
                }
                return {"graph": graph_output, "program_output": proc.stdout};
            }
            return {
                "graph": "",
                "program_output": proc.stdout,
                "error": proc.stderr.strip() or "No graph output generated"
            };
        } except subprocess.TimeoutExpired {
            return {"graph": "", "error": "Execution timed out"};
        } except Exception as e {
            return {"graph": "", "error": str(e)};
        } finally {
            try {
                shutil.rmtree(tmp_dir);
            } except Exception { }
        }
    }
    (success, result) = run_with_timeout(_do_graph, timeout=DEFAULT_TIMEOUT);
    if not success {
        return {"graph": "", "error": str(result)};
    }
    return result;
}

impl CompilerBridge.list_templates -> dict[str, any] {
    def _do_list_templates -> dict[str, any] {
        import from jaclang.project.template_registry {
            get_template_registry,
            initialize_template_registry
        }
        initialize_template_registry();
        registry = get_template_registry();
        templates = registry.list_templates();
        result: list[dict[str, str]] = [];
        for (name, description) in templates {
            result.append({"name": name, "description": description});
        }
        return {"templates": result};
    }
    (success, result) = run_with_timeout(_do_list_templates);
    if not success {
        return {"templates": [], "error": str(result)};
    }
    return result;
}

impl CompilerBridge.create_project(
    name: str, template: str = "cli", directory: str = ""
) -> dict[str, any] {
    import subprocess;
    import from pathlib { Path }

    if not name {
        return {"success": False, "error": "Project name is required"};
    }

    if directory {
        work_dir = str(Path(directory).resolve());
    } else {
        work_dir = tempfile.gettempdir();
    }

    cmd: list[str] = ["jac", "create", name, "-u", template, "--force"];

    def _do_create -> dict[str, any] {
        result = subprocess.run(
            cmd, capture_output=True, text=True, cwd=work_dir, timeout=30
        );

        project_path = str(Path(work_dir) / name);

        files_created: list[str] = [];
        pp = Path(project_path);
        if pp.exists() {
            for f in pp.rglob("*") {
                if f.is_file() {
                    files_created.append(str(f.relative_to(pp)));
                }
            }
        }

        success = result.returncode == 0;
        return {
            "success": success,
            "project_path": project_path,
            "files_created": files_created,
            "output": result.stdout,
            "error": result.stderr if not success else ""
        };
    }

    (success, result) = run_with_timeout(_do_create, timeout=30);
    if not success {
        return {
            "success": False,
            "project_path": "",
            "files_created": [],
            "output": "",
            "error": str(result)
        };
    }
    return result;
}
