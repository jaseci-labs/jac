"""Implementation of compiler bridge."""

import from typing { Any }
import tempfile;
import os;
import threading;

"""Run a function with timeout protection."""
impl run_with_timeout(func: object, timeout: int = 10) -> tuple {
    result_holder: list = [None];
    error_holder: list = [None];
    def _worker -> None {
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
                errors.append({"line": 0, "col": 0, "message": str(e)});
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
                errors.append({"line": 0, "col": 0, "message": str(e)});
            }
            for w in program.warnings_had {
                warnings.append({"line": 0, "col": 0, "message": str(w)});
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
                errors.append({"line": 0, "col": 0, "message": str(e)});
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
