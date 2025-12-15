node a {
    has name: str;
}

node b {
    has name: str;
}

walker create {
    can setup with `root entry {
        na = here ++> a(name="node a");
        visit na;
    }

    can ata with a entry {
        here ++> b(name="node b");
    }
}

walker traverse {
    can at_root with `root entry {
        visit [-->];
    }

    can at_a with a entry {
        print(here.name);
        visit [-->];
    }

    can at_b with b entry {
        print(here.name);
    }
}

walker indirect_ref {
    can at_root with `root entry {
        node_as = [-->];
        print([node_as-->]);
        print([edge node_as-->]);
    }
}
