"""The leaf, two module boundaries from the slot it touches.

`DeepMid` is compiled `symtab_ir_only` as a dependency, so its own
`adopt_imported_bases` never runs and its recorded linearization stops at
`DeepBase`... which the leaf then copies as `['DeepLeaf', 'DeepMid']`.
`slot_a` is therefore invisible here unless the chain is continued through
`DeepMid`'s own recorded ancestry. That is the exact shape of
`NaIRGenPass -> Transform -> BaseTransform`.
"""

import from .deep_chain_mid { DeepMid }

obj DeepLeaf(DeepMid) {
    has slot_c: int = 0;

    def store_grandparent_slot(v: int) {
        self.slot_a = v;
    }

    def read_grandparent_slot -> int {
        return self.slot_a;
    }
}

def probe_deep(v: int) -> int {
    d = DeepLeaf();
    d.store_grandparent_slot(v);
    return d.read_grandparent_slot();
}
