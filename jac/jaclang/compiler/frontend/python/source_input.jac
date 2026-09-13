"""Decode Python source values using native encoding detection."""
import from jaclang.compiler.frontend.python.source_encoding { source_encoding }
import from jaclang.runtime.python.native_services {
    take_buffer,
    take_error_text,
    runtime_failure,
    jacpy_buffer_size,
    jacpy_buffer_byte
}
import from jaclang.compiler.frontend.python.syntax_error { syntax_failure }
import from c {
    def jacpy_source_kind(handle: u64) -> i64;  def jacpy_error_pending -> i64;  def jacpy_source_bytes(
        handle: u64
    ) -> u64;  def jacpy_utf8(handle: u64) -> u64;  def jacpy_decode(
        handle: u64, encoding: str
    ) -> u64;  def jacpy_error_is(name: str) -> i64;  def jacpy_release(handle: u64);
}

def decode_source_value(source: u64) -> str {
    kind = int(jacpy_source_kind(source));
    if kind < 0 and jacpy_error_pending() != 0 {
        raise runtime_failure();
    }
    if kind < 0 or kind == 2 {
        raise TypeError("source must be a string or bytes object");
    }
    text = "";
    if kind == 0 {
        text = bytes(take_buffer(jacpy_utf8(source))).decode("utf-8", "surrogatepass");
    } else {
        raw = jacpy_source_bytes(source);
        if raw == 0 {
            raise runtime_failure();
        }
        try {
            # Detection inspects compiler-owned bytes; decoding is a retained codec operation.
            data: list[int] = [];
            for index in range(int(jacpy_buffer_size(raw))) {
                data.append(int(jacpy_buffer_byte(raw, i64(index))));
            }
            encoding = source_encoding(bytes(data));
            decoded = jacpy_decode(raw, encoding);
            if decoded == 0 and jacpy_error_is("UnicodeError") != 0 {
                raise syntax_failure(
                    "(unicode error) " + take_error_text(), filename="<string>"
                );
            }
            text = bytes(take_buffer(decoded)).decode("utf-8", "surrogatepass");
        } finally {
            jacpy_release(raw);
        }
    }
    return text;
}
