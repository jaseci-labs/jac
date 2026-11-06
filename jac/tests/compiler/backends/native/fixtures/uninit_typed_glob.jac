"""A typed module glob with no initializer is a zero slot a setter fills later."""

obj Realm {
    has name: str = "realm",
        depth: int = 0;
}

glob KEY_BASE: int = 10,
     _OBJ_REALM: Realm;
glob _LABEL: str,
     _COUNT: int,
     _RATIO: float;

def set_realm(realm: Realm) {
    _OBJ_REALM = realm;
}

def set_label(label: str, count: int) {
    _LABEL = label;
    _COUNT = count;
    _RATIO = count / 4;
}

def realm_name -> str {
    return _OBJ_REALM.name + ":" + str(_OBJ_REALM.depth + KEY_BASE);
}

with entry {
    set_realm(Realm(name="first", depth=1));
    print(realm_name());
    set_realm(Realm(name="second", depth=2));
    print(realm_name());
    set_label("count", 6);
    print(_LABEL, _COUNT, _RATIO);
}
