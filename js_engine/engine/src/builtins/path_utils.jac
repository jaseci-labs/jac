"""
Canonical POSIX path utilities shared by module_resolver.na.jac and modules.na.jac.

These used to be duplicated as private helpers (_normalize_path/_split_path in
modules.na.jac) and module-local copies (mr_normalize_path/mr_split_path/
resolver_path_dirname/mr_path_join in module_resolver.na.jac).  They now live
here so both files can import them without a circular dependency (modules.na.jac
imports from module_resolver.na.jac, so the reverse direction is forbidden).
"""

"""Split a path string by '/' separator."""
def:pub path_split(path: str) -> list[str] {
    parts: list[str] = [];
    cur: str = "";
    i: int = 0;
    while i < len(path) {
        ch: str = path[i];
        if ch == "/" {
            parts.append(cur);
            cur = "";
        } else {
            cur = cur + ch;
        }
        i = i + 1;
    }
    parts.append(cur);
    return parts;
}

"""
Normalize a path: collapse "/./" to "/" and resolve "/../".
Simple implementation — does not handle symlinks.
"""
def:pub path_normalize(path: str) -> str {
    parts: list[str] = path_split(path);
    result: list[str] = [];
    for p in parts {
        if p == "." {
            # skip
        } elif p == ".." {
            if len(result) > 0 and result[len(result) - 1] != "" {
                del result[len(result) - 1];
            }
        } else {
            result.append(p);
        }
    }
    if len(result) == 0 {
        return "/";
    }
    out: str = "";
    i: int = 0;
    while i < len(result) {
        if i > 0 {
            out = out + "/";
        }
        out = out + result[i];
        i = i + 1;
    }
    return out;
}

"""
Extract the directory portion of a file path.
"/a/b/c.js" → "/a/b"
"c.js" → ""
"""
def:pub path_dirname(path: str) -> str {
    # Strip trailing slashes before scanning so dirname("/a/b/") == "/a"
    end: int = len(path);
    while end > 1 and path[end - 1] == "/" {
        end = end - 1;
    }
    last_slash: int = -1;
    i: int = 0;
    while i < end {
        if path[i] == "/" {
            last_slash = i;
        }
        i = i + 1;
    }
    if last_slash < 0 {
        return "";
    }
    if last_slash == 0 {
        return "/";
    }
    return path[0:last_slash];
}

"""Return an absolute path given a potentially-relative path and a cwd string."""
def:pub path_abspath(path: str, cwd: str) -> str {
    if len(path) > 0 and path[0] == "/" {
        return path_normalize(path);
    }
    if cwd == "" {
        return path_normalize(path);
    }
    return path_normalize(cwd + "/" + path);
}
