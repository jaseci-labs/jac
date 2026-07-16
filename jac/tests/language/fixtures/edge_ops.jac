import random;

node node_a {
    has value: int;
}

walker Creator {
    can create with Root entry;
    can travel with Root | node_a entry;
}

edge MyEdge {
    has val: int = 5,
        val2: int = 10;
}

impl Creator.create{
    end = here;
    for i = 0 with i < 5 as i += 1 {
        end ++> (end := node_a(value=i + 1));
        if i == 2 {
            for j = 0 with j < 3 as j += 1 {
                end +>: MyEdge : val=random.randint(1, 15),val2=random.randint(1, 5) :+> node_a(
                    value=j + 10
                );
            }
            print(
                [
                    (arch.val, arch.val2)
                    for i in end.__jac__.edges
                    if isinstance(arch := i.archetype, MyEdge)
                ]
            );
        }
    }
    for i = 0 with i < 3 as i += 1 {
        end +>: MyEdge : val=random.randint(1, 20) :+> node_a(value=i + 5);
    }
}

impl Creator.travel{
    for i in [->:MyEdge:val<=5:->] {
        print(i.value);
    }
    visit [-->];
}

with entry {
    random.seed(1);
    root spawn Creator();
    #print(root._jac_.gen_dot());
}
