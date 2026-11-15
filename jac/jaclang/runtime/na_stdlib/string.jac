import from c { def memchr(s: int, c: i32, n: u64) -> int;  }

glob:pub whitespace: str = " \t\n\r\x0b\x0c",
     ascii_lowercase: str = "abcdefghijklmnopqrstuvwxyz",
     ascii_uppercase: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
     ascii_letters: str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
     digits: str = "0123456789",
     hexdigits: str = "0123456789abcdefABCDEF",
     octdigits: str = "01234567",
     punctuation: str = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
     printable: str = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r\x0b\x0c";


def:pub capwords(s: str, sep: (str | None) = None) -> str;


def _strval(v: any) -> str;


def _invalid(template: str, i: int);


def _ph(bv: bytes, i: int, n: int) -> tuple[(str, int, str)];


def _expand_ascii(template: str, mapping: (dict[str, any] | None), safe: bool) -> str;


def _expand(template: str, mapping: (dict[str, any] | None), safe: bool) -> str;


obj:pub Template {
    has template: str = "";

    def init(template: str);
    def substitute(mapping: dict[str, any]) -> str;
    def safe_substitute(mapping: dict[str, any]) -> str;
    def is_valid -> bool;
    def get_identifiers -> list[str];
}
