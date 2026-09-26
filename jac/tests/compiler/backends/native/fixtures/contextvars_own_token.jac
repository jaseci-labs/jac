"""A program's own `Token` next to the contextvars shim, and the shim's token
still importable under CPython's name."""
import from contextvars { ContextVar }
import from contextvars { Token as VarToken }

glob _depth: ContextVar[int] = ContextVar("depth");

obj Token {
    has name: str,
        value: str,
        line: int = 0;

    def describe -> str {
        return f"{self.name}={self.value}@{self.line}";
    }
}

def make(name: str, line: int) -> Token {
    tok = Token(name=name, value=name.upper(), line=line);
    tok.value = tok.value + "!";
    return tok;
}

def enter(depth: int) -> VarToken[int] {
    return _depth.set(depth);
}

with entry {
    reset = enter(2);
    toks = [make("ab", 1), make("cd", 7)];
    for tok in toks {
        print(tok.describe(), len(tok.value), tok.line + _depth.get());
    }
    _depth.reset(reset);
    print(_depth.get(0));
}
