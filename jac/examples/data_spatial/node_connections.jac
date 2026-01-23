node a {
    has value: int = 10;
}

edge b {
    has value: int = 20;
}

glob node_1 = a(value=5),
     node_2 = a(),
     node_3 = a(value=15),
     node_4 = a(value=20),
     node_5 = a(value=25);

with entry {
    root ++> node_1;
    node_1 +>: edge_1 := b(value=5) :+> node_2;
    node_1 +>: edge_2 := b(value=10) :+> node_3;
    node_1 +>: edge_3 := b(value=15) :+> node_4;
    node_1 +>: edge_4 := b() :+> node_5;

    node_1 del --> node_2;
    del node_3;
}
