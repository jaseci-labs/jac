import from .type_identity_types { RemoteValue }
import from .type_identity_library { make_value, make_child }

def probe -> int {
    value = make_value();
    child = make_child();
    if type(value) is not RemoteValue {
        return 1;
    }
    if type(child) is RemoteValue {
        return 2;
    }
    return 0;
}

with entry {
    assert probe() == 0;
}
