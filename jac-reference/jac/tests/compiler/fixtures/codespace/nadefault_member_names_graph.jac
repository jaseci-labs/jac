"""A pure graph module whose edge has a field named like a browser global."""

import from nadefault_member_names_helper { bump }

node Room {
    has id: int = 0;
}

edge Passage: Room --> Room {
    has window: bool = False;
}

def carve(a: Room, b: Room) -> int {
    a +>:Passage(window=True):+> b;
    return bump(len([a->:Passage:window==True:->]));
}
