node Item {
    has label: str = "";
}

walker Visitor {
    can look with Item entry {
        print(here.label);
    }
}
