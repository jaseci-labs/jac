import from jacbootstrap {
    def jac_boot_executable(buffer: bytes, length: int) -> int;  def jac_boot_cache_suffix -> int;  def jac_boot_argc -> int;  def jac_boot_arg(
        index: int
    ) -> int;  def jac_boot_is_file(path: str) -> bool;  def jac_boot_is_dir(
        path: str
    ) -> bool;  def jac_boot_size(path: str) -> int;  def jac_boot_mtime(
        path: str
    ) -> float;  def jac_boot_clock(monotonic: bool) -> float;  def jac_boot_mkdirs(
        path: str
    ) -> bool;  def jac_boot_remove(path: str) -> bool;  def jac_boot_rmtree(
        path: str
    ) -> bool;  def jac_boot_rename(source: str, dest: str) -> bool;  def jac_boot_sha256(
        data: bytes, length: int, output: bytes
    ) -> None;  def jac_boot_extract(data: bytes, length: int, path: str) -> int;
}
import from c {
    def getenv(name: str) -> str;  def setenv(
        name: str, value: str, overwrite: i32
    ) -> i32;  def unsetenv(name: str) -> i32;  def getpid -> i32;  def `exit(
        status: i32
    ) -> None;
}
import from ._libc { c_string }

def:pub arguments -> list[str] {
    return [c_string(jac_boot_arg(index)) for index in range(jac_boot_argc())];
}

def:pub environment(name: str) -> str {
    return getenv(name) or "";
}

def:pub set_environment(name: str, value: str) -> bool {
    return setenv(name, value, i32(1)) == 0;
}

def:pub clear_environment(name: str) -> bool {
    return unsetenv(name) == 0;
}

def:pub terminate(status: int) {
    `exit(i32(status));
}

def:pub process_id -> int {
    return int(getpid());
}

def:pub payload_digest(data: bytes) -> str {
    result = b"\x00" * 64;
    jac_boot_sha256(data, len(data), result);
    return result.decode();
}

def:pub unpack_payload(data: bytes, path: str) -> str {
    error = jac_boot_extract(data, len(data), path);
    return c_string(error) if error != 0 else "";
}


def:pub executable_path -> str {
    buffer = b"\x00" * 4096;
    length = jac_boot_executable(buffer, len(buffer));
    return buffer[0:length].decode() if length >= 0 else "";
}

def:pub platform_cache_home(home: str) -> str {
    return home + c_string(jac_boot_cache_suffix());
}
