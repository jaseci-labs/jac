"""Fixture for the default, MRO, constructor and override rules.

Each line marked `# E10xx` must report exactly that code, and nothing else
may report these codes.
"""

import from collections.abc { Sequence }
import from importlib.abc { MetaPathFinder }
import from importlib.machinery { ModuleSpec }
import from types { ModuleType }

def default_reads_later(a: int = b, b: int = 1) -> int {  # E1007
    return a + b;
}

def default_reads_earlier(a: int, b: int = a) -> int {
    return a + b;
}

obj A {}
obj B(A) {}
obj Bad(A, B) {}  # E1008

obj HA {
    has x: int = 0;

    def init(y: int) {
        self.x = y * 2;
    }
}

obj HB(HA) {}

obj HC(HA) {  # E1009
    has z: int = 0;
}

obj HD(HA) {  # E1012
    def postinit {
        self.x = 1;
    }
}

obj PA {
    has a: int = 0;
}

obj PB {
    has b: int = 0;
}

obj PC(PA, PB) {}

obj Base {
    has n: int = 0;

    def process(data: str, k: int = 1) -> int {
        return len(data) + k;
    }
}

obj Good(Base) {
    def process(data: str, k: int = 1) -> int {
        return len(data) * 2;
    }
}

obj BadSig(Base) {
    def process(data: int, k: int = 1) -> str {  # E1013
        return str(data);
    }
}

obj BadDefault(Base) {
    def process(data: str, k: int = 2) -> int {  # E1014
        return 0;
    }
}

obj BadField(Base) {
    has n: str = "";  # E1013
}

obj StubDefaultFinder(MetaPathFinder) {
    def find_spec(
        fullname: str, path: Sequence[str] | None, target: ModuleType | None = None
    ) -> ModuleSpec | None {
        return None;
    }
}
