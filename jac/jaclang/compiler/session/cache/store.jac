import os;
import from pathlib { Path }
import from tempfile { NamedTemporaryFile }

def atomic_write(path: Path, payload: bytes) {
    path.parent.mkdir(parents=True, exist_ok=True);
    temporary: Path | None = None;
    try {
        with NamedTemporaryFile(
            dir=path.parent, prefix=path.name + '.', delete=False
        ) as stream {
            temporary = Path(stream.name);
            stream.write(payload);
            stream.flush();
        }
        assert temporary is not None;
        os.replace(temporary, path);
    } finally {
        if temporary is not None {
            temporary.unlink(missing_ok=True);
        }
    }
}
