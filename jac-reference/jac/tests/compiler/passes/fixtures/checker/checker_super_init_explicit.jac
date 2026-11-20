# Test super.init() with explicit init methods (deep inheritance chain)

# Level 1: Base class with explicit init
obj Animal {
    def init(name: str, age: int) {
        self.name = name;
        self.age = age;
    }
}

# Level 2: Dog extends Animal
obj Dog(Animal) {
    def init(name: str, age: int, breed: str) {
        super.init(name, age);
        self.breed = breed;
    }
}

# Level 3: TrainedDog extends Dog
obj TrainedDog(Dog) {
    def init(name: str, age: int, breed: str, skill: str) {
        super.init(name, age, breed);
        self.skill = skill;
    }
}

# Level 4: ServiceDog extends TrainedDog
obj ServiceDog(TrainedDog) {
    def init(name: str, age: int, breed: str, skill: str, owner: str) {
        super.init(name, age, breed, skill);
        self.owner = owner;
    }
}

# Level 5: GuideDog extends ServiceDog
obj GuideDog(ServiceDog) {
    def init(name: str, age: int, breed: str, owner: str, certified: bool) {
        super.init(name, age, breed, "guiding", owner);
        self.certified = certified;
    }
}

# ERROR: Wrong type at level 2
obj BadDog1(Animal) {
    def init(x: int) {
        super.init(123, 5);  # ERROR: int instead of str for 'name'
    }
}

# ERROR: Wrong type at level 3
obj BadDog2(Dog) {
    def init(x: int) {
        super.init("Rex", "five", "Lab");  # ERROR: str instead of int for 'age'
    }
}

# ERROR: Missing argument at level 4
obj BadDog3(TrainedDog) {
    def init(x: int) {
        super.init("Rex", 3, "Lab");  # ERROR: Missing 'skill'
    }
}

# ERROR: Wrong type at level 5
obj BadDog4(ServiceDog) {
    def init(x: int) {
        super.init("Rex", 3, "Lab", "guiding", 123);  # ERROR: int instead of str for 'owner'
    }
}
