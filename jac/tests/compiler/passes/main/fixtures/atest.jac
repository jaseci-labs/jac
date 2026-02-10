node N {}
walker W {
    can enter with Root entry;
}

with entry {
    n = N();
    root ++> n;
    root spawn W();
    print(42);
}
