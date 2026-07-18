import json;
import os;

import from pathlib { Path }
import from jaclang.jac0core.sealed { MANIFEST_NAME }

glob SERVE_MANIFEST_REL: str = os.path.join(".jac", "serve_manifest.json"),
     CLIENT_DIST_REL: str = os.path.join(".jac", "client", "dist"),
     NATIVE_DIR_REL: str = os.path.join(".jac", "native");

def sealed_root_for(path: str) -> (str | None) {
    d = os.path.dirname(os.path.normpath(os.path.abspath(path)));
    while True {
        if os.path.isfile(os.path.join(d, "_precompiled", MANIFEST_NAME)) {
            return d;
        }
        parent = os.path.dirname(d);
        if parent == d {
            return None;
        }
        d = parent;
    }
}

def serve_manifest_for(path: str) -> (dict[str, any] | None) {
    img_root = sealed_root_for(path);
    if img_root is None {
        return None;
    }
    mf = os.path.join(img_root, SERVE_MANIFEST_REL);
    if not os.path.isfile(mf) {
        return None;
    }
    try {
        data = json.loads(Path(mf).read_text(encoding="utf-8"));
    } except Exception {
        return None;
    }
    return data if isinstance(data, dict) else None;
}

def client_dist_for(path: str) -> (Path | None) {
    img_root = sealed_root_for(path);
    if img_root is None {
        return None;
    }
    dist = Path(img_root) / CLIENT_DIST_REL;
    if dist.is_dir() and any(dist.glob("client.*.js")) {
        return dist;
    }
    return None;
}
