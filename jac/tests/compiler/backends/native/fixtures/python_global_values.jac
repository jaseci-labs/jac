import math;

glob FIRST = math.sqrt(4.0);

import from math { sqrt as later_sqrt }

glob SECOND = later_sqrt(9.0);
glob NATIVE: float = math.sqrt(16.0);

import json;
import from contextvars { ContextVar }

glob VALUE = json.loads("[1, 2]"),
     ALIAS = VALUE,
     CONTEXT: ContextVar[int] = ContextVar[int]("native_global", `default=7);

def ordered_values -> int {
    return int(FIRST) * 100 + int(SECOND);
}

def mutate -> int {
    VALUE.append(3);
    return len(ALIAS);
}

def replace -> int {
    VALUE = json.loads("[9]");
    return len(VALUE) * 10 + len(ALIAS);
}

def context_default -> int {
    return CONTEXT.get();
}

def native_scalar -> float {
    return NATIVE;
}
