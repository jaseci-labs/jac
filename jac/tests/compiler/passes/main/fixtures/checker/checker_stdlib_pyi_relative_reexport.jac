"""Covers relative .pyi re-export resolution.

In typeshed, `os/__init__.pyi` declares:

    from .path import (
        ... sep as sep, pathsep as pathsep, ...
    )

and the originals live in `posixpath.pyi` as `sep: LiteralString` /
`pathsep: LiteralString`. Resolving `os.pathsep` therefore requires
the module resolver to find the relative sibling stub `os/path.pyi`.

The resolver must honour `.pyi` when handling relative imports -- not
just `.py`/`.jac` -- otherwise the re-exported symbols collapse to
<Unknown> and innocuous calls like `str.split(os.pathsep)` fail with
a misleading E1054 "No matching overload found".
"""
import os;

with entry {
    current_path: str = os.environ.get("PATH", "");
    parts: list[str] = current_path.split(os.pathsep);
    first_sep: str = os.sep;
    print(parts, first_sep);
}
