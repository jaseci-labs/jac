"""Native tempfile entry points used by the in-process regression test."""

import tempfile;

def make_default -> str {
    return tempfile.mkdtemp();
}

def make_affixed -> str {
    return tempfile.mkdtemp(suffix="-sfx", prefix="jacp-");
}

def make_in_dir(path: str) -> str {
    return tempfile.mkdtemp(dir=path);
}

def missing_dir_error(path: str) -> str {
    try {
        tempfile.mkdtemp(dir=path);
    } except OSError as e {
        return str(e);
    }
    return "unreachable";
}
