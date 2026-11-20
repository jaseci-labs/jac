import os;
import from legacy_stub_aliases { normalize }

def text_path(path: str) -> str {
    return os.path.relpath(path);
}

def binary_path(path: bytes) -> bytes {
    return os.path.relpath(path);
}

def text_alias(value: str) -> str {
    return normalize(value);
}

def binary_alias(value: bytes) -> bytes {
    return normalize(value);
}
