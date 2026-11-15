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

    def init(p: (str | Path) = "");
    def __str__ -> str;
    def __truediv__(other: str) -> Path;
    def exists -> bool;
    def is_dir -> bool;
    def read_bytes -> bytes;
    def iterdir -> Iterator[Path];
    def resolve -> Path;
}
