class Apple {
    with entry {
        a = 1;
    }
}

class Orange {
    with entry {
        b = 2;
    }
}

with entry {
    mm = [Apple, Orange];
}

class Banana(mm[1]) {
    with entry {
        c = 3;
    }
}

def return_class()  -> `Type[Apple] {
    print('Returning Apple');
    return Apple;
}

class Kiwi(return_class()) {
    with entry {
        d = 4;
        ;
    }
}

with entry {
    a = Kiwi();
    print(Kiwi.d);
}
