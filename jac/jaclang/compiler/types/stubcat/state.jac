import os;
import type from jaclang.compiler.types.stubcat.reader { StubCatalog }

glob _ACTIVE: list[StubCatalog | None] = [None];

def active -> StubCatalog | None {
    return _ACTIVE[0];
}

def set_active(catalog: StubCatalog | None) {
    _ACTIVE[0] = catalog;
}

def env_disabled -> bool {
    return bool(os.environ.get("JAC_STUBCAT_BUILDING"));
}
