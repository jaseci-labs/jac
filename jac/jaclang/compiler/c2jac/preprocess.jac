"""c2jac preprocessing (§8.1): pcpp-driven C preprocessor front-end.

pycparser does NOT run the C preprocessor — it expects an already-expanded
translation unit, and `#include`/`#define`/`#if` reach the parser verbatim and
fail. We default to pcpp (pure-Python), so v1 needs no system C toolchain, and
expose a GCC-compatible flag *surface* (`-I`/`-D`/`-U`/`-include`/`-nostdinc`),
forwarding the subset pcpp understands — not GCC fidelity (§8.1).

Crucially we suppress pcpp's `#line` directives. pycparser *honors* them and
would remap node coords into the ORIGINAL-source space, which no longer matches
the flattened text we hand the driver as `orig_src`. PyastBuildPass slices that
text by node coords (string literals; once, surrogates), so the text and the
coordinate space must agree. Suppressing line markers keeps the preprocessed
output self-consistent — coords index the very text we transpile. The cost is
that Tier-B `c_line` numbers refer to the flattened translation unit, not the
user's original line; acceptable for v1.

Entry point: preprocess_c(c_src, filename, ...) -> str
"""

import io;
import os;
import pycparser;
import from pcpp { Preprocessor, OutputDirective, Action }


class _C2JacPreprocessor(Preprocessor) {
    """pcpp Preprocessor that collects diagnostics instead of only printing
    them, drops unresolved `#include`s (so pycparser never sees a directive),
    and emits no `#line` markers (see module docstring).

    `c2jac_errors` and `line_directive=None` are set by preprocess_c right after
    construction rather than in an override `__init__`: Jac `class` does not give
    a callable `super()` for chaining to Preprocessor.__init__ (which does real
    setup), so we let the base ctor run untouched and stamp our fields after."""
    def on_error(self: _C2JacPreprocessor, file: str, line: int, msg: str) {
        self.c2jac_errors.append(f"{file}:{line}: {msg}");
    }

    def on_include_not_found(
        self: _C2JacPreprocessor,
        is_malformed: bool,
        is_system_include: bool,
        curdir: str,
        includepath: str
    ) {
        kind = "<...>" if is_system_include else '"..."';
        self.c2jac_errors.append(
            f"#include {kind} not found: {includepath} "
            f"(add its dir with -I, or -nostdinc is off and no fake libc is bundled)"
        );
        # Remove the directive so the parser isn't handed raw `#include`; the
        # recorded error makes preprocess_c hard-fail before we transpile.
        raise OutputDirective(Action.IgnoreAndRemove);
    }
}


def _fake_libc_dir -> str | None {
    # pycparser bundles fake system headers (stdio.h, stddef.h, …) under
    # utils/fake_libc_include. Wheels do NOT ship `utils/`, only the git source
    # does, so this is best-effort: present → standard includes resolve without
    # a real libc; absent → a file that includes system headers hard-fails with
    # the on_include_not_found guidance above.
    base = os.path.dirname(pycparser.__file__);
    cand = os.path.join(base, "utils", "fake_libc_include");
    return cand if os.path.isdir(cand) else None;
}


def preprocess_c(
    c_src: str,
    filename: str,
    include_dirs: (list[str] | None) = None,
    defines: (list[str] | None) = None,
    undefines: (list[str] | None) = None,
    force_includes: (list[str] | None) = None,
    nostdinc: bool = False
) -> str {
    # Run the C preprocessor over `c_src` and return the flattened translation
    # unit (no surviving directives), ready for pycparser. Raises ValueError on
    # any preprocessing diagnostic (unknown macro in #if, unterminated #if,
    # unresolved #include) — preprocessing failure is a §8.2 hard failure.
    pp = _C2JacPreprocessor();
    pp.c2jac_errors = [];
    # Suppress `#line N "file"` output so coords index the text we transpile.
    pp.line_directive = None;
    # Default search path: the file's own directory first (so `#include "x.h"`
    # resolves next to it), then the bundled fake libc unless -nostdinc.
    src_dir = os.path.dirname(filename) or ".";
    pp.add_path(src_dir);
    for d in (include_dirs or []) {
        pp.add_path(d);
    }
    if not nostdinc {
        fake = _fake_libc_dir();
        if fake is not None {
            pp.add_path(fake);
        }
    }
    for d in (defines or []) {
        # GCC `-DNAME=VALUE` → pcpp `define("NAME VALUE")`; bare `-DNAME` → "NAME".
        pp.define(d.replace("=", " ", 1));
    }
    for u in (undefines or []) {
        pp.undef(u);
    }
    # `-include hdr` forces a header in before the main source (GCC semantics).
    prefix = "";
    for h in (force_includes or []) {
        prefix += f'#include "{h}"\n';
    }
    out = io.StringIO();
    try {
        pp.parse(prefix + c_src, filename);
        pp.write(out);
    } except OutputDirective {
        pass;
    }
    if pp.c2jac_errors {
        joined = "\n  ".join(pp.c2jac_errors);
        raise ValueError(f"{filename}: preprocessing failed:\n  {joined}");
    }
    return out.getvalue();
}
