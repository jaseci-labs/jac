obj Animal {
    has species: str;
    has sound: str;

}

obj Dog(Animal) {
    has breed: str;
    has trick: str by postinit;

    def postinit {
        self.trick = "Roll over";
    }
}

obj Cat(Animal) {
    def init(fur_color: str) {
        super.init(species="Cat", sound="Meow!");
        self.fur_color = fur_color;
    }
}

with entry {
    dog = Dog(breed="Labrador", species="Dog", sound="Woof!");
    cat = Cat(fur_color="Tabby");

    print(dog.breed, dog.sound, dog.trick);
    # print(f"The dog is a {dog.breed} and says '{dog.sound}'");
    # print(f"The cat's fur color is {cat.fur_color}");
}
