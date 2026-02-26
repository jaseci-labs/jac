import from typing { Protocol }

obj SizeProtocol {
    def __len__()  -> int {
        return 0;
    }
}

obj Runnable(Protocol) {
    def run()  -> None { }
}

obj Thread {
    def run()  -> None {
        print("Thread Running");
    }
}

obj Foo {}

def run(runnable: Runnable) -> None {
    runnable.run();
}

with entry {
    # len() expect protocol with __len__ method
    lst: list[int] = [1, 2, 3];
    len(lst);  # <-- Ok
    len(SizeProtocol());  # <-- OK
    len(Foo());  # <-- Error

    # run() expect protocol with run method
    run(Thread());  # <-- OK
    run(Foo());  # <-- Error
}
