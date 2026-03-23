"""B3 fix: match/case scope narrowing.

Before this fix, the match subject's type was not narrowed inside case bodies,
so accessing subclass-specific attributes produced errors.
"""

obj Animal {
    has name: str = "";
}

obj Dog(Animal) {
    has breed: str = "unknown";
}

obj Cat(Animal) {
    has indoor: bool = True;
}

with entry {
    pet: Animal = Dog(name="Rex", breed="Lab");
    match pet {
        case Dog():
            b: str = pet.breed;  # narrowed to Dog

        case Cat():
            i: bool = pet.indoor;  # narrowed to Cat

        case _:
            n: str = pet.name;  # stays Animal
    }
}
