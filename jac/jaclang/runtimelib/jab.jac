import hashlib;
import io;
import json;
import os;
import shutil;
import tarfile;

import from pathlib { Path }
import from jaclang.jac0core.cache_paths { get_app_cache_dir }
import from jaclang.jac0core.sealed {
    MANIFEST_NAME,
    register_image,
    image_for_bundle_dir
}

glob JAB_SUFFIX: str = ".jab";

def is_jab(path: str) -> bool {
    return path.lower().endswith(JAB_SUFFIX);
}

def materialize_jab(jab_path: str) -> Path {
    return _materialize_jab_data(Path(jab_path).read_bytes(), jab_path);
}

def materialize_jab_bytes(data: bytes) -> Path {
    return _materialize_jab_data(data, "<app image>");
}

def _materialize_jab_data(data: bytes, label: str) -> Path {
    digest = hashlib.sha256(data).hexdigest();
    dest = get_app_cache_dir() / digest[:20];
    manifest_path = dest / "_precompiled" / MANIFEST_NAME;
    if not manifest_path.is_file() {
        tmp = dest.with_suffix(f".{os.getpid()}.tmp");
        shutil.rmtree(tmp, ignore_errors=True);
        tmp.mkdir(parents=True, exist_ok=True);
        try {
            with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tf {
                tf.extractall(tmp, filter="data");
            }
            if not (tmp / "_precompiled" / MANIFEST_NAME).is_file() {
                raise RuntimeError(f"{label} is not a jab: no sealed manifest inside");
            }
            shutil.rmtree(dest, ignore_errors=True);
            tmp.rename(dest);
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }
    bundle_dir = str(dest / "_precompiled");
    if image_for_bundle_dir(bundle_dir) is None
    and register_image(bundle_dir) is None {
        raise RuntimeError(f"{label}: sealed manifest failed to load");
    }
    return dest;
}

def jab_app_meta(img_root: Path) -> dict[str, any] {
    raw = json.loads(
        (img_root / "_precompiled" / MANIFEST_NAME).read_text(encoding="utf-8")
    );
    meta = raw if isinstance(raw, dict) else {};
    return {
        "kind": meta.get("kind", ""),
        "capabilities": meta.get("capabilities") or [],
        "entry": meta.get("entry") or {},
        "package": meta.get("package", "")
    };
}
