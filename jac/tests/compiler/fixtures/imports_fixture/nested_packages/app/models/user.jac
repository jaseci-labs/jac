import from ..constants { APP_NAME }

obj User {
    has name: str;
    has app: str = APP_NAME;

    def __repr__ -> str {
        return f"User({self.name}) from {self.app}";
    }
}
