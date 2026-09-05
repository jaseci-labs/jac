"""The native compiler kernel: materialize-once equivalence and seam guards.

The kernel (libjac_compiler) parses natively and hands Python a fully
materialized unitree. The first guard pins the one piece of role knowledge
the kernel exports by name (jc_shape3 covers exactly the roles any getter
shape-consults); the equivalence test runs only where a built kernel lib
is present, and compares the materialized tree against the store parser's
tree for the same source.
"""

import os;

glob SHAPE_EXPORTED: set[str] = {"BodyRole", "SpecRole", "AccessorsRole"};

def _frontend_dir -> (str | None) {
    import jaclang.compiler.frontend as fe;
    f = fe?.__file__;
    if f is None {
        return None;
    }
    return os.path.dirname(os.path.abspath(f));
}

def _shape_consulted_roles -> (set[str] | None) {
    import re;
    base = _frontend_dir();
    if base is None {
        return None;
    }
    pat = re.compile(r"_role_shaped\(\s*(\w+)");
    found: set[str] = set();
    for rel in ("unitree.impl/roles.impl.jac", "impl/unitree.impl.jac") {
        path = os.path.join(base, rel);
        if not os.path.isfile(path) {
            continue;
        }
        with open(path, encoding="utf-8") as f {
            for m in pat.finditer(f.read()) {
                if m.group(1) != "role" {
                    found.add(m.group(1));
                }
            }
        }
    }
    return found;
}

test "every shape-consulted role is exported by the kernel" {
    consulted = _shape_consulted_roles();
    if consulted is None {
        # Sealed image: no source tree to scan; the guard runs in checkouts.
        assert True;
        return;
    }
    assert consulted , "no _role_shaped call sites found; guard is stale";
    assert consulted <= SHAPE_EXPORTED , (
        f"roles {consulted - SHAPE_EXPORTED} are shape-consulted but not "
        "exported by jc_shape3 (jc_unit.jac); extend it and this guard."
    );
}

glob SNIPPET: str = """
obj Point {
    has x: int = 0,
        y: int = 1;

    def dist(other: Point) -> int;
}

impl Point.dist(other: Point) -> int {
    # a comment to carry through
    return abs(self.x - other.x) + abs(self.y - other.y);
}

with entry {
    p = Point(x=3, y=4);
    print(p.dist(Point()));
}
""";

def _profile(nd: any) -> list {
    out: list = [];
    stack = [nd];
    while stack {
        cur = stack.pop();
        row = [`type(cur).__name__];
        v = cur?.value;
        if isinstance(v, str) {
            row.append(v);
        }
        out.append(row);
        kids = list(cur.kid);
        kids.reverse();
        for k in kids {
            stack.append(k);
        }
    }
    return out;
}

test "kernel parse materializes the store parser's tree" {
    import from jaclang.compiler.native_compiler { ensure_loaded }
    kernel = ensure_loaded();
    if kernel is None {
        # No built kernel lib in this tree; nothing to compare against.
        assert True;
    } else {
        import from jaclang.compiler.frontend.parser.frontend { parse, parse_woven }
        (nat_mod, nat_err) = parse_woven(SNIPPET, "kernel_eq.jac", None, []);
        (py_mod, py_err) = parse(SNIPPET, "kernel_eq.jac");
        assert nat_err == py_err;
        assert kernel.skipped() == 0 , (
            "kernel skipped objects during materialization"
        );
        nat_prof = _profile(nat_mod);
        py_prof = _profile(py_mod);
        assert len(nat_prof) == len(py_prof);
        assert nat_prof == py_prof;
    }
}


def _rss_kb -> (int | None) {
    try {
        with open("/proc/self/status", encoding="utf-8") as f {
            for line in f {
                if line.startswith("VmRSS:") {
                    return int(line.split()[1]);
                }
            }
        }
    } except OSError {
        return None;
    }
    return None;
}

def _parse_and_drop(src: str, path: str) {
    import from jaclang.compiler.frontend.parser.frontend { parse_woven }
    parse_woven(src, path, None, []);
}

def _kernel_growth_mb(src: str, path: str, rounds: int) -> (float | None) {
    import gc;
    _parse_and_drop(src, path);
    gc.collect();
    start = _rss_kb();
    for _i in range(rounds) {
        _parse_and_drop(src, path);
        gc.collect();
    }
    end = _rss_kb();
    if start is None or end is None {
        return None;
    }
    return (end - start) / 1024.0;
}

test "kernel parses retain no native memory once the tree is handed over" {
    import from jaclang.compiler.native_compiler { ensure_loaded }
    kernel = ensure_loaded();
    base = _frontend_dir();
    src_path = os.path.join(base, "unitree.jac") if base is not None else "";
    if kernel is None or not src_path or not os.path.isfile(src_path) {
        # No built kernel or no source tree to parse; the guard runs in checkouts.
        assert True;
    } else {
        with open(src_path, encoding="utf-8") as f {
            src = f.read();
        }
        grown = _kernel_growth_mb(src, src_path, 4);
        if grown is None {
            # No /proc on this host; nothing to measure.
            assert True;
        } else {
            assert grown < 40.0 , (
                f"four kernel parses of unitree.jac grew RSS by {grown:.0f} MB; "
                "the parse region is not being dropped at the end of jc_run"
            );
        }
    }
}


test "JAC_COMPILER_LIB=off selects the store parser: no kernel is resolved" {
    # The explicit switch is the first step of `resolve_kernel`'s precedence
    # (`kernel_resolve.jac`): `off` means no kernel, before a sealed image or
    # the source tree is consulted, so `ensure_loaded` serves the store parser.
    import from jaclang.compiler.backends.native.kernel_resolve {
        KERNEL_LIB_ENV,
        resolve_kernel
    }
    import from jaclang.compiler.native_compiler { ensure_loaded, reset_loaded }
    saved = os.environ.get(KERNEL_LIB_ENV);
    reset_loaded();
    try {
        os.environ[KERNEL_LIB_ENV] = "off";
        assert resolve_kernel() is None , "JAC_COMPILER_LIB=off must resolve no kernel";
        assert ensure_loaded() is None , "ensure_loaded must serve no kernel under the off switch";
    } finally {
        if saved is None {
            os.environ.pop(KERNEL_LIB_ENV, None);
        } else {
            os.environ[KERNEL_LIB_ENV] = saved;
        }
        reset_loaded();
    }
}
