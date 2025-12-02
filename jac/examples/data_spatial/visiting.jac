node MyNode {
    has Name: str;
}

edge a {}

with entry {
    Start = MyNode("Start");
    End = MyNode("End");
    root <+: a :<+ Start;
    root +>: a :+> End;

    print([root-->]);
    print([root<--]);
    print([Start-->]);
    print([End<--]);
}
