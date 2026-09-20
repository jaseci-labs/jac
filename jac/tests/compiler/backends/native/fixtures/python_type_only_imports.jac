import type from typing { Never }
import type from pathlib { Path }

def answer -> int {
    return 42;
}

def local_answer -> int {
    import type from contextvars { ContextVar }
    return 19;
}
