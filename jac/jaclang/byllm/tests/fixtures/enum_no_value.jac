"""A bare enum, whose members carry no values, as a `by llm()` return type."""

enum Tell { YES, NO }

"""Yes/No answering Bot"""
def yes_or_no(question: str) -> Tell by llm();
