import from math { sin as s , cos , sqrt as sq }
include random;
import from jaclang.tests.test_cli { JacCliTests as Jac }
import from deep.mycode { code as c }
import hashcheck as h , assign_compr as a;
import from jacsamp { my_print as m }


with entry {
    print(sq(4), s(30), cos(30));
    print(randint(1, 10));
    print(m("--->my_print<---"));
    print(h.a, a.mvar);
    print(c());
    print(Jac);
}
