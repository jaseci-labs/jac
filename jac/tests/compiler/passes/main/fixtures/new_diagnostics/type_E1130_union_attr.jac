"""Fixture for E1130: Not all union members have attribute."""

obj Cat {
    has name: str;
    has purr_volume: int;
}

obj Dog {
    has name: str;
    has bark_volume: int;
}

with entry {
    pet: Cat | Dog = Cat(name="Whiskers", purr_volume=5);
    print(pet.name);          # <-- Ok: both Cat and Dog have 'name'
    print(pet.purr_volume);   # <-- Error E1130: Dog has no 'purr_volume'
}
