"""Implementation of the reproducible npm tarball packer."""

import io;
import gzip;
import tarfile;

impl pack_tarball(members: list[tuple[str, bytes]]) -> bytes {
    ordered = sorted(members, key=lambda m: any : m[0]);
    raw = io.BytesIO();
    with tarfile.open(fileobj=raw, mode="w") as tar {
        for (arc, data) in ordered {
            ti = tarfile.TarInfo(name=arc);
            ti.size = len(data);
            ti.mtime = _NPM_MTIME;
            ti.mode = 0o644;
            ti.uid = 0;
            ti.gid = 0;
            ti.uname = "";
            ti.gname = "";
            tar.addfile(ti, io.BytesIO(data));
        }
    }
    out = io.BytesIO();
    with gzip.GzipFile(fileobj=out, mode="wb", mtime=0) as gz {
        gz.write(raw.getvalue());
    }
    return out.getvalue();
}
