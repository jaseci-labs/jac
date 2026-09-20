"""Native compiler entry points: each request returns a retained CPython value
or zero with the Python exception set."""
import from jaclang.runtime.python.bindings.pickle { PyInit__pickle }
import from jaclang.runtime.python.bindings.array { PyInit_array }
import from jaclang.runtime.python.bindings.itertools { PyInit_itertools }
import from jaclang.runtime.python.bindings.functools { PyInit__functools }
import from jaclang.runtime.python.bindings.math { PyInit_math }
import from jaclang.runtime.python.bindings.collections { PyInit__collections }
import from jaclang.runtime.python.bindings.struct { PyInit__struct }
import from jaclang.runtime.python.bindings.cmath { PyInit_cmath }

import from jaclang.runtime.python.bindings.csv { PyInit__csv }
import from jaclang.runtime.python.bindings.json { PyInit__json }
import from jaclang.runtime.python.bindings.queue { PyInit__queue }
import from jaclang.runtime.python.bindings.operator { PyInit__operator }
import from jaclang.runtime.python.bindings.binascii { PyInit_binascii }
import from jaclang.runtime.python.bindings.random { PyInit__random }
import from jaclang.runtime.python.bindings.bisect { PyInit__bisect }
import from jaclang.runtime.python.bindings.heapq { PyInit__heapq }
import from jaclang.runtime.python.bindings.statistics { PyInit__statistics }
import from jaclang.runtime.python.tokenize {
    token_iterator_state,
    token_iterator,
    token_object,
    jacpy_token_close
}
import from jaclang.compiler.frontend.python.source_encoding { source_fd_encoding }
import from jaclang.compiler.backends.py.jacpython.product_compile {
    compile_source,
    compile_ast,
    prepare_ast_output
}
import from jaclang.compiler.frontend.python.parser {
    parse_file,
    parse_eval_source,
    parse_interactive,
    parse_func_type
}
import from jaclang.compiler.frontend.python.ast_nodes { mod }
import from jaclang.compiler.frontend.python.syntax_error {
    syntax_failure,
    split_source_lines,
    source_character_column
}
import from jaclang.runtime.python.objects { PyObj, PyCode, PyError, PyInt }
import from jaclang.runtime.python.capi {
    boundary_failure,
    checked,
    required,
    text_object,
    text_value,
    jacpy_int,
    jacpy_none,
    jacpy_tuple_new,
    jacpy_tuple_set_owned,
    jacpy_release
}
import from jaclang.runtime.python.constant_output { constant_object }
import from jaclang.compiler.frontend.python.ast_input { read_node }
import from jaclang.compiler.frontend.python.ast_output { ast_write_node }
import from jaclang.compiler.frontend.python.ast_validation { validate_ast_value }
import from jaclang.runtime.python.symtable {
    source_symtable,
    symtable_to_object,
    SymtableEntry
}
import from jaclang.compiler.frontend.python.compiler_symtable { mangle_name }
import from jaclang.runtime.python.opcode_meta { stack_effect }
import from jaclang.compiler.frontend.python.source_input { decode_source_value }
import from c {
    def jacpy_source_kind(handle: u64) -> i64;  def jacpy_error_pending -> i64;  def jacpy_raise_compiler_error(
        kind: str, message: u64, location: u64
    );
}

glob PyCF_ONLY_AST: int = 1024;

# A request runs its compiler work inside one region: the tokens, trees,
# symbol tables and code units it builds are reclaimed together once the
# CPython result exists. Streaming requests keep state across calls and run
# on the heap.
obj native_request {
    has filename: str = "<string>",
        isolated: bool = True,
        located: bool = True;

    def run -> u64 abst;
}

def serve(request: native_request) -> u64 {
    if not request.isolated {
        return respond(request);
    }
    arena = Region();
    result: u64 = 0;
    in arena {
        result = respond(request);
    }
    return result;
}

# Python exception kinds for failures raised by the compiler implementation.
def respond(request: native_request) -> u64 {
    try {
        return request.run();
    } except syntax_failure as error {
        raise_failure(request, error);
    } except boundary_failure {
        return 0;
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
    return 0;
}

def raise_failure(request: native_request, error: syntax_failure) {
    try {
        message = text_object(error.msg);
        try {
            location: u64 = 0;
            if request.located {
                location = failure_location(request.filename, error);
            }
            try {
                jacpy_raise_compiler_error(error.kind, message, location);
            } finally {
                jacpy_release(location);
            }
        } finally {
            jacpy_release(message);
        }
    } except boundary_failure {}
}

# (filename, lineno, offset, text, end_lineno, end_offset), as SyntaxError args.
def failure_location(filename: str, error: syntax_failure) -> u64 {
    result = required(jacpy_tuple_new(6));
    try {
        checked(jacpy_tuple_set_owned(result, 0, text_object(filename)));
        checked(
            jacpy_tuple_set_owned(result, 1, required(jacpy_int(i64(error.lineno))))
        );
        checked(
            jacpy_tuple_set_owned(result, 2, required(jacpy_int(i64(error.offset))))
        );
        checked(
            jacpy_tuple_set_owned(
                result,
                3,
                text_object(error.text)
                    if error.text is not None
                    else required(jacpy_none())
            )
        );
        checked(
            jacpy_tuple_set_owned(result, 4, required(jacpy_int(i64(error.end_lineno))))
        );
        checked(
            jacpy_tuple_set_owned(result, 5, required(jacpy_int(i64(error.end_offset))))
        );
    } except Exception {
        jacpy_release(result);
        raise;
    }
    return result;
}

# A compiler PyError becomes a located failure over the request source.
def code_result(value: PyObj, source: str, filename: str) -> u64 {
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
) -> u64 {
    output = prepare_ast_output(tree, filename, optimize, flags);
    if isinstance(output, PyObj) {
        return code_result(output, source, filename);
    }
    return ast_write_node(output);
}

obj compile_request(native_request) {
    has source: u64,
        filename_handle: u64,
        mode: str,
        optimize: int,
        flags: int,
        feature: int;

    def run -> u64 {
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

    def compile_text(text: str) -> u64 {
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

    def compile_tree -> u64 {
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
    has source: u64,
        filename_handle: u64,
        mode: str;

    def run -> u64 {
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
    has private: u64,
        name: u64;

    def run -> u64 {
        return text_object(
            mangle_name(text_value(self.private), text_value(self.name))
        );
    }
}

obj fd_encoding_request(native_request) {
    has fd: int;

    def run -> u64 {
        return text_object(source_fd_encoding(self.fd));
    }
}

obj token_request(native_request) {
    has iterator: token_iterator_state;

    def run -> u64 {
        return token_object(self.iterator);
    }
}

def:pub jacpy_compile_object(
    source: u64,
    filename_handle: u64,
    mode: str,
    optimize: int,
    flags: int,
    feature: int
) -> u64 {
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

def:pub jacpy_symtable_object(source: u64, filename_handle: u64, mode: str) -> u64 {
    return serve(
        symtable_request(source=source, filename_handle=filename_handle, mode=mode)
    );
}

def:pub jacpy_mangle(private: u64, name: u64) -> u64 {
    return serve(
        mangle_request(private=private, name=name, isolated=False, located=False)
    );
}

def:pub jacpy_fd_encoding(fd: int) -> u64 {
    return serve(fd_encoding_request(fd=fd, isolated=False, located=False));
}

def:pub jacpy_stack_effect(opcode: int, argument: int, jump: int) -> int {
    effect = stack_effect(opcode, argument, jump);
    return effect if effect is not None else 2147483647;
}

def:pub jacpy_token_create(
    reader: u64, encoding: str, decode: bool, extra: bool
) -> token_iterator_state {
    return token_iterator(reader, encoding, decode, extra);
}

# Zero with no exception set marks the end of the token stream.
def:pub jacpy_token_step(iterator: token_iterator_state) -> u64 {
    return serve(token_request(iterator=iterator, isolated=False));
}

def:pub jacpy_token_dispose(iterator: token_iterator_state) {
    jacpy_token_close(iterator);
}
