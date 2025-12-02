node MyNode {
    has Name: str;
}

edge a {}

edge b {}

with entry {
    Start = MyNode("Start");
    End = MyNode("End");
    mid = MyNode("Middle");
    root <+: a :<+ Start;
    root +>: a :+> End;
    root +>: b :+> mid;
    root +>: a :+> mid;

    print([root-->]);
}
