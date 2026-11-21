"""test file for assign_compr."""
obj MyObj {
    has apple: int = 0,
        banana: int = 0;
}

with entry {
    x = MyObj();
    y = MyObj();

    mvar = [x, y](=apple=5,banana=7);
    print(mvar);
    # mvar = [x, y];
    # mvar(* apple=8, banana=7);
    # print(mvar);
}
