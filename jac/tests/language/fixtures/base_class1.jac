import test_py;

class B(test_py.A) {}

with entry {
    a = test_py.A();
    b = B();

    a.start();
    b.start();
}
