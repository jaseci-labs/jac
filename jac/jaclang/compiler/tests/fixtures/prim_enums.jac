"""Enum member values must agree across codespaces: bare members follow
Python's auto() (1-based, continuing after explicit values)."""

enum Color: int { RED, GREEN, BLUE }
enum Mix: int { A = 5, B, C = 10, D }
enum Status: int { OK = 0, PENDING, FAILED }

def enums_py() -> dict {
    return {
        "red": int(Color.RED),
        "green": int(Color.GREEN),
        "blue": int(Color.BLUE),
        "mix_a": int(Mix.A),
        "mix_b": int(Mix.B),
        "mix_c": int(Mix.C),
        "mix_d": int(Mix.D),
        "ok": int(Status.OK),
        "pending": int(Status.PENDING),
        "failed": int(Status.FAILED),
        "same": Color.RED == Color.RED,
        "diff": Color.RED == Color.GREEN,
        "distinct": int(Color.RED) != int(Color.GREEN)
    };
}

def enums_cl() -> dict {
    return {
        "red": int(Color.RED),
        "green": int(Color.GREEN),
        "blue": int(Color.BLUE),
        "mix_a": int(Mix.A),
        "mix_b": int(Mix.B),
        "mix_c": int(Mix.C),
        "mix_d": int(Mix.D),
        "ok": int(Status.OK),
        "pending": int(Status.PENDING),
        "failed": int(Status.FAILED),
        "same": Color.RED == Color.RED,
        "diff": Color.RED == Color.GREEN,
        "distinct": int(Color.RED) != int(Color.GREEN)
    };
}

def enums_na() -> dict {
    return {};
}
