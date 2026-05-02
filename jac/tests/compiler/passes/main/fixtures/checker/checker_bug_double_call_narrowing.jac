"""Bug: calling a function twice — once in a guard, once in the body — loses narrowing.

Root cause: The type checker narrows the RESULT of a function call only for the
specific call expression that appears in the guard. A second call to the same
function is a distinct expression with its own return type (T | None), so the
narrowing from the first call does not apply to it.

Fix in user code: store the function result in a variable before guarding on it.
The variable is a Name node; CFG narrowing propagates the narrowed type to all
uses of that Name within the guarded block.

All functions below use the correct (variable-stored) pattern and should
produce 0 errors.
"""

def get_token() -> str | None {
    return "TOKEN";
}

def get_value(key: str) -> int | None {
    return 42;
}

obj Config {
    has debug: bool = False;
}

def maybe_config() -> Config | None {
    return Config();
}

# Basic: store once, guard, then use the variable (not a second call).
def process_token() -> str {
    tok = get_token();
    if tok is not None {
        return tok.upper();  # tok: str
    }
    return "";
}

# Attribute access on stored result.
def process_config() -> bool {
    cfg = maybe_config();
    if cfg is not None {
        return cfg.debug;  # cfg: Config
    }
    return False;
}

# Chained: multiple attributes, all on the stored variable.
def process_multi() -> str {
    tok = get_token();
    val = get_value("x");
    if tok is not None and val is not None {
        return tok.upper() + str(val);  # tok: str, val: int
    }
    return "";
}
