node MyNode {
    has val: int;
}

walker MyWalker {

    can func1 with `root entry {
        print(f"Entering root");
        visit :0:[-->];
    }

    can func2 with MyNode entry {
        print(f"Entering MyNode with value: {here.val}");
        visit :0:[-->];
    }

    can func3 with MyNode exit {
        print(f"Exiting MyNode with value: {here.val}");
    }

    can func4 with `root exit{
        print(f"Exiting from root");
    }
}

with entry {
    root ++> MyNode(5) ++> [MyNode(15), MyNode(20)];
    root ++> MyNode(10) ++> MyNode(25);
    root spawn MyWalker();
}