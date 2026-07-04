# Test that install_bridge populates the version-scoped cache and that
# find_bridge_lib resolves from it without the dev fallback or
# JAC_RUST_BRIDGES_PATH.
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { install_bridge }
import from jaclang.compiler.rust_bridge._finder { find_bridge_lib }
import from _fixtures { regex_so }


def _regex_path -> object {
    try {
        return Path(regex_so());
    } except FileNotFoundError {
        return None;
    }
}


def _save_env(keys: list) -> dict {
    saved = {};
    for k in keys {
        saved[k] = os.environ.get(k);
    }
    return saved;
}


def _restore_env(saved: dict) {
    for k in saved {
        v = saved[k];
        if v is None {
            os.environ.pop(k, None);
        } else {
            os.environ[k] = v;
        }
    }
}


test "install and find" {
    # install_bridge copies .so into cache; find_bridge_lib resolves it.
    _p = _regex_path();
    if _p is None {
        return;
    }
    td = tempfile.mkdtemp();
    _saved = _save_env(
        ["XDG_CACHE_HOME", "JAC_RUST_BRIDGES_PATH", "JAC_BRIDGE_DEV_FALLBACK"]
    );
    os.environ["XDG_CACHE_HOME"] = td;
    os.environ.pop("JAC_RUST_BRIDGES_PATH", None);
    os.environ.pop("JAC_BRIDGE_DEV_FALLBACK", None);
    try {
        dest = install_bridge(_p, "1.0.0");
        assert dest.is_file() , f"install_bridge did not create {dest}";
        assert dest.name == _p.name;
        found = find_bridge_lib("regex");
        assert found is not None , "find_bridge_lib returned None — cache install did not populate the search path";
        assert found.resolve() == dest.resolve();
    } finally {
        _restore_env(_saved);
        shutil.rmtree(td, ignore_errors=True);
    }
}


test "install version layout" {
    # Cache layout is <cache>/jac/rust-bridges/<crate>/<ver>/<target>/<lib>.
    _p = _regex_path();
    if _p is None {
        return;
    }
    td = tempfile.mkdtemp();
    _saved = _save_env(["XDG_CACHE_HOME"]);
    os.environ["XDG_CACHE_HOME"] = td;
    try {
        dest = install_bridge(_p, "2.3.4");
        parts = dest.parts;
        cache_idx = [
            i
            for i in range(len(parts))
            if parts[i] == "rust-bridges"
        ][0];
        crate = parts[cache_idx + 1];
        version = parts[cache_idx + 2];
        assert crate == "regex";
        assert version == "2.3.4";
    } finally {
        _restore_env(_saved);
        shutil.rmtree(td, ignore_errors=True);
    }
}


test "no fallback without install" {
    # find_bridge_lib returns None when cache is empty and fallback is off.
    td = tempfile.mkdtemp();
    _saved = _save_env(
        ["XDG_CACHE_HOME", "JAC_RUST_BRIDGES_PATH", "JAC_BRIDGE_DEV_FALLBACK"]
    );
    os.environ["XDG_CACHE_HOME"] = td;
    os.environ.pop("JAC_RUST_BRIDGES_PATH", None);
    os.environ.pop("JAC_BRIDGE_DEV_FALLBACK", None);
    try {
        assert find_bridge_lib("regex") is None;
    } finally {
        _restore_env(_saved);
        shutil.rmtree(td, ignore_errors=True);
    }
}
