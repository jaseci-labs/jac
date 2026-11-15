def _class_end(pat: str, start: int) -> int;

def _class_hit(pat: str, start: int, close: int, ch: str) -> bool;

def _match(name: str, pat: str) -> bool;

def normcase(s: str) -> str;

def:pub fnmatchcase(name: str, pat: str) -> bool;

def:pub fnmatch(name: str, pat: str) -> bool;
