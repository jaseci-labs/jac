walker Creator {
    can func2 with `root entry;
}

node node_1 {
    has val: int;

    can func_1 with Creator entry;
}

impl node_1.func_1 {
    print("visiting ", self);
    visit [-->];
}

impl Creator.func2 {
    end = here;
    for i=0 to i<5 by i+=1  {
        end ++> (end := node_1(val=i + 1));
    }
    visit [-->];
}

with entry {
    root spawn :> Creator;
    root spawn |> Creator;
}
