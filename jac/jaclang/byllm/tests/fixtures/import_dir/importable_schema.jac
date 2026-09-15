"""A `by llm()` function imported from another module; the module name ends in 'a'."""

obj ImportedData {
    has name: str;
}

def get_imported_data(txt: str) -> ImportedData by llm();
