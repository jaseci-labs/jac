"""Native BOM and coding-cookie detection for Python source input."""
import from jaclang.compiler.frontend.python.syntax_error { syntax_failure }

import from jaclang.runtime.python.native_services { runtime_failure, take_error_text }
import from c {
    def jacpy_codec_valid(name: str) -> i64;  def jacpy_error_is(name: str) -> i64;
}

def normal_encoding(name: str) -> str {
    prefix = name[:12].lower().replace("_", "-");
    if prefix == "utf-8" or prefix.startswith("utf-8-") {
        return "utf-8";
    }
    if prefix in ("latin-1", "iso-8859-1", "iso-latin-1")
        or prefix.startswith("latin-1-")
        or prefix.startswith("iso-8859-1-")
        or prefix.startswith("iso-latin-1-") {
        return "iso-8859-1";
    }
    return name;
}

def cookie_encoding(line: bytes) -> str | None {
    pos = 0;
    while pos < len(line) and line[pos] in (32, 9, 12) {
        pos += 1;
    }
    if pos == len(line) or line[pos] != 35 {
        return None;
    }
    pos += 1;
    while pos + 7 <= len(line) {
        if line[pos:pos + 6] == b"coding" and line[pos + 6] in (58, 61) {
            start = pos + 7;
            while start < len(line) and line[start] in (32, 9) {
                start += 1;
            }
            end = start;
            while end < len(line) {
                ch = line[end];
                if not (
                    (ch >= 65 and ch <= 90)
                    or (ch >= 97 and ch <= 122)
                    or (ch >= 48 and ch <= 57)
                    or ch in (45, 95, 46)
                ) {
                    break;
                }
                end += 1;
            }
            if end > start {
                return normal_encoding(line[start:end].decode("ascii"));
            }
        }
        pos += 1;
    }
    return None;
}

def source_encoding(source: bytes) -> str {
    bom = source[:3] == b"\xef\xbb\xbf";
    start = 3 if bom else 0;
    for line_index in range(2) {
        end = start;
        while end < len(source) and source[end] != 10 {
            end += 1;
        }
        if end < len(source) {
            end += 1;
        }
        line = source[start:end];
        encoding = cookie_encoding(line);
        if encoding is not None {
            if jacpy_codec_valid(encoding) == 0 {
                if jacpy_error_is("LookupError") != 0 {
                    take_error_text();
                    raise syntax_failure("unknown encoding: " + encoding);
                }
                raise runtime_failure();
            }
            if bom and encoding != "utf-8" {
                raise syntax_failure("encoding problem: utf-8");
            }
            return "utf-8-sig" if bom else encoding;
        }
        pos = 0;
        while pos < len(line) and line[pos] in (32, 9, 12) {
            pos += 1;
        }
        if pos < len(line) and line[pos] not in (35, 13, 10) {
            break;
        }
        start = end;
    }
    return "utf-8-sig" if bom else "utf-8";
}

import from jaclang.runtime.python.native_services { take_buffer }
import from c { def jacpy_fd_line(fd: i64) -> u64;  }
def source_fd_encoding(fd: int) -> str {
    first = bytes(take_buffer(jacpy_fd_line(i64(fd))));
    if not first {
        return "utf-8";
    }
    line = first[3:] if first[:3] == b"\xef\xbb\xbf" else first;
    if cookie_encoding(line) is not None {
        return source_encoding(first);
    }
    pos = 0;
    while pos < len(line) and line[pos] in (32, 9, 12) {
        pos += 1;
    }
    if pos < len(line) and line[pos] not in (35, 10, 13) {
        return source_encoding(first);
    }
    second = bytes(take_buffer(jacpy_fd_line(i64(fd))));
    return source_encoding(first + second);
}
