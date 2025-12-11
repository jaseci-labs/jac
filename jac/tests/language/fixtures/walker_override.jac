walker a {
    can foo with `root entry {
        print("foo");
    }
}

walker b(a) {
    can bar with `root entry {
        print("bar");
    }
}

walker c(b) {
    override can foo with `root entry {
        print("baz");
    }
}

with entry {
    root spawn c();
}
