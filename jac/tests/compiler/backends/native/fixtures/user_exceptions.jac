"""User exception classes: message, subclass catch, and builtin bases.

A user class deriving from Exception carries the positional arguments it was
built with as its message, so str(e) renders them the way Python does, and an
`except Base` handler catches every subclass, whether the class lives in this
module or in an imported one, and whether its base is a user class or a
builtin exception.
"""

import user_exceptions_lib;

obj AppError(Exception) {}

obj ConfigError(AppError) {}

obj BadValue(ValueError) {}

obj OutOfRange(IndexError) {}

obj ParseError(Exception) {
    has line_no: int = 0,
        hint: str = "";
}

def fail(i: int) -> int {
    raise ConfigError("config " + str(i));
}

with entry {
    try {
        raise AppError("direct");
    } except AppError as e {
        print("direct:", str(e));
    }
    try {
        fail(1);
    } except ConfigError as e {
        print("exact:", str(e));
    }
    try {
        fail(2);
    } except AppError as e {
        print("base:", str(e));
    }
    try {
        fail(3);
    } except Exception as e {
        print("any:", str(e));
    }
    try {
        raise AppError();
    } except AppError as e {
        print("empty:[" + str(e) + "]");
    }
    try {
        raise AppError("a", 2);
    } except AppError as e {
        print("args:", str(e));
    }
    try {
        raise BadValue("bad value");
    } except ValueError as e {
        print("builtin base:", str(e));
    }
    try {
        raise OutOfRange("out of range");
    } except LookupError as e {
        print("builtin ancestor:", str(e));
    }
    try {
        raise ParseError(line_no=4, hint="tok");
    } except ParseError as e {
        print("fields:", e.line_no, e.hint, "[" + str(e) + "]");
    }
    try {
        raise ParseError(5, "x");
    } except ParseError as e {
        print("positional fields:", e.line_no, e.hint, str(e));
    }
    try {
        user_exceptions_lib.bind(1);
    } except user_exceptions_lib.ProgrammingError as e {
        print("cross exact:", str(e));
    }
    try {
        user_exceptions_lib.bind(2);
    } except user_exceptions_lib.DatabaseError as e {
        print("cross base:", str(e));
    }
    try {
        user_exceptions_lib.bind(3);
    } except user_exceptions_lib.Error as e {
        print("cross root:", str(e));
    }
    try {
        try {
            fail(4);
        } except ValueError {
            print("wrong handler");
        }
    } except AppError as e {
        print("propagated:", str(e));
    }
    try {
        fail(5);
    } except (IndexError, AppError) as e {
        print("tuple:", str(e));
    }
    held = ConfigError("held");
    print("held:", str(held), f"{held}");
}
