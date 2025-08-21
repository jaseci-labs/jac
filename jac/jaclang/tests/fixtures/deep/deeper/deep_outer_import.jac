import from jaclang.tests.fixtures.deep.one_lev_dup { olprint }
import from jaclang.tests.fixtures.needs_import_dup { my_print , pyfunc }


with entry {
    # print(olpyprint());
    print(
        olprint()
    );
    print(my_print(pyfunc));
}
