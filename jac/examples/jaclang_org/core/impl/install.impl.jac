import os;
import hashlib;
import from core.github { fetch }
import from core.timefmt { now_iso, seconds_since }

impl _get_meta -> InstallMeta | None {
    metas = [root.shared-->[?:InstallMeta]];
    return metas[0] if metas else None;
}

impl cache_path -> str {
    return os.path.join(CACHE_DIR, "install.sh");
}

impl _fresh(meta: InstallMeta) -> bool {
    waited = seconds_since(meta.checked_at);
    return waited >= 0.0 and waited < CHECK_TTL_S;
}

impl looks_like_script(text: str) -> bool {
    return text.startswith("#!") and len(text) >= MIN_SCRIPT_BYTES;
}

impl _fetch_script -> str | None {
    data = fetch(INSTALL_SRC, USER_AGENT);
    if data is None {
        return None;
    }
    try {
        text = data.decode("utf-8");
    } except UnicodeDecodeError {
        return None;
    }
    return text if looks_like_script(text) else None;
}

impl _write_cache(text: str) {
    os.makedirs(CACHE_DIR, exist_ok=True);
    tmp = os.path.join(CACHE_DIR, ".install.sh.tmp");
    with open(tmp, "w") as f {
        f.write(text);
    }
    os.replace(tmp, cache_path());
}

impl install_sh -> str {
    path = cache_path();
    if not os.path.exists(path) {
        text = _fetch_script();
        if text is None {
            return UNAVAILABLE_SH;
        }
        _write_cache(text);
    }
    with open(path) as f {
        return f.read();
    }
}

impl ensure_install -> InstallStatus {
    meta = _get_meta();
    if meta is None {
        meta = (root.shared ++> InstallMeta()) as InstallMeta;
    }
    have_file = os.path.exists(cache_path());
    if (_fresh(meta) and have_file) or _pulling {
        return InstallStatus(
            building=_pulling, sha=meta.sha, checked_at=meta.checked_at
        );
    }
    _pulling = True;
    updated = False;
    try {
        text = _fetch_script();
        if text is not None {
            new_sha = hashlib.sha256(text.encode("utf-8")).hexdigest();
            if new_sha != meta.sha or not have_file {
                _write_cache(text);
                meta.sha = new_sha;
                meta.updated_at = now_iso();
                updated = True;
            }
            meta.checked_at = now_iso();
        }
    } finally {
        _pulling = False;
    }
    return InstallStatus(updated=updated, sha=meta.sha, checked_at=meta.checked_at);
}
