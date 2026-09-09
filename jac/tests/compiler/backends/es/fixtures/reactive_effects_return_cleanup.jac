"""Closure-local lifecycle cleanup, dependency changes and early returns."""
glob events: list[str] = [];

def:pub history -> list[str] {
    return events;
}

def:pub app -> JsxElement {
    has generation: int = 0,
        unrelated: int = 0;

    can with [generation] entry {
        snapshot = generation;
        if snapshot == 2 {
            return;
        }
        events.append("setup:" + str(snapshot));
        listener = lambda (_event: any) { events.append("event:" + str(snapshot)); };
        window.addEventListener("jac-ping", listener);
        return lambda {
            window.removeEventListener("jac-ping", listener);
            events.append("cleanup:" + str(snapshot));
        };
    }

    can with exit {
        events.append("exit");
    }

    return
        <div>
            <button id="next" onClick={lambda { generation += 1; }}>Next</button>
            <button id="unrelated" onClick={lambda { unrelated += 1; }}>
                {unrelated}
            </button>
        </div>;
}
