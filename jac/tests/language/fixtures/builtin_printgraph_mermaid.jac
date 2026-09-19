node N {
    has val: int;
}

edge E: any --> any {
    has val: int = 0;
}

glob end = root;
with entry {
    for i in range(0, 2) {
        end +>:E:val=i:+> (end := [N(val=i) for i in range(0, 2)]);
    }
    data = printgraph(nd=root, format="mermaid");
    print(data);
}
