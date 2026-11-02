def version_key(v: str) -> tuple[int, int, int];

def is_plain_version(s: str) -> bool;

def split_clause(clause: str) -> tuple[str, str];

def satisfies(version: str, spec: str) -> bool;

def exact_pin(spec: str) -> str;
