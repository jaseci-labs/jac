"""Decode Python source values using native encoding detection."""

def invalid_utf8_source_error(
    data: bytes, detail: str, filename: str
) -> tuple[str, int, str] {
    # Match the tokenizer's source error instead of exposing the lower-level
    # UnicodeDecodeError used by the codec boundary.
    marker = "position ";
    marker_at = detail.find(marker);
    position = 0;
    if marker_at >= 0 {
        start = marker_at + len(marker);
        end = start;
        while end < len(detail) and detail[end].isdigit() {
            end += 1;
        }
        if end > start {
            position = int(detail[start:end]);
        }
    }
    position = min(max(position, 0), len(data) - 1);
    byte = data[position] if data else 0;
    line = 1;
    index = 0;
    while index < position {
        if data[index] == 10 {
            line += 1;
        } elif data[index] == 13 and (index + 1 >= position or data[index + 1] != 10) {
            line += 1;
        }
        index += 1;
    }
    line_start = 0;
    current_line = 1;
    while line_start < len(data) and current_line < line {
        if data[line_start] == 13 {
            if line_start + 1 < len(data) and data[line_start + 1] == 10 {
                line_start += 1;
            }
            current_line += 1;
        } elif data[line_start] == 10 {
            current_line += 1;
        }
        line_start += 1;
    }
    line_end = line_start;
    while line_end < len(data) and data[line_end] not in (10, 13) {
        line_end += 1;
    }
    source_text = data[line_start:line_end].decode("utf-8", "replace");
    return (
        f"Non-UTF-8 code starting with '\\x{byte:02x}' in file {filename} on line {line}",
        line,
        source_text
    );
}

def decode_source_value(source: ptr[PyObject], filename: str = "<string>") -> str {
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
                detail = take_error_text();
                if encoding == "utf-8" or encoding == "utf-8-sig" {
                    (message, line, source_text) = invalid_utf8_source_error(
                        read_buffer(raw), detail, filename
                    );
                    raise syntax_failure(
                        message, filename=filename, lineno=line, text=source_text
                    );
                }
                raise syntax_failure("(unicode error) " + detail, filename="<string>");
            }
            text = take_buffer(decoded).decode("utf-8", "surrogatepass");
        } finally {
            jacpy_release(raw);
        }
    }
    return text;
}
