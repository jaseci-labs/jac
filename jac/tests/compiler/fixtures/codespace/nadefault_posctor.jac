obj Vec {
    has x: float = 0.0;
    has z: float = 0.0;
}

def make() -> float {
    return Vec(1.0, 3.0).z;
}
