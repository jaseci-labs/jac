impl exists(path: str) -> bool {
    return os.path.exists(path);
}

impl isfile(path: str) -> bool {
    return os.path.isfile(path);
}

impl isdir(s: str) -> bool {
    return os.path.isdir(s);
}

impl realpath(filename: str) -> str {
    return os.path.realpath(filename);
}

impl getsize(filename: str) -> int {
    return os.path.getsize(filename);
}

impl getmtime(filename: str) -> float {
    return os.path.getmtime(filename);
}

impl isabs(s: str) -> bool {
    return s.startswith("/");
}

impl _all_slashes(s: str) -> bool {
    n: int = len(s);
    if n == 0 {
        return False;
    }
    k: int = 0;
    while k < n {
        if s[k] != "/" {
            return False;
        }
        k += 1;
    }
    return True;
}

impl _rstrip_slashes(s: str) -> str {
    end: int = len(s);
    while end > 0 and s[end - 1] == "/" {
        end -= 1;
    }
    return s[:end];
}

impl split(p: str) -> tuple[(str, str)] {
    i: int = p.rfind("/") + 1;
    head: str = p[:i];
    tail: str = p[i:];
    if head and not _all_slashes(head) {
        head = _rstrip_slashes(head);
    }
    return (head, tail);
}

impl dirname(p: str) -> str {
    (head, tail) = split(p);
    return head;
}

impl basename(p: str) -> str {
    (head, tail) = split(p);
    return tail;
}

impl splitext(p: str) -> tuple[(str, str)] {
    sep_index: int = p.rfind("/");
    dot_index: int = p.rfind(".");
    if dot_index > sep_index {
        filename_index: int = sep_index + 1;
        while filename_index < dot_index {
            if p[filename_index] != "." {
                return (p[:dot_index], p[dot_index:]);
            }
            filename_index += 1;
        }
    }
    return (p, "");
}

impl _join2(a: str, b: str) -> str {
    if b.startswith("/") {
        return b;
    }
    if a == "" or a.endswith("/") {
        return a + b;
    }
    return a + "/" + b;
}

impl join(
    a: str,
    p1: (str | None) = None,
    p2: (str | None) = None,
    p3: (str | None) = None,
    p4: (str | None) = None
) -> str {
    out: str = a;
    if p1 is not None {
        out = _join2(out, p1);
    }
    if p2 is not None {
        out = _join2(out, p2);
    }
    if p3 is not None {
        out = _join2(out, p3);
    }
    if p4 is not None {
        out = _join2(out, p4);
    }
    return out;
}

impl abspath(path: str) -> str {
    if not isabs(path) {
        path = join(os.getcwd(), path);
    }
    return normpath(path);
}

impl normcase(s: str) -> str {
    return s;
}

impl relpath(path: str, start: str = ".") -> str {
    if path == "" {
        raise ValueError("no path specified");
    }
    start_list: list[str] = [];
    for seg in abspath(start).split(sep) {
        if seg != "" {
            start_list.append(seg);
        }
    }
    path_list: list[str] = [];
    for seg in abspath(path).split(sep) {
        if seg != "" {
            path_list.append(seg);
        }
    }
    shared: int = 0;
    limit: int = len(start_list);
    if len(path_list) < limit {
        limit = len(path_list);
    }
    while shared < limit and start_list[shared] == path_list[shared] {
        shared += 1;
    }
    rel_list: list[str] = [];
    back: int = len(start_list) - shared;
    while len(rel_list) < back {
        rel_list.append(pardir);
    }
    idx: int = shared;
    while idx < len(path_list) {
        rel_list.append(path_list[idx]);
        idx += 1;
    }
    if not rel_list {
        return curdir;
    }
    return sep.join(rel_list);
}

impl normpath(path: str) -> str {
    if path == "" {
        return ".";
    }
    initial_slashes: int = 0;
    if path.startswith("/") {
        initial_slashes = 1;

        if path.startswith("//") and not path.startswith("///") {
            initial_slashes = 2;
        }
    }
    comps: list[str] = path.split("/");
    new_comps: list[str] = [];
    for comp in comps {
        if comp == "" or comp == "." {
            continue;
        }
        if (
            comp != ".."
            or (initial_slashes == 0 and not new_comps)
            or (new_comps and new_comps[len(new_comps) - 1] == "..")
        ) {
            new_comps.append(comp);
        } elif new_comps {
            new_comps.pop();
        }
    }
    out: str = "/".join(new_comps);
    if initial_slashes == 1 {
        out = "/" + out;
    } elif initial_slashes == 2 {
        out = "//" + out;
    }
    if len(out) == 0 {
        return ".";
    }
    return out;
}

impl expanduser(path: str) -> str {
    if not path.startswith("~") {
        return path;
    }
    end = path.find("/");
    if end < 0 {
        end = len(path);
    }
    home: str | None = None;
    if end == 1 {
        home = os.getenv("HOME");
    }
    if home is None {
        home = user_home(path[1:end]);
    }
    if home is None {
        return path;
    }
    expanded = _rstrip_slashes(home) + path[end:];
    return expanded or "/";
}
