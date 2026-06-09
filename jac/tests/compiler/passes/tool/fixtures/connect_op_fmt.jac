"""Connect-operator formatting: compact, consistent with traversal/disconnect."""
node N {
    has v: int = 0;
}

edge E {
    has w: int = 0;
}

walker build {
    can run with `root entry {
        a = root +>:E:+> N(v=1);
        b = a[0] +>:E:w=5:+> N(v=2);
        c = a[0] +>:E:w=1, v=2:+> N(v=3);
        d = a[0] <+:E:<+ N(v=4);
        e = a[0] <+:E:+> N(v=5);
        f = a[0] ++> N(v=6);
        g = a[0] <++ N(v=7);
        h = a[0] <++> N(v=8);
        targets = [a[0]->:E:w>0:->];
        a[0] del ->:E:-> N(v=1);
    }
}
