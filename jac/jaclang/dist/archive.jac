import gzip;
import io;
import os;
import tarfile;
import from pathlib { Path }

def det_tar_member(info: tarfile.TarInfo) -> tarfile.TarInfo;

def open_det_tar(buf: io.BytesIO) -> tuple[tarfile.TarFile, gzip.GzipFile];

def tar_gz_dir(top: Path) -> bytes;

def extract_tar_gz(data: bytes, dest: Path);
