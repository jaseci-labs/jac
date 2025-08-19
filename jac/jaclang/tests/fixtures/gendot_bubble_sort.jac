"""Bubble sort using DS Features of Jac (somparision and swapping happens in inner nodes)."""

glob list1 = [80, 79, 60, 59, 40, 35, 19, 1];

node main_node {
    has no: int = 0;
}

node inner_node {
    has main: int = 0,
        sub: int = 0;
}

walker walker1 {
    can create_main_node with `root entry;
}

impl walker1.create_main_node {
    end = here;
    for i=0 to i<len(list1)+1 by i+=1  {
        end ++> (end := main_node(no=i + 1));
        visit [-->];
    }
}

walker walker2 {
    can skip_root with `root entry {
        visit [-->];
    }
    can process with main_node entry;
}

impl walker2.process {
    global list1 ;

    for j in range(0, len(list1) - (here.no)) {
        here ++> inner_node(main=here.no, sub=j + 1);
    }
    visit [-->];
}

walker walker3 {
    can skiproot with `root entry {
        visit [-->];
    }
    can adjust with main_node entry;
}

impl walker3.adjust {
    here spawn walker4();
}

walker walker4 {
    can skipmain with main_node entry {
        visit [-->];#  print(f"iteration {here.no} started  {list1}");
    }

    can skipin with inner_node entry {
        global list1 ;

        j = here.sub - 1;
        if list1[j] > list1[j + 1] {
            x = list1[j];
            list1[j] = list1[j + 1];
            list1[j + 1] = x;
        }
        #uncomment below to see the swap in each inner nodes
        # print(list1);
    }
}

with entry {
    root spawn walker1();
    root spawn walker2();
    root spawn walker3();
    print(printgraph(root));
}
