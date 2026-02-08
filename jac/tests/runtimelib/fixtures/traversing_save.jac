node A {}
node B {}

walker build {
    can run with Root entry {
        a = A();
        a ++> B();
        # connecting two non persistent nodes
        here ++> a;
    }
}

walker view {
    can run with Root entry {
        print(printgraph(here));
    }
}
