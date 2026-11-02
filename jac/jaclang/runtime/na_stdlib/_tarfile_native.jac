import from c { def chmod(path: str, mode: i32) -> i32;  }
import from c { def symlink(target: str, linkpath: str) -> i32;  }
import from c { def link(oldpath: str, newpath: str) -> i32;  }
import from c { def unlink(path: str) -> i32;  }
import from c { def utime(path: str, times: bytes) -> i32;  }
import from c { def creat(path: str, mode: i32) -> i32;  }
import from c { def write(fd: i32, buf: bytes, n: u64) -> i64;  }
import from c { def close(fd: i32) -> i32;  }


def:pub tar_read_file(path: str) -> bytes;


def:pub tar_create(path: str) -> int;


def:pub tar_write(fd: int, data: bytes) -> int;


def:pub tar_close(fd: int) -> int;


def:pub tar_chmod(path: str, mode: int) -> int;


def:pub tar_symlink(target: str, linkpath: str) -> int;


def:pub tar_link(src: str, dst: str) -> int;


def:pub tar_utime(path: str, mtime: int) -> int;
