class Animal {}

obj Domesticated {}

@print_base_classes
node Pet(Animal , Domesticated) {}

walker Person(Animal) {}

walker Feeder(Person) {}

@print_base_classes
walker Zoologist(Feeder) {}
