node Node {
    has val: int;
}
edge Edge {
    has val: str = "";
}

with entry {
    root +>:Edge:val="1":+> Node(val=1);

    # a = [root-->];
    # a = _.refs(_.Path(_.root())._out())
    # print(a);

    # a = [root->:Edge:val=="1":->(`?Node:val==1)];
    # a = _.refs(_.Path(_.root())._out(edge=lambda i: isinstance(i, Edge) and i.val == '1', node=lambda i: isinstance(i, Node) and i.val == 1))
    # print(a);

    a = _.refs(_.Path(_.root())._out());
    print(a);

    a = _.refs(_.Path(_.root())._out(
        edge=_.query(P._and(P._eq("name","Edge"), P._eq("archetype.val", "1"))),
        node=_.query(P._and(P._eq("name","Node"), P._eq("archetype.val", 2)))
    ));
    print(a);
}