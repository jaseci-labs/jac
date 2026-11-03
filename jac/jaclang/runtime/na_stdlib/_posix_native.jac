import from c { def __jac_stat(path: str, out: bytes) -> i32;  }
import from c { def getcwd(buf: bytes, size: int) -> int;  }
import from c { def getenv(name: str) -> int;  }
import from c { def realpath(path: str, resolved: bytes) -> int;  }
import from c { def mkdir(path: str, mode: i32) -> i32;  }
import from c { def strdup(s: int) -> str;  }

glob:pub S_IFMT: int = 0o170000,
     S_IFDIR: int = 0o040000,
     S_IFREG: int = 0o100000;

def:pub stat_fields(path: str) -> (list[int] | None);

def:pub cwd_path -> str;

def:pub env_value(name: str) -> (str | None);

def:pub resolved_path(path: str) -> (str | None);

def:pub make_dir(path: str, mode: int) -> int;
