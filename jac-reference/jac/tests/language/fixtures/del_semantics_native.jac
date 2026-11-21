"""`del` under the native backend, restricted to constructs it lowers.

Every function returns a count so the JIT-compiled symbol can be called
directly and compared against the same program under the Python backend.
"""
node N {
    has t: int;
}

edge E : N --> N {}

def del_edge_ref -> int {
    a = N(1);
    b = N(2);
    a +>:E:+> b;
    a +>:E:+> b;
    del [edge a->:E:->];
    return len([edge a->:E:->]);
}

def del_edge_name -> int {
    a = N(1);
    b = N(2);
    a +>:E:+> b;
    es = [edge a->:E:->];
    del es;
    return len([edge a->:E:->]);
}

def del_node_name -> int {
    a = N(1);
    b = N(2);
    a +>:E:+> b;
    del b;
    return len([edge a->:E:->]);
}

def del_traversal -> int {
    a = N(1);
    a ++> N(2);
    a ++> N(3);
    del [a-->];
    return len([a-->]);
}

def del_subscript_destroys_node -> int {
    a = N(1);
    b = N(2);
    a +>:E:+> b;
    holder = [b];
    del holder[0];
    return len([edge a->:E:->]) * 10 + len(holder);
}

def del_dict_key_destroys_node -> int {
    a = N(1);
    b = N(2);
    a +>:E:+> b;
    holder = {7: b};
    del holder[7];
    return len([edge a->:E:->]) * 10 + len(holder);
}

def del_plain_subscript -> int {
    xs = [1, 2, 3];
    del xs[0];
    return len(xs);
}
