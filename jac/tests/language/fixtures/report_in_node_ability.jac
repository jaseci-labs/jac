node Spot {
    can greet with Visitor entry {
        report "hi";
    }
}

walker Visitor {
    can go with Root entry {
        here ++> Spot();
        visit [-->];
    }
}

with entry {
    w = root spawn Visitor();
    print(w.reports);
}
