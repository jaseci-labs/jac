node MyNode {
    has Name: str;
}

edge a {}

glob Start = MyNode("Start"),
     End = MyNode("End");

with entry {
    root <+: a :<+ Start;
    root +>: a :+> End;

    print([root-->]);
    print([root<--]);
    print([Start-->]);
    print([End<--]);
}
