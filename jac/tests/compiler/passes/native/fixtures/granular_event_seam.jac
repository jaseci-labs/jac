"""Fixture: an event ability's capability violation, sibling event clean.

`W.go` reads `.tag` off an untyped (`any`) node-ref element -- the
attribute-access refusal class the capability authority rejects
statically. Granular demotion must seam exactly that ability and leave
`W.done` natively lowered.
"""

node N {
    has tag: int = 0;
}

edge Portal {}

walker W {
    has v: int = 0;

    can go with N entry {
        nbrs = [here->:Portal:->];
        if len(nbrs) > 0 {
            self.v = nbrs[0].tag;
        }
    }

    can done with N exit {
        self.v = self.v + 1;
    }
}

with entry {
    a = N(tag=7);
    print(a.tag);
}
