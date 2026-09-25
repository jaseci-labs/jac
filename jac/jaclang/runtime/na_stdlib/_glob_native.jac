import from c { def lstat(path: str, buf: int) -> i32;  }
import from c { def malloc(size: int) -> int;  }

glob _GLOB_STBUF: int = malloc(512);

def:pub glob_lexists(path: str) -> bool {
    return lstat(path, _GLOB_STBUF) == 0;
}
