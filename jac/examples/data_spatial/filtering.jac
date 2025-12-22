node A {
    has val: int = 0;
}

node B {
    has val: int = 0;
}

node C {
    has val: int = 0;
}

edge a {}

edge b {}

edge c {}

glob Start = A(5),
     Intermediate = B(10),
     End = C(25);

with entry {
    root +>: a :+> Start;
    Start +>: b :+> Intermediate +>: c :+> C(15);
    Start +>: b :+> A(20) +>: a :+> End;
    Intermediate +>: c :+> End;

    print([root-->->:b:->(`?A)]);
    print([root->:a:->->:b:->->:a:->(`?C)]);
    print([root->:a:->->:b:->->:c:->(`?C)]);
    print([root->:a:->->:b:->->:c:->(`?C)](?val==25));
    # print([root->:a:-> ->:b:-> ->:c:->(`?C)(?val==25)]); # syntax error
    print([root->:a:->->:b:->->:c:->(?val<20)]);
    print([root->:a:->->:b:->->:c:->](?val<20));  # both are similar
}
