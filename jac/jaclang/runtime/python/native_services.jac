def take_buffer(handle: ptr[PyObject]) -> bytes;

def take_error_text -> str;

def normalize_identifier(value: str) -> str;

def decode_unicode(value: str) -> str;

def decode_bytes(value: str) -> list[int];

def warn(message: str, filename: str, line: int, column: int = 0);

def parse_integer(value: str) -> PyObj;

def parse_float(value: str) -> float;

impl take_buffer(handle: ptr[PyObject]) -> bytes {
    required(handle);
    try {
        return read_buffer(handle);
    } finally {
        jacpy_release(handle);
    }
}

impl take_error_text -> str {
    return take_buffer(jacpy_take_error_text()).decode("utf-8", "surrogatepass");
}

impl normalize_identifier(value: str) -> str {
    text = text_object(value);
    module: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    try {
        module = required(PyImport_ImportModule(ptr[u8]("unicodedata")));
        result = required(PyObject_CallMethod(module, "normalize", "sO", "NFKC", text));
        return text_value(result);
    } finally {
        jacpy_release(result);
        jacpy_release(module);
        jacpy_release(text);
    }
}

impl decode_unicode(value: str) -> str {
    handle = jacpy_unicode_escape(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and PyErr_ExceptionMatches(PyExc_UnicodeError) != 0 {
        raise syntax_failure("(unicode error) " + take_error_text());
    }
    return take_buffer(handle).decode("utf-8", "surrogatepass");
}

impl decode_bytes(value: str) -> list[int] {
    handle = jacpy_bytes_escape(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and PyErr_ExceptionMatches(PyExc_ValueError) != 0 {
        raise syntax_failure(take_error_text());
    }
    return list(take_buffer(handle));
}

impl warn(message: str, filename: str, line: int, column: int = 0) {
    message_text = jacpy_unicode_from_text(message);
    filename_text = jacpy_unicode_from_text(filename);
    status: i32 = -1;
    if message_text and filename_text {
        status = PyErr_WarnExplicit(
            PyExc_SyntaxWarning,
            PyUnicode_AsUTF8(message_text),
            PyUnicode_AsUTF8(filename_text),
            i32(line),
            ptr[u8](),
            NULL
        );
    }
    jacpy_release(filename_text);
    jacpy_release(message_text);
    if status < 0 {
        if PyErr_ExceptionMatches(PyExc_SyntaxWarning) != 0 {
            take_error_text();
            raise syntax_failure(
                message, filename=filename, lineno=line, offset=column + 1
            );
        }
        raise boundary_failure();
    }
}

impl parse_integer(value: str) -> PyObj {
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

impl parse_float(value: str) -> float {
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
