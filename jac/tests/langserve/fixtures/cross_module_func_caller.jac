"""Imports a function from a stub module and calls it."""

import from cross_module_func { greet_user }

glob result = greet_user("Alice", "Hello", 2);
