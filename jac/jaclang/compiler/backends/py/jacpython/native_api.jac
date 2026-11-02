"""Native compiler entry points: each request returns a retained CPython value
or zero with the Python exception set."""

# Object-model ports define interpreter types and objects under their C names
# (Objects/boolobject.c: PyBool_Type, _Py_FalseStruct, _Py_TrueStruct).
glob PyCF_ONLY_AST: int = 1024;

# A request runs its compiler work inside one region: the tokens, trees,
# symbol tables and code units it builds are reclaimed together once the
# CPython result exists. Streaming requests keep state across calls and run
# on the heap.
obj native_request {
    has filename: str = "<string>",
        isolated: bool = True,
        located: bool = True;

    def run -> ptr[PyObject] abst;
}

def serve(request: native_request) -> ptr[PyObject] {
    if not request.isolated {
        return respond(request);
    }
    arena = Region();
    result: ptr[PyObject] = NULL;
    in arena {
        result = respond(request);
    }
    return result;
}

# Python exception kinds for failures raised by the compiler implementation.
def respond(request: native_request) -> ptr[PyObject] {
    try {
        return request.run();
    } except syntax_failure as error {
        raise_failure(request, error);
    } except boundary_failure {
        return NULL;
    } except ValueError as error {
        raise_failure(request, syntax_failure(str(error), kind="ValueError"));
    } except TypeError as error {
        raise_failure(request, syntax_failure(str(error), kind="TypeError"));
    } except OverflowError as error {
        raise_failure(request, syntax_failure(str(error), kind="OverflowError"));
    } except RecursionError as error {
        raise_failure(request, syntax_failure(str(error), kind="RecursionError"));
    } except RuntimeError as error {
        raise_failure(request, syntax_failure(str(error), kind="RuntimeError"));
    } except Exception as error {
        raise_failure(request, syntax_failure(str(error), kind="SystemError"));
    }
    return NULL;
}

"""The exception type a compiler diagnostic names; NULL for an unknown kind."""
def:priv failure_type(kind: str) -> ptr[PyObject] {
    if kind == "SyntaxError" {
        return PyExc_SyntaxError;
    } elif kind == "IndentationError" {
        return PyExc_IndentationError;
    } elif kind == "TabError" {
        return PyExc_TabError;
    } elif kind == "_IncompleteInputError" {
        return addressof(_PyExc_IncompleteInputError);
    } elif kind == "ValueError" {
        return PyExc_ValueError;
    } elif kind == "TypeError" {
        return PyExc_TypeError;
    } elif kind == "OverflowError" {
        return PyExc_OverflowError;
    } elif kind == "RecursionError" {
        return PyExc_RecursionError;
    } elif kind == "RuntimeError" {
        return PyExc_RuntimeError;
    } elif kind == "NotImplementedError" {
        return PyExc_NotImplementedError;
    } elif kind == "MemoryError" {
        return PyExc_MemoryError;
    } elif kind == "SystemError" {
        return PyExc_SystemError;
    }
    return NULL;
}

def raise_failure(request: native_request, error: syntax_failure) {
    try {
        message = text_object(error.msg);
        try {
            location: ptr[PyObject] = NULL;
            if request.located {
                location = failure_location(request.filename, error);
            }
            try {
                kind = failure_type(error.kind);
                if kind == 0 {
                    object_error(
                        PyExc_SystemError, "unknown native diagnostic " + error.kind
                    );
                } elif location and PyObject_IsSubclass(kind, PyExc_SyntaxError) > 0 {
                    # A SyntaxError subclass takes CPython's argument shape:
                    # (message, (filename, lineno, offset, text, end_lineno, end_offset)).
                    args = PyTuple_Pack(2, message, location);
                    if args {
                        PyErr_SetObject(kind, args);
                        jacpy_release(args);
                    }
                } else {
                    PyErr_SetObject(kind, message);
                }
            } finally {
                jacpy_release(location);
            }
        } finally {
            jacpy_release(message);
        }
    } except boundary_failure {}
}

# (filename, lineno, offset, text, end_lineno, end_offset), as SyntaxError args.
def failure_location(filename: str, error: syntax_failure) -> ptr[PyObject] {
    result = required(PyTuple_New(6));
    try {
        checked(jacpy_tuple_set_owned(result, 0, text_object(filename)));
        checked(
            jacpy_tuple_set_owned(
                result, 1, required(PyLong_FromLongLong(i64(error.lineno)))
            )
        );
        checked(
            jacpy_tuple_set_owned(
                result, 2, required(PyLong_FromLongLong(i64(error.offset)))
            )
        );
        checked(
            jacpy_tuple_set_owned(
                result,
                3,
                text_object(error.text)
                    if error.text is not None
                    else required(Py_NewRef(Py_None))
            )
        );
        checked(
            jacpy_tuple_set_owned(
                result,
                4,
                required(Py_NewRef(Py_None))
                    if error.open_end
                    else required(PyLong_FromLongLong(i64(error.end_lineno)))
            )
        );
        checked(
            jacpy_tuple_set_owned(
                result,
                5,
                required(Py_NewRef(Py_None))
                    if error.open_end
                    else required(PyLong_FromLongLong(i64(error.end_offset)))
            )
        );
    } except Exception {
        jacpy_release(result);
        raise;
    }
    return result;
}

# A compiler PyError becomes a located failure over the request source.
def code_result(value: PyObj, source: str, filename: str) -> ptr[PyObject] {
    if isinstance(value, PyError) {
        error = syntax_failure(
            value.exception.message, filename=filename, kind=value.exception.type_name
        );
        if "lineno" in value.exception.type_fields {
            error.lineno = (value.exception.type_fields["lineno"] as PyInt).val;
            error.offset = (value.exception.type_fields["offset"] as PyInt).val;
            lines = split_source_lines(source);
            if error.lineno > 0 and error.lineno <= len(lines) {
                line = lines[error.lineno - 1];
                error.text = line;
                error.offset = source_character_column(line, error.offset - 1) + 1;
            }
        }
        raise error;
    }
    if not isinstance(value, PyCode) {
        raise syntax_failure(
            "JacPython compiler returned no code object",
            kind="SystemError",
            filename=filename
        );
    }
    return constant_object(value);
}

def tree_result(
    tree: mod, source: str, filename: str, optimize: int, flags: int
) -> ptr[PyObject] {
    output = prepare_ast_output(tree, filename, optimize, flags);
    if isinstance(output, PyObj) {
        return code_result(output, source, filename);
    }
    return ast_write_node(output);
}

obj compile_request(native_request) {
    has source: ptr[PyObject],
        filename_handle: ptr[PyObject],
        mode: str,
        optimize: int,
        flags: int,
        feature: int;

    def run -> ptr[PyObject] {
        self.filename = text_value(self.filename_handle);
        kind = int(jacpy_source_kind(self.source));
        if kind == 2 {
            return self.compile_tree();
        }
        if kind < 0 and jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        if kind < 0 {
            raise syntax_failure(
                "compile() arg 1 must be a string, bytes or AST object",
                kind="TypeError"
            );
        }
        return self.compile_text(decode_source_value(self.source));
    }

    def compile_text(text: str) -> ptr[PyObject] {
        if "\x00" in text {
            raise syntax_failure("source code string cannot contain null bytes");
        }
        if not (self.flags & PyCF_ONLY_AST) {
            return code_result(
                compile_source(
                    text, self.filename, self.mode, self.optimize, self.flags
                ),
                text,
                self.filename
            );
        }
        version = self.feature if self.feature >= 0 else 14;
        tree: mod | None = None;
        if self.mode == "exec" {
            tree = parse_file(text, self.filename, self.flags, version);
        } elif self.mode == "eval" {
            tree = parse_eval_source(text, self.filename, self.flags, version);
        } elif self.mode == "single" {
            tree = parse_interactive(text, self.filename, self.flags, version);
        } elif self.mode == "func_type" {
            tree = parse_func_type(text, self.filename, self.flags, version);
        }
        if tree is None {
            raise syntax_failure("invalid syntax");
        }
        return tree_result(tree, text, self.filename, self.optimize, self.flags);
    }

    def compile_tree -> ptr[PyObject] {
        # PyAST_obj2mod(): the root must be the mode's node before any field
        # is converted.
        (required_kind, required_name) = {
            "exec": (ast_kind.Module, "Module"),
            "eval": (ast_kind.Expression, "Expression"),
            "single": (ast_kind.Interactive, "Interactive"),
            "func_type": (ast_kind.FunctionType, "FunctionType")
        }[self.mode];
        if int(jacpy_ast_kind(self.source)) != required_kind.value {
            raise syntax_failure(
                f"expected {required_name} node, got {type_name(self.source)}",
                kind="TypeError"
            );
        }
        tree = read_node(self.source);
        validate_ast_value(tree);
        if not isinstance(tree, mod) {
            raise syntax_failure(
                "AST root does not match compilation mode", kind="TypeError"
            );
        }
        if self.flags & PyCF_ONLY_AST {
            return tree_result(tree, "", self.filename, self.optimize, self.flags);
        }
        return code_result(
            compile_ast(tree, self.filename, self.mode, self.optimize, self.flags),
            "",
            self.filename
        );
    }
}

obj symtable_request(native_request) {
    has source: ptr[PyObject],
        filename_handle: ptr[PyObject],
        mode: str;

    def run -> ptr[PyObject] {
        self.filename = text_value(self.filename_handle);
        text = decode_source_value(self.source);
        result = source_symtable(text, self.filename, self.mode);
        if isinstance(result, SymtableEntry) {
            return symtable_to_object(result);
        }
        return code_result(result, text, self.filename);
    }
}

obj mangle_request(native_request) {
    has private: ptr[PyObject],
        name: ptr[PyObject];

    def run -> ptr[PyObject] {
        return text_object(
            mangle_name(text_value(self.private), text_value(self.name))
        );
    }
}

obj fd_encoding_request(native_request) {
    has fd: int;

    def run -> ptr[PyObject] {
        return text_object(source_fd_encoding(self.fd));
    }
}

obj token_request(native_request) {
    has iterator: token_iterator_state;

    def run -> ptr[PyObject] {
        return token_object(self.iterator);
    }
}

def:pub jacpy_compile_object(
    source: ptr[PyObject],
    filename_handle: ptr[PyObject],
    mode: str,
    optimize: int,
    flags: int,
    feature: int
) -> ptr[PyObject] {
    return serve(
        compile_request(
            source=source,
            filename_handle=filename_handle,
            mode=mode,
            optimize=optimize,
            flags=flags,
            feature=feature
        )
    );
}

def:pub jacpy_symtable_object(
    source: ptr[PyObject], filename_handle: ptr[PyObject], mode: str
) -> ptr[PyObject] {
    return serve(
        symtable_request(source=source, filename_handle=filename_handle, mode=mode)
    );
}

def:pub jacpy_mangle(private: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    return serve(
        mangle_request(private=private, name=name, isolated=False, located=False)
    );
}

def:pub jacpy_fd_encoding(fd: int) -> ptr[PyObject] {
    return serve(fd_encoding_request(fd=fd, isolated=False, located=False));
}

def:pub jacpy_stack_effect(opcode: int, argument: int, jump: int) -> int {
    effect = stack_effect(opcode, argument, jump);
    return effect if effect is not None else 2147483647;
}

def:pub jacpy_token_create(
    reader: ptr[PyObject], encoding: str, decode: bool, extra: bool
) -> token_iterator_state {
    return token_iterator(reader, encoding, decode, extra);
}

# Zero with no exception set marks the end of the token stream.
def:pub jacpy_token_step(iterator: token_iterator_state) -> ptr[PyObject] {
    return serve(token_request(iterator=iterator, isolated=False));
}

def:pub jacpy_token_dispose(iterator: token_iterator_state) {
    jacpy_token_close(iterator);
}
