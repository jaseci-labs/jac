# Bug #SELF-ANNO-TVAR: constructor overload's `self: C[T]` annotation must bind T.

import tempfile;


def takes_str(s: str) {
    print(s);
}


def go {
    td = tempfile.TemporaryDirectory();
    takes_str(td.__enter__());

    with tempfile.TemporaryDirectory() as p {
        takes_str(p);
    }
}
