"""A node archetype has a graph anchor that `copy.copy` would share and
`copy.deepcopy` would recursively duplicate, which the Python runtime does not
handle either; native lowering refuses it naming the node."""

import copy;

node Station {
    has name: str = "s";
}

def run_probe {
    s = Station(name="a");
    t = copy.copy(s);
    print(t.name);
}

with entry {
    run_probe();
}
