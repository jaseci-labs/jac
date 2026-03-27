"""Common enums for jac-scale."""

"""Supported SSO platforms."""
enum Platforms {
    GOOGLE = 'google',
    APPLE = 'apple',
    GITHUB = 'github',
}

"""SSO operations."""
enum Operations {
    LOGIN = 'login',
    REGISTER = 'register',
}
