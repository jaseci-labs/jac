import from "libdl.so.2" {
    def dlopen(filename: str, flags: i32) -> int;  def dlsym(
        handle: int, symbol: str
    ) -> int;  def dlerror -> int;
}
import from c { def strdup(s: int) -> str;  }

glob RTLD_NOW: int = 2,
     RTLD_GLOBAL: int = 256,
     SHLIB_EXT: str = ".so";

def:pub dl_error -> str {
    p = dlerror();
    if p == 0 {
        return "unknown dl error";
    }
    return strdup(p);
}
