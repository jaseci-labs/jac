"""Walkers over the domain model."""

import from model { User, Post }

def make_user(name: str) -> User {
    return User(name=name);
}

walker Crawler {
    can scan with User entry {
        print(here.name);
    }
}
