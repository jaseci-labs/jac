def _is_space_ch(c: int) -> bool;


def _spaces(n: int) -> str;


def _cat(parts: list[str]) -> str;


def _sumlen(parts: list[str]) -> int;


def _expandtabs(s: str) -> str;


def _munge(text: str) -> str;


def _split_chunks(s: str) -> list[str];


def _wrap_chunks(chunks: list[str], width: int) -> list[str];


def:pub wrap(text: str, width: int = 70) -> list[str];


def:pub fill(text: str, width: int = 70) -> str;


def _leading_ws(s: str) -> str;


def _common_prefix(a: str, b: str) -> str;


def:pub dedent(text: str) -> str;


def _splitlines_keepends(text: str) -> list[str];


def:pub indent(text: str, prefix: str) -> str;
