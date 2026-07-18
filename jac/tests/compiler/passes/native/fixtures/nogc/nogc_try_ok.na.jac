"""In-frame try/except stays fully legal in an enforced module: the raise is
inside the try body of its own frame, so normal handling applies."""

def safe(n: int) -> int {
    try {
        if n > 2 {
            raise ValueError("big");
        }
        return 1;
    } except Exception as e {
        return 2;
    }
}

with entry {
    print(safe(1));
    print(safe(5));
}
