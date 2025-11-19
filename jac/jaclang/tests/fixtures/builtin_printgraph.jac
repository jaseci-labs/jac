node a {
    has val: int;
}


edge Edge1 {
    has val: int = 5;
}


with entry {
    end = root;
    for i in range(0, 4) {
        end ++> (end := [ a(val=i) for i in range(0, 3) ]);
    }
    x = [ a(val=i) for i in range(0, 3) ];
    end = x[1];
    for i in range(0, 8) {
        locals()[chr(ord('b') + i)] = (values := [ a(val=j * i + 5.2 * i + 6) for j in range(0, 3) ]);
        end ++> (end := values);
    }
    p = b[1];
    for k in range(0, 10) {
        p +>: Edge1 : val=6 :+> (p := a(val=k));
    }
    # b++>c;
     # c++>b;
     d1 = printgraph();
    l1 = d1 |> len;
    #generate dot for all connected with root
     #  d2=printgraph(b[1],Traverse=True,depth=20,bfs=False,node_limit=12);l2=d2|>len;  #generate dot for all connected with root
     d2 = printgraph(
        b[1],
        edge_type=["Edge1"],
        depth=20,
        traverse=True,
        bfs=False,
        node_limit=19
    );
    l2 = d2 |> len;
    #generate dot for all connected with root
     d3 = printgraph(b[2], edge_limit=5, depth=5);
    l3 = d3 |> len;
    #generate dot for all connected with b[1] node
     d4 = printgraph(
        b[1],
        bfs=True,
        edge_type=["Edge1"],
        node_limit=100,
        edge_limit=900,
        depth=300
    );
    l4 = d4 |> len;
    #generate dot from nodes with depth 3 connected with b[1] node
     d5 = printgraph(b[1], node_limit=10, edge_limit=90);
    l5 := d5 |> len;
    #generate dot from nodes with depth 3 connected with b[1] node
    print(
        d1.count('a(val') == 12,
        d1.count('#FFFFE0') == 3,
        'Root' in d1,
        d1.count('label=""') == 30
    );
    print(
        d2.count('a(val') == 19,
        d2.count('#F5E5FF') == 2,
        'Edge1' not in d2,
        d2.count('label=""') == 42
    );
    print(d3.count('a(val') == 6, d3.count('label=""') == 5, d3.count('#F5E5FF') == 1);
    print(d4.count("a(val") == 25, d4.count('label=""') == 66, d4.count('#FFF0F') == 3);
    print(d5.count("Edge1(val=6)") == 2, d5.count('label=""') == 24);
    # print(l3<l2);

    # print(d1);

    # print(d2);

    # print(d3);

    # print(d4);

    # print(printgraph(node=b[2],bfs=True,depth=3.96,edge_limit=12,node_limit=12.96));

}
