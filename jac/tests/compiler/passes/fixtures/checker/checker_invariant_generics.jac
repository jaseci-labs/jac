"""Invariant generic arguments reject unsound container substitutions."""

obj Animal {}
obj Dog(Animal) {}
obj Box[T] {}
obj DogBox(Box[Dog]) {}

def accept_float(values: list[float]) {}
def accept_animal(values: list[Animal]) {}
def accept_objects(values: list[object]) {
    values.append("not a dog");
}

def accept_animal_or_str(values: list[Animal | str]) {}
def accept_box_animals(values: Box[Animal]) {}
def accept_box_objects(values: Box[object]) {}
def accept_box_animal_or_str(values: Box[Animal | str]) {}

glob ints: list[int] = [1];

with entry {
    accept_float(ints);
}

glob dogs: list[Dog] = [];

with entry {
    accept_animal(dogs);
    accept_objects(dogs);
}

glob dog_or_str: list[Dog | str] = [];

with entry {
    accept_animal_or_str(dog_or_str);

    dog_box: DogBox = DogBox();
    accept_box_animals(dog_box);
    accept_box_objects(dog_box);
    accept_box_animal_or_str(dog_box);
}
