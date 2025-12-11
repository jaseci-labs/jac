node simple {
    has tag: str;
}

edge simple_edge {
    has index: int = 0;
}

with entry {
    if (not [root-->]) {
        root +>: simple_edge : index=0 :+> simple(tag="first");
        root +>: simple_edge : index=1 :+> simple(tag="second");
    }
}

walker filter_on_edge_get_edge {
    can filter with `root entry {
        print([edge ->:simple_edge:index==1:->]);
    }
}

walker filter_on_edge_get_node {
    can filter with `root entry {
        print([->:simple_edge:index==1:->]);
    }
}

walker filter_on_node_get_node {
    can filter with `root entry {
        print([-->](?tag=="second"));
    }
}

walker filter_on_node_get_edge {
    can filter with `root entry {
        print([edge -->](?tag=="second"));
    }
}

walker filter_on_edge_visit {
    can filter with `root entry {
        visit ([->:simple_edge:index==0:->]);
    }

    can end with simple entry {
        print(here);
    }
}

walker filter_on_node_visit {
    can filter with `root entry {
        visit ([-->](?tag=="first"));
    }

    can end with simple entry {
        print(here);
    }
}
