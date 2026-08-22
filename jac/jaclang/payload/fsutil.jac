import from typing { NoReturn }

class PayloadDie(Exception) {}

def log(msg: str);
def die(msg: str) -> NoReturn;
def file_exists(path: str) -> bool;
def file_size_or_zero(path: str) -> int;
def mtime_ns(path: str) -> int | None;
def sha256_hex(data: bytes) -> str;
def read_bytes(path: str) -> bytes;
def read_trimmed(path: str) -> str | None;
def write_bytes(path: str, data: bytes);
def write_text(path: str, text: str);
def make_dirs(path: str);
def delete_tree(path: str);
def delete_file(path: str);
def copy_file(src: str, dst: str);
def copy_into(repo_root: str, name: str, dst: str);
def walk_sorted(top: str) -> list[tuple[str, list[str], list[str]]];
def copy_tree(src_dir: str, dst_path: str, skip_fn: Callable[[str], bool]);
def skip_none(p: str) -> bool;
def skip_jaclang(p: str) -> bool;
def skip_stage_site(p: str) -> bool;
def skip_typeshed_tests(p: str) -> bool;
def toml_string(toml: str, key: str) -> str | None;
def find_sum_line(sums: str, asset: str) -> str | None;
def clone_env(parent: dict[str, str] | None = None) -> dict[str, str];
def run_child(argv: list[str], env: dict[str, str] | None, allow_fail: bool) -> bool;
def strip_best_effort(path: str);
def source_file_mode(path: str) -> int;
def host_os_arch -> str;
def rd_u16(b: bytes, off: int) -> int;
def rd_u32(b: bytes, off: int) -> int;
def extract_tar(
    tar_bytes: bytes, dest: str, strip_components: int, exec_bit_only: bool
);
