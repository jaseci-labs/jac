import from c {
    def pread(fd: i32, buf: bytes, n: int, off: int) -> int;  def close(
        fd: i32
    ) -> i32;  def getuid -> i32;  def opendir(path: str) -> int;  def readdir(
        dirp: int
    ) -> int;  def closedir(dirp: int) -> i32;  def malloc(size: int) -> int;  def free(
        ptr: int
    ) -> None;  def strcpy(dst: int, src: str) -> int;  def strdup(s: int) -> str;  def memcpy(
        dst: bytes, src: int, n: int
    ) -> int;  def memmove(dst: int, src: bytes, n: int) -> int;
}
import from c { def write(fd: i32, buf: bytes, n: int) -> int;  }
import from _dirent_native { dirent_name }
import from _fd_native { open_readonly, open_writetrunc }

def:pub write_file(path: str, data: bytes) -> bool;

def:pub read_at(path: str, off: int, n: int) -> bytes;

def:pub listdir(path: str) -> list[str];

def:pub c_string(ptr: int) -> str;

def:pub c_alloc_string(s: str) -> int;

def:pub peek(ptr: int, n: int) -> bytes;

def:pub poke(ptr: int, data: bytes);
