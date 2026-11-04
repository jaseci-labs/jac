def:pub replace(
    src: str, dst: str, *, src_dir_fd: int | None = None, dst_dir_fd: int | None = None
);

glob sep: str = "/",
     extsep: str = ".",
     pardir: str = "..",
     curdir: str = ".",
     pathsep: str = ":",
     linesep: str = "\n",
     devnull: str = "/dev/null";

def:pub getcwd -> str;

def:pub getenv(key: str, fallback: (str | None) = None) -> (str | None);

def:pub environ_get(key: str, fallback: (str | None) = None) -> (str | None);

def:pub environ_getitem(key: str) -> str;

def:pub environ_setitem(key: str, value: str) -> None;

def:pub environ_delitem(key: str) -> None;

def:pub environ_pop(key: str, fallback: (str | None) = "\x00") -> (str | None);

def:pub environ_contains(key: str) -> bool;

def _environ_name(key: str) -> None;

def:pub listdir(path: str = ".") -> list[str];

def:pub makedirs(name: str, mode: int = 511, exist_ok: bool = False) -> None;

def:pub mkdir(path: str, mode: int = 511) -> None;

def:pub remove(path: str) -> None;

def:pub unlink(path: str) -> None;

def:pub rmdir(path: str) -> None;

def:pub system(command: str) -> int;

def:pub getpid -> int;

def:pub rename(src: str, dst: str) -> None;

import os.path;
