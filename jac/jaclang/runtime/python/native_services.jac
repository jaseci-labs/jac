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

# unicodedata.normalize("NFKC", value), as the tokenizer normalizes a
# non-ASCII identifier.
def normalize_identifier(value: str) -> str {
    text = text_object(value);
    module: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    try {
        module = required(PyImport_ImportModule("unicodedata"));
        result = required(PyObject_CallMethod(module, "normalize", "sO", "NFKC", text));
        return text_value(result);
    } finally {
        jacpy_release(result);
        jacpy_release(module);
        jacpy_release(text);
    }
}

def decode_unicode(value: str) -> str {
    handle = jacpy_unicode_escape(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and PyErr_ExceptionMatches(PyExc_UnicodeError) != 0 {
        raise syntax_failure("(unicode error) " + take_error_text());
    }
    return take_buffer(handle).decode("utf-8", "surrogatepass");
}

def decode_bytes(value: str) -> list[int] {
    handle = jacpy_bytes_escape(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and PyErr_ExceptionMatches(PyExc_ValueError) != 0 {
        raise syntax_failure(take_error_text());
    }
    return list(take_buffer(handle));
}

def warn(message: str, filename: str, line: int, column: int = 0) {
    if PyErr_WarnExplicit(
        PyExc_SyntaxWarning, message, filename, i32(line), ptr[u8](), NULL
    )
        < 0 {
        if PyErr_ExceptionMatches(PyExc_SyntaxWarning) != 0 {
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
    if handle == 0 and PyErr_ExceptionMatches(PyExc_ValueError) != 0 {
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
        if PyErr_ExceptionMatches(PyExc_ValueError) != 0 {
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
