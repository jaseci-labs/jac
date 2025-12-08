import from database { User, Post, connect, disconnect, DB_VERSION }

import from database.models { Comment }

with entry {
    print(f"Init nested - DB_VERSION: {DB_VERSION}");
    print(f"Init nested - connect('mydb'): {connect('mydb')}");
    user = User(name="Alice", email="alice@example.com");
    print(f"Init nested - User: {user}");
    post = Post(title="Hello World", author="Alice");
    print(f"Init nested - Post: {post}");
    comment = Comment(text="Great post!", author="Bob");
    print(f"Init nested - Comment: {comment}");
    print(f"Init nested - disconnect(): {disconnect()}");
}
