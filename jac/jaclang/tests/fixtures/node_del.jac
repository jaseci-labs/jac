node person {
    has age: int;
}

with entry {
    p1 = person(10);
    p5 = person(50);
    p2 = person(20);
    p6 = person(60);
    p3 = person(30);
    p7 = person(70);
    p4 = person(40);
    p8 = person(80);
    root ++> p1 ++> p2 ++> p3 ++> p4;
    root ++> p5 ++> p6 ++> p7 ++> p8;
    p4 ++> p8;
    # # before deletion
    a = printgraph(root);
    assert a.count('label=""]') == 9;
    assert a.count('[label="person(') == 8;
    # # delete p2
    del p2 ;
    b = printgraph(root);
    assert b.count('label="person') == 7;
    assert 'age=20' not in b;
    # doublecheck p3 also doesnot attach to it
    c = printgraph(p3);
    assert c.count('label="person') == 7;
    assert 'age=20' not in c;
    # # del multiple nodes
    del [p1, p4] ;
    d = printgraph(root);
    assert d.count('label="person') == 4;
    for i in [10, 20, 30, 40] {
        assert f'age={i}' not in d;
    }
    apple_list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    del apple_list[0] ;
    print('apple list after delete 0 :', apple_list);
    del [apple_list[6], apple_list[7]] ;
    print('apple list after delete 7, 8 :', apple_list);
    obj Inner {
        has c: list;
        has d: int;
    }
    obj Outer {
        has b: Inner;
    }
    a = Outer(b=Inner(c=[1, 2, 3], d=4));
    print('a.b before delete :', a.b);
    del a.b.c[1] ;
    print('a.b after delete :', a.b);
}
