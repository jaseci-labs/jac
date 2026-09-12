import sys;
import os;
import operator;
import from types { CodeType }
import from jaclang.runtime.python.objects {
    PyObj,
    PyNoneType,
    PyBool,
    PyInt,
    PyFloat,
    PyComplex,
    PyStr,
    PyBytes,
    PyTuple,
    PySet,
    PySlice,
    PyCode,
    PyEllipsis
}

def constant_value(value: PyObj, constants: dict[str, any] | None = None) -> any {
    import from jaclang.compiler.backends.py.jacpython.compiler_ir { constant_key }
    if constants is None {
        constants = {};
    }
    key = constant_key(value);
    if key not in constants {
        constants[key] = _constant_value(value, constants);
    }
    return constants[key];
}

def _constant_value(value: PyObj, constants: dict[str, any]) -> any {
    if isinstance(value, PyNoneType) {
        return None;
    }
    if isinstance(value, PyEllipsis) {
        return ...;
    }
    if isinstance(value, PyBool) {
        return value.val;
    }
    if isinstance(value, PyInt) {
        return value.val;
    }
    if isinstance(value, PyFloat) {
        return value.val;
    }
    if isinstance(value, PyComplex) {
        return complex(value.real, value.imag);
    }
    if isinstance(value, PyStr) {
        return value.val;
    }
    if isinstance(value, PyBytes) {
        return bytes(value.val);
    }
    if isinstance(value, PyTuple) {
        return tuple(constant_value(item, constants) for item in value.items);
    }
    if isinstance(value, PySet) and value.frozen {
        return frozenset(
            constant_value(item, constants) for item in value.items.values()
        );
    }
    if isinstance(value, PySlice) {
        return slice(
            constant_value(value.start, constants),
            constant_value(value.stop, constants),
            constant_value(value.step, constants)
        );
    }
    if isinstance(value, PyCode) {
        return code_object(value, constants);
    }
    raise TypeError(f"Unsupported Python compiler constant: {value.t}");
}

def code_object(code: PyCode, constants: dict[str, any] | None = None) -> CodeType {
    if sys.version_info[:2] != (3, 14) {
        raise RuntimeError("JacPython bytecode requires CPython 3.14");
    }
    if constants is None {
        constants = {};
    }
    result = CodeType(
        code.argcount,
        code.posonlyargcount,
        code.kwonlyargcount,
        len(code.varnames),
        code.stacksize,
        code.flags,
        bytes(code.co_code),
        constant_value(PyTuple(t="tuple", items=code.consts), constants),
        tuple(code.names),
        tuple(code.varnames),
        code.filename,
        code.name,
        code.qualname,
        code.firstlineno,
        bytes(code.linetable),
        bytes(code.exceptiontable),
        tuple(code.freevars),
        tuple(code.cellvars)
    );
    constructor = (sys as any)?._jacpython_code;
    metadata = {};
    for name in code.varnames {
        hidden = not bool(code.flags & 1);
        if name.startswith(".comp.") or hidden {
            public_name = name[6:] if name.startswith(".comp.") else name;
            metadata[name] = (public_name, hidden);
        }
    }
    if metadata {
        if constructor is None {
            raise RuntimeError(
                "Rebuild the Python runtime with JacPython code metadata support"
            );
        }
        result = constructor(result, metadata);
    }
    return result;
}


def compile_python(
    source: any,
    filename: any,
    mode: str,
    flags: int = 0,
    dont_inherit: bool = False,
    optimize: int = -1,
    *,
    _feature_version: int = -1
) -> any {
    import ast;
    import from jaclang.compiler.frontend.python.ast_bridge {
        from_python_ast,
        validate_python_ast,
        to_python_ast
    }
    import from jaclang.compiler.backends.py.jacpython.product_compile {
        compile_source,
        compile_ast,
        prepare_ast_output
    }
    import from jaclang.runtime.python.objects { PyError }
    import from jaclang.compiler.frontend.python.ast_nodes { mod }
    filename = os.fsdecode(os.fspath(filename));
    if "\x00" in filename {
        raise ValueError("embedded null character");
    }
    if not isinstance(mode, str) {
        raise TypeError("compile() argument 'mode' must be str");
    }
    flags = operator.index(flags);
    optimize = operator.index(optimize);
    _feature_version = operator.index(_feature_version);
    if flags < -(1 << 31)
        or flags >= (1 << 31)
        or optimize < -(1 << 31)
        or optimize >= (1 << 31)
        or _feature_version < -(1 << 31)
        or _feature_version >= (1 << 31) {
        raise OverflowError("Python int too large to convert to C int");
    }
    dont_inherit = bool(dont_inherit);
    if mode == "func_type" and not flags & ast.PyCF_ONLY_AST {
        raise ValueError("compile() mode 'func_type' requires flag PyCF_ONLY_AST");
    }
    if mode not in ("exec", "eval", "single", "func_type") {
        raise ValueError("compile() mode must be 'exec', 'eval' or 'single'");
    }
    if flags & ~(0x1FE0000 | 0x10 | 0xF600) {
        raise ValueError("compile(): unrecognised flags");
    }
    if not dont_inherit {
        flags |= sys._getframe(1).f_code.co_flags & 0x1FE0000;
    }
    if optimize == -1 {
        optimize = sys.flags.optimize;
    }
    if optimize not in (0, 1, 2) {
        raise ValueError("compile(): invalid optimize value");
    }
    if isinstance(source, ast.AST) {
        expected_root = {
            "exec": ast.Module,
            "eval": ast.Expression,
            "single": ast.Interactive,
            "func_type": ast.FunctionType
        }[mode];
        if not isinstance(source, expected_root) {
            raise TypeError(
                f"expected {expected_root.__name__} node, got {type(source).__name__}"
            );
        }
        validate_python_ast(source);
        tree = from_python_ast(source);
        if flags & ast.PyCF_ONLY_AST {
            output = prepare_ast_output(tree, filename, optimize, flags);
            if isinstance(output, PyError) {
                raise_compiler_error(output, source, filename);
            }
            return to_python_ast(output, constant_value);
        }
        result = compile_ast(tree, filename, mode, optimize, flags);
    } else {
        if not isinstance(source, str) {
            try {
                raw = bytes(memoryview(source));
            } except TypeError {
                raise TypeError(
                    "compile() arg 1 must be a string, bytes or AST object"
                );
            }
            if b"\x00" in raw {
                raise SyntaxError("source code string cannot contain null bytes");
            }
            # detect_encoding only reads the BOM and the first two coding-cookie
            # lines. It does not invoke CPython's C tokenizer or parser.
            import io;
            import tokenize;
            encoding = tokenize.detect_encoding(io.BytesIO(raw).readline)[0];
            try {
                source = raw.decode(encoding);
            } except UnicodeDecodeError as error {
                raise SyntaxError(str(error));
            }
        }
        if "\x00" in source {
            raise SyntaxError("source code string cannot contain null bytes");
        }
        if flags & ast.PyCF_ONLY_AST {
            import from jaclang.compiler.frontend.python.parser {
                parse_file,
                parse_eval_source,
                parse_interactive,
                parse_func_type
            }
            version = _feature_version if _feature_version >= 0 else 14;
            tree: mod | None = None;
            if mode == "exec" {
                tree = parse_file(source, filename, flags, version);
            } elif mode == "eval" {
                tree = parse_eval_source(source, filename, flags, version);
            } elif mode == "func_type" {
                tree = parse_func_type(source, filename, flags, version);
            } else {
                tree = parse_interactive(source, filename, flags, version);
            }
            if tree is None {
                raise SyntaxError("invalid syntax");
            }
            output = prepare_ast_output(tree, filename, optimize, flags);
            if isinstance(output, PyError) {
                raise_compiler_error(output, source, filename);
            }
            return to_python_ast(output, constant_value);
        }
        result = compile_source(source, filename, mode, optimize, flags);
    }
    if isinstance(result, PyError) {
        raise_compiler_error(result, source, filename);
    }
    if not isinstance(result, PyCode) {
        raise SystemError("JacPython compiler returned no code object");
    }
    return code_object(result);
}

def raise_compiler_error(result: any, source: any, filename: str) {
    import builtins;
    error_type: type[BaseException] = vars(builtins).get(
        result.exception.type_name, RuntimeError
    );
    if issubclass(error_type, SyntaxError)
        and "lineno" in result.exception.type_fields {
        line = constant_value(result.exception.type_fields["lineno"]);
        column = constant_value(result.exception.type_fields["offset"]) - 1;
        lines = source.splitlines(keepends=True) if isinstance(source, str) else [];
        text = lines[line - 1] if line <= len(lines) else None;
        if text is not None {
            column = len(
                text.encode("utf-8")[:column].decode("utf-8", errors="ignore")
            );
        }
        raise error_type(result.exception.message, (filename, line, column + 1, text));
    }
    raise error_type(result.exception.message);
}
