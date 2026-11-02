import from c { def openat(dirfd: i32, path: str, flags: i32) -> i32;  }
import from c { def creat(path: str, mode: i32) -> i32;  }
import from c { def __jac_at_fdcwd -> i32;  }

glob AT_FDCWD: int = int(__jac_at_fdcwd());

def:pub open_readonly(path: str) -> i32;

def:pub open_writetrunc(path: str) -> i32;
