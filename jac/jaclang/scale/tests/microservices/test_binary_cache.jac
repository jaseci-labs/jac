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
        )
            == 1;
        assert binmod.download_release_binary("dev", "x86_64") == _payload;
        # Round two fetched only the tiny checksum; the binary came from cache.
        assert len(
            [
                c
                for c in _calls
                if not c.endswith(".sha256")
            ]
        )
            == 1;
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


def _fake_stable_http(url: str) -> bytes {
    import hashlib;
    import json;
    if "api.github.com" in url {
        ver = url.rsplit("/v", 1)[-1];
        return json.dumps(
            {
                "tag_name": f"v{ver}",
                "assets": [
                    {
                        "name": f"jac-{ver}-linux-x86_64",
                        "browser_download_url": f"https://dl.test/{ver}"
                    },
                    {
                        "name": f"jac-{ver}-linux-x86_64.sha256",
                        "browser_download_url": f"https://dl.test/{ver}.sha256"
                    }
                ]
            }
        ).encode();
    }
    payload = f"ELF-{url.rsplit('/', 1)[-1].replace('.sha256', '')}".encode();
    if url.endswith(".sha256") {
        return f"{hashlib.sha256(payload).hexdigest()}  jac".encode();
    }
    return payload;
}


test "two pinned versions keep separate cache entries" {
    import jaclang.scale.injector.binary as binmod;
    import from pathlib { Path }
    cache_dir = tempfile.mkdtemp();
    saved_env = os.environ.get("JAC_SCALE_CACHE_DIR");
    saved_http = binmod._http_get_bytes;
    os.environ["JAC_SCALE_CACHE_DIR"] = cache_dir;
    binmod._http_get_bytes = _fake_stable_http;
    try {
        first = binmod.download_release_binary("stable", "x86_64", "0.34.3");
        second = binmod.download_release_binary("stable", "x86_64", "0.34.4");
        assert first != second;
        # On one shared key the second download would have evicted the first.
        assert binmod.download_release_binary("stable", "x86_64", "0.34.3") == first;
        assert len(list(Path(cache_dir).`glob("jac-stable-*-linux-x86_64"))) == 2;
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
