import from ..models.user { User }
import from ..constants { VERSION }

def create_user(name: str) -> User {
    return User(name=name);
}

def get_version -> str {
    return VERSION;
}
