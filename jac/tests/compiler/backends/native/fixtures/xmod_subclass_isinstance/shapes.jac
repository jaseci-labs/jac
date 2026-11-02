"""Classes whose isinstance checks are compiled here, before any subclass."""

obj Base {
    has level: int;
}

obj Mid(Base) {
    has depth: int = 0;
}

obj Plain {
    has tag: int;
}

def is_base(value: &object) -> bool {
    return isinstance(value, Base);
}

def is_mid(value: &object) -> bool {
    return isinstance(value, Mid);
}

def is_plain(value: &object) -> bool {
    return isinstance(value, Plain);
}

def base_is_mid(value: &Base) -> bool {
    return isinstance(value, Mid);
}
