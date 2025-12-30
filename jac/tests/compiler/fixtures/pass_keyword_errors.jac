def foo() {
    pass;
}

with entry {

    if True {
        pass;
    }

    for i in [1, 2, 3] {
         pass;
    }

    try {
        x = 1 / 0;
    } except Exception{
        pass;
    }
}
