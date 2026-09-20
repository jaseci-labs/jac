"""Tarfile: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

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
