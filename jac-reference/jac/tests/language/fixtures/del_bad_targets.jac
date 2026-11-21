# Targets `del` rejects, per issue #8774. Each one used to reach the
# backend and surface as E5043 with the module's first line as its location.
obj Slot {
    has value: int = 1;
}

def ints -> list[int] {
    return [1, 2, 3];
}

def bad_targets(holder: Slot | None) {
    del 5;
    del "text";
    del ();
    del [];
    del holder?.value;
    del *ints();
    del ints();
}
