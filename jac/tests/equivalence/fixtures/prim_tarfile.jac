"""Bundled native ``tarfile`` + ``compression.zstd`` + ``io`` extraction fixture.

The SAME source binds CPython's real ``tarfile`` / ``compression.zstd`` / ``io``
on the sv (Python) backend and the bundled ``na_stdlib`` modules on the na
(native LLVM) backend. Both entry points perform the single-binary launcher's
exact extraction sequence -- wrap the payload in ``ZstdFile(io.BytesIO(...))``,
``tarfile.open(fileobj=..., mode="r|")``, ``extractall(dest)`` (default ``data``
filter) -- reading the payload path and destination directory from the
environment (``JAC_TARFILE_PAYLOAD`` / ``JAC_TARFILE_DEST_PY`` /
``JAC_TARFILE_DEST_NA``). Each returns the number of members extracted; the
owning ``test_tarfile_equivalence`` suite compares the two resulting trees on
disk (relative path, size, ``mode & 0o777``, sha256). ES/JS opts out."""

import os;
import tarfile;
import from io { BytesIO }
import from compression.zstd { ZstdFile }


def _env(name: str) -> str {
    v = os.getenv(name);
    if v is None {
        return "";
    }
    return v;
}


def _extract(payload_path: str, dest: str) -> int {
    f = open(payload_path, "rb");
    payload = f.read();
    f.close();
    zf = ZstdFile(BytesIO(payload));
    tf = tarfile.open(fileobj=zf, mode="r|");
    count = 0;
    member = tf.next();
    while member is not None {
        count += 1;
        member = tf.next();
    }
    tf.close();
    zf.close();

    f2 = open(payload_path, "rb");
    payload2 = f2.read();
    f2.close();
    zf2 = ZstdFile(BytesIO(payload2));
    tf2 = tarfile.open(fileobj=zf2, mode="r|");
    tf2.extractall(dest);
    tf2.close();
    zf2.close();
    return count;
}


def tarfile_extract_py() -> int {
    return _extract(_env("JAC_TARFILE_PAYLOAD"), _env("JAC_TARFILE_DEST_PY"));
}


def tarfile_extract_na() -> int {
    return _extract(_env("JAC_TARFILE_PAYLOAD"), _env("JAC_TARFILE_DEST_NA"));
}
