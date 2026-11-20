"""One component on three UI libraries: `has`, a derived value, an effect, a keyed list
whose rows keep their state, a hook and a crossing. Nothing here names a library."""

"""A hook's object: its fields stay current wherever they're read."""
obj Tally {
    has total: int,
        bump: Callable[[int], None];
}

def use_tally(start: int) -> Tally {
    has total: int = start;

    return Tally(total=total, bump=lambda (n: int) { total = total + n; });
}

def Row(label: str) -> JsxElement {
    has taps: int = 0;

    return <Line>
        <Label>{label}: {taps}</Label>
        <Btn label="tap" press={lambda { taps = taps + 1; }} />
    </Line>;
}

def Playground(lib: str, step: int = 2) -> JsxElement {
    has count: int = 0;
    has effects: int = 0;
    has items: list[str] = ["a", "b"];
    has shown: bool = True;
    has server: str = "not asked yet";
    has runs: Ref[int] = Ref(0);

    doubled = count * step;
    tally = use_tally(10);

    can with [count] entry {
        runs.current = runs.current + 1;
        effects = runs.current;
    }

    async def ask {
        server = await demo_hello(lib);
    }

    return <Card>
        <Title>{lib}</Title>
        <Line>
            <Label>count {count}, derived {doubled}, effect ran {effects}</Label>
            <Btn label="count + 1" press={lambda { count = count + 1; }} />
        </Line>
        <Line>
            <Btn label="toggle" press={lambda { shown = not shown; }} />
            {<Label>shown</Label> if shown else <Label>hidden</Label>}
        </Line>
        <Line>
            <Btn label="add row" press={lambda { items = items + ["row" + str(len(items))]; }} />
            <Btn label="drop first" press={lambda { items = items[1:]; }} />
        </Line>
        {[<Row key={x} label={x} /> for x in items]}
        <Line>
            <Label>hook {tally.total}</Label>
            <Btn label="hook + 5" press={lambda { tally.bump(5) }} />
        </Line>
        <Line><Btn label="ask the server" press={lambda { ask() }} /><Label>{server}</Label></Line>
    </Card>;
}
