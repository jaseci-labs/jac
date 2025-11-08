#Filter comprehension
import random;

obj TestObj {
    has x: int = random.randint(0, 15),
        y: int = random.randint(0, 15),
        z: int = random.randint(0, 15);
}

with entry {
    random.seed(42);
    apple = [];
    for i=0 to i<100 by i+=1  {
        apple.append(TestObj());
    }

    # check if all apple's x are random between 0 and 15
    print(apple(?x >= 0, x <= 15) == apple);
}

obj MyObj {
    has apple: int = 0,
        banana: int = 0;
}

with entry {
    x = MyObj();
    y = MyObj();
    mvar = [x, y](=apple=5, banana=7);
    print(mvar);
}
