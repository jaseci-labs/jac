"""Example of simple walker walking nodes."""

node A {}

walker Walk {
    has id: int = 0;

    can skip_root with `root entry {
        visit [-->];
    }

    can step with A entry {
        print(f'Visited {self.id}');
    }
}

with entry {
    root ++> (a := A());
}

glob ae = [edge root-->a][0];

with entry {
    Walk(id=1) spawn ae;
    ae spawn Walk(id=2);
}
