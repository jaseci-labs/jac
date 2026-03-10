"""Implementation of compiler bridge."""

import from typing { Any }
import tempfile;
import os;
import threading;
import io;
import sys;

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
            compiler = Jac.get_compiler();

            old_stderr = sys.stderr;
            captured = io.StringIO();
            sys.stderr = captured;

            try {
                ir = compiler.compile(tmp_path, program);
            } finally {
                sys.stderr = old_stderr;
            }

            errors: list[dict] = [];
            stderr_output = captured.getvalue();
            if stderr_output.strip() {
                for line in stderr_output.strip().split("\n") {
                    if line.strip() {
                        errors.append({"line": 0, "col": 0, "message": line.strip()});
                    }
                }
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

            old_stderr = sys.stderr;
            captured = io.StringIO();
            sys.stderr = captured;

            try {
                ir = compiler.compile(tmp_path, program);
            } finally {
                sys.stderr = old_stderr;
            }

            errors: list[dict] = [];
            warnings: list[dict] = [];
            stderr_output = captured.getvalue();
            if stderr_output.strip() {
                for line in stderr_output.strip().split("\n") {
                    line = line.strip();
                    if "warning" in line.lower() {
                        warnings.append({"line": 0, "col": 0, "message": line});
                    } elif line {
                        errors.append({"line": 0, "col": 0, "message": line});
                    }
                }
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
            old_stderr = sys.stderr;
            captured = io.StringIO();
            sys.stderr = captured;

            try {
                result_prog = compiler.jac_str_formatter(code, tmp_path);
            } finally {
                sys.stderr = old_stderr;
            }

            if result_prog is None {
                stderr_output = captured.getvalue().strip();
                return {
                    "formatted": code,
                    "changed": False,
                    "error": stderr_output or "Format failed"
                };
            }

            # Get formatted source from the result
            formatted = code;
            if result_prog?.ir and result_prog.ir {
                if result_prog.ir?.source and result_prog.ir.source?.code {
                    formatted = result_prog.ir.source.code;
                }
            } elif result_prog?.source {
                formatted = str(result_prog.source);
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

            old_stderr = sys.stderr;
            captured = io.StringIO();
            sys.stderr = captured;

            try {
                ir = compiler.compile(tmp_path, program);
            } finally {
                sys.stderr = old_stderr;
            }

            warnings: list[str] = [];
            stderr_output = captured.getvalue().strip();
            if stderr_output {
                for line in stderr_output.split("\n") {
                    if line.strip() {
                        warnings.append(line.strip());
                    }
                }
            }

            if ir is None {
                return {"jac_code": "", "warnings": warnings or ["Conversion failed"]};
            }

            # Try to get the unparsed Jac source
            jac_code = "";
            if ir?.source and ir.source?.code {
                jac_code = ir.source.code;
            } elif ir?.gen {
                jac_code = str(ir.gen.jac) if ir.gen?.jac else "";
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
