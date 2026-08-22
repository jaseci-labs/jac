import tomllib;
import from jaclang.jac0core.helpers { read_file_with_encoding }

class MalformedJacTomlError(tomllib.TOMLDecodeError) {
    has file_path: str,
        original: tomllib.TOMLDecodeError;

    def init(
        self: MalformedJacTomlError, file_path: str, original: tomllib.TOMLDecodeError
    ) {
        msg = f"jac.toml is malformed at {file_path}: {original}";
        if hasattr(original, "doc") and hasattr(original, "pos") {
            tomllib.TOMLDecodeError.__init__(
                self, msg, getattr(original, "doc"), getattr(original, "pos")
            );
        } else {
            tomllib.TOMLDecodeError.__init__(self, msg);
        }
        self.file_path = file_path;
        self.original = original;
    }
}


def read_toml_with_encoding(file_path: str) -> dict {
    try {
        return tomllib.loads(read_file_with_encoding(file_path));
    } except tomllib.TOMLDecodeError as exc {
        raise MalformedJacTomlError(file_path, exc);
    }
}

def _warn_malformed_jac_toml(exc: MalformedJacTomlError) {
    import sys;
    sys.stderr.write(
        f"warning: jac.toml is malformed ({exc.file_path}): {exc.original}; "
        "ignoring [plugins].disabled. "
        "Run a `jac` CLI command for the actionable error.\n"
    );
}
