node A {}
node B {}

walker build {
    can run with `root entry {
        a = A();
        a ++> B();
        # connecting two non persistent nodes
        here ++> a;
    }
}

walker view {
    can run with `root entry {
        print(printgraph(here));
    }
}
