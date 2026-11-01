import os;

def _root_of(p: str) -> str;

def _parts_of(p: str) -> list[str];

def _assemble(anchor: str, parts: list[str]) -> str;

def _norm(p: str) -> str;

def _collapse(p: str) -> str;

obj:pub Path {
    has _p: str = ".";
    has name: str { getter; }
    has stem: str { getter; }
    has parent: Path { getter; }
    has suffix: str { getter; }
    has parts: tuple[str, ...] { getter; }

    def init(p: (str | Path) = "");
    def __str__ -> str;
    def __fspath__ -> str;
    def __eq__(other: any) -> bool;
    def __hash__ -> int;
    def __truediv__(other: (str | Path)) -> Path;
    def joinpath(other: (str | Path)) -> Path;
    def exists -> bool;
    def is_dir -> bool;
    def is_file -> bool;
    def is_absolute -> bool;
    def is_relative_to(other: (str | Path)) -> bool;
    def relative_to(other: (str | Path)) -> Path;
    def read_text(encoding: (str | None) = None) -> str;
    static def cwd -> Path;
    def read_bytes -> bytes;
    def iterdir -> Iterator[Path];
    def resolve -> Path;
}
