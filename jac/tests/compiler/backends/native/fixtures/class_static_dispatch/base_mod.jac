obj Contract {
    has weight: int = 0;
}

obj Step {
    static has contract: (Contract | None) = None;
}
