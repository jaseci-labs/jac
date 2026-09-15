"""module_alpha's `process_data`, which shares its name with module_beta's."""

obj AlphaResult {
    has value: str;
}

def process_data -> AlphaResult by llm();
