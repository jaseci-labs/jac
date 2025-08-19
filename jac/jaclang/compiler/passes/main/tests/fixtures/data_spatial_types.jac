node NodeA {
    has value: int = 10;
}

node NodeC {
    has value: int = 10;
}

edge EdgeB {
    has value: int = 20;
}

with entry {
    node_1 = a(value=5);
    node_2 = a();
    node_3 = a(value=15);
    node_4 = a(value=20);
    node_5 = c(value=25);
    print(type(root ++> node_1));
    node_1 +>:edge_1 := b(value=5):+> node_2;
    node_1 +>:edge_2 := b(value=10):+> node_3;
    node_1 +>:edge_3 := b(value=15):+> node_4;
    node_1 +>:edge_4 := b():+> node_5;
    node_1 del--> node_2;
    del node_3;
}


node A {
    has val: int = 0;
}

edge a {}

walker W {
    can create with `root entry;
}

impl W.create {
    Start = A(5);
    here +>:a:+> Start;
    Start +>:a:+> A(10) +>:a:+> A(15);
    Start +>:a:+> A(20) +>:a:+> A(25);
}

with entry {
    root spawn W();
    print([root-->-->(`?A)]);
    print([root-->-->-->(`?A)]);
}

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