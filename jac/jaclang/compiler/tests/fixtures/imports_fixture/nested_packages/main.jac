import from app.services.user_service { create_user, get_version }
import from app.models.user { User }
import from app.constants { APP_NAME }

with entry {
    print(f"Nested deep - APP_NAME: {APP_NAME}");
    print(f"Nested deep - get_version(): {get_version()}");
    user = create_user("Alice");
    print(f"Nested deep - create_user('Alice'): {user}");
}
