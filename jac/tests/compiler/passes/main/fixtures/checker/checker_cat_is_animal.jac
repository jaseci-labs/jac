obj Animal {}
obj Cat(Animal) {}
obj Lion(Cat) {}

obj NotAnimal {}

def animal_func(a: Animal) -> None { }

with entry {
    cat: Cat = Cat();
    lion: Lion = Lion();
    not_animal: NotAnimal = NotAnimal();

    animal_func(cat);  # <-- Ok
    animal_func(lion);  # <-- Ok
    animal_func(not_animal);  # <-- Error
}
