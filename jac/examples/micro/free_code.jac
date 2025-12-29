"""Organized free coding at module level."""

obj Obj1 {
    has var: int;

    def init {
        self.var = 1;
    }
}
# with entry {  # allowed but discouraged
#    o1 = spawn Obj1; o1::init;
# }
obj Obj2 {
    has var: int;

    def init {
        self.var = 2;
    }
}
# with entry {  # allowed but discouraged
#     o2 = spawn Obj2; o2::init;
# }
obj Obj3 {
    has var: int;

    def init {
        self.var = 3;
    }
}
# with entry {  # allowed but discouraged
#     o3 = spawn Obj1; o3::init;
# }
glob o1 = spawn Obj1;

with entry {
    |> o1.init;
}

glob o2 = spawn Obj2;

with entry {
    |> o2.init;
}

glob o3 = spawn Obj3;

with entry {
    |> o3.init;
    print(o1.var);
    print(o2.var);
    print(o3.var);
}
