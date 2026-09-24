import os;
import type from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.project.source { JACIGNORE_FILENAME, normalize_exclude_patterns }

glob _JAC_TEXT_ENCODINGS: list[str] = [
         'utf-8-sig',
         'utf-8',
         'utf-16',
         'utf-16le',
         'utf-16be'
     ];

def read_file_with_encoding(file_path: str) -> str {
    for encoding in _JAC_TEXT_ENCODINGS {
        try {
            with open(file_path, encoding=encoding) as f {
                return f.read();
            }
        } except UnicodeError {
            continue;
        } except Exception as e {
            raise OSError(
                f"Could not read file {file_path}: {e}. Report this issue: https://github.com/jaseci-labs/jaseci/issues"
            );
        }
    }
    raise OSError(
        f"Could not read file {file_path} with any encoding. Report this issue:https://github.com/jaseci-labs/jaseci/issues"
    );
}

def read_jacignore_patterns(project_root: str) -> list[str] {
    ignore_file = os.path.join(project_root, JACIGNORE_FILENAME);
    if not os.path.isfile(ignore_file) {
        return [];
    }
    return normalize_exclude_patterns(
        read_file_with_encoding(ignore_file).splitlines()
    );
}

def span_for_file(
    mod_path: str, line: int, col: int, end_col: int = 0, source: str = ''
) -> Span {
    import from jaclang.compiler.frontend.srcloc { Span as SrcSpan }
    bare = SrcSpan(
        mod_path=mod_path,
        first_line=line,
        last_line=line,
        col_start=col,
        col_end=(end_col if end_col > col else col)
    );
    if (line < 1) or (mod_path == '') {
        return bare;
    }
    code = source;
    if (code == '') {
        try {
            code = read_file_with_encoding(mod_path);
        } except Exception {
            return bare;
        }
    }
    fb = code.encode("utf-8");
    flen = len(fb);
    off = 0;
    curr = 1;
    while (curr < line) {
        nl = fb.find(b'\n', off);
        if (nl < 0) {
            return bare;
        }
        off = nl + 1;
        curr += 1;
    }
    start = off + (col - 1 if col > 0 else 0);
    if (start > flen) {
        start = flen;
    }
    stop = off + (end_col - 1) if (end_col > col) else (start + 1);
    if (stop > flen) {
        stop = flen;
    }
    return SrcSpan.make(
        mod_path,
        code,
        (line, line),
        (col, end_col if (end_col > col) else col),
        (start, stop)
    );
}
