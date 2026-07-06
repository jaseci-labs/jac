"""M5.4 registry-as-cache resolver — version selection + file:// fetch/verify.

Everything here runs against a local file:// index and a dummy .so, so no
network or Rust toolchain is needed. XDG_CACHE_HOME is redirected to a temp dir
so fetched artifacts land in an isolated cache we can assert on.
"""

import hashlib;
import json;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import jaclang.compiler.rust_bridge._registry as reg;
import from jaclang.compiler.rust_bridge._finder { _target_triple, _cache_root }


def _index(crate: str, versions: dict) -> dict {
    return {"schema": 1, "crates": {crate: versions}};
}


test "version key orders numerically not lexically" {
    assert reg._ver_key("1.12.4") > reg._ver_key("1.9.0");
    assert reg._ver_key("1.11") < reg._ver_key("1.11.4");
    assert reg._ver_key("2.0.0") > reg._ver_key("1.99.99");
}


test "matches honours star, exact, and dotted-prefix" {
    assert reg._matches("1.12.4", "*");
    assert reg._matches("1.12.4", "");
    assert reg._matches("1.12.4", "1.12.4");
    assert reg._matches("1.11.4", "1.11");
    assert not reg._matches("1.110.0", "1.11");
    assert not reg._matches("2.0.0", "1.11");
}


test "resolve_entry picks the highest matching version for this triple" {
    triple = _target_triple();
    idx = _index(
        "regex",
        {
            "1.9.0": {triple: {"url": "a.so", "sha256": "x"}},
            "1.12.4": {triple: {"url": "b.so", "sha256": "y"}},
            "1.11.4": {triple: {"url": "c.so", "sha256": "z"}}
        }
    );
    entry = reg.resolve_entry(idx, "regex", "*");
    assert entry.version == "1.12.4" , entry;
    # A dotted-prefix constraint stays within its series.
    entry2 = reg.resolve_entry(idx, "regex", "1.11");
    assert entry2.version == "1.11.4" , entry2;
}


test "resolve_entry returns None when the host triple is absent" {
    idx = _index(
        "regex", {"1.12.4": {"some-other-triple": {"url": "a.so", "sha256": "x"}}}
    );
    assert reg.resolve_entry(idx, "regex", "*") is None;
    assert reg.resolve_entry(idx, "nope", "*") is None;
}


test "fetch_bridge downloads, verifies, and caches via file://" {
    with TemporaryDirectory() as tmp {
        regdir = Path(tmp);
        triple = _target_triple();
        payload = b"\x7fELF-dummy-bridge";
        digest = hashlib.sha256(payload).hexdigest();
        # Lay out the artifact under the registry dir and describe it in index.json.
        art_rel = f"regex/1.12.4/{triple}/libjac_bridge_regex.so";
        art = regdir / art_rel;
        art.parent.mkdir(parents=True, exist_ok=True);
        art.write_bytes(payload);
        idx = _index("regex", {"1.12.4": {triple: {"url": art_rel, "sha256": digest}}});
        (regdir / "index.json").write_text(json.dumps(idx), encoding="utf-8");
        cache = regdir / "cache";
        saved_xdg = os.environ.get("XDG_CACHE_HOME");
        saved_reg = os.environ.get("JAC_BRIDGE_REGISTRY");
        os.environ["XDG_CACHE_HOME"] = str(cache);
        os.environ["JAC_BRIDGE_REGISTRY"] = str(regdir);
        try {
            dest = reg.fetch_bridge("regex", "1.12");
        } finally {
            _restore("XDG_CACHE_HOME", saved_xdg);
            _restore("JAC_BRIDGE_REGISTRY", saved_reg);
        }
        assert dest is not None;
        assert Path(dest).is_file();
        assert Path(dest).read_bytes() == payload;
        # Landed at the finder's version-scoped cache location.
        expect = cache / "jac" / "rust-bridges" / "regex" / "1.12.4" / triple / "libjac_bridge_regex.so";
        assert Path(dest) == expect , dest;
    }
}


test "fetch_bridge rejects a sha256 mismatch" {
    with TemporaryDirectory() as tmp {
        regdir = Path(tmp);
        triple = _target_triple();
        art_rel = f"regex/1.12.4/{triple}/libjac_bridge_regex.so";
        art = regdir / art_rel;
        art.parent.mkdir(parents=True, exist_ok=True);
        art.write_bytes(b"real-bytes");
        idx = _index(
            "regex", {"1.12.4": {triple: {"url": art_rel, "sha256": "deadbeef"}}}
        );
        (regdir / "index.json").write_text(json.dumps(idx), encoding="utf-8");
        saved_xdg = os.environ.get("XDG_CACHE_HOME");
        saved_reg = os.environ.get("JAC_BRIDGE_REGISTRY");
        os.environ["XDG_CACHE_HOME"] = str(regdir / "cache");
        os.environ["JAC_BRIDGE_REGISTRY"] = str(regdir);
        raised = False;
        try {
            reg.fetch_bridge("regex", "*");
        } except RuntimeError as e {
            raised = "sha256" in str(e);
        } finally {
            _restore("XDG_CACHE_HOME", saved_xdg);
            _restore("JAC_BRIDGE_REGISTRY", saved_reg);
        }
        assert raised;
    }
}


test "fetch_bridge is a no-op when no registry is configured" {
    saved_reg = os.environ.get("JAC_BRIDGE_REGISTRY");
    os.environ.pop("JAC_BRIDGE_REGISTRY", None);
    try {
        assert reg.fetch_bridge("regex", "*") is None;
        assert reg.fetch_index() is None;
    } finally {
        _restore("JAC_BRIDGE_REGISTRY", saved_reg);
    }
}


def _restore(key: str, value: object) {
    if value is None {
        os.environ.pop(key, None);
    } else {
        os.environ[key] = value;
    }
}
