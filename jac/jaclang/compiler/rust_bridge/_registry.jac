import hashlib;
import json;
import os;
import from pathlib { Path }
import from urllib.parse { urljoin, urlparse }
import from urllib.request { urlopen, pathname2url }
import from jaclang.compiler.rust_bridge._finder {
    _cache_root,
    _target_triple,
    _ver_key,
    _matches,
    crate_lib_stem
}


def registry_url -> object {
    return os.environ.get("JAC_BRIDGE_REGISTRY") or None;
}


def _as_url(location: str) -> str {
    if urlparse(location).scheme {
        return location;
    }
    return urljoin("file:", pathname2url(str(Path(location).resolve())));
}


def _index_url(base: str) -> str {
    url = _as_url(base);
    if url.endswith(".json") {
        return url;
    }
    if not url.endswith("/") {
        url = url + "/";
    }
    return urljoin(url, "index.json");
}


def _fetch(url: str) -> bytes {
    with urlopen(url) as resp {
        return resp.read();
    }
}


def fetch_index(base: object = None) -> object {
    base = base if base is not None else registry_url();
    if not base {
        return None;
    }
    raw = _fetch(_index_url(base));
    return json.loads(raw);
}


def resolve_entry(
    index: object, crate: str, constraint: str, triple: object = None
) -> object {
    if not index {
        return None;
    }
    crates = index.get("crates") or {};
    versions = crates.get(crate);
    if not versions {
        return None;
    }
    triple = triple if triple is not None else _target_triple();
    candidates = [
        v
        for v in versions.keys()
        if _matches(v, constraint) and triple in (versions[v] or {})
    ];
    if not candidates {
        return None;
    }
    best = sorted(candidates, key=_ver_key, reverse=True)[0];
    artifact = versions[best][triple];
    return {
        "version": best,
        "url": artifact.get("url"),
        "sha256": artifact.get("sha256")
    };
}


def _install_bytes(crate: str, version: str, filename: str, data: bytes) -> Path {
    dest_dir = _cache_root() / crate / version / _target_triple();
    dest_dir.mkdir(parents=True, exist_ok=True);
    dest = dest_dir / filename;
    tmp = dest.with_name(f"{filename}.{os.getpid()}.tmp");
    tmp.write_bytes(data);
    os.replace(tmp, dest);
    return dest;
}


def fetch_bridge(
    crate: str, constraint: str = "*", verbose: bool = False, base: object = None
) -> object {
    base = base if base is not None else registry_url();
    if not base {
        return None;
    }
    index = fetch_index(base);
    entry = resolve_entry(index, crate, constraint);
    if entry is None {
        return None;
    }
    url = entry["url"];
    if not urlparse(url).scheme {
        url = urljoin(_index_url(base), url);
    }
    data = _fetch(url);

    want = entry["sha256"];
    if want {
        got = hashlib.sha256(data).hexdigest();
        if got != want {
            raise RuntimeError(
                f"rust:{crate} {entry['version']}: sha256 mismatch " + f"(expected {want}, got {got}) from {url}"
            );
        }
    }

    fallback = "libjac_bridge_" + crate_lib_stem(crate) + ".so";
    filename = Path(urlparse(url).path).name or fallback;
    return _install_bytes(crate, entry["version"], filename, data);
}
