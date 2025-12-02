obj MyObj {
    has mylist: list[int] = [1, 2, 3],
        mydict: dict[int, int] = {"a": 2, "b": 4};

    static has mylist2: list[int] = [1, 2, 3];

    def obj_print {
        print("mylist: ", self.mylist);
        print("mydict: ", self.mydict);
    }
}

with entry {
    myo = MyObj();
    myo.obj_print();
}
