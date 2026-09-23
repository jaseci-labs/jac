"""`copy.deepcopy` of an archetype holding an `any` field has no runtime type
to dispatch that field's copy on, so native lowering refuses it naming the
field."""

import copy;

obj Slot {
    has label: str = "l",
        payload: any = None;
}

def run_probe {
    s = Slot(label="a", payload=[1]);
    t = copy.deepcopy(s);
    print(t.label);
}

with entry {
    run_probe();
}
