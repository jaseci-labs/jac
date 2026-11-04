import os;
import from uuid { uuid4 }

glob _DEFAULT_PREFIX: str = "tmp";

impl mkdtemp(
    suffix: (str | None) = None,
    prefix: (str | None) = None,
    dir: (str | None) = None
) -> str {
    base: str = "";
    if dir is not None {
        base = dir;
    } else {
        base = str(os.environ.get("TMPDIR", ""));
        if not base {
            base = "/tmp";
        }
    }

    stem: str = _DEFAULT_PREFIX;
    if prefix is not None {
        stem = prefix;
    }
    tail: str = "";
    if suffix is not None {
        tail = suffix;
    }

    for _ in range(100) {
        path: str = os.path.join(base, stem + uuid4().hex + tail);
        os.mkdir(path, 0o700);
        if os.path.isdir(path) {
            return path;
        }
    }
    raise OSError("unable to create a unique temporary directory");
}
