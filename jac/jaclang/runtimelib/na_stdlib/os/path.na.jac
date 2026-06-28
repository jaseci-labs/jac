"""Bundled native `os.path` (POSIX) — pure-Jac Mechanism-B standard library.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issues #6404 / #6940). On the native (na)
pathway `import from os.path { normpath, dirname, ... }` resolves to this
module through the shared bundled-stdlib resolver; on the sv/Python pathway
the identical import binds CPython's real `os.path` (posixpath). The two are
held congruent by the tri-backend equivalence suite (prim_ospath.jac).

WARNING (sv/na congruence is POSIX-only): CPython's `os.path` is `posixpath`
on POSIX hosts but `ntpath` on Windows. This module implements `posixpath`
semantics unconditionally, so on a Windows native target (`nacompile --target
windows`) `import from os.path` would resolve here and silently diverge from
the sv pathway's `ntpath` (backslash separators, drive letters, ...). The
congruence guarantee therefore holds on POSIX targets (Linux/macOS) only; a
bundled `ntpath` plus platform-aware dispatch for Windows native is tracked as
a follow-up under #6940.

These are the pure-string POSIX path helpers — they mirror CPython's
`posixpath` byte-for-byte, including the `normpath`/`split`/`splitext` edge
cases (collapsed slashes, `..` resolution, leading-dot filenames). Functions
that need a syscall (`realpath`, `abspath`, `exists`, ...) are NOT here; they
remain compiler intercepts over libc.
"""

glob sep: str = "/",
     extsep: str = ".",
     pardir: str = "..",
     curdir: str = ".";


"""True if `p` begins with a slash (an absolute POSIX path)."""
def:pub isabs(p: str) -> bool {
    return p.startswith("/");
}


"""True if `s` is non-empty and made up entirely of '/' characters."""
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


"""`s` with any trailing '/' characters removed."""
def _rstrip_slashes(s: str) -> str {
    end: int = len(s);
    while end > 0 and s[end - 1] == "/" {
        end -= 1;
    }
    return s[:end];
}


"""Split `p` into (head, tail) at the last slash. `tail` has no slash; `head`
keeps trailing slashes only when it is all slashes (matches posixpath.split)."""
def:pub split(p: str) -> tuple[(str, str)] {
    i: int = p.rfind("/") + 1;
    head: str = p[:i];
    tail: str = p[i:];
    if head and not _all_slashes(head) {
        head = _rstrip_slashes(head);
    }
    return (head, tail);
}


"""The directory portion of `p` (everything up to, not including, the final
slash) — posixpath.dirname."""
def:pub dirname(p: str) -> str {
    (head, tail) = split(p);
    return head;
}


"""The final component of `p` (after the last slash) — posixpath.basename."""
def:pub basename(p: str) -> str {
    (head, tail) = split(p);
    return tail;
}


"""Split `p` into (root, ext) at the last extension separator in the final
component, ignoring leading dots in the basename — posixpath.splitext."""
def:pub splitext(p: str) -> tuple[(str, str)] {
    sep_index: int = p.rfind("/");
    dot_index: int = p.rfind(".");
    if dot_index > sep_index {
        # Skip leading dots in the basename (e.g. '.cshrc' has no extension).
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


"""Normalize `p`: collapse redundant separators and up-level (`..`) references,
preserving POSIX leading-slash semantics (1, 2, or 3+→1) — posixpath.normpath."""
def:pub normpath(p: str) -> str {
    if p == "" {
        return ".";
    }
    initial_slashes: int = 0;
    if p.startswith("/") {
        initial_slashes = 1;
        # POSIX treats exactly two leading slashes specially; 3+ collapse to 1.
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
