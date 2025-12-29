obj Animal {
    has : priv species: str;

    def : priv introduce()  -> str {
        return "Hello, I am " + self.species + ". ";
    }
}

obj Dog(Animal) {
    has breed: str;

    def init(breed: str) -> None {
        super.init("Dog");
    }

    def : pub bark()  -> str {
        return "Woof! Woof!";
    }

    obj Body {
        has : pub s: str = "22";
    }
}

glob : priv body: int = 2,
     m = "hi";

with entry {
    myDog = Dog(breed="Golden Retriever");
    print(" Name: " + myDog.species);
    print(" Breed: " + myDog.breed);
    print(myDog.introduce());
    print(myDog.bark());
    body = myDog.Body("33");
    account = BankAccount(3333);
}
