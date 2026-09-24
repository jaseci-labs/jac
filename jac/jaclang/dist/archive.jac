import gzip;
import io;
import os;
import tarfile;
import from pathlib { Path }

def det_tar_member(info: tarfile.TarInfo) -> tarfile.TarInfo {
    info.mtime = 0;
    info.uid = 0;
    info.gid = 0;
    info.uname = "";
    info.gname = "";
    return info;
}

def open_det_tar(buf: io.BytesIO) -> tuple[tarfile.TarFile, gzip.GzipFile] {
    gz = gzip.GzipFile(fileobj=buf, mode="wb", mtime=0);
    return (tarfile.open(fileobj=gz, mode="w"), gz);
}

def tar_gz_dir(top: Path) -> bytes {
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w") as tf {
        for (dirpath, dirnames, filenames) in os.walk(str(top)) {
            dirnames.sort();
            for fn in sorted(filenames) {
                full = Path(str(dirpath)) / str(fn);
                tf.add(
                    str(full),
                    arcname=full.relative_to(top).as_posix(),
                    filter=det_tar_member
                );
            }
        }
    }
    return gzip.compress(buf.getvalue(), 6, mtime=0);
}

def extract_tar_gz(data: bytes, dest: Path) {
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tf {
        tf.extractall(dest, filter="data");
    }
}
