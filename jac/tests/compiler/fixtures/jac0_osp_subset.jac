node Item {
    has name: str,
        weight: int = 0;
}

edge Part {
    has idx: int = 0;
}

edge Link {}

walker Sum {
    has total: int = 0,
        seen: list[str] = [];

    can start with Item entry;
    can leave with Item exit {
        self.seen.append("exit:" + here.name);
    }

    can wrap with exit {
        self.seen.append("done");
    }
}

impl Sum.start with Item entry {
    self.total += here.weight;
    self.seen.append("enter:" + here.name);
    kids = [here->:Part:->];
    visit kids;
    if here.name == "stop" {
        disengage;
    }
}

def build -> Item {
    top = Item(name="top", weight=1);
    a = Item(name="a", weight=2);
    b = Item(name="b", weight=3);
    top +>:Part(idx=0):+> a;
    top +>:Part(idx=1):+> b;
    a ++> b;
    return top;
}

def run -> tuple[int, list[str], int, int, int, int, int] {
    check_indexed_refs();
    top = build();
    w = top spawn Sum();
    parts = [top->:Part:->];
    back = [parts[0]<-:Part:<-];
    edges = [edge top->:Part:->];
    plain = [top-->];
    for e in edges {
        if e.idx == 1 {
            del e;
        }
    }
    after = [top->:Part:->];
    return (w.total, w.seen, len(parts), len(back), len(edges), len(plain), len(after));
}


def check_indexed_refs {
    top = Item(name='top');
    first = Item(name='first');
    last = Item(name='last');
    top +>:Link:+> first;
    top +>:Link:+> last;
    assert [top->:Link:->][0] is first;
    assert [top->:Link:->][-1] is last;
    assert [first<-:Link:<-][0] is top;
    assert [last<-:Link:<-][-1] is top;
    top +>:Part:+> first;
    assert [top->:Part:->][0] is first;
    assert [top->:Part:->][-1] is first;
    del [edge top->:Link:->];
    missing = False;
    try {
        [top->:Link:->][0];
    } except IndexError {
        missing = True;
    }
    assert missing;
}
