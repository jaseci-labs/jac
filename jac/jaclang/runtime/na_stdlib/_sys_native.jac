import from ._sys_platform { platform_label }
import from c { def write(fd: i32, data: bytes, size: int) -> int;  }

glob platform: str = platform_label,
     _INT_MAX_STR_DIGITS: list[int] = [4300];

def:pub stderr_write(text: str) -> int;

def:pub stdout_write(text: str) -> int;

def:pub stderr_flush;

def:pub stdout_flush;

def:pub set_int_max_str_digits(maxdigits: int);

def:pub get_int_max_str_digits -> int;
