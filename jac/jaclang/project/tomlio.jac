import tomllib;
import from difflib { get_close_matches }

obj MalformedJacTomlError(tomllib.TOMLDecodeError) {
    has file_path: str,
        original: tomllib.TOMLDecodeError;

    def __str__ -> str;
}

obj JacTomlError(ValueError) {
    has origin: str,
        where: str,
        detail: str;

    def __str__ -> str;
}

def read_toml_with_encoding(file_path: str) -> dict[str, any];

def toml_kind(value: any) -> str;

obj TomlTable {
    has data: dict[str, any],
        where: str = "",
        origin: str = "";

    def error(key: str, detail: str) -> JacTomlError;
    def keys -> list[str];
    def has_key(key: str) -> bool;
    def child_where(key: str) -> str;
    def text(key: str) -> str;
    def scalar_text(key: str) -> str;
    def optional_text(key: str) -> (str | None);
    def flag(key: str) -> bool;
    def integer(key: str) -> int;
    def number(key: str) -> float;
    def texts(key: str) -> list[str];
    def text_or_texts(key: str) -> list[str];
    def text_map(key: str) -> dict[str, str];
    def text_list_map(key: str) -> dict[str, list[str]];
    def raw_table(key: str) -> dict[str, any];
    def table(key: str) -> TomlTable;
    def unknown(key: str, known: list[str]) -> JacTomlError;
}
