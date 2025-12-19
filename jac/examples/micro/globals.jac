"""Globals are explicitly defined."""

glob age = 25,
     temperature = 98.6,
     name = "John Doe";
glob fruits = ["apple", "banana", "orange"];
glob person = {"name": "Alice", "age": 30, "city": "New York"};

def print_globs()  -> None {
    global fruits,age;
    age = 30;
    fruits = ["pear", "grape", "kiwi"];
    print(age, temperature, name);  # global <name> references global vs local
    fruits |> print;
    person |> print;
}
