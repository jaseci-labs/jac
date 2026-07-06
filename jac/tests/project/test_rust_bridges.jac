"""M5 packaging UX — rust-bridge spec parsing, ensure/resolve, and bundle copy.

These exercise the pure plumbing with a *dummy* bridge library placed on
JAC_RUST_BRIDGES_PATH, so nothing here needs the Rust toolchain or the network.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.project.config { JacConfig }
import jaclang.cli.commands.project as project_cmd;


def _write_dummy_bridge(dir: Path, crate: str) -> Path {
    # find_bridge_lib resolves lib{jac_bridge_<crate>}.so on Linux; a dummy file
    # under a JAC_RUST_BRIDGES_PATH entry is enough for copy/resolve tests.
    dir.mkdir(parents=True, exist_ok=True);
    so = dir / f"libjac_bridge_{crate}.so";
    so.write_bytes(b"\x7fELF-dummy");
    return so;
}


test "parse rust spec variants" {
    assert project_cmd._parse_rust_spec("rust:regex") == ("regex", "*");
    assert project_cmd._parse_rust_spec("rust:regex@1.11") == ("regex", "1.11");
    assert project_cmd._parse_rust_spec("rust:regex==1.11") == ("regex", "1.11");
    # surrounding whitespace is trimmed.
    assert project_cmd._parse_rust_spec("rust: uuid @ 1.0 ") == ("uuid", "1.0");
}


test "ensure resolves a cached bridge without building" {
    with TemporaryDirectory() as tmp {
        libdir = Path(tmp) / "libs";
        _write_dummy_bridge(libdir, "regex");
        saved = os.environ.get("JAC_RUST_BRIDGES_PATH");
        os.environ["JAC_RUST_BRIDGES_PATH"] = str(libdir);
        try {
            status = project_cmd._ensure_rust_bridge("regex", "1.11", False);
        } finally {
            if saved is None {
                os.environ.pop("JAC_RUST_BRIDGES_PATH", None);
            } else {
                os.environ["JAC_RUST_BRIDGES_PATH"] = saved;
            }
        }
        assert status == "cached" , status;
    }
}


test "ensure downloads from a file registry on a cache miss" {
    import hashlib;
    import json;
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        # A registry serving one regex artifact for the host triple.
        import from jaclang.compiler.rust_bridge._finder { _target_triple }
        triple = _target_triple();
        payload = b"\x7fELF-dummy";
        art_rel = f"regex/1.12.4/{triple}/libjac_bridge_regex.so";
        art = base / art_rel;
        art.parent.mkdir(parents=True, exist_ok=True);
        art.write_bytes(payload);
        idx = {
            "schema": 1,
            "crates": {
                "regex": {
                    "1.12.4": {
                        triple: {
                            "url": art_rel,
                            "sha256": hashlib.sha256(payload).hexdigest()
                        }
                    }
                }
            }
        };
        (base / "index.json").write_text(json.dumps(idx), encoding="utf-8");
        # Empty cache (fresh XDG) + no dev libs on the path → forces the fetch.
        saved = {};
        for k in ("XDG_CACHE_HOME", "JAC_BRIDGE_REGISTRY", "JAC_RUST_BRIDGES_PATH") {
            saved[k] = os.environ.get(k);
        }
        os.environ["XDG_CACHE_HOME"] = str(base / "cache");
        os.environ["JAC_BRIDGE_REGISTRY"] = str(base);
        os.environ.pop("JAC_RUST_BRIDGES_PATH", None);
        try {
            status = project_cmd._ensure_rust_bridge("regex", "1.12", False);
        } finally {
            for (k, v) in saved.items() {
                if v is None {
                    os.environ.pop(k, None);
                } else {
                    os.environ[k] = v;
                }
            }
        }
        assert status == "downloaded" , status;
    }
}


test "bundle copies configured bridges next to the artifact" {
    with TemporaryDirectory() as tmp {
        libdir = Path(tmp) / "libs";
        _write_dummy_bridge(libdir, "regex");
        _write_dummy_bridge(libdir, "uuid");
        dest = Path(tmp) / "out";
        cfg = JacConfig.from_toml_str(
            "[project]\nname = \"demo\"\n\n[rust-bridges]\nregex = \"1.11\"\nuuid = \"*\"\n"
        );
        saved = os.environ.get("JAC_RUST_BRIDGES_PATH");
        os.environ["JAC_RUST_BRIDGES_PATH"] = str(libdir);
        try {
            copied = project_cmd._copy_rust_bridges(cfg, dest);
        } finally {
            if saved is None {
                os.environ.pop("JAC_RUST_BRIDGES_PATH", None);
            } else {
                os.environ["JAC_RUST_BRIDGES_PATH"] = saved;
            }
        }
        assert copied == 2 , copied;
        bridges = dest / "rust-bridges";
        assert (bridges / "libjac_bridge_regex.so").is_file();
        assert (bridges / "libjac_bridge_uuid.so").is_file();
    }
}


test "find_bridge_lib honors a version constraint over lexicographic order" {
    import from jaclang.compiler.rust_bridge._finder { find_bridge_lib, _target_triple }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        triple = _target_triple();
        # A cache with 1.9.0 and 1.12.4 side by side. Lexicographically "1.9.0"
        # sorts *above* "1.12.4"; numeric ordering must prefer 1.12.4.
        for ver in ("1.9.0", "1.12.4") {
            _write_dummy_bridge(
                base / "cache" / "jac" / "rust-bridges" / "regex" / ver / triple,
                "regex"
            );
        }
        saved = {};
        for k in ("XDG_CACHE_HOME", "JAC_RUST_BRIDGES_PATH") {
            saved[k] = os.environ.get(k);
        }
        os.environ["XDG_CACHE_HOME"] = str(base / "cache");
        os.environ.pop("JAC_RUST_BRIDGES_PATH", None);
        try {
            # Unconstrained: highest numeric version wins, not the lexicographic max.
            hit_any = find_bridge_lib("regex");
            # A 1.9-series constraint must not resolve the 1.12 artifact.
            hit_19 = find_bridge_lib("regex", constraint="1.9");
            # A constraint with no cached match returns None (forcing a fetch/build).
            hit_11 = find_bridge_lib("regex", constraint="1.11");
        } finally {
            for (k, v) in saved.items() {
                if v is None {
                    os.environ.pop(k, None);
                } else {
                    os.environ[k] = v;
                }
            }
        }
        assert hit_any is not None;
        assert "1.12.4" in str(hit_any) , hit_any;
        assert hit_19 is not None and "1.9.0" in str(hit_19) , hit_19;
        assert hit_11 is None , hit_11;
    }
}


test "bundle copies zero bridges when crate is uncached" {
    with TemporaryDirectory() as tmp {
        dest = Path(tmp) / "out";
        cfg = JacConfig.from_toml_str(
            "[project]\nname = \"demo\"\n\n[rust-bridges]\nmissing_crate = \"1.0\"\n"
        );
        saved = os.environ.get("JAC_RUST_BRIDGES_PATH");
        os.environ["JAC_RUST_BRIDGES_PATH"] = str(Path(tmp) / "empty");
        try {
            copied = project_cmd._copy_rust_bridges(cfg, dest);
        } finally {
            if saved is None {
                os.environ.pop("JAC_RUST_BRIDGES_PATH", None);
            } else {
                os.environ["JAC_RUST_BRIDGES_PATH"] = saved;
            }
        }
        assert copied == 0 , copied;
    }
}
