import from jaclang.runtime.python.cpython_api {
    PyObject,
    jacpy_bytes_escape,
    jacpy_error_is,
    jacpy_float_value,
    jacpy_normalize,
    jacpy_parse_float,
    jacpy_parse_long,
    jacpy_release,
    jacpy_take_error_text,
    jacpy_unicode_escape,
    jacpy_warning
}
import from jaclang.runtime.python.capi { read_buffer, required, boundary_failure }
import from jaclang.runtime.python.objects { PyObj }
import from jaclang.compiler.frontend.python.syntax_error { syntax_failure }
import from jaclang.runtime.python.compiler_integer { integer_from_marshal }
def take_buffer(handle: ptr[PyObject]) -> bytes {
    required(handle);
    try {
        return read_buffer(handle);
    } finally {
        jacpy_release(handle);
    }
}

def take_error_text -> str {
    return take_buffer(jacpy_take_error_text()).decode("utf-8", "surrogatepass");
}

def normalize_identifier(value: str) -> str {
    return take_buffer(jacpy_normalize(value, i64(len(value.encode("utf-8"))))).decode(
        "utf-8"
    );
}

def decode_unicode(value: str) -> str {
    handle = jacpy_unicode_escape(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and jacpy_error_is("UnicodeError") != 0 {
        raise syntax_failure("(unicode error) " + take_error_text());
    }
    return take_buffer(handle).decode("utf-8", "surrogatepass");
}

def decode_bytes(value: str) -> list[int] {
    handle = jacpy_bytes_escape(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and jacpy_error_is("ValueError") != 0 {
        raise syntax_failure(take_error_text());
    }
    return list(take_buffer(handle));
}

def warn(message: str, filename: str, line: int, column: int = 0) {
    if jacpy_warning(message, filename, i64(line)) < 0 {
        if jacpy_error_is("SyntaxWarning") != 0 {
            take_error_text();
            raise syntax_failure(
                message, filename=filename, lineno=line, offset=column + 1
            );
        }
        raise boundary_failure();
    }
}

def parse_integer(value: str) -> PyObj {
    handle = jacpy_parse_long(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and jacpy_error_is("ValueError") != 0 {
        message = take_error_text();
        if message.startswith("Exceeds the limit ") {
            message += " Consider hexadecimal for huge integer literals to avoid decimal conversion limits.";
        }
        raise syntax_failure(message);
    }
    return integer_from_marshal(take_buffer(handle));
}

def parse_float(value: str) -> float {
    handle = jacpy_parse_float(value, i64(len(value.encode("utf-8"))));
    if handle == 0 {
        if jacpy_error_is("ValueError") != 0 {
            raise syntax_failure(take_error_text());
        }
        raise boundary_failure();
    }
    try {
        return float(jacpy_float_value(handle));
    } finally {
        jacpy_release(handle);
    }
}
