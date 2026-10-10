import from os.path { split, join, isdir }
import from fnmatch { fnmatchcase }
import from _directory_native { try_directory_names }
import from _glob_native { glob_lexists }

def:pub has_magic(s: str) -> bool {
    n: int = len(s);
    i: int = 0;
    while i < n {
        c = s[i];
        if c == "*" or c == "?" or c == "[" {
            return True;
        }
        i += 1;
    }
    return False;
}

def:pub escape(pathname: str) -> str {
    out: str = "";
    n: int = len(pathname);
    i: int = 0;
    while i < n {
        c = pathname[i];
        if c == "*" or c == "?" or c == "[" {
            out += "[";
            out += c;
            out += "]";
        } else {
            out += c;
        }
        i += 1;
    }
    return out;
}

def _ishidden(p: str) -> bool {
    return len(p) > 0 and p[0] == ".";
}

def _isrecursive(pattern: str) -> bool {
    return pattern == "**";
}

def _list_names(dirname: str, dironly: bool) -> list[str] {
    dir: str = dirname;
    if dir == "" {
        dir = ".";
    }
    names = try_directory_names(dir);
    out: list[str] = [];
    for n in names {
        if dironly {
            if not isdir(join(dir, n)) {
                continue;
            }
        }
        out.append(n);
    }
    return sorted(out);
}

def _glob1(
    dirname: str, pattern: str, dironly: bool, include_hidden: bool
) -> list[str] {
    out: list[str] = [];
    show_hidden: bool = include_hidden or _ishidden(pattern);
    for n in _list_names(dirname, dironly) {
        if not show_hidden and _ishidden(n) {
            continue;
        }
        if fnmatchcase(n, pattern) {
            out.append(n);
        }
    }
    return out;
}

def _glob0(dirname: str, basename: str) -> list[str] {
    if basename != "" {
        if glob_lexists(join(dirname, basename)) {
            return [basename];
        }
        return [];
    }
    if isdir(dirname) {
        return [basename];
    }
    return [];
}

def _rlistdir(
    dirname: str, dironly: bool, include_hidden: bool, prefix: str, out: list[str]
) {
    for x in _list_names(dirname, dironly) {
        if not include_hidden and _ishidden(x) {
            continue;
        }
        path: str = x;
        if prefix != "" {
            path = prefix + "/" + x;
        }
        out.append(path);
        sub: str = x;
        if dirname != "" {
            sub = join(dirname, x);
        }
        _rlistdir(sub, dironly, include_hidden, path, out);
    }
}

def _glob2(dirname: str, dironly: bool, include_hidden: bool) -> list[str] {
    out: list[str] = [];
    if dirname == "" or isdir(dirname) {
        out.append("");
    }
    _rlistdir(dirname, dironly, include_hidden, "", out);
    return out;
}

def _iglob(
    pathname: str, recursive: bool, dironly: bool, include_hidden: bool
) -> list[str] {
    out: list[str] = [];
    parts = split(pathname);
    dirname: str = parts[0];
    basename: str = parts[1];
    if not has_magic(pathname) {
        if basename != "" {
            if glob_lexists(pathname) {
                out.append(pathname);
            }
        } elif isdir(dirname) {
            out.append(pathname);
        }
        return out;
    }
    if dirname == "" {
        if recursive and _isrecursive(basename) {
            return _glob2("", dironly, include_hidden);
        }
        return _glob1("", basename, dironly, include_hidden);
    }
    dirs: list[str] = [];
    if has_magic(dirname) {
        dirs = _iglob(dirname, recursive, True, include_hidden);
    } else {
        dirs.append(dirname);
    }
    for d in dirs {
        names: list[str] = [];
        if has_magic(basename) {
            if recursive and _isrecursive(basename) {
                names = _glob2(d, dironly, include_hidden);
            } else {
                names = _glob1(d, basename, dironly, include_hidden);
            }
        } else {
            names = _glob0(d, basename);
        }
        for name in names {
            out.append(join(d, name));
        }
    }
    return out;
}

def _glob_all(pathname: str, recursive: bool, include_hidden: bool) -> list[str] {
    out = _iglob(pathname, recursive, False, include_hidden);
    if pathname == "" or (recursive and _isrecursive(pathname[0:2])) {
        if len(out) > 0 and out[0] == "" {
            res: list[str] = [];
            i: int = 1;
            while i < len(out) {
                res.append(out[i]);
                i += 1;
            }
            return res;
        }
    }
    return out;
}

def:pub `glob(
    pathname: str, recursive: bool = False, include_hidden: bool = False
) -> list[str] {
    return _glob_all(pathname, recursive, include_hidden);
}

def:pub iglob(
    pathname: str, recursive: bool = False, include_hidden: bool = False
) -> list[str] {
    return _glob_all(pathname, recursive, include_hidden);
}
