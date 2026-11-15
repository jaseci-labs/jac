"""Builtin exceptions raised with a number or a bool for their argument."""

def:pub int_message(x: int) -> str {
    try {
        raise ValueError(x);
    } except ValueError as e {
        return str(e);
    }
    return "";
}

def:pub float_message(x: int) -> str {
    try {
        raise RuntimeError(x * 1.5);
    } except RuntimeError as e {
        return str(e);
    }
    return "";
}

def:pub bool_message(x: int) -> str {
    try {
        raise RuntimeError(x > 1);
    } except RuntimeError as e {
        return str(e);
    }
    return "";
}

def:pub exit_message(x: int) -> str {
    try {
        raise SystemExit(x);
    } except SystemExit as e {
        return str(e);
    }
    return "";
}
