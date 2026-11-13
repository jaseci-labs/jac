impl last_errno -> int {
    return int(__mem_load_i32(errno_address()));
}

impl clear_errno {
    __mem_store_i32(errno_address(), 0);
}

impl errno_message -> str {
    return strerror(i32(last_errno()));
}

impl _raise_for_errno(code: int, message: imm str) {
    if code == ENOENT {
        raise FileNotFoundError(message);
    }
    if code == EISDIR {
        raise IsADirectoryError(message);
    }
    if code == ENOTDIR {
        raise NotADirectoryError(message);
    }
    if code == EACCES or code == EPERM {
        raise PermissionError(message);
    }
    raise OSError(message);
}

impl raise_errno(code: int, operation: imm str = "") {
    message = "[Errno " + str(code) + "] ";
    if operation != "" {
        message = message + operation + ": ";
    }
    _raise_for_errno(code, message + strerror(i32(code)));
}

impl raise_os_error(operation: imm str, path: imm str, code: int) {
    _raise_for_errno(code, operation + ": " + strerror(i32(code)) + ": " + path);
}
