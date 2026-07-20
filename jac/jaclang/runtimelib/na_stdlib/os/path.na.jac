import os;

glob sep: str = "/",
     extsep: str = ".",
     pardir: str = "..",
     curdir: str = ".";


def:pub isabs(p: str) -> bool {
    return p.startswith("/");
}


def _all_slashes(s: str) -> bool {
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


def _rstrip_slashes(s: str) -> str {
    end: int = len(s);
    while end > 0 and s[end - 1] == "/" {
        end -= 1;
    }
    return s[:end];
}


def:pub split(p: str) -> tuple[(str, str)] {
    i: int = p.rfind("/") + 1;
    head: str = p[:i];
    tail: str = p[i:];
    if head and not _all_slashes(head) {
        head = _rstrip_slashes(head);
    }
    return (head, tail);
}


def:pub dirname(p: str) -> str {
    (head, tail) = split(p);
    return head;
}


def:pub basename(p: str) -> str {
    (head, tail) = split(p);
    return tail;
}


def:pub splitext(p: str) -> tuple[(str, str)] {
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


def _join2(a: str, b: str) -> str {
    if b.startswith("/") {
        return b;
    }
    if a == "" or a.endswith("/") {
        return a + b;
    }
    return a + "/" + b;
}


def:pub join(
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


def:pub abspath(p: str) -> str {
    if not isabs(p) {
        p = join(os.getcwd(), p);
    }
    return normpath(p);
}


def:pub normpath(p: str) -> str {
    if p == "" {
        return ".";
    }
    initial_slashes: int = 0;
    if p.startswith("/") {
        initial_slashes = 1;

        if p.startswith("//") and not p.startswith("///") {
            initial_slashes = 2;
        }
    }
    comps: list[str] = p.split("/");
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
