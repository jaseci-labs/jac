node MyNode {
    has val: int = 0;
}

edge a {}

edge b {}

edge c {}

glob Start = MyNode(5);

with entry {
    root +>: a :+> Start;
    Start +>: b :+> MyNode(10) +>: c :+> MyNode(15);
    Start +>: b :+> MyNode(20) +>: a :+> MyNode(25);

    print([root-->]);
    print([root<--]);
    print([root->:a:->]);
    print([root->:a:->->:b:->]);
    print([root->:a:->->:b:->->:c:->]);
}
