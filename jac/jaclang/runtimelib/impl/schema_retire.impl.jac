"""Implementation of the `__jac_schema__` retirement codemod."""

impl _skip_string(src: str, i: int) -> int {
    n = len(src);
    triple = src[i:i + 3];
    if triple == '"""' or triple == "'''" {
        j = i + 3;
        while j < n {
            if src[j] == '\\' {
                j += 2;
                continue;
            }
            if src[j:j + 3] == triple {
                return j + 3;
            }
            j += 1;
        }
        return n;
    }
    q = src[i];
    j = i + 1;
    while j < n {
        if src[j] == '\\' {
            j += 2;
            continue;
        }
        if src[j] == q {
            return j + 1;
        }
        if src[j] == '\n' {
            # Unterminated single-line string; don't run past the line.
            return j;
        }
        j += 1;
    }
    return n;
}


impl match_brace(src: str, open_idx: int) -> int {
    n = len(src);
    depth = 0;
    i = open_idx;
    while i < n {
        c = src[i];
        if c == '#' {
            while i < n and src[i] != '\n' {
                i += 1;
            }
            continue;
        }
        if c == '"' or c == "'" {
            i = _skip_string(src, i);
            continue;
        }
        if c == '{' {
            depth += 1;
        } elif c == '}' {
            depth -= 1;
            if depth == 0 {
                return i;
            }
        }
        i += 1;
    }
    return -1;
}


impl _line_start(src: str, idx: int) -> int {
    return src.rfind('\n', 0, idx) + 1;
}


impl _absorb_leading_doc(src: str, start: int) -> int {
    j = start;
    while j > 0 {
        # Previous line is [ps, pe); src[pe] is the '\n' that ends it.
        pe = j - 1;
        if pe < 0 {
            break;
        }
        ps = src.rfind('\n', 0, pe) + 1;
        line = src[ps:pe];
        s = line.strip();
        if s == '' {
            j = ps;
            continue;
        }
        is_doc = (
            (s.startswith('"""') and s.endswith('"""') and len(s) >= 6)
            or (s.startswith("'''") and s.endswith("'''") and len(s) >= 6)
            or s.startswith('#')
        );
        if is_doc {
            return ps;
        }
        break;
    }
    return j;
}


impl _class_body_span(src: str, class_name: str) -> (tuple | None) {
    m = re.search(r'\b(obj|node|edge|walker)\s+' + re.escape(class_name) + r'\b', src);
    if m is None {
        return None;
    }
    brace = src.find('{', m.end());
    if brace == -1 {
        return None;
    }
    close = match_brace(src, brace);
    if close == -1 {
        return None;
    }
    return (brace + 1, close);
}


impl strip_hook_from_source(src: str, class_name: str) -> tuple {
    removed: list[str] = [];
    out = src;
    # 1) impl <Class>.__jac_schema__ { ... }  (there may be more than one)
    impl_re = r'\bimpl\s+' + re.escape(class_name) + r'\s*\.\s*__jac_schema__\b';
    while True {
        m = re.search(impl_re, out);
        if m is None {
            break;
        }
        brace = out.find('{', m.end());
        if brace == -1 {
            break;
        }
        close = match_brace(out, brace);
        if close == -1 {
            break;
        }
        start = _absorb_leading_doc(out, _line_start(out, cast(int, m.start())));
        end = close + 1;
        if end < len(out) and out[end] == '\n' {
            end += 1;
        }
        removed.append(out[start:end]);
        out = out[:start] + out[end:];
    }
    # 2) static def __jac_schema__ ... ;  inside the class body
    span = _class_body_span(out, class_name);
    if span is not None {
        (bstart, bend) = cast(tuple[int, int], span);
        seg = out[bstart:bend];
        dm = re.search(r'[ \t]*static\s+def\s+__jac_schema__\b[^\n]*;[ \t]*\n?', seg);
        if dm is not None {
            ds = _absorb_leading_doc(
                out, _line_start(out, bstart + cast(int, dm.start()))
            );
            de = bstart + cast(int, dm.end());
            removed.append(out[ds:de]);
            out = out[:ds] + out[de:];
        }
    }
    return (out, removed);
}


impl hook_source_files(search_root: str, class_name: str) -> list[str] {
    hits: list[str] = [];
    cache_marker = os.sep + '.jac' + os.sep;
    for path in Path(search_root).rglob('*.jac') {
        sp = str(path);
        # Skip the Jac bytecode cache; only original sources are editable.
        if cache_marker in sp {
            continue;
        }
        try {
            text = path.read_text(encoding='utf-8');
        } except Exception {
            continue;
        }
        # Candidate iff the codemod would change it: keeps discovery and rewrite
        # in lockstep and idempotent (a stripped file stops matching).
        if '__jac_schema__' not in text {
            continue;
        }
        (_new, removed) = strip_hook_from_source(text, class_name);
        if removed {
            hits.append(sp);
        }
    }
    return sorted(hits);
}
