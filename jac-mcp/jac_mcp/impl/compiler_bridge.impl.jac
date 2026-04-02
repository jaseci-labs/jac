"""Implementation of compiler bridge."""

import from typing { Any }
import tempfile;
import os;
import sys;
import threading;
import io;
"""Extract line, col, and message from an Alert object."""
def _extract_error_info(alert: object) -> dict[str, Any] {
    return {
        "line": alert?.loc?.first_line or 0,
        "col": alert?.loc?.col_start or 0,
        "message": alert?.msg or str(alert)
    };
}

"""Run a function with timeout protection."""
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

"""Parse Jac code and return structured errors."""
impl CompilerBridge.parse_snippet(
    code: str, filename: str = "snippet.jac"
) -> dict[str, Any] {
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
    def _do_parse -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        Jac.setup();

        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
            f.write(code);
            tmp_path = f.name;
        }

        try {
            program = JacProgram();

            ir = program.parse_str(code, tmp_path);

            errors: list[dict] = [];
            for e in program.errors_had {
                errors.append(_extract_error_info(e));
            }

            valid = len(errors) == 0 and ir is not None;
            return {"valid": valid, "errors": errors};
        } finally {
            os.unlink(tmp_path);
        }
    }
    (success, result) = run_with_timeout(_do_parse);
    if not success {
        return {
            "valid": False,
            "errors": [{"line": 0, "col": 0, "message": str(result)}]
        };
    }
    return result;
}

"""Full type-check pipeline on Jac code."""
impl CompilerBridge.typecheck_snippet(
    code: str, filename: str = "snippet.jac"
) -> dict[str, Any] {
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
    def _do_typecheck -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        Jac.setup();

        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
            f.write(code);
            tmp_path = f.name;
        }

        try {
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
        } finally {
            os.unlink(tmp_path);
        }
    }
    (success, result) = run_with_timeout(_do_typecheck);
    if not success {
        return {
            "valid": False,
            "errors": [{"line": 0, "col": 0, "message": str(result)}],
            "warnings": []
        };
    }
    return result;
}

"""Format Jac code."""
impl CompilerBridge.format_snippet(code: str) -> dict[str, Any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "formatted": code,
            "changed": False,
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
        };
    }
    def _do_format -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }

        Jac.setup();
        compiler = Jac.get_compiler();

        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
            f.write(code);
            tmp_path = f.name;
        }

        try {
            result_prog = compiler.jac_str_formatter(code, tmp_path);

            if result_prog is None {
                return {"formatted": code, "changed": False, "error": "Format failed"};
            }

            # Get formatted source from the result
            formatted = code;
            if result_prog.mod and result_prog.mod?.unparse {
                formatted = result_prog.mod.unparse();
            }

            changed = formatted != code;
            return {"formatted": formatted, "changed": changed};
        } finally {
            os.unlink(tmp_path);
        }
    }
    (success, result) = run_with_timeout(_do_format);
    if not success {
        return {"formatted": code, "changed": False, "error": str(result)};
    }
    return result;
}

"""Convert Python code to Jac."""
impl CompilerBridge.py_to_jac(python_code: str) -> dict[str, Any] {
    if len(python_code) > MAX_INPUT_SIZE {
        return {
            "jac_code": "",
            "warnings": [f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"]
        };
    }
    def _do_py2jac -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        Jac.setup();
        compiler = Jac.get_compiler();

        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f {
            f.write(python_code);
            tmp_path = f.name;
        }

        try {
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

            # Get transpiled Jac source via unparse
            jac_code = "";
            if ir?.unparse {
                jac_code = ir.unparse();
            }

            return {"jac_code": jac_code, "warnings": warnings};
        } finally {
            os.unlink(tmp_path);
        }
    }
    (success, result) = run_with_timeout(_do_py2jac);
    if not success {
        return {"jac_code": "", "warnings": [str(result)]};
    }
    return result;
}

"""Parse Jac code and return AST representation."""
impl CompilerBridge.get_ast_snippet(code: str, fmt: str = "tree") -> dict[str, Any] {
    import json;

    if len(code) > MAX_INPUT_SIZE {
        return {
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes",
            "ast": None
        };
    }
    def _do_ast -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        Jac.setup();

        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
            f.write(code);
            tmp_path = f.name;
        }

        try {
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
        } finally {
            os.unlink(tmp_path);
        }
    }
    (success, result) = run_with_timeout(_do_ast);
    if not success {
        return {"error": str(result), "ast": None};
    }
    return result;
}

"""Lint Jac code and return violations with optional auto-fix."""
impl CompilerBridge.lint_snippet(code: str, auto_fix: bool = False) -> dict[str, Any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "violations": [],
            "fixed_code": None,
            "changed": False,
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
        };
    }
    def _do_lint -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.compiler { JacCompiler }

        Jac.setup();

        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
            f.write(code);
            tmp_path = f.name;
        }

        try {
            if auto_fix {
                # Use format with auto_lint=True to get auto-fixed code
                prog = JacCompiler.jac_str_formatter(
                    source_str=code, file_path=tmp_path, auto_lint=True
                );
            } else {
                # Lint-only pass
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

            return {
                "violations": violations,
                "fixed_code": fixed_code,
                "changed": changed
            };
        } finally {
            os.unlink(tmp_path);
        }
    }
    (success, result) = run_with_timeout(_do_lint);
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

"""Convert Jac code to Python."""
impl CompilerBridge.jac_to_py(code: str) -> dict[str, Any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "python_code": "",
            "warnings": [f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"]
        };
    }
    def _do_jac2py -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        Jac.setup();

        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
            f.write(code);
            tmp_path = f.name;
        }

        try {
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
                return {
                    "python_code": "",
                    "warnings": errors or ["Conversion failed"]
                };
            }

            py_code = ir.gen.py or "";
            return {"python_code": py_code, "warnings": warnings};
        } finally {
            os.unlink(tmp_path);
        }
    }
    (success, result) = run_with_timeout(_do_jac2py, timeout=DEFAULT_TIMEOUT);
    if not success {
        return {"python_code": "", "warnings": [str(result)]};
    }
    return result;
}

"""Convert Jac code to JavaScript."""
impl CompilerBridge.jac_to_js(code: str) -> dict[str, Any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "js_code": "",
            "warnings": [f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"]
        };
    }
    def _do_jac2js -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.program { JacProgram }

        Jac.setup();

        with tempfile.NamedTemporaryFile(mode="w", suffix=".cl.jac", delete=False) as f {
            f.write(code);
            tmp_path = f.name;
        }

        try {
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
        } finally {
            os.unlink(tmp_path);
        }
    }
    (success, result) = run_with_timeout(_do_jac2js, timeout=DEFAULT_TIMEOUT);
    if not success {
        return {"js_code": "", "warnings": [str(result)]};
    }
    return result;
}

"""Execute Jac code and return output."""
impl CompilerBridge.run_snippet(
    code: str, entrypoint: str = "", timeout: int = 10
) -> dict[str, Any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "stdout": "",
            "stderr": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes",
            "exit_code": 1,
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
        };
    }
    def _do_run -> dict[str, Any] {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.constructs { WalkerArchetype }

        Jac.setup();

        # Create temp file
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".jac", delete=False, dir=tempfile.gettempdir()
        ) as f {
            f.write(code);
            tmp_path = f.name;
        }

        # Capture stdout and stderr
        old_stdout = sys.stdout;
        old_stderr = sys.stderr;
        captured_out = io.StringIO();
        captured_err = io.StringIO();
        sys.stdout = captured_out;
        sys.stderr = captured_err;

        original_argv = sys.argv;
        sys.argv = [tmp_path];

        try {
            (base, mod_name) = os.path.split(tmp_path);
            base = base or './';
            mod_name = mod_name[:-4];  # Remove .jac

            if not Jac.base_path_dir {
                Jac.set_base_path(base);
            }
            mach = Jac.create_j_context(user_root=None);
            Jac.set_context(mach);

            try {
                if entrypoint {
                    # Load module then run specific entrypoint
                    ret = Jac.jac_import(
                        target=mod_name, base_path=base, override_name='__main__'
                    );
                    if ret {
                        (loaded_mod, ) = ret;
                        if loaded_mod and hasattr(loaded_mod, entrypoint) {
                            archetype = getattr(loaded_mod, entrypoint)();
                            if (
                                isinstance(archetype, WalkerArchetype)
                                and Jac.check_read_access(mach.entry_node)
                            ) {
                                Jac.spawn(mach.entry_node.archetype, archetype);
                            }
                        } else {
                            sys.stderr.write(
                                f"Entrypoint '{entrypoint}' not found in module\n"
                            );
                        }
                    }
                } else {
                    # Run as main module
                    Jac.jac_import(
                        target=mod_name,
                        base_path=base,
                        override_name='__main__',
                        lng='jac'
                    );
                }

                # Collect reports from execution context
                reports = [];
                if mach?.reports and mach.reports {
                    for r in mach.reports {
                        try {
                            reports.append(str(r));
                        } except Exception {
                            reports.append(repr(r));
                        }
                    }
                }

                mach.close();
                stdout_val = captured_out.getvalue();
                stderr_val = captured_err.getvalue();

                result: dict[str, Any] = {
                    "stdout": stdout_val,
                    "stderr": stderr_val,
                    "exit_code": 0
                };
                if reports {
                    result["reports"] = reports;
                }
                return result;
            } except SystemExit as se {
                mach.close();
                exit_code = se.code if se.code is not None else 0;
                return {
                    "stdout": captured_out.getvalue(),
                    "stderr": captured_err.getvalue(),
                    "exit_code": int(exit_code) if isinstance(exit_code, int) else 1
                };
            } except Exception as e {
                mach.close();
                return {
                    "stdout": captured_out.getvalue(),
                    "stderr": captured_err.getvalue(),
                    "exit_code": 1,
                    "error": str(e)
                };
            }
        } finally {
            sys.stdout = old_stdout;
            sys.stderr = old_stderr;
            sys.argv = original_argv;
            try {
                os.unlink(tmp_path);
            } except Exception { }
        }
    }
    (success, result) = run_with_timeout(_do_run, timeout=timeout);
    if not success {
        return {
            "stdout": "",
            "stderr": str(result),
            "exit_code": 1,
            "error": str(result)
        };
    }
    return result;
}

"""Generate graph visualization from Jac code."""
impl CompilerBridge.graph_viz_snippet(
    code: str,
    format: str = "dot",
    depth: int = -1,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512
) -> dict[str, Any] {
    if len(code) > MAX_INPUT_SIZE {
        return {
            "graph": "",
            "error": f"Input exceeds maximum size of {MAX_INPUT_SIZE} bytes"
        };
    }
    def _do_graph -> dict[str, Any] {
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

"""List available Jac project templates."""
impl CompilerBridge.list_templates -> dict[str, Any] {
    def _do_list_templates -> dict[str, Any] {
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

"""Create a new Jac project from a template."""
impl CompilerBridge.create_project(
    name: str, template: str = "default", directory: str = ""
) -> dict[str, Any] {
    import subprocess;
    import from pathlib { Path }

    if not name {
        return {"success": False, "error": "Project name is required"};
    }

    # Determine working directory
    if directory {
        work_dir = str(Path(directory).resolve());
    } else {
        work_dir = tempfile.gettempdir();
    }

    # Build command
    cmd: list[str] = ["jac", "create", name, "-u", template, "--force"];

    def _do_create -> dict[str, Any] {
        result = subprocess.run(
            cmd, capture_output=True, text=True, cwd=work_dir, timeout=30
        );

        project_path = str(Path(work_dir) / name);

        # List files created
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

"""Start a Jac REST API server as a background process."""
impl CompilerBridge.start_server(
    filename: str, port: int = 8000, faux: bool = False
) -> dict[str, Any] {
    import subprocess;
    import from pathlib { Path }
    import time;

    if not filename {
        return {"error": "Filename is required"};
    }

    filepath = Path(filename);
    if not filepath.exists() {
        return {"error": f"File not found: {filename}"};
    }

    # Run from the file's parent directory so jac.toml is discovered
    project_dir = str(filepath.resolve().parent);
    file_name_only = filepath.name;

    if faux {
        # Faux mode: run jac start --faux synchronously to get endpoint docs
        def _do_faux -> dict[str, Any] {
            result = subprocess.run(
                ["jac", "start", file_name_only, "--faux", "-p", str(port)],
                capture_output=True,
                text=True,
                cwd=project_dir,
                timeout=30
            );
            return {
                "mode": "faux",
                "endpoints": result.stdout,
                "error": result.stderr if result.returncode != 0 else ""
            };
        }
        (success, result) = run_with_timeout(_do_faux, timeout=30);
        if not success {
            return {"mode": "faux", "endpoints": "", "error": str(result)};
        }
        return result;
    }

    # Start server as background process
    try {
        proc = subprocess.Popen(
            ["jac", "start", file_name_only, "-p", str(port)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=project_dir
        );

        # Give it a moment to start or fail
        time.sleep(1.5);

        if proc.poll() is not None {
            # Process already exited - likely an error
            stdout_val = proc.stdout.read().decode() if proc.stdout else "";
            stderr_val = proc.stderr.read().decode() if proc.stderr else "";
            return {
                "error": f"Server exited immediately (code {proc.returncode})",
                "stdout": stdout_val,
                "stderr": stderr_val
            };
        }

        return {
            "url": f"http://localhost:{port}",
            "pid": proc.pid,
            "message": f"Server started on port {port} (PID {proc.pid})"
        };
    } except Exception as e {
        return {"error": f"Failed to start server: {str(e)}"};
    }
}
