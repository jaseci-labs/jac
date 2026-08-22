import from c { def openat(dirfd: i32, path: str, flags: i32) -> i32;  }

glob AT_FDCWD: int = -100;

def:pub open_readonly(path: str) -> i32 {
    return openat(AT_FDCWD, path, 0);
}
