"""Small social graph fixture for native JAC persistence.

Graph shape:  Root --> User --> Post
              (each User can have multiple Posts)
"""
import from jac_scale.lib { kvstore }

node User {
    has name: str,
        role: str,
        age: int;
}

node Post {
    has title: str,
        content: str;
}

walker:pub BuildGraph {
    """Build a small social graph - nodes are automatically persisted."""
    can build with Root entry {
        alice = here ++> User(name='Alice', role='admin', age=30);
        bob = here ++> User(name='Bob', role='user', age=25);

        p1 = alice ++> Post(title='Hello World', content='My first post');
        p2 = alice ++> Post(title='Jac is cool', content='Graph programming rocks');
        p3 = bob ++> Post(title='Getting started', content='Learning Jac today');

        report {'users': 2, 'posts': 3};
    }
}

walker:pub QueryGraph {
    """Query persisted nodes using find_nodes."""
    has mongo_uri: str;

    can query with Root entry {
        # Use kvstore to access the database where nodes are persisted
        db = kvstore(db_name='jac_db', db_type='mongodb', uri=self.mongo_uri);

        # Find users younger than 28
        young = list(db.find_nodes('User', {'age': {'$lt': 28}}));

        # Find admin users
        admins = list(db.find_nodes('User', {'role': 'admin'}));

        # Find all posts
        posts = list(db.find_nodes('Post', {}));

        report {'admins': admins, 'young': young, 'posts': posts};
    }
}
