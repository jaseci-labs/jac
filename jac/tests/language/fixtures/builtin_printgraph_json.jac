import json;

node N {
    has val: int;
}

edge E {
    has val: int = 0;
}

with entry {
    end = root;
    for i in range(0, 2) {
        end +>: E : val=i :+> (end := [N(val=i) for i in range(0, 2)]);
    }
    data = printgraph(nd=root, format="json");
    print(data);
}
