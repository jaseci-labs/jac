import from tests.language.fixtures.deep.one_lev_dup { olprint }
import from tests.language.fixtures.needs_import_dup { my_print, pyfunc }

with entry {
    # print(olpyprint());
    print(olprint());
    print(my_print(pyfunc));
}
