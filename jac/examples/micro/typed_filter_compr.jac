node MyObj {
    has a: int;
}

node MyObj2 {
    has a: int;
}

with entry {
    my_list = [];
    for i = 0 to i < 10 by i += 1 {
        my_list.append(MyObj(a=i));
        my_list.append(MyObj2(a=i + 2));
    }
    #[-->](`?`MyObj:a<4, b<5);
    print(my_list(?a<4));
    print(my_list(`?MyObj:a<4,a<3));
    my_list(=a=5);
    print(my_list);
}
