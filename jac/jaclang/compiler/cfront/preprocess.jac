import io;
import os;
import jaclang.vendor.pycparser as pycparser;
import from jaclang.vendor.pcpp { Preprocessor, OutputDirective, Action }


class _C2JacPreprocessor(Preprocessor) {
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

        raise OutputDirective(Action.IgnoreAndRemove);
    }
}


def _fake_libc_dir -> str | None {
    base = os.path.dirname(pycparser.__file__);
    cand = os.path.join(base, "utils", "fake_libc_include");
    return cand if os.path.isdir(cand) else None;
}


def _configure_pp(
    filename: str,
    include_dirs: (list[str] | None),
    defines: (list[str] | None),
    undefines: (list[str] | None),
    nostdinc: bool
) -> _C2JacPreprocessor {
    pp = _C2JacPreprocessor();
    pp.c2jac_errors = [];

    pp.line_directive = None;

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
        pp.define(d.replace("=", " ", 1));
    }
    for u in (undefines or []) {
        pp.undef(u);
    }
    return pp;
}


def _run_pp(
    pp: _C2JacPreprocessor,
    c_src: str,
    filename: str,
    force_includes: (list[str] | None)
) -> str {
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


def _object_macros(pp: _C2JacPreprocessor) -> dict[str, list] {
    out: dict[str, list] = {};
    for (name, m) in pp.macros.items() {
        if name.startswith("__") {
            continue;
        }

        if m.arglist is not None {
            continue;
        }
        out[name] = [(t.type, t.value) for t in (m.value or [])];
    }
    return out;
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
    pp = _configure_pp(filename, include_dirs, defines, undefines, nostdinc);
    return _run_pp(pp, c_src, filename, force_includes);
}


def preprocess_c_collect(
    c_src: str,
    filename: str,
    include_dirs: (list[str] | None) = None,
    defines: (list[str] | None) = None,
    undefines: (list[str] | None) = None,
    force_includes: (list[str] | None) = None,
    nostdinc: bool = False
) -> tuple[str, dict] {
    pp = _configure_pp(filename, include_dirs, defines, undefines, nostdinc);
    text = _run_pp(pp, c_src, filename, force_includes);
    return (text, _object_macros(pp));
}
