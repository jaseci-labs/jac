node MyNode {
    has val: int;

    can ability1 with MyWalker entry {
        print("MyWalker from node", visitor);
    }

    can ability2 with MyWalker exit {
        print("MyWalker from node", visitor);
    }
}

edge MyEdge {
    has path: int;

    can ability3 with MyWalker entry {
        print("MyWalker from edge", visitor);
    }

    can ability4 with MyWalker exit {
        print("MyWalker from edge", visitor);
    }
}

walker MyWalker {
    can ability5 with MyEdge entry {
        print("MyEdge from walker", here);
    }

    can ability6 with MyEdge exit {
        print("MyEdge from walker", here);
    }

    can ability7 with MyNode entry {
        print("MyNode from walker", here);
        visit [edge -->];
    }

    can ability8 with MyNode exit {
        print("MyNode from walker", here);
        visit [edge -->];
    }
}

with entry {
    e1 = MyEdge(1);
    root +>: e1 :+> MyNode(10) +>: MyEdge(2) :+> MyNode(20);
    MyWalker() spawn e1;
}
