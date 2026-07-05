# Drift guard: the D2 ABI constants are declared canonically in Rust
# (bridges/jac-bridge-schema/src/lib.rs) and mirrored by hand in the in-compiler
# Jac parser (jaclang.compiler.rust_bridge._blob). There is no generated header
# tying the two together, so this test parses the Rust schema and asserts every
# shared constant matches the Jac value -- a divergence (someone bumps the ABI or
# renumbers a tag on one side only) fails CI instead of silently miscompiling
# every bridge blob.
import re;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._finder { is_bridge_module }
import from jaclang.jac0core.codeinfo { _is_rust_bridge_module }
import from jaclang.compiler.rust_bridge._blob {
    FN_CTOR,
    FN_METHOD,
    KIND_ERROR,
    KIND_OPAQUE,
    MAGIC,
    SUPPORTED_ABI,
    TAG_BOOL,
    TAG_FN,
    TAG_INT,
    TAG_MAP_BIT,
    TAG_OPT_BIT,
    TAG_REF_BIT,
    TAG_STR,
    TAG_UINT,
    TAG_VOID
}


def _rust_consts -> dict {
    repo = Path(__file__).resolve().parents[4];
    lib_rs = repo / "bridges" / "jac-bridge-schema" / "src" / "lib.rs";
    text = lib_rs.read_text(encoding="utf-8");
    out = {};
    for m in re.finditer(r'pub const (\w+)\s*:\s*[^=]+=\s*([^;]+);', text) {
        (name, raw) = (m.group(1), m.group(2).strip());
        if raw.startswith('b"') {
            # b"JACBRDG1" -> the raw magic bytes.
            out[name] = raw[2:-1].encode("ascii");
        } else {
            # Ints may be hex and carry `_` digit separators (0xFFFF_FFFF).
            out[name] = int(raw.replace("_", ""), 0);
        }
    }
    return out;
}


test "jac ABI constants mirror the canonical rust schema" {
    r = _rust_consts();
    # Sanity: we actually parsed the schema (guards against a moved/renamed file
    # silently turning every assertion below into a vacuous pass).
    assert "MAGIC" in r and "ABI_VERSION" in r , "could not parse jac-bridge-schema/src/lib.rs -- has the file moved?";

    # (rust name in lib.rs, jac value in _blob). SUPPORTED_ABI is the Jac spelling
    # of Rust's ABI_VERSION; every other name is shared verbatim.
    pairs = [
        ("MAGIC", MAGIC),
        ("ABI_VERSION", SUPPORTED_ABI),
        ("TAG_BOOL", TAG_BOOL),
        ("TAG_INT", TAG_INT),
        ("TAG_UINT", TAG_UINT),
        ("TAG_STR", TAG_STR),
        ("TAG_FN", TAG_FN),
        ("TAG_VOID", TAG_VOID),
        ("TAG_REF_BIT", TAG_REF_BIT),
        ("TAG_OPT_BIT", TAG_OPT_BIT),
        ("TAG_MAP_BIT", TAG_MAP_BIT),
        ("KIND_OPAQUE", KIND_OPAQUE),
        ("KIND_ERROR", KIND_ERROR),
        ("FN_CTOR", FN_CTOR),
        ("FN_METHOD", FN_METHOD)
    ];
    for (rust_name, jac_val) in pairs {
        assert rust_name in r , f"schema drift: rust lib.rs no longer defines {rust_name}";
        assert r[rust_name] == jac_val , f"ABI drift on {rust_name}: rust={r[
            rust_name
        ]!r} jac={jac_val!r}";
    }
}


test "codeinfo bridge-namespace mirror tracks the canonical rule" {
    # codeinfo._is_rust_bridge_module is a deliberate zero-dependency copy of
    # rust_bridge.is_bridge_module (it runs during compile bootstrap and cannot
    # import the compiler package). Pin the two together so the copy can't drift.
    samples = [
        "rust.regex",
        "rust.owning",
        "rust.a.b",
        "rust.",
        "rust",
        ".rust.regex",
        "numpy",
        "os",
        "",
        "myrust.regex"
    ];
    for s in samples {
        assert _is_rust_bridge_module(s) == is_bridge_module(s) , f"bridge-namespace mirror drift on {s!r}: " + f"codeinfo={_is_rust_bridge_module(
            s
        )} rust_bridge={is_bridge_module(s)}";
    }
}
