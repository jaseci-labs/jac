node MyNode {
    has val: int;
}

walker MyWalker {

    can func1 with `root entry {
        print(f"Entering root");
        visit [-->];
    }

    can func2 with MyNode entry {
        print(f"Entering MyNode with value: {here.val}");
        visit [-->];
    }

    can func3 with MyNode exit {
        print(f"Exiting MyNode with value: {here.val}");
    }

    can func4 with `root exit{
        print(f"Exiting from root");
    }
}

with entry {
    root ++> MyNode(5) ++> MyNode(15);
    root ++> MyNode(10);
    root spawn MyWalker();
}