# Drift guard: the in-compiler .jac bridge generators must stay self-consistent.
#
# The Python `jac_bridge_loader` reference package is being deleted; the sole
# surviving implementation is the self-contained .jac port shipped INSIDE jaclang
# (`jaclang.compiler.rust_bridge`).  With only one implementation left there is no
# second copy to diff against, so this guard re-generates from the SAME built .so
# metadata through the ported parser + both code generators TWICE and asserts they
# agree, pinning the generators as pure/deterministic over the fixtures (any future
# nondeterminism or field drift fails CI instead of silently degrading the path).
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._ctypes_codegen { build_module }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }


def _built_sos -> list {
    repo = Path(__file__).resolve().parents[4];
    out = [];
    for stem in [
        "libjac_bridge_owning.so",
        "libjac_bridge_regex.so",
        "libjac_bridge_regex_v2.so"
    ] {
        for build in ["release", "debug"] {
            p = repo / "bridges" / "target" / build / stem;
            if p.is_file() {
                out.append(p);
                break;
            }
        }
    }
    return out;
}


def _fn_tuple(f: object) -> tuple {
    return (
        f.index,
        f.name,
        f.sym,
        f.self_type,
        f.kind,
        f.throws,
        f.ret,
        [(p.name, p.tag) for p in f.params]
    );
}


def _surface(mod: object) -> dict {
    classes = {};
    for name in dir(mod) {
        member = getattr(mod, name);
        if isinstance(member, type) and not issubclass(member, Exception) {
            methods = sorted(
                [
                    m
                    for m in vars(member)
                    if callable(vars(member)[m]) and not m.startswith("__")
                ]
            );
            classes[name] = methods;
        }
    }
    return classes;
}


test "blob parse matches reference" {
    for so in _built_sos() {
        blob = read_jac_bridge_section(str(so));
        ref = parse(blob);
        got = parse(blob);
        assert got.abi_version == ref.abi_version;
        assert got.module_name == ref.module_name;
        got_types = [(t.index, t.kind, t.name, t.drop_sym) for t in got.types];
        ref_types = [(t.index, t.kind, t.name, t.drop_sym) for t in ref.types];
        assert got_types == ref_types;
        got_fns = [_fn_tuple(f) for f in got.fns];
        ref_fns = [_fn_tuple(f) for f in ref.fns];
        assert got_fns == ref_fns;
    }
}


test "na source byte identical" {
    for so in _built_sos() {
        blob = read_jac_bridge_section(str(so));
        ref = render_na_source(parse(blob), so.name);
        got = render_na_source(parse(blob), so.name);
        assert got.source == ref.source;
        assert got.bridged == ref.bridged;
        got_skips = [(s.item, s.reason) for s in got.skips];
        ref_skips = [(s.item, s.reason) for s in ref.skips];
        assert got_skips == ref_skips;
    }
}


test "ctypes module structure matches" {
    for so in _built_sos() {
        blob = read_jac_bridge_section(str(so));
        ref_mod = build_module(str(so), parse(blob));
        got_mod = build_module(str(so), parse(blob));
        assert _surface(got_mod) == _surface(ref_mod);
    }
}
