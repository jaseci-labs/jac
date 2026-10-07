"""Path helpers for the package manager (POSIX, pure string work)."""

"""Normalise a path: collapse "//", drop "." segments, resolve ".." (an
absolute path never climbs above "/"; a relative one keeps leading "..")."""
def:pub pm_path_normalize(path: str) -> str {
    if path == "" {
        return ".";
    }
    absolute: bool = path.startswith("/");
    out: list[str] = [];
    for seg in path.split("/") {
        if seg == "" or seg == "." {
            continue;
        }
        if seg == ".." {
            if len(out) > 0 and out[len(out) - 1] != ".." {
                del out[len(out) - 1];
            } elif not absolute {
                out.append("..");
            }
            continue;
        }
        out.append(seg);
    }
    joined: str = "/".join(out);
    if absolute {
        return "/" + joined;
    }
    if joined == "" {
        return ".";
    }
    return joined;
}

"""Join `base` and `rel` (an absolute `rel` wins) and normalise."""
def:pub pm_path_join(base: str, rel: str) -> str {
    if rel.startswith("/") {
        return pm_path_normalize(rel);
    }
    if base == "" {
        return pm_path_normalize(rel);
    }
    return pm_path_normalize(base + "/" + rel);
}

"""Relative path from directory `from_dir` to `to_path` (both absolute)."""
def:pub pm_path_relative(from_dir: str, to_path: str) -> str {
    a: list[str] = [];
    b: list[str] = [];
    for seg in pm_path_normalize(from_dir).split("/") {
        if seg != "" {
            a.append(seg);
        }
    }
    for seg in pm_path_normalize(to_path).split("/") {
        if seg != "" {
            b.append(seg);
        }
    }
    i: int = 0;
    while i < len(a) and i < len(b) and a[i] == b[i] {
        i = i + 1;
    }
    out: list[str] = [];
    j: int = i;
    while j < len(a) {
        out.append("..");
        j = j + 1;
    }
    k: int = i;
    while k < len(b) {
        out.append(b[k]);
        k = k + 1;
    }
    if len(out) == 0 {
        return ".";
    }
    return "/".join(out);
}

def:pub pm_path_dirname(path: str) -> str {
    cut: int = path.rfind("/");
    if cut < 0 {
        return ".";
    }
    if cut == 0 {
        return "/";
    }
    return path[0:cut];
}

def:pub pm_path_basename(path: str) -> str {
    cut: int = path.rfind("/");
    if cut < 0 {
        return path;
    }
    return path[cut + 1:];
}

"""Package name without its scope: "@scope/name" → "name"."""
def:pub pm_unscoped_name(name: str) -> str {
    if name.startswith("@") {
        slash: int = name.find("/");
        if slash >= 0 {
            return name[slash + 1:];
        }
    }
    return name;
}

"""bun's `normalizedBinName`: the part after the last '/', '\\' or ':'."""
def:pub pm_normalized_bin_name(name: str) -> str {
    i: int = len(name) - 1;
    while i >= 0 {
        c: str = name[i];
        if c == "/" or c == "\\" or c == ":" {
            return name[i + 1:];
        }
        i = i - 1;
    }
    return name;
}
