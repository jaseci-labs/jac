impl read_file_with_encoding(file_path: str) -> str {
    with open(file_path, "rb") as f {
        data: bytes = f.read();
    }
    for encoding in _JAC_TEXT_ENCODINGS {
        try {
            text = data.decode(encoding);
        } except UnicodeError {
            continue;
        }
        return text.replace("\r\n", "\n").replace("\r", "\n");
    }
    raise UnicodeError(
        f"Could not decode {file_path} as any of {', '.join(_JAC_TEXT_ENCODINGS)}"
    );
}

impl read_jacignore_patterns(project_root: str) -> list[str] {
    ignore_file = os.path.join(project_root, JACIGNORE_FILENAME);
    if not os.path.isfile(ignore_file) {
        return [];
    }
    return normalize_exclude_patterns(
        read_file_with_encoding(ignore_file).splitlines()
    );
}

impl span_for_file(
    mod_path: str, line: int, col: int, end_col: int = 0, source: str = ''
) -> Span {
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
        if not os.path.isfile(mod_path) {
            return bare;
        }
        code = read_file_with_encoding(mod_path);
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

impl drop_git_ignored(paths: list[str], cwd: str = "") -> list[str] {
    import shutil;
    import subprocess;
    if not paths or shutil.which("git") is None {
        return paths;
    }
    proc = subprocess.run(
        ['git', 'check-ignore', '--stdin'],
        input="\n".join(paths),
        capture_output=True,
        text=True,
        check=False,
        cwd=cwd or None
    );
    if proc.returncode == 128 {
        return paths;
    }
    if proc.returncode != 0 and proc.returncode != 1 {
        raise RuntimeError(
            f"git check-ignore failed ({proc.returncode}) in {cwd or os.getcwd()}: "
                + str(proc.stderr).strip()
        );
    }
    ignored: set[str] = set();
    for line in str(proc.stdout).splitlines() {
        if line {
            ignored.add(line);
        }
    }
    return [
        p
        for p in paths
        if p not in ignored
    ];
}
