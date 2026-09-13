import from jaclang.runtime.python.objects { PyObj }
import from jaclang.compiler.frontend.python.syntax_error { syntax_failure }
import from jaclang.runtime.python.compiler_integer { integer_from_marshal }
import from c {
    def jacpy_take_error_text -> u64;  def jacpy_error_is(name: str) -> i64;  def jacpy_parse_long(
        source: str, size: i64
    ) -> u64;  def jacpy_parse_float(source: str, size: i64) -> u64;  def jacpy_float_value(
        handle: u64
    ) -> f64;  def jacpy_normalize(source: str, size: i64) -> u64;  def jacpy_unicode_escape(
        source: str, size: i64
    ) -> u64;  def jacpy_bytes_escape(source: str, size: i64) -> u64;  def jacpy_buffer_size(
        handle: u64
    ) -> i64;  def jacpy_buffer_byte(handle: u64, index: i64) -> i64;  def jacpy_release(
        handle: u64
    );  def jacpy_warning(message: str, filename: str, line: i64) -> i64;
}

obj runtime_failure(Exception) {}

def take_buffer(handle: u64) -> list[int] {
    if handle == 0 {
        raise runtime_failure();
    }
    result: list[int] = [];
    try {
        for index in range(int(jacpy_buffer_size(handle))) {
            result.append(int(jacpy_buffer_byte(handle, i64(index))));
        }
    } finally {
        jacpy_release(handle);
    }
    return result;
}

def take_error_text -> str {
    return bytes(take_buffer(jacpy_take_error_text())).decode("utf-8", "surrogatepass");
}

def normalize_identifier(value: str) -> str {
    return bytes(
        take_buffer(jacpy_normalize(value, i64(len(value.encode("utf-8")))))
    ).decode(
        "utf-8"
    );
}

def decode_unicode(value: str) -> str {
    handle = jacpy_unicode_escape(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and jacpy_error_is("UnicodeError") != 0 {
        raise syntax_failure("(unicode error) " + take_error_text());
    }
    return bytes(take_buffer(handle)).decode("utf-8", "surrogatepass");
}

def decode_bytes(value: str) -> list[int] {
    handle = jacpy_bytes_escape(value, i64(len(value.encode("utf-8"))));
    if handle == 0 and jacpy_error_is("ValueError") != 0 {
        raise syntax_failure(take_error_text());
    }
    return take_buffer(handle);
}

def warn(message: str, filename: str, line: int, column: int = 0) {
    if jacpy_warning(message, filename, i64(line)) < 0 {
        if jacpy_error_is("SyntaxWarning") != 0 {
            take_error_text();
            raise syntax_failure(
                message, filename=filename, lineno=line, offset=column + 1
            );
        }
        raise runtime_failure();
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
        raise runtime_failure();
    }
    try {
        return float(jacpy_float_value(handle));
    } finally {
        jacpy_release(handle);
    }
}
