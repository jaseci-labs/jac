"""What `except T as e` binds, for exception classes local and imported.

A field-less class binds the raised message, so `str(e)` is that message; a
class with fields binds its struct. `raise e` re-raises the caught exception,
keeping its class and message.
"""

import from exc_binding_errors { BindError, CodedError, bind_value }

obj LocalError(Exception) {}

def raise_local(n: int) -> int {
    if n > 0 {
        raise LocalError("local " + str(n));
    }
    return n;
}

def local_message -> str {
    try {
        raise_local(3);
    } except LocalError as e {
        return str(e);
    }
    return "none";
}

def imported_message -> str {
    try {
        bind_value(0);
    } except BindError as e {
        return str(e);
    }
    return "none";
}

def struct_code -> int {
    try {
        bind_value(1);
    } except CodedError as c {
        return c.code;
    }
    return 0;
}

def rethrow(kind: int) -> int {
    try {
        return bind_value(kind);
    } except BindError as e {
        raise e;
    } except CodedError as c {
        raise c;
    }
}

def reraised_message -> str {
    try {
        rethrow(0);
    } except BindError as e {
        return str(e);
    }
    return "none";
}

def reraised_code -> int {
    try {
        rethrow(1);
    } except CodedError as c {
        return c.code;
    }
    return 0;
}
