walker Visitor {
    can travel with `root entry {
        visit [-->] else {
            visit root;
        }
    }
}

node item {
    can speak with Visitor entry {
        print("Hey There!!!");
        disengage;
    }
}

with entry {
    for i=0 to i<5 by i+=1  {
        root ++> item();
    }
    root spawn Visitor();
}
