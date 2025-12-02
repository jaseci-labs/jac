node MyNode {
    has val: int;

    can do with MyWalker entry {
        print(visitor, "from node", self);
    }
}

edge MyEdge {
    has path: int;

    can do with MyWalker entry {
        print(visitor, "from edge", self);
    }
}

walker MyWalker {
    can does with MyNode entry {
        visit [edge <--];
    }
}

with entry {
    n0 = MyNode(0);
    n1 = MyNode(10);
    root +>: MyEdge(0) :+> n0 <+: MyEdge(1) :<+ n1;
    n1 <+: MyEdge(2) :<+ MyNode(20);
    n1 <+: MyEdge(3) :<+ MyNode(30);
    n1 <+: MyEdge(4) :<+ MyNode(40);
    MyWalker() spawn n0;
}
