import from c { def __error -> int;  }

def:pub errno_address -> int {
    return __error();
}
