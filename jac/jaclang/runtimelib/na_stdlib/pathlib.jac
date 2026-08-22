import os;

def _root_of(p: str) -> str {
    if p.startswith("//") and not p.startswith("///") {
        return "//";
    }
    if p.startswith("/") {
        return "/";
    }
    return "";
}

def _parts_of(p: str) -> list[str] {
    out: list[str] = [];
    for comp in p.split("/") {
        if comp == "" or comp == "." {
            continue;
        }
        out.append(comp);
    }
    return out;
}

def _assemble(anchor: str, parts: list[str]) -> str {
    out: str = anchor + "/".join(parts);
    if out == "" {
        return ".";
    }
    return out;
}

def _norm(p: str) -> str {
    return _assemble(_root_of(p), _parts_of(p));
}

def _collapse(p: str) -> str {
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

obj:pub Path {
    has _p: str = ".";
    has name: str { getter; }
    has stem: str { getter; }
    has parent: Path { getter; }

    def init(p: (str | Path) = "") {
        if isinstance(p, Path) {
            self._p = p._p;
        } else {
            self._p = _norm(p);
        }
    }

    def __str__ -> str {
        return self._p;
    }

    def __truediv__(other: str) -> Path {
        if other.startswith("/") {
            return Path(other);
        }
        if self._p.endswith("/") {
            return Path(self._p + other);
        }
        return Path(self._p + "/" + other);
    }

    def exists -> bool {
        return os.path.exists(self._p);
    }

    def is_dir -> bool {
        return os.path.isdir(self._p);
    }

    def resolve -> Path {
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
