"""A field read on `here` after isinstance narrowed it to several node types.

`here` is not a local, so the read goes through the narrowed union's field
dispatch rather than a place for the name.
"""
node Item {
    has weight: int = 1;
}

node Tool(Item) {
    has sharp: bool = False;
}

node Gem(Item) {
    has sharp: bool = False;
}

walker Count {
    has hits: int = 0;

    can on_item with Item entry {
        if isinstance(here, (Tool, Gem)) and here.sharp {
            self.hits += 1;
        }
        visit [-->];
    }
}

def run_count -> int {
    a = Item();
    b = Tool(sharp=True);
    c = Gem(sharp=True);
    d = Tool();
    a ++> b;
    a ++> c;
    a ++> d;
    w = a spawn Count();
    return w.hits;
}

with entry {
    print(run_count());
}
