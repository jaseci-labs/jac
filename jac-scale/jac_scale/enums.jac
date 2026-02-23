"""Common enums for jac-scale."""
import from enum { StrEnum }

"""Supported SSO platforms."""
enum Platforms ( StrEnum ) {
    GOOGLE = 'google'
}

"""SSO operations."""
enum Operations ( StrEnum ) {
    LOGIN = 'login',
    REGISTER = 'register'
}
