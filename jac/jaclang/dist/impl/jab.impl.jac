impl is_jab(path: str) -> bool {
    return path.lower().endswith(JAB_SUFFIX);
}

impl materialize_jab(jab_path: str) -> Path {
    return _materialize_jab_data(
        lambda { Path(jab_path).read_bytes(); }, jab_path, file_sha256(jab_path)
    );
}

impl materialize_jab_bytes(data: bytes, expected_sha256: str = "") -> Path {
    return _materialize_jab_data(lambda { data; }, "<app image>", expected_sha256);
}

impl _materialize_jab_data(
    load: Callable[[], bytes], label: str, expected_sha256: str = ""
) -> Path {
    """The extraction directory is addressed by the image's sha256, and an
    image is only renamed into it after its bytes matched that digest, so a
    present directory needs no re-hash.""";
    data: (bytes | None) = None;
    digest = expected_sha256;
    if not digest {
        data = load();
        digest = hashlib.sha256(data).hexdigest();
    }
    dest = bucket("apps").path() / digest[:20];
    manifest_path = dest / "_precompiled" / MANIFEST_NAME;
    if not manifest_path.is_file() {
        if data is None {
            data = load();
        }
        actual = hashlib.sha256(data).hexdigest();
        if actual != digest {
            raise RuntimeError(
                f"{label} does not match its recorded sha256 "
                f"(expected {digest[:16]}, got {actual[:16]})"
            );
        }
        tmp = dest.with_suffix(f".{os.getpid()}.tmp");
        shutil.rmtree(tmp, ignore_errors=True);
        tmp.mkdir(parents=True, exist_ok=True);
        try {
            with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tf {
                tf.extractall(tmp, filter="data");
            }
            manifest_file = tmp / "_precompiled" / MANIFEST_NAME;
            if not manifest_file.is_file() {
                raise RuntimeError(f"{label} is not a jab: no sealed manifest inside");
            }
            role = json.loads(manifest_file.read_text(encoding="utf-8")).get(
                "role", "app"
            );
            if role != "app" {
                raise RuntimeError(
                    f"{label} is a {role} package, not an app: add a library with "
                    "'jac install', create from a template with 'jac create --use'"
                );
            }
            shutil.rmtree(dest, ignore_errors=True);
            tmp.rename(dest);
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        maybe_sweep("apps");
    }
    bucket("apps").note_hit(dest);
    bundle_dir = str(dest / "_precompiled");
    if image_for_bundle_dir(bundle_dir) is None
        and register_image(bundle_dir) is None {
        raise RuntimeError(f"{label}: sealed manifest failed to load");
    }

    activate_vendored(dest);
    return dest;
}

impl jab_app_meta(img_root: Path) -> dict[str, any] {
    raw = json.loads(
        (img_root / "_precompiled" / MANIFEST_NAME).read_text(encoding="utf-8")
    );
    meta = raw if isinstance(raw, dict) else {};
    return {
        "kind": meta.get("kind", ""),
        "app": meta.get("app", ""),
        "capabilities": meta.get("capabilities") or [],
        "entry": meta.get("entry") or {},
        "package": meta.get("package", "")
    };
}
