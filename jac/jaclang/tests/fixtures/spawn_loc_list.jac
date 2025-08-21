node MyNode{
    has val:int;
}

edge MyEdge {
    has val:int;
}

walker W {
    can func1 with MyNode exit {
        visit [-->];
        print("I am here", here);
    }

    can func2 with MyEdge exit {
        print("I am here", here);
    }
}

with entry {
    (node1:=MyNode(5)) ++> MyNode(10);
    node1 spawn W();
    W() spawn MyNode(15);
    edge1 = MyEdge(100);
    root +>:edge1:+> MyNode(30);
    W() spawn [MyNode(20), MyNode(25), edge1];
}