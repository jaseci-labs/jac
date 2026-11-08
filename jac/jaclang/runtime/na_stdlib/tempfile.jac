import os;
import from c { def access(path: str, mode: i32) -> i32;  }
import from c { def mkdir(path: str, mode: i32) -> i32;  }
import from uuid { uuid4 }

glob _DEFAULT_PREFIX: str = "tmp",
     _TMP_MAX: int = 10000;

def _gettempdir -> str;

def:pub mkdtemp(
    suffix: (str | None) = None, prefix: (str | None) = None, dir: (str | None) = None
) -> str;
