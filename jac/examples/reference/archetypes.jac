def print_base_classes(cls: type) -> type {
    print(
        f"Base classes of {cls.__name__}: {[c.__name__ for c in cls.__bases__]}"
    );
    return cls;
}

class Animal {}

obj Domesticated {}

@print_base_classes
node Pet(Animal, Domesticated) {}

walker Person(Animal) {}

walker Feeder(Person) {}

@print_base_classes
walker Zoologist(Feeder) {}

async walker MyWalker {}
