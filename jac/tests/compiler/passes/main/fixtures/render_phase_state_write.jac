"""Fixture: render-phase writes to component state (E0082).

Component body statements run on every render, so assigning a `has` state
field there loops under read-your-writes semantics. Only the two direct
body writes below are errors; writes inside abilities, methods, and
lambdas are deferred and legal.
"""

def:pub Broken -> JsxElement {
    has n: int = 0,
        msg: str = "ok";

    n = 5;  # ERROR: direct render-phase write
    if n > 3 {
        msg = "big";  # ERROR: nested control flow is still render
    }

    can with entry {
        n = 1;  # legal: entry ability runs post-commit
    }

    can with [n] entry {
        msg = "n moved";  # legal: dependency effect
    }

    def poke {
        n = 2;  # legal: method body, runs from handlers
    }

    return <button onClick={lambda { n = 4; }}>{msg}</button>;  # legal: event handler lambda
}

def:pub Fine -> JsxElement {
    has count: int = 0;

    total: int = count + 1;  # legal: plain local, not a state field

    can with entry {
        count += 1;
    }

    return <span>{total}</span>;
}

# Not a component: body-level `has` is also the native pathway's local
# declaration syntax. Only defs returning a Jsx* type are render bodies,
# so these writes are legal.
def compute_checksum(data: list[int]) -> int {
    has result: int = 0;
    for val in data {
        result = (result * 31 + val) % 1000000007;
    }
    return result;
}
