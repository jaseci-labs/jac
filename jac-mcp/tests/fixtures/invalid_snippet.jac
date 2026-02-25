# This file intentionally contains Python-style syntax errors for testing

class Animal:
    def __init__(self, name: str, species: str):
        self.name = name
        self.species = species

    def describe(self) -> str:
        return f"{self.name} is a {self.species}"
