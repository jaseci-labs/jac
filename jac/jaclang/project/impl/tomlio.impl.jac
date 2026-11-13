impl MalformedJacTomlError.init(
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

impl read_toml_with_encoding(file_path: str) -> dict[str, any] {
    try {
        return tomllib.loads(read_file_with_encoding(file_path));
    } except tomllib.TOMLDecodeError as exc {
        raise MalformedJacTomlError(file_path, exc);
    }
}
