"""Fixture: the client state read-your-writes contract, one face per field.

Face A -- `flag`/`label`: a `can with entry` ability writes `flag` and then
branches on it in the same invocation; the branch must see the new value.
Face B -- `seen`: a helper method called after the write reads the new value.
Face C -- `n`: two augmented writes in one handler must both apply.
Face D -- `echo`: a callback created inside a handler reads current state
when it fires, not a render-time snapshot.
The `[n]` dependency effect (`pulses`) pins the dep-sampling contract.
"""

def:pub app -> JsxElement {
    has flag: bool = False,
        label: str = "unset",
        seen: int = 0,
        n: int = 0,
        echo: int = 0,
        pulses: int = 0;

    can with entry {
        flag = True;
        if flag {
            label = "fresh";
        } else {
            label = "stale";
        }
        record();
    }

    can with [n] entry {
        pulses += 1;
    }

    def record {
        seen = 7 if flag else 3;
    }

    return
        <div>
            <span data-testid="label">{label}</span>
            <span data-testid="seen">{seen}</span>
            <span data-testid="n">{n}</span>
            <span data-testid="echo">{echo}</span>
            <span data-testid="pulses">{pulses}</span>
            <button
                data-testid="bump"
                onClick={lambda {
                    n += 1;
                    n += 1;
                    setTimeout(lambda { echo = n + 100; }, 0);
                }}
            >
                bump
            </button>
        </div>;
}
