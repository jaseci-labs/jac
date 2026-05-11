"""Minimal fixture for persistence race and async-blocking tests.

Contains:
  - AddItem walker: appends an Item node to Root (stresses the root edge list).
  - Touch walker: read-modify-write on a Counter node child of Root —
    simulates a sibling walker that reads Root's edges into L1 and commits back.
  - ListItems walker: enumerates Items for assertion.
  - Slow walker: sleeps SLOW_SECONDS to measure event-loop blocking.
"""

import from time { sleep }

node Item {
    has name: str = "";
}

node Counter {
    has value: int = 0;
}

walker:pub AddItem {
    has name: str = "x";

    can create with Root entry {
        here ++> Item(name=self.name);
        report {"ok": True, "name": self.name};
    }
}

walker:pub Touch {
    can touch with Root entry {
        counters = [-->(?:Counter)];
        if not counters {
            here ++> Counter(value=1);
        } else {
            counters[0].value = counters[0].value + 1;
        }
        report {"ok": True};
    }
}

walker:pub ListItems {
    can read with Root entry {
        items = [-->(?:Item)];
        report {"count": len(items), "names": [i.name for i in items]};
    }
}

walker:pub Slow {
    has seconds: float = 3.0;

    can slow with Root entry {
        sleep(self.seconds);
        report {"ok": True, "slept": self.seconds};
    }
}

walker:pub BulkCreate {
    has count: int = 10;

    can create with Root entry {
        for i in range(self.count) {
            here ++> Item(name=f"bulk_{i}");
        }
        report {"ok": True, "created": self.count};
    }
}

walker:pub CountItems {
    can read with Root entry {
        report {"count": len([-->(?:Item)])};
    }
}
