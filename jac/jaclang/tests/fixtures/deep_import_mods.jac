import sys;

with entry {
    before_mod = list(sys.modules.keys());
}

import deep.one_lev as one_lev;
import from deep.one_lev { olprint }

with entry {
    after_mod = [
        m
        for m in sys.modules.keys()
        if m not in before_mod
    ];
    print(after_mod);
}
