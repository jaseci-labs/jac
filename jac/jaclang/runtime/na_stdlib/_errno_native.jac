import from c { def strerror(errnum: i32) -> str;  }
import from _errno_platform { errno_address }

def:pub last_errno -> int {
    return int(__mem_load_i32(errno_address()));
}

def:pub clear_errno {
    __mem_store_i32(errno_address(), 0);
}

def:pub errno_message -> str {
    return strerror(i32(last_errno()));
}

def:pub raise_os_error(operation: str, path: str, code: int) {
    message = operation + ": " + strerror(i32(code)) + ": " + path;
    if code == 2 {
        raise FileNotFoundError(message);
    }
    if code == 20 {
        raise NotADirectoryError(message);
    }
    if code == 13 or code == 1 {
        raise PermissionError(message);
    }
    raise OSError(message);
}
