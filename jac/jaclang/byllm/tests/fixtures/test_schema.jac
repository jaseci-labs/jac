"""A module whose name ends in 'a', for scope name resolution."""

obj DataItem {
    has value: str;
}

def generate_data -> DataItem by llm();
