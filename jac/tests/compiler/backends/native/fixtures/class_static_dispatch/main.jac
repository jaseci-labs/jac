"""A static read through a class value dispatches on the class it holds, for
subclasses another module defines and this one names."""
import from .base_mod { Step }
import from .steps { FirstStep, SecondStep }

def weight_of(p: type[Step]) -> int {
    found = p.contract;
    return found.weight if found is not None else -1;
}

def chk_static_dispatch -> int {
    schedule: list[type[Step]] = [FirstStep, SecondStep, Step];
    total = 0;
    for p in schedule {
        total = total * 10 + weight_of(p);
    }
    return total;
}

with entry {
    print(chk_static_dispatch());
}
