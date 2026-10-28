import tomllib;

class MalformedJacTomlError(tomllib.TOMLDecodeError) {
    has file_path: str,
        original: tomllib.TOMLDecodeError;

    def init(
        self: MalformedJacTomlError, file_path: str, original: tomllib.TOMLDecodeError
    );
}


def read_toml_with_encoding(file_path: str) -> dict[str, any];

def _warn_malformed_jac_toml(exc: MalformedJacTomlError);
