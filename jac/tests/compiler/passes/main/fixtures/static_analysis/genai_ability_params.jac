"""Test: by-llm ability parameters should NOT trigger unused warnings."""
enum Category { WORK, PERSONAL, OTHER }

def categorize(title: str) -> Category by llm();

def summarize(text: str, max_len: int) -> str by llm();
