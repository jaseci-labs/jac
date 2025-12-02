node MyNode {
    has value: int = 0;
}

with entry {
    root ++> (x := MyNode());
    obj_id = jid(x);
    myobj = & obj_id;
    print(obj_id);
    print(myobj);
    print("valid:", myobj == x);
}
