node City {
    has name: str;
}

with entry {
    c: City = City("Metropolis");
    root ++> c;
    x: str = root;  # <- error
}
