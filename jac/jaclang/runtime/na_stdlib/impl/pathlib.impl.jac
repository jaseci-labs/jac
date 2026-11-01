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

impl Path.__truediv__(other: (str | Path)) -> Path {
    tail: str = str(other);
    if tail.startswith("/") {
        return Path(tail);
    }
    if self._p.endswith("/") {
        return Path(self._p + tail);
    }
    return Path(self._p + "/" + tail);
}

impl Path.joinpath(other: (str | Path)) -> Path {
    return self / other;
}

impl Path.__fspath__ -> str {
    return self._p;
}

impl Path.__eq__(other: any) -> bool {
    if isinstance(other, Path) {
        return self._p == other._p;
    }
    return False;
}

impl Path.__hash__ -> int {
    return hash(self._p);
}

impl Path.is_file -> bool {
    return os.path.isfile(self._p);
}

impl Path.is_absolute -> bool {
    return self._p.startswith("/");
}

impl Path.is_relative_to(other: (str | Path)) -> bool {
    base: list[str] = _parts_of(Path(other)._p);
    mine: list[str] = _parts_of(self._p);
    if _root_of(Path(other)._p) != _root_of(self._p) or len(base) > len(mine) {
        return False;
    }
    i: int = 0;
    while i < len(base) {
        if base[i] != mine[i] {
            return False;
        }
        i += 1;
    }
    return True;
}

impl Path.relative_to(other: (str | Path)) -> Path {
    if not self.is_relative_to(other) {
        raise ValueError(f"'{self._p}' is not in the subpath of '{Path(other)._p}'");
    }
    base: list[str] = _parts_of(Path(other)._p);
    mine: list[str] = _parts_of(self._p);
    return Path(_assemble("", mine[len(base):]));
}

impl Path.read_text(encoding: (str | None) = None) -> str {
    return read_file_bytes(self._p).decode(encoding or "utf-8");
}

impl Path.cwd -> Path {
    return Path(os.getcwd());
}

impl Path.suffix.getter -> str {
    nm: str = self.name;
    cut: int = nm.rfind(".");
    if cut <= 0 or cut == len(nm) - 1 {
        return "";
    }
    return nm[cut:];
}

impl Path.parts.getter -> tuple[str, ...] {
    anchor: str = _root_of(self._p);
    out: list[str] = [];
    if anchor != "" {
        out.append(anchor);
    }
    for comp in _parts_of(self._p) {
        out.append(comp);
    }
    return tuple(out);
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

impl Path.name.getter -> str {
    parts: list[str] = _parts_of(self._p);
    if not parts {
        return "";
    }
    return parts[len(parts) - 1];
}

impl Path.stem.getter -> str {
    nm: str = self.name;
    cut: int = nm.rfind(".");
    if cut <= 0 {
        return nm;
    }
    lead: int = 0;
    while lead < cut {
        if nm[lead] != "." {
            return nm[:cut];
        }
        lead += 1;
    }
    return nm;
}

impl Path.parent.getter -> Path {
    parts: list[str] = _parts_of(self._p);
    if not parts {
        return self;
    }
    parts.pop();
    return Path(_assemble(_root_of(self._p), parts));
}
