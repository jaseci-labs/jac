"""Example: Jac.find_nodes — server-side type and field filtering.

Run with:
    MONGODB_URI=<uri> jac start app.jac

Or without MongoDB (SQLite fallback, Python-side filter):
    jac start app.jac

The find_nodes call looks identical in both cases.
"""

import from jaclang { JacRuntime as Jac }

node User {
    has name: str = '',
        age: int = 0,
        role: str = 'user';
}

walker:pub Seed {
    """Create sample users. Call once after starting the server."""
    can run with Root entry {
        here ++> User(name='Alice', age=30, role='admin');
        here ++> User(name='Bob',   age=25, role='user');
        here ++> User(name='Carol', age=22, role='user');
        here ++> User(name='Dan',   age=17, role='user');
        report {'seeded': 4};
    }
}

walker:pub YoungUsers {
    """Return all User nodes with age < 28.

    On MongoDB this issues a single indexed query.
    On SQLite it iterates the in-memory anchor dict.
    """
    can run with Root entry {
        young: list[User] = Jac.find_nodes(User, {'age': {'$lt': 28}});
        report [{'name': u.name, 'age': u.age} for u in young];
    }
}

walker:pub AdminUsers {
    """Return all User nodes with role == 'admin'."""
    can run with Root entry {
        admins: list[User] = Jac.find_nodes(User, {'role': 'admin'});
        report [{'name': u.name, 'role': u.role} for u in admins];
    }
}

walker:pub AllUsers {
    """Return all User nodes (no field filter)."""
    can run with Root entry {
        users: list[User] = Jac.find_nodes(User);
        report [{'name': u.name, 'age': u.age} for u in users];
    }
}
