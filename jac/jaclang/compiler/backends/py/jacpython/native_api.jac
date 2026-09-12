"""Native request orchestration; CPython value conversion stays at the ABI."""
import from jaclang.runtime.python.tokenize {
    token_iterator_state,
    token_iterator,
    jacpy_token_next,
    jacpy_token_close
}
import from jaclang.compiler.frontend.python.source_encoding { source_fd_encoding }
import from jaclang.compiler.backends.py.jacpython.marshal_writer {
    marshal_constant,
    marshal_output
}
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
import from jaclang.runtime.python.objects {
    PyObj,
    PyCode,
    PyError,
    PyInt,
    PyStr,
    PyTuple,
    PyNoneType
}
import from jaclang.runtime.python.native_services { runtime_failure }
import from jaclang.compiler.frontend.python.ast_input { read_node }
import from jaclang.compiler.frontend.python.ast_output { ast_write_node }
import from jaclang.compiler.frontend.python.ast_validation { validate_ast_value }
import from jaclang.runtime.python.symtable { source_symtable, symtable_to_object }
import from jaclang.runtime.python.symtable { SymtableEntry }
import from jaclang.compiler.frontend.python.compiler_symtable { mangle_name }
import from jaclang.runtime.python.opcode_meta { stack_effect }
import from jaclang.compiler.frontend.python.ast_output { ast_write_text }
import from jaclang.compiler.frontend.python.source_input { decode_source_value }
import from jaclang.runtime.python.native_services { take_buffer, take_error_text }
import from c {
    def jacpy_source_kind(handle: u64) -> i64;  def jacpy_error_pending -> i64;  def jacpy_raise_error(
        kind: str, message: str, size: i64
    );  def jacpy_source_bytes(handle: u64) -> u64;  def jacpy_utf8(
        handle: u64
    ) -> u64;  def jacpy_decode(handle: u64, encoding: str) -> u64;  def jacpy_error_is(
        name: str
    ) -> i64;  def jacpy_release(handle: u64);
}

import from jaclang.compiler.backends.py.jacpython.request_result {
    native_result,
    error_packet
}

def compiler_result(value: PyObj, source: str, filename: str) -> native_result {
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
        return error_packet(error);
    }
    if not isinstance(value, PyCode) {
        return error_packet(
            syntax_failure(
                "JacPython compiler returned no code object",
                kind="SystemError",
                filename=filename
            )
        );
    }
    return native_result(packet=marshal_constant(value));
}

def:pub jacpy_compile_source(
    source: str, filename: str, mode: str, optimize: int, flags: int, feature: int
) -> native_result {
    try {
        if "\x00" in source {
            return error_packet(
                syntax_failure(
                    "source code string cannot contain null bytes", filename=filename
                )
            );
        }
        if flags & 0x400 {
            version = feature if feature >= 0 else 14;
            tree: mod | None = None;
            if mode == "exec" {
                tree = parse_file(source, filename, flags, version);
            } elif mode == "eval" {
                tree = parse_eval_source(source, filename, flags, version);
            } elif mode == "single" {
                tree = parse_interactive(source, filename, flags, version);
            } elif mode == "func_type" {
                tree = parse_func_type(source, filename, flags, version);
            }
            if tree is None {
                return error_packet(
                    syntax_failure("invalid syntax", filename=filename)
                );
            }
            output = prepare_ast_output(tree, filename, optimize, flags);
            if isinstance(output, PyObj) {
                return compiler_result(output, source, filename);
            }
            return native_result(tree=output);
        }
        return compiler_result(
            compile_source(source, filename, mode, optimize, flags), source, filename
        );
    } except syntax_failure as error {
        return error_packet(error);
    } except runtime_failure {
        return native_result(runtime_error=True);
    } except ValueError as error {
        return error_packet(
            syntax_failure(str(error), kind="ValueError", filename=filename)
        );
    } except TypeError as error {
        return error_packet(
            syntax_failure(str(error), kind="TypeError", filename=filename)
        );
    } except OverflowError as error {
        return error_packet(
            syntax_failure(str(error), kind="OverflowError", filename=filename)
        );
    } except RecursionError as error {
        return error_packet(
            syntax_failure(str(error), kind="RecursionError", filename=filename)
        );
    } except RuntimeError as error {
        return error_packet(
            syntax_failure(str(error), kind="RuntimeError", filename=filename)
        );
    } except Exception as error {
        return error_packet(
            syntax_failure(str(error), kind="SystemError", filename=filename)
        );
    }
}

def:pub jacpy_result_kind(result: native_result) -> int {
    return -1
        if result.runtime_error
        else 3
            if result.eof
            else 2 if result.value_handle != 0 else 1 if result.tree is not None else 0;
}

def:pub jacpy_packet_size(result: native_result) -> int {
    return -1 if result.packet.error else len(result.packet.data);
}

def:pub jacpy_packet_byte(result: native_result, index: int) -> int {
    return result.packet.data[index];
}

def:pub jacpy_compile_ast(
    handle: u64, filename: str, mode: str, optimize: int, flags: int
) -> native_result {
    try {
        tree = read_node(handle);
        validate_ast_value(tree);
        if not isinstance(tree, mod) {
            return error_packet(
                syntax_failure(
                    "AST root does not match compilation mode",
                    kind="TypeError",
                    filename=filename
                )
            );
        }
        if flags & 0x400 {
            output = prepare_ast_output(tree, filename, optimize, flags);
            if isinstance(output, PyObj) {
                return compiler_result(output, "", filename);
            }
            return native_result(tree=output);
        }
        return compiler_result(
            compile_ast(tree, filename, mode, optimize, flags), "", filename
        );
    } except syntax_failure as error {
        return error_packet(error);
    } except runtime_failure {
        return native_result(runtime_error=True);
    } except ValueError as error {
        return error_packet(
            syntax_failure(str(error), kind="ValueError", filename=filename)
        );
    } except TypeError as error {
        return error_packet(
            syntax_failure(str(error), kind="TypeError", filename=filename)
        );
    } except OverflowError as error {
        return error_packet(
            syntax_failure(str(error), kind="OverflowError", filename=filename)
        );
    } except RecursionError as error {
        return error_packet(
            syntax_failure(str(error), kind="RecursionError", filename=filename)
        );
    } except RuntimeError as error {
        return error_packet(
            syntax_failure(str(error), kind="RuntimeError", filename=filename)
        );
    } except Exception as error {
        return error_packet(
            syntax_failure(str(error), kind="SystemError", filename=filename)
        );
    }
}

def:pub jacpy_ast_result(result: native_result) -> u64 {
    if result.tree is None {
        return 0;
    }
    try {
        return ast_write_node(result.tree);
    } except runtime_failure {
        return 0;
    } except Exception as error {
        message = str(error);
        jacpy_raise_error("SystemError", message, i64(len(message.encode("utf-8"))));
        return 0;
    }
}

def:pub jacpy_compile_object(
    source: u64,
    filename_handle: u64,
    mode: str,
    optimize: int,
    flags: int,
    feature: int
) -> native_result {
    filename = "<string>";
    try {
        filename = bytes(take_buffer(jacpy_utf8(filename_handle))).decode(
            "utf-8", "surrogatepass"
        );
        kind = int(jacpy_source_kind(source));
        if kind == 2 {
            return jacpy_compile_ast(source, filename, mode, optimize, flags);
        }
        if kind < 0 and jacpy_error_pending() != 0 {
            raise runtime_failure();
        }
        if kind < 0 {
            return error_packet(
                syntax_failure(
                    "compile() arg 1 must be a string, bytes or AST object",
                    kind="TypeError",
                    filename=filename
                )
            );
        }
        text = decode_source_value(source);
        return jacpy_compile_source(text, filename, mode, optimize, flags, feature);
    } except syntax_failure as error {
        error.filename = filename;
        return error_packet(error);
    } except runtime_failure {
        return native_result(runtime_error=True);
    } except Exception as error {
        return error_packet(
            syntax_failure(str(error), kind="SystemError", filename=filename)
        );
    }
}

def:pub jacpy_take_value(result: native_result) -> u64 {
    handle = result.value_handle;
    result.value_handle = 0;
    return handle;
}

def:pub jacpy_mangle(private: u64, name: u64) -> u64 {
    try {
        private_text = bytes(take_buffer(jacpy_utf8(private))).decode(
            "utf-8", "surrogatepass"
        );
        name_text = bytes(take_buffer(jacpy_utf8(name))).decode(
            "utf-8", "surrogatepass"
        );
        return ast_write_text(mangle_name(private_text, name_text));
    } except runtime_failure {
        return 0;
    } except Exception as error {
        message = str(error);
        jacpy_raise_error("SystemError", message, i64(len(message.encode("utf-8"))));
        return 0;
    }
}

def:pub jacpy_stack_effect(opcode: int, argument: int, jump: int) -> int {
    effect = stack_effect(opcode, argument, jump);
    return effect if effect is not None else 2147483647;
}

def:pub jacpy_symtable(source: str, filename: str, mode: str) -> native_result {
    try {
        result = source_symtable(source, filename, mode);
        if isinstance(result, SymtableEntry) {
            return native_result(value_handle=symtable_to_object(result));
        }
        return compiler_result(result, source, filename);
    } except syntax_failure as error {
        return error_packet(error);
    } except runtime_failure {
        return native_result(runtime_error=True);
    } except Exception as error {
        return error_packet(
            syntax_failure(str(error), kind="SystemError", filename=filename)
        );
    }
}

def:pub jacpy_token_create(
    reader: u64, encoding: str, decode: bool, extra: bool
) -> token_iterator_state {
    return token_iterator(reader, encoding, decode, extra);
}

def:pub jacpy_token_step(iterator: token_iterator_state) -> native_result {
    return jacpy_token_next(iterator);
}

def:pub jacpy_token_dispose(iterator: token_iterator_state) {
    jacpy_token_close(iterator);
}

def:pub jacpy_fd_encoding(fd: int) -> u64 {
    try {
        return ast_write_text(source_fd_encoding(fd));
    } except runtime_failure {
        return 0;
    } except syntax_failure as error {
        jacpy_raise_error(error.kind, error.msg, i64(len(error.msg.encode("utf-8"))));
        return 0;
    } except Exception as error {
        message = str(error);
        jacpy_raise_error("SystemError", message, i64(len(message.encode("utf-8"))));
        return 0;
    }
}

def:pub jacpy_symtable_object(
    source: u64, filename_handle: u64, mode: str
) -> native_result {
    filename = "<string>";
    try {
        filename = bytes(take_buffer(jacpy_utf8(filename_handle))).decode(
            "utf-8", "surrogatepass"
        );
        return jacpy_symtable(decode_source_value(source), filename, mode);
    } except syntax_failure as error {
        error.filename = filename;
        return error_packet(error);
    } except runtime_failure {
        return native_result(runtime_error=True);
    } except Exception as error {
        return error_packet(
            syntax_failure(str(error), kind="TypeError", filename=filename)
        );
    }
}
