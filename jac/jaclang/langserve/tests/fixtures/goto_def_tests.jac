node SomeNode {
    has some_attr: int;

    can with SomeWalker entry {
        print(visitor); # <-- go to definition of here
    }
}

walker SomeWalker {
    can with SomeNode entry {
        print(here); # <-- go to definition of here
        visit [-->(`?SomeNode:some_attr==10)];
    }
}

