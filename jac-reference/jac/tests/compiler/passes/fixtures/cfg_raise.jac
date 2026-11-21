def safe_sqrt(x: float) -> float {
    if x < 0 {
        raise ValueError("negative");
    }
    return x ** 0.5;
}
