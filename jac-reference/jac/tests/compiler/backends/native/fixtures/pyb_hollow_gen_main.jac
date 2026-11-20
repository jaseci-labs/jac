"""A native class over the generic Python-side chain, constructed and read.

This is `SemDefMatchPass(Transform[Module, Module])` in miniature: the
subclass overrides `transform`, declares native state of its own, and
lets the base's `postinit` be the thing that runs. In the sv lane
`read_back` answers 103; the native lane's shadow construction cannot
reach either the override or the native slot.
"""
import from pyb_hollow_gen_lib { HollowGenMid }

obj Payload {
    has val: int = 0;
}

obj HollowKid(HollowGenMid[Payload, Payload]) {
    has seen: int = 5;

    def transform(ir_in: Payload) -> Payload {
        self.seen = ir_in.val + 100;
        return ir_in;
    }
}

def read_back -> int {
    k = HollowKid(ir_in=Payload(val=3));
    return k.seen;
}

with entry {
    print(read_back());
}
