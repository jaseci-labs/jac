import os;
import shutil;
import tempfile;

glob _calls: list[str] = [],
     _payload: bytes = b"ELF-fake-jac";


def _fake_http(url: str) -> bytes {
    import hashlib;
    _calls.append(url);
    if url.endswith(".sha256") {
        digest = hashlib.sha256(_payload).hexdigest();
        return f"{digest}  jac-dev-linux-x86_64".encode();
    }
    return _payload;
}


test "an unchanged release is served from the local cache, not re-downloaded" {
    import jaclang.scale.injector.binary as binmod;
    _calls.clear();
    cache_dir = tempfile.mkdtemp();
    saved_env = os.environ.get("JAC_SCALE_CACHE_DIR");
    saved_http = binmod._http_get_bytes;
    os.environ["JAC_SCALE_CACHE_DIR"] = cache_dir;
    binmod._http_get_bytes = _fake_http;
    try {
        assert binmod.download_release_binary("dev", "x86_64") == _payload;
        assert len(
            [
                c
                for c in _calls
                if not c.endswith(".sha256")
            ]
        ) == 1;
        assert binmod.download_release_binary("dev", "x86_64") == _payload;
        # Round two fetched only the tiny checksum; the binary came from cache.
        assert len(
            [
                c
                for c in _calls
                if not c.endswith(".sha256")
            ]
        ) == 1;
    } finally {
        binmod._http_get_bytes = saved_http;
        if saved_env is None {
            os.environ.pop("JAC_SCALE_CACHE_DIR", None);
        } else {
            os.environ["JAC_SCALE_CACHE_DIR"] = saved_env;
        }
        shutil.rmtree(cache_dir, ignore_errors=True);
    }
}


glob _release_meta_payload: dict = {};


def _fake_release_http(url: str) -> bytes {
    import hashlib;
    import json;
    _calls.append(url);
    if "api.github.com" in url {
        return json.dumps(_release_meta_payload).encode();
    }
    if url.endswith(".sha256") {
        digest = hashlib.sha256(_payload).hexdigest();
        return f"{digest}  asset".encode();
    }
    return _payload;
}


test "a pinned stable release resolves releases/tags and caches by version" {
    import jaclang.scale.injector.binary as binmod;
    _calls.clear();
    _release_meta_payload.clear();
    _release_meta_payload.update(
        {
            "tag_name": "v0.34.2",
            "assets": [
                {
                    "name": "jac-0.34.2-linux-x86_64",
                    "browser_download_url": "https://example.invalid/jac-0.34.2-linux-x86_64"
                },
                {
                    "name": "jac-0.34.2-linux-x86_64.sha256",
                    "browser_download_url": "https://example.invalid/jac-0.34.2-linux-x86_64.sha256"
                }
            ]
        }
    );
    cache_dir = tempfile.mkdtemp();
    saved_env = os.environ.get("JAC_SCALE_CACHE_DIR");
    saved_http = binmod._http_get_bytes;
    os.environ["JAC_SCALE_CACHE_DIR"] = cache_dir;
    binmod._http_get_bytes = _fake_release_http;
    try {
        assert binmod.download_release_binary("stable", "x86_64", "0.34.2") == _payload;
        assert any(["releases/tags/v0.34.2" in c for c in _calls]);
        assert not any(["releases/latest" in c for c in _calls]);
        assert os.path.exists(os.path.join(cache_dir, "jac-0.34.2-linux-x86_64"));
        _calls.clear();
        assert binmod.download_release_binary("stable", "x86_64") == _payload;
        assert any(["releases/latest" in c for c in _calls]);
        assert os.path.exists(os.path.join(cache_dir, "jac-stable-linux-x86_64"));
    } finally {
        binmod._http_get_bytes = saved_http;
        if saved_env is None {
            os.environ.pop("JAC_SCALE_CACHE_DIR", None);
        } else {
            os.environ["JAC_SCALE_CACHE_DIR"] = saved_env;
        }
        shutil.rmtree(cache_dir, ignore_errors=True);
    }
}
