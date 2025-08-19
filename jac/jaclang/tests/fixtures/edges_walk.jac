walker creator{
    can create with `root entry;
}

node node_a{
    has val:int;
}

edge Edge_a{
    has value:int = 10;
}

edge Edge_b{
    has value1:int =  20;
}
edge Edge_c{
    has value2 :int = 30;
}
impl creator.create{
    for i = 0 to i <2 by i+=1{
        here +>: Edge_c:value2=30:+> (node_a(val=i+1));
        visit[-->];
    }
    here +>:Edge_a:value=10:+> (end := node_a(val=i + 10));
    end +>: Edge_b:value1=20 :+> (last := node_a(val=i+20));
    for j = 0 to j<2 by j+=1{
        last +>: Edge_c:value2=40 :+> (node_a(val=i+40));
    }
}

with entry{
    print(root spawn creator());
    print(printgraph(root));
    print([root ->:Edge_a:->]);
    print([root ->:Edge_c:->]);
    print([root ->:Edge_a:-> ->:Edge_b:->]);
    print([root ->:Edge_a:-> ->:Edge_b:-> ->:Edge_c:->]);
}