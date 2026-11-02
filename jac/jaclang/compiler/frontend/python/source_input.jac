"""Decode Python source values using native encoding detection."""

def decode_source_value(source: ptr[PyObject]) -> str {
    kind = int(jacpy_source_kind(source));
    if kind < 0 and jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
    if kind < 0 or kind == 2 {
        raise TypeError("source must be a string or bytes object");
    }
    text = "";
    if kind == 0 {
        text = take_buffer(jacpy_utf8(source)).decode("utf-8", "surrogatepass");
    } else {
        raw = jacpy_source_bytes(source);
        if raw == 0 {
            raise boundary_failure();
        }
        try {
            # Detection inspects compiler-owned bytes; decoding is a retained codec operation.
            encoding = source_encoding(read_buffer(raw));
            decoded = jacpy_decode(raw, encoding);
            if decoded == 0 and PyErr_ExceptionMatches(PyExc_UnicodeError) != 0 {
                raise syntax_failure(
                    "(unicode error) " + take_error_text(), filename="<string>"
                );
            }
            text = take_buffer(decoded).decode("utf-8", "surrogatepass");
        } finally {
            jacpy_release(raw);
        }
    }
    return text;
}
