from dataclasses import dataclass, field


@dataclass
class Animal:
    species: str
    sound: str


@dataclass
class Dog(Animal):
    breed: str
    trick: str = field(init=False)

    def __post_init__(self):
        self.trick = "Roll over"


@dataclass
class Cat(Animal):

    def __init__(self, fur_color: str):
        super().__init__(species="Cat", sound="Meow!")
        self.fur_color = fur_color


dog = Dog(breed="Labrador", species="Dog", sound="Woof!")
cat = Cat(fur_color="Tabby")

print(dog.breed, dog.sound, dog.trick)
# print(f'The dog is a {dog.breed} and says "{dog.sound}"')
# print(f"The cat's fur color is {cat.fur_color}")
