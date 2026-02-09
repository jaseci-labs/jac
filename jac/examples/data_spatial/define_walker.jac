node A {
    has val: int = 0;
}

edge a {}

walker W {
    can create with Root entry;
}

impl W.create{
    Start = A(5);
    here +>: a :+> Start;
    Start +>: a :+> A(10) +>: a :+> A(15);
    Start +>: a :+> A(20) +>: a :+> A(25);
}

with entry {
    root spawn W();
    print([root-->-->(?:A)]);
    print([root-->-->-->(?:A)]);
}
