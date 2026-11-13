import from c { def strerror(errnum: i32) -> str;  }

glob EPERM: int = 1,
     ENOENT: int = 2,
     EINTR: int = 4,
     EACCES: int = 13,
     ENOTDIR: int = 20,
     EISDIR: int = 21;

def:pub last_errno -> int;

def:pub clear_errno;

def:pub errno_message -> str;

def _raise_for_errno(code: int, message: imm str);

def:pub raise_errno(code: int, operation: imm str = "");

def:pub raise_os_error(operation: imm str, path: imm str, code: int);
