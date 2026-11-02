"""Raising a value whose static type is a base but whose object is a subclass.

The handler for the subclass has to ask the raised object for its class at
run time: the raise site only knows the static type.
"""

obj AppError(Exception) {}

obj ConfigError(AppError) {}

def pick(kind: int) -> AppError {
    if kind == 1 {
        return ConfigError("picked");
    }
    return AppError("base");
}

with entry {
    try {
        raise pick(1);
    } except ConfigError as e {
        print("dynamic:", str(e));
    }
    try {
        raise pick(0);
    } except ConfigError as e {
        print("wrong handler:", str(e));
    } except AppError as e {
        print("static:", str(e));
    }
    err: AppError = ConfigError("stored");
    try {
        raise err;
    } except ConfigError as e {
        print("stored:", str(e));
    }
}
