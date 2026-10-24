impl _root_of(p: str) -> str {
    if p.startswith("//") and not p.startswith("///") {
        return "//";
    }
    if p.startswith("/") {
        return "/";
    }
    return "";
}

impl _parts_of(p: str) -> list[str] {
    out: list[str] = [];
    for comp in p.split("/") {
        if comp == "" or comp == "." {
            continue;
        }
        out.append(comp);
    }
    return out;
}

impl _assemble(anchor: str, parts: list[str]) -> str {
    out: str = anchor + "/".join(parts);
    if out == "" {
        return ".";
    }
    return out;
}

impl _norm(p: str) -> str {
    return _assemble(_root_of(p), _parts_of(p));
}

impl _collapse(p: str) -> str {
    anchor: str = _root_of(p);
    out: list[str] = [];
    for comp in _parts_of(p) {
        if comp != ".." {
            out.append(comp);
            continue;
        }
        if anchor != "" {
            if out {
                out.pop();
            }
            continue;
        }
        if out and out[len(out) - 1] != ".." {
            out.pop();
            continue;
        }
        out.append("..");
    }
    return _assemble(anchor, out);
}

impl Path.init(p: (str | Path) = "") {
    if isinstance(p, Path) {
        self._p = p._p;
    } else {
        self._p = _norm(p);
    }
}

impl Path.__str__ -> str {
    return self._p;
}

impl Path.__truediv__(other: str) -> Path {
    if other.startswith("/") {
        return Path(other);
    }
    if self._p.endswith("/") {
        return Path(self._p + other);
    }
    return Path(self._p + "/" + other);
}

impl Path.exists -> bool {
    return os.path.exists(self._p);
}

impl Path.is_dir -> bool {
    return os.path.isdir(self._p);
}

impl Path.read_bytes -> bytes {
    return read_file_bytes(self._p);
}

impl Path.iterdir -> Iterator[Path] {
    children: list[Path] = [];
    for name in directory_names(self._p) {
        children.append(self / name);
    }
    return iter(children);
}

impl Path.resolve -> Path {
    base: str = self._p;
    if not base.startswith("/") {
        cwd: str = os.getcwd();
        if base == "." {
            base = cwd;
        } else {
            base = cwd + "/" + base;
        }
    }
    return Path(_collapse(os.path.realpath(base)));
}
