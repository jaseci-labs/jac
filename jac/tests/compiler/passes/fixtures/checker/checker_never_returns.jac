"""Never-returning calls end paths; ordinary calls and conditional paths do not."""

import from .checker_never_helper { fail, legacy_fail, may_return }

def terminal -> int {
    fail();
}

def terminal_legacy -> int {
    legacy_fail();
}

def handler(value: str) -> int {
    try {
        return int(value);
    } except ValueError {
        fail();
    }
}

def branches(flag: bool) -> int {
    if flag {
        return 1;
    } else {
        fail();
    }
}

def conditional(flag: bool) -> int {
    if flag {
        fail();
    }
}

def ordinary -> int {
    may_return();
}
