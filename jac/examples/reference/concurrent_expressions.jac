import from time { sleep }

node A {
    has val: int = 0;

    can do with entry {
        print("Started");
        sleep(2);
        print(visitor);

    }
}

walker B {
    has name: str;

}

def add(x: int, y: int) -> int {
    print(x);
    z = x + y;
    sleep(2);
    print(x);
    return z;
}

with entry {
    t1 = flow A() spawn B("Hi") ;

    task1 = flow add(1, 10) ;
    task2 = flow add(2, 11) ;
    print("All are started");
    res1 = wait task1 ;
    res2 = wait task2 ;
    print("All are done");
    print(res1);
    print(res2);
}
