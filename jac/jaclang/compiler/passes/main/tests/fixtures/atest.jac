node N {}
walker W {
    can enter with `root entry;
}

with entry {
    n = N();
    root ++> n;
    root spawn W();
    print(42);
}
