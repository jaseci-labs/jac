obj User {
    has name: str;
    has email: str;

    def __repr__ -> str {
        return f"User(name={self.name}, email={self.email})";
    }
}
