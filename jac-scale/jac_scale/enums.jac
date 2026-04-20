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

"""Supported identity types for user registration."""
enum IdentityType {
    USERNAME = 'username',
    EMAIL = 'email',
}

"""Supported credential types for user authentication."""
enum CredentialType {
    PASSWORD = 'password',
}
