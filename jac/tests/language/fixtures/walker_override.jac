walker a {
    can foo with Root entry {
        print("foo");
    }
}

walker b(a) {
    can bar with Root entry {
        print("bar");
    }
}

walker c(b) {
    override can foo with Root entry {
        print("baz");
    }
}

with entry {
    root spawn c();
}
