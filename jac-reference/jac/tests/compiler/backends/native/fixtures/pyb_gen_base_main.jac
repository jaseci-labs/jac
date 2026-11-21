"""Native unit inheriting a SUBSCRIPTED generic Python-side base.

`Kid(PyGenBase[int])` is the shape every compiler pass takes
(`SemDefMatchPass(Transform[Module, Module])`): the base reference is an
`AtomTrailer` carrying an `IndexSlice`, not a bare `Name`. The bridge must
unwrap the subscript to find the Python-side base, or stores to inherited
fields and calls to inherited methods demote instead of bridging.
"""
import from pyb_gen_base_lib { PyGenBase }

obj Kid(PyGenBase[int]) {
    def poke -> int {
        self.count = 99;
        return self.bump(1);
    }
}

def run_all -> int {
    return Kid().poke();
}

with entry {
    print(run_all());
}
