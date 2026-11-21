import from .type_identity_types { RemoteValue, RemoteChild }

def make_value -> RemoteValue {
    return RemoteValue();
}

def make_child -> RemoteValue {
    return RemoteChild();
}
