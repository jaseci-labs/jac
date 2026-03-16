"""Fixture for W0061: new bracket filter syntax should NOT warn."""

node MyObj {
    has a: int;
}

with entry {
    my_list: list = [MyObj(a=1), MyObj(a=2), MyObj(a=5)];
    print(my_list[?:MyObj, a<4]);
}
