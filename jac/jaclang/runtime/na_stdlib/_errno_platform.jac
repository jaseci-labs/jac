import from c { def __errno_location -> int;  }

def:pub errno_address -> int {
    return __errno_location();
}
