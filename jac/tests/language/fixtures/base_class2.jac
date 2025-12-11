import from test_py { A }

class B(A) {}

with entry {
    a = A();
    b = B();

    a.start();
    b.start();
}
