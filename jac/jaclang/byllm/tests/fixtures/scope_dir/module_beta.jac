"""module_beta's `process_data`, which shares its name with module_alpha's."""

obj BetaResult {
    has value: str;
}

def process_data -> BetaResult by llm();
