import from c { def openat(dirfd: i32, path: str, flags: i32) -> i32;  }
import from c { def creat(path: str, mode: i32) -> i32;  }

glob AT_FDCWD: int = -2;

def:pub open_readonly(path: str) -> i32 {
    return openat(i32(AT_FDCWD), path, 0);
}

def:pub open_writetrunc(path: str) -> i32 {
    return creat(path, i32(420));
}
