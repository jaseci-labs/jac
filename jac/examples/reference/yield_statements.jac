def myFunc {
    yield "Hello";
    yield 91;
    yield "Good Bye";
    yield ;
}

with entry {
    x = myFunc();
    for z in x {
        print(z);
    }
}
