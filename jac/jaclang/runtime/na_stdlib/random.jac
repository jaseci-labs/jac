glob _N: int = 624,
     _M: int = 397,
     _MT: list[int] = [0] * 624,
     _INDEX: list[int] = [625];

def _init_genrand(s: int);

def _init_by_array(key: list[int]);

def _ensure_seeded;

def _genrand -> int;

def _randbelow(n: int) -> int;

def:pub seed(a: (int | None) = None);

def:pub random -> float;

def:pub getrandbits(k: int) -> int;

def:pub randrange(start: int, stop: (int | None) = None, step: int = 1) -> int;

def:pub randint(a: int, b: int) -> int;

def:pub uniform(a: float, b: float) -> float;
